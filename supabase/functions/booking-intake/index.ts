// Supabase Edge Function `booking-intake` — единая точка приёма брони.
//
// Клиенты (виджет, Telegram-бот, приложение) знают только этот HTTP-контракт
// (docs/INTEGRATION.md). Функция валидирует, вызывает RPC booking_create_order
// и рассылает бронь дальше (Telegram; позже — приложение / CRM).
//
// Задеплоена на cpjmirlujtfuzvdnysyx 2026-09-04 (v1, verify_jwt=true).
// Обновление:
//   supabase functions deploy booking-intake --project-ref cpjmirlujtfuzvdnysyx
// Для Telegram-уведомлений задать секреты:
//   supabase secrets set --project-ref cpjmirlujtfuzvdnysyx \
//     TELEGRAM_BOT_TOKEN=... TELEGRAM_CHAT_ID=... [BOOKING_INTAKE_KEY=...] [BOOKING_CORS_ORIGIN=https://booking.example]
//
// verify_jwt=true на уровне шлюза Supabase: вызывающий шлёт
// `Authorization: Bearer <anon key>` (или authenticated JWT). Функция дополнительно
// проверяет токен: при заданном BOOKING_INTAKE_KEY — точное совпадение.

import { createClient } from "jsr:@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const INTAKE_KEY = Deno.env.get("BOOKING_INTAKE_KEY") ?? "";
const CORS_ORIGIN = Deno.env.get("BOOKING_CORS_ORIGIN") ?? "*";
const TG_TOKEN = Deno.env.get("TELEGRAM_BOT_TOKEN") ?? "";
const TG_CHAT = Deno.env.get("TELEGRAM_CHAT_ID") ?? "";

const db = createClient(SUPABASE_URL, SERVICE_ROLE, {
  auth: { persistSession: false },
});

const cors = {
  "Access-Control-Allow-Origin": CORS_ORIGIN,
  "Access-Control-Allow-Headers": "authorization, content-type",
  "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
};

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, "Content-Type": "application/json" },
  });
}

/** Путь после сегмента `booking-intake` (учитывает /functions/v1/… и кастомный домен). */
function route(url: URL): string {
  const p = url.pathname;
  const i = p.indexOf("/booking-intake");
  const tail = i >= 0 ? p.slice(i + "/booking-intake".length) : p;
  return tail.replace(/\/+$/, "") || "/";
}

/** Проверка Bearer-ключа. Если INTAKE_KEY пуст — принимаем любой непустой. */
function authorized(req: Request): boolean {
  const h = req.headers.get("authorization") ?? "";
  const token = h.startsWith("Bearer ") ? h.slice(7) : "";
  if (!token) return false;
  return INTAKE_KEY ? token === INTAKE_KEY : true;
}

/** Ошибку RPC booking_create_order превращаем в контрактный ответ. */
function reservationError(err: { code?: string; message?: string }): Response {
  const code = err.code ?? "";
  const msg = err.message ?? "";
  if (code === "23P01") return json({ error: "SLOT_TAKEN" }, 409);
  if (msg.includes("DISCOUNT_MIN_STATIONS")) {
    const n = parseInt(msg.replace(/\D/g, ""), 10) || 1;
    return json({ error: "DISCOUNT_MIN_STATIONS", required_stations: n }, 422);
  }
  if (msg.includes("DISCOUNT_NOT_FOUND")) return json({ error: "DISCOUNT_NOT_FOUND" }, 422);
  for (const e of ["OUTSIDE_WORKING_HOURS", "STARTS_IN_PAST", "BAD_DURATION", "NO_STATIONS", "STATION_NOT_IN_CLUB", "CLUB_NOT_FOUND"]) {
    if (msg.includes(e)) return json({ error: e }, 422);
  }
  return json({ error: "UNEXPECTED", detail: msg }, 500);
}

async function notifyTelegram(text: string): Promise<void> {
  if (!TG_TOKEN || !TG_CHAT) return;
  try {
    await fetch(`https://api.telegram.org/bot${TG_TOKEN}/sendMessage`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ chat_id: TG_CHAT, text, parse_mode: "HTML" }),
    });
  } catch (_) {
    // Уведомление не должно влиять на успех брони.
  }
}

Deno.serve(async (req: Request): Promise<Response> => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (!authorized(req)) return json({ error: "UNAUTHORIZED" }, 401);

  const url = new URL(req.url);
  const path = route(url);
  const q = url.searchParams;

  try {
    // ---- GET /clubs ----
    if (req.method === "GET" && path === "/clubs") {
      const { data, error } = await db
        .from("booking_clubs")
        .select("id,slug,name,timezone,open_time,close_time,slot_gap_minutes,sort_order")
        .eq("is_active", true)
        .order("sort_order")
        .order("name");
      if (error) return json({ error: "DB", detail: error.message }, 500);
      return json(data);
    }

    // ---- GET /stations?club_id= ----
    if (req.method === "GET" && path === "/stations") {
      const clubId = q.get("club_id");
      if (!clubId) return json({ error: "club_id required" }, 400);
      const { data, error } = await db
        .from("booking_stations")
        .select("id,room_id,type,label,row_index,position_in_row,sort_order,is_active,booking_rooms!inner(name,club_id)")
        .eq("booking_rooms.club_id", clubId)
        .order("sort_order");
      if (error) return json({ error: "DB", detail: error.message }, 500);
      const flat = (data ?? []).map((s: Record<string, unknown>) => ({
        id: s.id, room_id: s.room_id, type: s.type, label: s.label,
        row_index: s.row_index, position_in_row: s.position_in_row,
        sort_order: s.sort_order, is_active: s.is_active,
        room_name: (s.booking_rooms as { name?: string } | null)?.name ?? "",
      }));
      return json(flat);
    }

    // ---- GET /prices?club_id= ----
    if (req.method === "GET" && path === "/prices") {
      const clubId = q.get("club_id");
      if (!clubId) return json({ error: "club_id required" }, 400);
      const { data, error } = await db
        .from("booking_prices")
        .select("station_type,day_kind,price_per_hour")
        .eq("club_id", clubId);
      if (error) return json({ error: "DB", detail: error.message }, 500);
      return json(data);
    }

    // ---- GET /availability?club_id=&day= ----
    if (req.method === "GET" && path === "/availability") {
      const clubId = q.get("club_id");
      const day = q.get("day");
      if (!clubId || !day) return json({ error: "club_id and day required" }, 400);
      const { data, error } = await db.rpc("booking_busy_intervals", {
        p_club_id: clubId,
        p_day: day,
      });
      if (error) return json({ error: "DB", detail: error.message }, 500);
      return json(data);
    }

    // ---- POST /discount/validate ----
    if (req.method === "POST" && path === "/discount/validate") {
      const body = await req.json();
      const { data, error } = await db.rpc("booking_validate_discount", {
        p_code: body.code ?? null,
        p_station_count: body.station_count ?? 0,
      });
      if (error) {
        if (error.message?.includes("DISCOUNT_MIN_STATIONS")) {
          const n = parseInt(error.message.replace(/\D/g, ""), 10) || 1;
          return json({ error: "DISCOUNT_MIN_STATIONS", required_stations: n }, 422);
        }
        if (error.message?.includes("DISCOUNT_NOT_FOUND")) {
          return json({ error: "DISCOUNT_NOT_FOUND" }, 422);
        }
        return json({ error: "DB", detail: error.message }, 500);
      }
      const row = Array.isArray(data) ? data[0] : data;
      return json({ discount: row ?? null });
    }

    // ---- POST /reservations ----
    if (req.method === "POST" && path === "/reservations") {
      const b = await req.json();
      const { data, error } = await db.rpc("booking_create_order", {
        p_club_id: b.club_id,
        p_client_name: b.client_name,
        p_client_phone: b.client_phone,
        p_station_ids: b.station_ids,
        p_starts_at: b.starts_at,
        p_minutes: b.minutes,
        p_people_count: b.people_count ?? null,
        p_discount_code: b.discount_code ?? null,
        p_comment: b.comment ?? null,
        p_source: b.source ?? "site",
      });
      if (error) return reservationError(error);

      const orderId = data as string;
      const stations = Array.isArray(b.station_ids) ? b.station_ids.length : 0;
      await notifyTelegram(
        `🎮 <b>Новая бронь</b>\n` +
          `${b.client_name} · ${b.client_phone}\n` +
          `${stations} ст. · ${b.minutes} мин · с ${b.starts_at}\n` +
          `источник: ${b.source ?? "site"} · №${String(orderId).slice(0, 8)}`,
      );
      return json({ order_id: orderId }, 201);
    }

    return json({ error: "NOT_FOUND", path }, 404);
  } catch (e) {
    return json({ error: "UNEXPECTED", detail: String(e) }, 500);
  }
});
