// Извлечено дословно из Claude Design canvas «Админка VR.dc.html»
// (проект 8d5d5ffe-dca2-44b9-9385-3fac38fbaae5), снято 2026-09-04.
// Логика прототипа админки: данные, тарифы/пакеты, расчёт «по часам», фильтры
// журнала записей. Эталон для lib/features/admin/. Компаньон: admin-widget.template.html
// Разбор и расхождения с docs/ADMIN_TASK.md — в design/ADMIN_DESIGN_SPEC.md

const CLUBS = [
  { id: "effect", name: "Effect VR", hours: "11:00 – 22:30", open: 660, close: 1350, gap: 10,
    halls: [{ id: "e-main", name: "Зал", helmets: 4, ps5: 2 }] },
  { id: "vray", name: "V-Ray", hours: "11:00 – 23:00", open: 660, close: 1380, gap: 0,
    halls: [{ id: "v-big", name: "Большой зал", helmets: 12, ps5: 0 }, { id: "v-small", name: "Малый зал", helmets: 4, ps5: 2 }] }
];
const DOW = ["вс", "пн", "вт", "ср", "чт", "пт", "сб"];
const MON = ["янв", "фев", "мар", "апр", "мая", "июн", "июл", "авг", "сен", "окт", "ноя", "дек"];
const MONL = ["января", "февраля", "марта", "апреля", "мая", "июня", "июля", "августа", "сентября", "октября", "ноября", "декабря"];
const hhmm = (m) => String(Math.floor(m / 60)).padStart(2, "0") + ":" + String(m % 60).padStart(2, "0");
const money = (n) => n.toLocaleString("ru-RU").replace(/,/g, " ") + " ₽";
const plural = (n, one, few, many) => { const m10 = n % 10, m100 = n % 100; if (m10 === 1 && m100 !== 11) return one; if (m10 >= 2 && m10 <= 4 && (m100 < 12 || m100 > 14)) return few; return many; };
const helmets = (n) => n + " " + plural(n, "шлем", "шлема", "шлемов");
const seats = (n) => n + " " + plural(n, "место", "места", "мест");
const stations = (n) => n + " " + plural(n, "станция", "станции", "станций");
const isWeekend = (d) => d.getDay() === 0 || d.getDay() === 6;
const num = (v, d) => { const n = parseInt(String(v).replace(/\D/g, ""), 10); return isNaN(n) ? d : n; };

// SEED — данные вкладки «Брони» (операционный список на выбранный день).
const SEED = [
  { id: "b1", club: "vray", time: 720, name: "Игорь", phone: "+7 (912) 344-11-08", hall: "Большой зал", n: 7, dur: 60, disc: "пакет «Компания»", discPct: 15 },
  { id: "b2", club: "vray", time: 900, name: "Настя", phone: "+7 (903) 771-20-64", hall: "Малый зал", n: 4, dur: 120, disc: "", discPct: 0 },
  { id: "b3", club: "vray", time: 1140, name: "Дима", phone: "+7 (999) 208-45-31", hall: "Большой зал", n: 12, dur: 60, disc: "", discPct: 0 },
  { id: "b4", club: "effect", time: 780, name: "Лена", phone: "+7 (905) 613-77-42", hall: "Зал", n: 4, dur: 60, disc: "", discPct: 0 },
  { id: "b5", club: "effect", time: 1200, name: "Артём", phone: "+7 (962) 480-15-93", hall: "Зал", n: 6, dur: 120, disc: "пакет «Компания»", discPct: 10 }
];

// LOG — данные вкладки «Записи» (журнал + агрегаты KPI). day: 0/1/2 от базовой даты.
const LOG = [
  { id: "l1", club: "vray", hall: "v-big", day: 0, time: 720, dur: 120, vr: 6, ps5: 0, name: "Игорь", phone: "+7 (912) 344-11-08", pack: "Команда", status: "paid", src: "виджет" },
  { id: "l2", club: "vray", hall: "v-small", day: 0, time: 900, dur: 120, vr: 3, ps5: 1, name: "Настя", phone: "+7 (903) 771-20-64", pack: "", status: "confirmed", src: "виджет" },
  { id: "l3", club: "vray", hall: "v-big", day: 0, time: 1140, dur: 60, vr: 12, ps5: 0, name: "Дима", phone: "+7 (999) 208-45-31", pack: "", status: "new", src: "звонок" },
  { id: "l4", club: "vray", hall: "v-small", day: 1, time: 780, dur: 60, vr: 0, ps5: 2, name: "Кирилл", phone: "+7 (964) 112-90-77", pack: "", status: "confirmed", src: "виджет" },
  { id: "l5", club: "vray", hall: "v-big", day: 1, time: 1020, dur: 120, vr: 12, ps5: 0, name: "Марина", phone: "+7 (908) 555-31-20", pack: "Арена", status: "paid", src: "виджет" },
  { id: "l6", club: "vray", hall: "v-small", day: 2, time: 660, dur: 60, vr: 4, ps5: 2, name: "Олег", phone: "+7 (917) 604-18-52", pack: "", status: "new", src: "звонок" },
  { id: "l7", club: "effect", hall: "e-main", day: 0, time: 780, dur: 60, vr: 4, ps5: 0, name: "Лена", phone: "+7 (905) 613-77-42", pack: "", status: "confirmed", src: "виджет" },
  { id: "l8", club: "effect", hall: "e-main", day: 0, time: 1200, dur: 120, vr: 4, ps5: 2, name: "Артём", phone: "+7 (962) 480-15-93", pack: "Полный зал", status: "paid", src: "виджет" },
  { id: "l9", club: "effect", hall: "e-main", day: 1, time: 900, dur: 60, vr: 0, ps5: 2, name: "Соня", phone: "+7 (951) 220-64-09", pack: "", status: "new", src: "виджет" },
  { id: "l10", club: "effect", hall: "e-main", day: 2, time: 1080, dur: 120, vr: 2, ps5: 0, name: "Паша", phone: "+7 (926) 337-45-11", pack: "", status: "confirmed", src: "звонок" }
];
const STATUS = { new: { label: "новая", c: "#FFC98A", bg: "#1E1610", bd: "#3A2A1C" }, confirmed: { label: "подтверждена", c: "#8BEFCB", bg: "#0C1A16", bd: "#1E3A31" }, paid: { label: "оплачена", c: "#A9F04A", bg: "#141A0C", bd: "#2C3A1C" } };

class Component extends DCLogic {
  state = {
    tab: "prices", clubId: "vray", dayIdx: 0,
    logDay: "all", logHall: "all", logType: "all", logStatus: "all",
    prices: {
      "e-main": { wd: { vr: 1400, ps5: 1000 }, we: { vr: 1700, ps5: 1200 } },
      "v-big": { wd: { vr: 1400, ps5: 1000 }, we: { vr: 1700, ps5: 1200 } },
      "v-small": { wd: { vr: 1400, ps5: 1000 }, we: { vr: 1700, ps5: 1200 } }
    },
    packs: [
      { id: "p1", club: "effect", hall: "e-main", name: "Вдвоём", vr: 2, ps5: 0, dur: 120, price: 5000, on: true },
      { id: "p2", club: "effect", hall: "e-main", name: "Компания", vr: 4, ps5: 0, dur: 120, price: 10000, on: true },
      { id: "p3", club: "effect", hall: "e-main", name: "Полный зал", vr: 4, ps5: 2, dur: 120, price: 14000, on: true },
      { id: "p4", club: "vray", hall: "v-big", name: "Команда", vr: 6, ps5: 0, dur: 120, price: 14000, on: true },
      { id: "p5", club: "vray", hall: "v-big", name: "Арена", vr: 12, ps5: 0, dur: 120, price: 26000, on: true },
      { id: "p6", club: "vray", hall: "v-small", name: "Малый зал целиком", vr: 4, ps5: 2, dur: 120, price: 14000, on: true },
      { id: "p7", club: "vray", hall: "v-small", name: "Шлемы и PS5", vr: 2, ps5: 2, dur: 60, price: 4300, on: true }
    ],
    newPack: { name: "", hall: "", vr: 2, ps5: 0, dur: 60, price: 5000 }, packMsg: "",
    intake: true, closedHalls: [], closedSlots: [], cancelled: []
  };

  club() { return CLUBS.find((c) => c.id === this.state.clubId); }
  days() { const base = new Date(2026, 8, 3); return Array.from({ length: 14 }, (_, i) => { const d = new Date(base); d.setDate(base.getDate() + i); return d; }); }
  slots() { const c = this.club(); const out = []; for (let t = c.open; t + 60 <= c.close; t += 60 + c.gap) out.push(t); return out; }
  slotKey(t) { return this.state.clubId + "-" + this.state.dayIdx + "-" + t; }

  newHall() {
    const halls = this.club().halls;
    return halls.find((h) => h.id === this.state.newPack.hall) || halls[0];
  }

  logVals(A, At, Atx, days) {
    const st = this.state, club = this.club();
    const chip = (on) => "padding:7px 12px; border-radius:9px; cursor:pointer; font-size:13px; font-weight:600; white-space:nowrap; border:1px solid " + (on ? A : "#2A2C33") + "; background:" + (on ? At + "0.16)" : "transparent") + "; color:" + (on ? Atx : "#9A9AA6");
    const rate = (h, d, key) => st.prices[h][isWeekend(d) ? "we" : "wd"][key];
    const hourly = (e) => {
      const d = days[e.day];
      return Math.round(((rate(e.hall, d, "vr") * e.vr + rate(e.hall, d, "ps5") * e.ps5) * e.dur) / 60);
    };
    const packOf = (e) => (e.pack ? st.packs.find((p) => p.name === e.pack && p.club === e.club && p.hall === e.hall && p.vr === e.vr && p.ps5 === e.ps5 && p.dur === e.dur) : null);
    const cost = (e) => { const p = packOf(e); return p ? p.price : hourly(e); };

    const rows = LOG.filter((e) => e.club === club.id)
      .filter((e) => st.logDay === "all" || e.day === st.logDay)
      .filter((e) => st.logHall === "all" || e.hall === st.logHall)
      .filter((e) => st.logType === "all" || (st.logType === "vr" ? e.vr > 0 : e.ps5 > 0))
      .filter((e) => st.logStatus === "all" || e.status === st.logStatus)
      .sort((a, b) => a.day - b.day || a.time - b.time);
    const live = rows.filter((e) => st.cancelled.indexOf(e.id) === -1);
    const sum = (f) => live.reduce((a, e) => a + f(e), 0);

    const filters = [
      { label: "день", cur: st.logDay, key: "logDay", options: [{ v: "all", l: "все" }].concat(days.slice(0, 5).map((dd, i) => ({ v: i, l: DOW[dd.getDay()] + " " + dd.getDate() }))) },
      { label: "зал", cur: st.logHall, key: "logHall", options: [{ v: "all", l: "все залы" }].concat(club.halls.map((h) => ({ v: h.id, l: h.name }))) },
      { label: "тип", cur: st.logType, key: "logType", options: [{ v: "all", l: "всё" }, { v: "vr", l: "со шлемами" }, { v: "ps5", l: "с PS5" }] },
      { label: "статус", cur: st.logStatus, key: "logStatus", options: [{ v: "all", l: "любой" }, { v: "new", l: "новые" }, { v: "confirmed", l: "подтверждённые" }, { v: "paid", l: "оплаченные" }] }
    ];

    return {
      logFilters: filters.map((f) => ({
        label: f.label,
        options: f.options.map((o) => ({ label: o.l, style: chip(f.cur === o.v), onClick: () => this.setState({ [f.key]: o.v }) }))
      })),
      logStats: [
        { label: "записей", value: String(live.length), note: rows.length !== live.length ? "+ " + (rows.length - live.length) + " отменено" : "по фильтрам" },
        { label: "шлемов занято", value: String(sum((e) => e.vr)), note: "суммарно по записям" },
        { label: "PS5 занято", value: String(sum((e) => e.ps5)), note: "суммарно по записям" },
        { label: "часов сеансов", value: String(sum((e) => e.dur) / 60), note: "суммарная длительность" },
        { label: "станций-часов", value: String(sum((e) => ((e.vr + e.ps5) * e.dur) / 60)), note: "станции × длительность" },
        { label: "сумма", value: money(sum(cost)), note: "по текущему тарифу" }
      ].map((s) => ({ ...s, valStyle: "font-size:24px; font-weight:800; font-variant-numeric:tabular-nums; margin-top:6px; color:" + Atx })),
      logMeta: club.name + " · " + live.length + " " + plural(live.length, "активная", "активные", "активных"),
      logEmpty: rows.length === 0,
      logRows: rows.map((e) => {
        const off = st.cancelled.indexOf(e.id) > -1;
        const d = days[e.day], stt = STATUS[e.status];
        const hall = club.halls.find((h) => h.id === e.hall);
        const tag = (label, tone) => ({
          label,
          style: "padding:5px 9px; border-radius:8px; font-size:12px; font-weight:600; border:1px solid " + (tone === "acc" ? At + "0.35)" : "#2A2C33") + "; background:" + (tone === "acc" ? At + "0.1)" : "#0C0E11") + "; color:" + (tone === "acc" ? Atx : "#9A9AA6")
        });
        return {
          time: hhmm(e.time) + "–" + hhmm(e.time + e.dur),
          date: DOW[d.getDay()] + ", " + d.getDate() + " " + MON[d.getMonth()],
          name: e.name, contact: e.phone + " · " + e.src,
          status: off ? "отменена" : stt.label,
          statusStyle: "padding:4px 9px; border-radius:7px; font-size:11px; font-weight:700; letter-spacing:0.04em; text-transform:uppercase; border:1px solid " + (off ? "#3A2226" : stt.bd) + "; background:" + (off ? "#1B1114" : stt.bg) + "; color:" + (off ? "#FF9BA6" : stt.c),
          chips: [
            tag(hall ? hall.name : e.hall),
            e.vr ? tag("VR " + helmets(e.vr), "acc") : null,
            e.ps5 ? tag("PS5 × " + e.ps5, "acc") : null,
            tag(e.dur / 60 + " ч"),
            e.pack ? tag("пакет «" + e.pack + "»") : null
          ].filter(Boolean),
          total: money(cost(e)),
          pay: packOf(e) ? "фикс. цена пакета" : e.pack ? "состав не совпал с пакетом · по часам" : "почасовая оплата",
          cancelLabel: off ? "Вернуть" : "Отменить",
          cancelStyle: "margin-top:9px; padding:8px 11px; border-radius:9px; cursor:pointer; font-size:12px; font-weight:600; border:1px solid " + (off ? "#2A2C33" : "#3A2226") + "; background:" + (off ? "transparent" : "#1B1114") + "; color:" + (off ? "#C9C9D2" : "#FF9BA6"),
          onCancel: () => this.setState((s) => ({ cancelled: off ? s.cancelled.filter((x) => x !== e.id) : s.cancelled.concat(e.id) })),
          rowStyle: "display:flex; flex-wrap:wrap; gap:14px; justify-content:space-between; align-items:flex-start; padding:16px 18px; border-bottom:1px solid #1A1B20; opacity:" + (off ? "0.45" : "1")
        };
      })
    };
  }

  renderVals() {
    const st = this.state, club = this.club();
    const A = club.id === "vray" ? "#0FB981" : "#A9F04A";
    const At = club.id === "vray" ? "rgba(15,185,129," : "rgba(169,240,74,";
    const Atx = club.id === "vray" ? "#8BEFCB" : "#DDFCAE";
    const tab = (on, extra) => "padding:10px 15px; border-radius:11px; border:1px solid " + (on ? A : "#2A2C33") + "; background:" + (on ? At + "0.16)" : "transparent") + "; color:" + (on ? Atx : "#9A9AA6") + "; font-size:14px; font-weight:600; cursor:pointer; white-space:nowrap; flex:none;" + (extra || "");
    const sw = (on) => ({
      switchStyle: "flex:none; width:50px; height:29px; border-radius:15px; border:1px solid " + (on ? A : "#2A2C33") + "; background:" + (on ? At + "0.28)" : "#15171B") + "; padding:2px; cursor:pointer; display:flex; justify-content:" + (on ? "flex-end" : "flex-start"),
      knobStyle: "display:block; width:23px; height:23px; border-radius:50%; background:" + (on ? A : "#4E505A")
    });
    const days = this.days(), d = days[st.dayIdx];

    return {
      clubTabs: CLUBS.map((c) => ({
        label: c.name,
        style: "padding:8px 13px; border-radius:9px; border:1px solid " + (st.clubId === c.id ? (c.id === "vray" ? "#0FB981" : "#A9F04A") : "#2A2C33") + "; background:" + (st.clubId === c.id ? (c.id === "vray" ? "rgba(15,185,129,0.16)" : "rgba(169,240,74,0.16)") : "transparent") + "; color:" + (st.clubId === c.id ? (c.id === "vray" ? "#8BEFCB" : "#DDFCAE") : "#8A8A96") + "; font-size:13px; font-weight:600; cursor:pointer",
        onClick: () => this.setState({ clubId: c.id })
      })),

      tabs: [
        { id: "prices", label: "Цены" }, { id: "packs", label: "Пакеты" },
        { id: "avail", label: "Доступность" }, { id: "bookings", label: "Брони" },
        { id: "log", label: "Записи" }
      ].map((t) => ({ label: t.label, style: tab(st.tab === t.id), onClick: () => this.setState({ tab: t.id }) })),

      isPrices: st.tab === "prices", isPacks: st.tab === "packs",
      isAvail: st.tab === "avail", isBookings: st.tab === "bookings", isLog: st.tab === "log",

      ...this.logVals(A, At, Atx, days),

      priceCards: club.halls.map((h) => ({
        title: h.name, meta: club.name,
        hint: helmets(h.helmets) + (h.ps5 ? " и " + h.ps5 + " PS5" : ""),
        rows: [
          { key: "vr", label: "VR-шлем", sub: "за 1 час, одна станция" },
          h.ps5 ? { key: "ps5", label: "PS5", sub: "за 1 час, одна приставка" } : null
        ].filter(Boolean).map((r) => ({
          label: r.label, sub: r.sub,
          cells: [{ t: "wd", hint: "будни" }, { t: "we", hint: "выходные" }].map((c) => ({
            value: String(st.prices[h.id][c.t][r.key]), hint: c.hint,
            onChange: (e) => {
              const v = num(e.target.value, st.prices[h.id][c.t][r.key]);
              this.setState((s) => ({ prices: { ...s.prices, [h.id]: { ...s.prices[h.id], [c.t]: { ...s.prices[h.id][c.t], [r.key]: v } } } }));
            }
          }))
        }))
      })),

      durPreview: [60, 120, 180].map((m) => {
        const p = st.prices[club.halls[0].id];
        return {
          label: m / 60 + " ч · один шлем",
          price: money((p.wd.vr * m) / 60),
          note: "выходные — " + money((p.we.vr * m) / 60)
        };
      }),

      packs: st.packs.filter((p) => p.club === club.id).map((p) => {
        const i = st.packs.indexOf(p);
        const hall = club.halls.find((h) => h.id === p.hall) || club.halls[0];
        const pr = st.prices[hall.id].wd;
        const hourly = (pr.vr * p.vr + pr.ps5 * p.ps5) * (p.dur / 60);
        const save = hourly - p.price;
        const comp = [p.vr ? helmets(p.vr) : null, p.ps5 ? p.ps5 + " PS5" : null].filter(Boolean).join(" + ") || "состав не задан";
        const over = p.vr > hall.helmets || p.ps5 > hall.ps5;
        return {
          name: p.name,
          note: over ? "Не вмещается: в зале " + helmets(hall.helmets) + (hall.ps5 ? " и " + hall.ps5 + " PS5" : ", без PS5") : "",
          noteStyle: "font-size:12px; font-weight:600; color:#FF9BA6; margin-top:4px; display:" + (over ? "block" : "none"),
          meta: hall.name + " · " + comp + " · " + p.dur / 60 + " ч",
          price: money(p.price),
          compare: save > 0 ? "по часам вышло бы " + money(hourly) : save < 0 ? "дороже почасовой на " + money(-save) : "равно почасовой цене",
          compareStyle: "font-size:12px; margin-top:3px; color:" + (save > 0 ? Atx : "#6E6E7A"),
          rowStyle: "display:flex; flex-wrap:wrap; gap:14px; justify-content:space-between; align-items:center; padding:15px; border-radius:14px; border:1px solid " + (p.on ? "#212227" : "#1A1B20") + "; background:" + (p.on ? "#0C0E11" : "#0A0B0D") + "; opacity:" + (p.on ? "1" : "0.55"),
          fields: [
            { key: "vr", label: "шлемов", value: String(p.vr), w: "78px" },
            { key: "ps5", label: "PS5", value: String(p.ps5), w: "70px" },
            { key: "dur", label: "минут", value: String(p.dur), w: "84px" },
            { key: "price", label: "₽ за пакет", value: String(p.price), w: "104px" }
          ].map((fl) => ({
            label: fl.label, value: fl.value, w: fl.w,
            onChange: (e) => { const v = num(e.target.value, p[fl.key]); this.setState((s) => ({ packs: s.packs.map((x, j) => j === i ? { ...x, [fl.key]: v } : x) })); }
          })),
          toggleLabel: p.on ? "Выключить" : "Включить",
          toggleStyle: "padding:9px 12px; border-radius:9px; cursor:pointer; font-size:13px; font-weight:600; border:1px solid " + (p.on ? "#2A2C33" : A) + "; background:" + (p.on ? "transparent" : At + "0.14)") + "; color:" + (p.on ? "#C9C9D2" : Atx),
          onToggle: () => this.setState((s) => ({ packs: s.packs.map((x, j) => j === i ? { ...x, on: !x.on } : x) })),
          onDelete: () => this.setState((s) => ({ packs: s.packs.filter((_, j) => j !== i) }))
        };
      }),

      packsEmpty: st.packs.filter((p) => p.club === club.id).length === 0,
      packsHint: club.halls.map((h) => h.name + " — " + helmets(h.helmets) + (h.ps5 ? " и " + h.ps5 + " PS5" : ", без PS5")).join(" · "),
      newHalls: club.halls.map((h) => ({
        label: h.name,
        style: "padding:11px 13px; border-radius:10px; cursor:pointer; font-size:14px; font-weight:600; white-space:nowrap; border:1px solid " + (this.newHall().id === h.id ? A : "#2A2C33") + "; background:" + (this.newHall().id === h.id ? At + "0.16)" : "transparent") + "; color:" + (this.newHall().id === h.id ? Atx : "#9A9AA6"),
        onClick: () => this.setState((s) => ({ newPack: { ...s.newPack, hall: h.id }, packMsg: "" }))
      })),

      newPack: {
        name: st.newPack.name, vr: String(st.newPack.vr), ps5: String(st.newPack.ps5), dur: String(st.newPack.dur), price: String(st.newPack.price),
        onName: (e) => this.setState((s) => ({ newPack: { ...s.newPack, name: e.target.value }, packMsg: "" })),
        onVr: (e) => this.setState((s) => ({ newPack: { ...s.newPack, vr: num(e.target.value, s.newPack.vr) } })),
        onPs5: (e) => this.setState((s) => ({ newPack: { ...s.newPack, ps5: num(e.target.value, s.newPack.ps5) } })),
        onDur: (e) => this.setState((s) => ({ newPack: { ...s.newPack, dur: num(e.target.value, s.newPack.dur) } })),
        onPrice: (e) => this.setState((s) => ({ newPack: { ...s.newPack, price: num(e.target.value, s.newPack.price) } })),
        addStyle: "padding:12px 18px; border-radius:11px; border:none; font-size:14px; font-weight:700; cursor:pointer; background:" + (st.newPack.name.trim().length > 1 ? A : "#22242A") + "; color:" + (st.newPack.name.trim().length > 1 ? "#08090A" : "#6E6E7A"),
        onAdd: () => {
          const nm = st.newPack.name.trim(), hall = this.newHall();
          if (nm.length < 2) return this.setState({ packMsg: "Название от двух символов." });
          if (st.newPack.vr + st.newPack.ps5 < 1) return this.setState({ packMsg: "Укажите хотя бы одну станцию — шлем или PS5." });
          if (st.newPack.vr > hall.helmets) return this.setState({ packMsg: "В «" + hall.name + "» только " + helmets(hall.helmets) + "." });
          if (st.newPack.ps5 > hall.ps5) return this.setState({ packMsg: hall.ps5 ? "В «" + hall.name + "» только " + hall.ps5 + " PS5." : "В «" + hall.name + "» нет PS5." });
          this.setState((s) => ({
            packs: s.packs.concat({ id: "p" + Date.now(), club: club.id, hall: hall.id, name: nm, vr: s.newPack.vr, ps5: s.newPack.ps5, dur: s.newPack.dur, price: s.newPack.price, on: true }),
            newPack: { name: "", hall: hall.id, vr: 2, ps5: 0, dur: 60, price: 5000 }, packMsg: "Пакет «" + nm + "» добавлен в «" + hall.name + "»."
          }));
        },
        msg: st.packMsg, msgStyle: "font-size:12px; margin-top:10px; color:" + (st.packMsg.indexOf("добавлен") > -1 ? Atx : "#FFB020") + (st.packMsg ? "" : "; display:none")
      },

      intake: {
        ...sw(st.intake),
        hint: st.intake ? "Виджет принимает брони в обычном режиме." : "Виджет открывается, но вместо сетки показывает «запись приостановлена».",
        onToggle: () => this.setState({ intake: !st.intake })
      },

      halls: club.halls.map((h) => {
        const off = st.closedHalls.includes(h.id);
        return {
          name: h.name, meta: off ? "скрыт из виджета" : seats(h.helmets + h.ps5) + ", доступен",
          rowStyle: "display:flex; flex-wrap:wrap; gap:12px; justify-content:space-between; align-items:center; padding:14px; border-radius:13px; border:1px solid " + (off ? "#3A2A1C" : "#212227") + "; background:" + (off ? "#16110C" : "#0C0E11"),
          btnLabel: off ? "Открыть зал" : "Закрыть зал",
          btnStyle: "padding:10px 13px; border-radius:10px; cursor:pointer; font-size:13px; font-weight:600; border:1px solid " + (off ? A : "#2A2C33") + "; background:" + (off ? At + "0.14)" : "transparent") + "; color:" + (off ? Atx : "#C9C9D2"),
          onToggle: () => this.setState((s) => ({ closedHalls: off ? s.closedHalls.filter((x) => x !== h.id) : s.closedHalls.concat(h.id) }))
        };
      }),

      slotHint: club.name + ", " + club.hours + (club.gap ? " · перерыв " + club.gap + " минут между сеансами" : " · сеансы подряд, без перерыва"),
      dayLabel: d.getDate() + " " + MONL[d.getMonth()],

      dayChips: days.map((dd, i) => ({
        dow: DOW[dd.getDay()], day: dd.getDate(), mon: MON[dd.getMonth()],
        style: "display:flex; flex-direction:column; align-items:center; gap:1px; flex:none; width:54px; padding:9px 0 8px; border-radius:12px; cursor:pointer; border:1px solid " + (st.dayIdx === i ? A : "#2A2C33") + "; background:" + (st.dayIdx === i ? At + "0.16)" : "transparent") + "; color:" + (st.dayIdx === i ? Atx : "#9A9AA6"),
        onClick: () => this.setState({ dayIdx: i })
      })),

      slotCells: this.slots().map((t) => {
        const key = this.slotKey(t), off = st.closedSlots.includes(key);
        return {
          time: hhmm(t), tag: off ? "закрыт" : "открыт",
          tagStyle: "font-size:11px; margin-top:5px; color:" + (off ? "#FFC98A" : "#7C7C88"),
          style: "display:flex; flex-direction:column; align-items:flex-start; padding:11px 12px 10px; border-radius:12px; cursor:pointer; border:1px solid " + (off ? "#3A2A1C" : "#2A2C33") + "; background:" + (off ? "repeating-linear-gradient(135deg, #16110C 0 5px, #120E0A 5px 10px)" : "#0C0E11") + "; color:" + (off ? "#FFC98A" : "#C9C9D2"),
          onClick: () => this.setState((s) => ({ closedSlots: off ? s.closedSlots.filter((x) => x !== key) : s.closedSlots.concat(key) }))
        };
      }),

      closeAllDay: () => this.setState((s) => {
        const keys = this.slots().map((t) => this.slotKey(t));
        return { closedSlots: s.closedSlots.filter((k) => keys.indexOf(k) === -1).concat(keys) };
      }),
      openAllDay: () => this.setState((s) => {
        const keys = this.slots().map((t) => this.slotKey(t));
        return { closedSlots: s.closedSlots.filter((k) => keys.indexOf(k) === -1) };
      }),

      bookingsMeta: (() => {
        const mine = SEED.filter((b) => b.club === club.id);
        return mine.filter((b) => st.cancelled.indexOf(b.id) === -1).length + " активных из " + mine.length + " · тариф " + (isWeekend(d) ? "выходного дня" : "будней");
      })(),
      noBookings: SEED.filter((b) => b.club === club.id).length === 0,
      bookings: SEED.filter((b) => b.club === club.id).map((b) => {
        const off = st.cancelled.indexOf(b.id) > -1;
        const hall = club.halls.find((h) => h.name === b.hall) || club.halls[0];
        const tariff = isWeekend(d) ? "we" : "wd";
        const gross = st.prices[hall.id][tariff].vr * b.n * (b.dur / 60);
        const total = gross - Math.round((gross * b.discPct) / 100);
        return {
          time: hhmm(b.time) + "–" + hhmm(b.time + b.dur), name: b.name,
          meta: b.phone + " · " + b.hall + " · " + seats(b.n) + " · " + b.dur / 60 + " ч",
          total: money(total),
          gross: b.discPct ? money(gross) : "",
          grossStyle: "font-size:12px; color:#5B5B66; text-decoration:line-through" + (b.discPct ? "" : "; display:none"),
          disc: b.disc || "почасовая оплата",
          discStyle: "font-size:11px; margin-top:2px; color:" + (b.disc ? Atx : "#5B5B66"),
          timeStyle: "flex:none; padding:8px 10px; border-radius:9px; background:" + (off ? "#15171B" : At + "0.12)") + "; color:" + (off ? "#6E6E7A" : Atx) + "; font-size:13px; font-weight:700; font-variant-numeric:tabular-nums",
          rowStyle: "display:flex; flex-wrap:wrap; gap:12px; justify-content:space-between; align-items:center; padding:15px 18px; border-bottom:1px solid #1A1B20; opacity:" + (off ? "0.45" : "1"),
          cancelLabel: off ? "Вернуть" : "Отменить",
          cancelStyle: "padding:10px 12px; border-radius:10px; cursor:pointer; font-size:13px; font-weight:600; border:1px solid " + (off ? "#2A2C33" : "#3A2226") + "; background:" + (off ? "transparent" : "#1B1114") + "; color:" + (off ? "#C9C9D2" : "#FF9BA6"),
          onCancel: () => this.setState((s) => ({ cancelled: off ? s.cancelled.filter((x) => x !== b.id) : s.cancelled.concat(b.id) }))
        };
      })
    };
  }
}
