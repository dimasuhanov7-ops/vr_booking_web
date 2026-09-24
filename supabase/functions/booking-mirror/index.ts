// Supabase Edge Function `booking-mirror` — зеркало броней в Google Таблицу
// и уведомления в служебный Telegram-чат.
//
// Вызывается только из базы (pg_net): триггер `booking_orders_mirror` на каждую
// новую бронь, отмену и правку — с {"order_id": "..."}, и pg_cron раз в сутки —
// с {"mode": "resync"}. Настройка — docs/MIRROR.md.
//
// Функция не доверяет телу запроса: берёт из него только id заказа и сама
// перечитывает заказ из базы. Вызов подписан секретом из Vault
// (заголовок x-mirror-secret), поэтому verify_jwt выключен.
//
// Google Таблица ведётся через Apps Script внутри самой таблицы
// (tool/google_apps_script/booking_mirror.gs), опубликованный как веб-приложение:
// Google Cloud и сервисный аккаунт не нужны.
//
// Секреты функции (Supabase → Edge Functions → Secrets):
//   GOOGLE_SCRIPT_URL    — адрес веб-приложения Apps Script (…/exec);
//   GOOGLE_SCRIPT_SECRET — секрет из setupSecret() в скрипте;
//   TELEGRAM_BOT_TOKEN, TELEGRAM_CHAT_ID — бот и служебный чат;
//   TELEGRAM_THREAD_ID   — (необязательно) тема в группе с темами.
// Без Google-секретов таблица не ведётся, без Telegram — уведомлений нет;
// одно без другого работает.

import { createClient } from "jsr:@supabase/supabase-js@2";

const db = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  { auth: { persistSession: false } },
);

/** Секрет из панели: пробел или перенос строки при вставке ломают адрес и токены. */
const secret = (name: string) => (Deno.env.get(name) ?? "").trim();

const SCRIPT_URL = secret("GOOGLE_SCRIPT_URL");
const SCRIPT_SECRET = secret("GOOGLE_SCRIPT_SECRET");
const TG_TOKEN = secret("TELEGRAM_BOT_TOKEN");
const TG_CHAT = secret("TELEGRAM_CHAT_ID");
const TG_THREAD = Number(secret("TELEGRAM_THREAD_ID"));

/** Паузы перед повторами записи в таблицу: Google изредка отвечает 404/5xx
 * на отдаче результата, хотя сам скрипт доступен. */
const SHEET_RETRY_DELAYS_MS = [2000, 6000];

const STATUS: Record<string, string> = {
  confirmed: "подтверждена",
  cancelled: "отменена",
  completed: "завершена",
  no_show: "не пришёл",
};
const SOURCE: Record<string, string> = {
  site: "сайт",
  vk: "ВК",
  app: "приложение",
  tg: "Telegram",
  staff: "админка",
};

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

const ORDER_SELECT =
  "id,created_at,status,source,client_name,client_phone,people_count,comment,prepay," +
  "booking_clubs(name,timezone),booking_packages(name,price)," +
  "booking_order_items(station_id,starts_at,ends_at,price,booking_stations(type,booking_rooms(name)))";

type Item = {
  station_id: string;
  starts_at: string;
  ends_at: string;
  price: number | string | null;
  booking_stations: { type: string; booking_rooms: { name: string } | null } | null;
};

type Order = {
  id: string;
  created_at: string;
  status: string;
  source: string;
  client_name: string;
  client_phone: string;
  people_count: number | null;
  comment: string | null;
  prepay: number | null;
  booking_clubs: { name: string; timezone: string } | null;
  booking_packages: { name: string; price: number | string } | null;
  booking_order_items: Item[] | null;
};

type Cell = string | number;

// ---------------------------------------------------------------- вход ----

let cachedSecret = "";

async function expectedSecret(): Promise<string> {
  if (cachedSecret) return cachedSecret;
  const { data, error } = await db.rpc("booking_mirror_secret");
  if (error || typeof data !== "string") return "";
  cachedSecret = data;
  return data;
}

function safeEqual(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return diff === 0;
}

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

/** Задачи выполняются по очереди в пределах экземпляра функции. */
let queue: Promise<void> = Promise.resolve();

Deno.serve(async (req: Request): Promise<Response> => {
  if (req.method !== "POST") return json({ error: "METHOD" }, 405);

  const given = req.headers.get("x-mirror-secret") ?? "";
  const expected = await expectedSecret();
  if (!expected || !safeEqual(given, expected)) {
    return json({ error: "UNAUTHORIZED" }, 401);
  }

  let body: { order_id?: unknown; mode?: unknown } = {};
  try {
    body = await req.json();
  } catch {
    // пустое тело — ниже ответим 400
  }

  let job: () => Promise<void>;
  if (body.mode === "resync") {
    job = resync;
  } else if (typeof body.order_id === "string" && UUID.test(body.order_id)) {
    const id = body.order_id;
    job = () => syncOrder(id);
  } else {
    return json({ error: "BAD_REQUEST" }, 400);
  }

  queue = queue
    .then(job)
    .catch((e) => console.error("booking-mirror:", String(e)));

  // Отвечаем сразу и доделываем в фоне: pg_net не должен ждать Google.
  const runtime = (globalThis as {
    EdgeRuntime?: { waitUntil(p: Promise<unknown>): void };
  }).EdgeRuntime;
  if (runtime) {
    runtime.waitUntil(queue);
    return json({ accepted: true }, 202);
  }
  await queue;
  return json({ done: true });
});

// ------------------------------------------------------------- сценарии ----

async function syncOrder(id: string): Promise<void> {
  const { data, error } = await db
    .from("booking_orders")
    .select(ORDER_SELECT)
    .eq("id", id)
    .maybeSingle();
  if (error) throw new Error(`db: ${error.message}`);
  if (!data) return;
  const order = data as unknown as Order;

  try {
    await notify(order);
  } catch (e) {
    console.error("booking-mirror telegram:", String(e));
  }

  if (sheetEnabled()) {
    await pushRows("upsert", [row(order)]);
    await markSynced([order.id]);
  }
}

async function resync(): Promise<void> {
  if (!sheetEnabled()) return;
  const { data, error } = await db
    .from("booking_orders")
    .select(ORDER_SELECT)
    .order("created_at", { ascending: true })
    .limit(5000);
  if (error) throw new Error(`db: ${error.message}`);
  const orders = (data ?? []) as unknown as Order[];

  await pushRows("resync", orders.map(row));
  await markSynced(orders.map((o) => o.id));
}

async function markSynced(ids: string[]): Promise<void> {
  const at = new Date().toISOString();
  for (let i = 0; i < ids.length; i += 500) {
    const { error } = await db
      .from("booking_mirror_state")
      .upsert(
        ids.slice(i, i + 500).map((id) => ({ order_id: id, synced_at: at })),
        { onConflict: "order_id" },
      );
    if (error) throw new Error(`db state: ${error.message}`);
  }
}

// -------------------------------------------------------------- данные ----

function plural(n: number, one: string, few: string, many: string): string {
  const m10 = n % 10;
  const m100 = n % 100;
  if (m10 === 1 && m100 !== 11) return one;
  if (m10 >= 2 && m10 <= 4 && (m100 < 12 || m100 > 14)) return few;
  return many;
}

function money(n: number): string {
  return `${new Intl.NumberFormat("ru-RU").format(Math.round(n))} ₽`;
}

function clock(iso: string, tz: string) {
  const f = new Intl.DateTimeFormat("ru-RU", {
    timeZone: tz,
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
    hour: "2-digit",
    minute: "2-digit",
    hourCycle: "h23",
  });
  const p = Object.fromEntries(
    f.formatToParts(new Date(iso)).map((x) => [x.type, x.value]),
  );
  return {
    date: `${p.year}-${p.month}-${p.day}`,
    day: `${p.day}.${p.month}`,
    time: `${p.hour}:${p.minute}`,
  };
}

function summarize(o: Order) {
  const tz = o.booking_clubs?.timezone || "Asia/Yekaterinburg";
  const items = o.booking_order_items ?? [];
  let start = Number.POSITIVE_INFINITY;
  let end = Number.NEGATIVE_INFINITY;
  let itemsSum = 0;
  const rooms = new Map<string, { vr: Set<string>; ps: Set<string> }>();

  for (const it of items) {
    start = Math.min(start, Date.parse(it.starts_at));
    end = Math.max(end, Date.parse(it.ends_at));
    itemsSum += Number(it.price ?? 0);
    const name = it.booking_stations?.booking_rooms?.name ?? "Зал";
    const r = rooms.get(name) ?? { vr: new Set<string>(), ps: new Set<string>() };
    (it.booking_stations?.type === "ps5" ? r.ps : r.vr).add(it.station_id);
    rooms.set(name, r);
  }

  const composition = [...rooms]
    .map(([name, r]) => {
      const parts = [
        r.vr.size ? `${r.vr.size} ${plural(r.vr.size, "шлем", "шлема", "шлемов")}` : "",
        r.ps.size ? `${r.ps.size} PS5` : "",
      ].filter(Boolean);
      return `${name}: ${parts.join(" + ")}`;
    })
    .join("; ");

  const hasTime = Number.isFinite(start) && Number.isFinite(end);
  const from = hasTime ? clock(new Date(start).toISOString(), tz) : null;
  const to = hasTime ? clock(new Date(end).toISOString(), tz) : null;
  const cost = o.booking_packages
    ? Number(o.booking_packages.price)
    : Math.round(itemsSum);

  return {
    tz,
    composition,
    cost,
    date: from?.date ?? "",
    day: from?.day ?? "",
    time: from && to ? `${from.time}–${to.time}` : "",
  };
}

/** Строка таблицы. Порядок колонок — как HEADER в booking_mirror.gs. */
function row(o: Order): Cell[] {
  const s = summarize(o);
  const created = clock(o.created_at, s.tz);
  const now = clock(new Date().toISOString(), s.tz);
  const pack = o.booking_packages ? ` (пакет «${o.booking_packages.name}»)` : "";
  return [
    s.date,
    s.time,
    o.booking_clubs?.name ?? "",
    s.composition + pack,
    o.client_name ?? "",
    o.client_phone ?? "",
    o.people_count ?? "",
    STATUS[o.status] ?? o.status,
    SOURCE[o.source] ?? o.source,
    s.cost,
    o.prepay ?? 0,
    o.comment ?? "",
    `${created.date} ${created.time}`,
    `${now.date} ${now.time}`,
    o.id,
  ];
}

// ------------------------------------------------------------ Telegram ----

function esc(s: string): string {
  return s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
}

async function notify(o: Order): Promise<void> {
  if (!TG_TOKEN || !TG_CHAT) return;

  const { data: prev, error } = await db.rpc("booking_mirror_claim_notice", {
    p_order_id: o.id,
    p_status: o.status,
  });
  if (error) throw new Error(`claim: ${error.message}`);
  if (prev === null) return; // об этом статусе уже написали

  const s = summarize(o);
  const club = esc(o.booking_clubs?.name ?? "");
  const who = `${esc(o.client_name ?? "")} · ${esc(o.client_phone ?? "")}`;
  const when = `${s.day}, ${s.time}`;

  let text: string | null = null;
  if (o.status === "confirmed" && prev === "") {
    const lines = [
      `🎮 <b>Новая бронь</b> · ${club}`,
      when,
      esc(s.composition),
      who,
      `${SOURCE[o.source] ?? esc(o.source)} · ${money(s.cost)}` +
        (o.prepay ? ` · предоплата ${money(o.prepay)}` : ""),
    ];
    if (o.comment) lines.push(`💬 ${esc(o.comment)}`);
    text = lines.join("\n");
  } else if (o.status === "cancelled" && prev !== "") {
    text = [`❌ <b>Бронь отменена</b> · ${club}`, when, who].join("\n");
  } else if (o.status === "confirmed" && prev === "cancelled") {
    text = [`↩️ <b>Бронь возвращена</b> · ${club}`, when, who].join("\n");
  }
  if (!text) return;

  const res = await fetch(`https://api.telegram.org/bot${TG_TOKEN}/sendMessage`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      chat_id: TG_CHAT,
      // В группе с темами — в заданную тему, иначе в «General».
      ...(Number.isInteger(TG_THREAD) && TG_THREAD > 0
        ? { message_thread_id: TG_THREAD }
        : {}),
      text,
      parse_mode: "HTML",
      disable_web_page_preview: true,
    }),
  });
  if (!res.ok) {
    // Описание ошибки Telegram не содержит токена и данных клиента.
    const detail = await res.text().catch(() => "");
    throw new Error(`telegram ${res.status}: ${detail.slice(0, 200)}`);
  }
}

// -------------------------------------------------------- Google Таблица ----

function sheetEnabled(): boolean {
  // Только адрес Apps Script: секрет с данными не должен уйти на чужой адрес.
  return SCRIPT_URL.startsWith("https://script.google.com/") && SCRIPT_SECRET !== "";
}

/** Форма адреса для логов: длинные сегменты (идентификатор скрипта) скрыты,
 * видно только строение — /macros/s/<72>/exec, /dev, /u/0/ и т. п. */
function urlShape(u: string): string {
  try {
    const x = new URL(u);
    const path = x.pathname
      .split("/")
      .map((s) => (s.length > 12 ? `<${s.length}>` : s))
      .join("/");
    return `${x.host}${path}`;
  } catch {
    return "invalid-url";
  }
}

/** Отправить строки в Apps Script таблицы с повторами при сбое. Повторять
 * безопасно: скрипт находит строку по ID заказа и не создаёт дублей. */
async function pushRows(mode: "upsert" | "resync", rows: Cell[][]): Promise<void> {
  if (rows.length === 0 && mode === "upsert") return;
  let lastError: unknown;
  for (let attempt = 0; attempt <= SHEET_RETRY_DELAYS_MS.length; attempt++) {
    if (attempt > 0) {
      await new Promise((r) => setTimeout(r, SHEET_RETRY_DELAYS_MS[attempt - 1]));
    }
    try {
      await pushOnce(mode, rows);
      return;
    } catch (e) {
      lastError = e;
    }
  }
  throw lastError;
}

/** Одна попытка. Веб-приложение отвечает 200 даже на ошибку, поэтому смотрим
 * на поле ok в ответе. */
async function pushOnce(mode: "upsert" | "resync", rows: Cell[][]): Promise<void> {
  const res = await fetch(SCRIPT_URL, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ secret: SCRIPT_SECRET, mode, rows }),
    redirect: "follow",
  });
  const text = await res.text();
  let body: { ok?: boolean; error?: string } = {};
  try {
    body = JSON.parse(text);
  } catch {
    throw new Error(
      `apps script ${res.status} [${urlShape(SCRIPT_URL)} → ${urlShape(res.url)}]: ` +
        `ответ не JSON`,
    );
  }
  if (!body.ok) throw new Error(`apps script: ${body.error ?? res.status}`);
}
