
const CLUBS = [
  { id: "effect", name: "Effect VR", hours: "11:00 – 22:30", open: 660, close: 1350, gap: 10,
    halls: [{ id: "e-main", name: "Зал", helmets: 4, ps5: 2 }] },
  { id: "vray", name: "V-Ray", hours: "11:00 – 23:00", open: 660, close: 1380, gap: 0,
    halls: [{ id: "v-big", name: "Большой зал", helmets: 12, ps5: 0 }, { id: "v-small", name: "Малый зал", helmets: 4, ps5: 2 }] }
];
const DOW = ["вс", "пн", "вт", "ср", "чт", "пт", "сб"];
const MON = ["янв", "фев", "мар", "апр", "мая", "июн", "июл", "авг", "сен", "окт", "ноя", "дек"];
const MONL = ["января", "февраля", "марта", "апреля", "мая", "июня", "июля", "августа", "сентября", "октября", "ноября", "декабря"];
const MONN = ["январь", "февраль", "март", "апрель", "май", "июнь", "июль", "август", "сентябрь", "октябрь", "ноябрь", "декабрь"];
const hhmm = (m) => String(Math.floor(m / 60)).padStart(2, "0") + ":" + String(m % 60).padStart(2, "0");
const money = (n) => n.toLocaleString("ru-RU").replace(/,/g, " ") + " ₽";
const plural = (n, one, few, many) => { const m10 = n % 10, m100 = n % 100; if (m10 === 1 && m100 !== 11) return one; if (m10 >= 2 && m10 <= 4 && (m100 < 12 || m100 > 14)) return few; return many; };
const helmets = (n) => n + " " + plural(n, "шлем", "шлема", "шлемов");
const seats = (n) => n + " " + plural(n, "место", "места", "мест");
const isWeekend = (d) => d.getDay() === 0 || d.getDay() === 6;
const num = (v, d) => { const n = parseInt(String(v).replace(/\D/g, ""), 10); return isNaN(n) ? d : n; };

const SEED = [
  { id: "b1", club: "vray", time: 720, name: "Игорь", phone: "+7 (912) 344-11-08", hall: "Большой зал", n: 7, dur: 60, disc: "пакет «Компания»", discPct: 15 },
  { id: "b2", club: "vray", time: 900, name: "Настя", phone: "+7 (903) 771-20-64", hall: "Малый зал", n: 4, dur: 120, disc: "", discPct: 0 },
  { id: "b3", club: "vray", time: 1140, name: "Дима", phone: "+7 (999) 208-45-31", hall: "Большой зал", n: 12, dur: 60, disc: "", discPct: 0 },
  { id: "b4", club: "effect", time: 780, name: "Лена", phone: "+7 (905) 613-77-42", hall: "Зал", n: 4, dur: 60, disc: "", discPct: 0 },
  { id: "b5", club: "effect", time: 1200, name: "Артём", phone: "+7 (962) 480-15-93", hall: "Зал", n: 6, dur: 120, disc: "пакет «Компания»", discPct: 10 }
];

const LOG = [
  { id: "l1", club: "vray", hall: "v-big", day: 0, time: 720, dur: 120, vr: 6, ps5: 0, name: "Игорь", phone: "+7 (912) 344-11-08", pack: "Команда", status: "paid", src: "виджет", prepay: 14000, note: "Оплатили полностью переводом. Просят арену без новичков рядом." },
  { id: "l2", club: "vray", hall: "v-small", day: 0, time: 900, dur: 120, vr: 3, ps5: 1, name: "Настя", phone: "+7 (903) 771-20-64", pack: "", status: "confirmed", src: "виджет", prepay: 3000, note: "Детская группа, нужен инструктаж подлиннее." },
  { id: "l3", club: "vray", hall: "v-big", day: 0, time: 1140, dur: 60, vr: 12, ps5: 0, name: "Дима", phone: "+7 (999) 208-45-31", pack: "", status: "new", src: "звонок", prepay: 0, note: "Корпоратив, счёт на организацию. Перезвонить до 18:00." },
  { id: "l4", club: "vray", hall: "v-small", day: 1, time: 780, dur: 60, vr: 0, ps5: 2, name: "Кирилл", phone: "+7 (964) 112-90-77", pack: "", status: "confirmed", src: "виджет" },
  { id: "l5", club: "vray", hall: "v-big", day: 1, time: 1020, dur: 120, vr: 12, ps5: 0, name: "Марина", phone: "+7 (908) 555-31-20", pack: "Арена", status: "paid", src: "виджет" },
  { id: "l6", club: "vray", hall: "v-small", day: 2, time: 660, dur: 60, vr: 4, ps5: 2, name: "Олег", phone: "+7 (917) 604-18-52", pack: "", status: "new", src: "звонок" },
  { id: "l7", club: "effect", hall: "e-main", day: 0, time: 780, dur: 60, vr: 4, ps5: 0, name: "Лена", phone: "+7 (905) 613-77-42", pack: "", status: "confirmed", src: "виджет" },
  { id: "l8", club: "effect", hall: "e-main", day: 0, time: 1200, dur: 120, vr: 4, ps5: 2, name: "Артём", phone: "+7 (962) 480-15-93", pack: "Полный зал", status: "paid", src: "виджет" },
  { id: "l9", club: "effect", hall: "e-main", day: 1, time: 900, dur: 60, vr: 0, ps5: 2, name: "Соня", phone: "+7 (951) 220-64-09", pack: "", status: "new", src: "виджет" },
  { id: "l10", club: "effect", hall: "e-main", day: 2, time: 1080, dur: 120, vr: 2, ps5: 0, name: "Паша", phone: "+7 (926) 337-45-11", pack: "", status: "confirmed", src: "звонок" },
  { id: "l11", club: "vray", hall: "v-small", day: 0, time: 660, dur: 60, vr: 2, ps5: 2, name: "Рома", phone: "+7 (982) 145-70-23", pack: "Шлемы и PS5", status: "paid", src: "виджет", prepay: 4300, note: "День рождения, привезут торт — нужен стол." },
  { id: "l12", club: "vray", hall: "v-big", day: 0, time: 960, dur: 60, vr: 4, ps5: 0, name: "Юля", phone: "+7 (919) 302-88-14", pack: "", status: "new", src: "виджет", prepay: 0, note: "Просит подтвердить смс." },
  { id: "l14", club: "vray", hall: "v-big", day: 0, time: 960, dur: 60, vr: 3, ps5: 0, name: "Стас", phone: "+7 (958) 771-33-05", pack: "", status: "confirmed", src: "звонок", prepay: 2000, note: "Остаток наличными на месте." },
  { id: "l15", club: "vray", hall: "v-big", day: 0, time: 960, dur: 120, vr: 2, ps5: 0, name: "Алина", phone: "+7 (912) 909-42-61", pack: "", status: "paid", src: "виджет", prepay: 5600, note: "Оплачено онлайн целиком." },
  { id: "l16", club: "effect", hall: "e-main", day: 0, time: 1020, dur: 60, vr: 2, ps5: 1, name: "Гоша", phone: "+7 (927) 118-56-40", pack: "", status: "new", src: "виджет", prepay: 0, note: "Договорились на доплату на месте." },
  { id: "l13", club: "effect", hall: "e-main", day: 0, time: 1020, dur: 120, vr: 2, ps5: 1, name: "Тимур", phone: "+7 (937) 556-04-77", pack: "", status: "confirmed", src: "звонок", prepay: 1500, note: "Просили PS5 с двумя геймпадами." }
];
const hexRgb = (h) => {
  const s = h.replace("#", "");
  const v = s.length === 3 ? s.split("").map((c) => c + c).join("") : s;
  return [parseInt(v.slice(0, 2), 16), parseInt(v.slice(2, 4), 16), parseInt(v.slice(4, 6), 16)];
};
const rgbaPrefix = (h) => { const [r, g, b] = hexRgb(h); return "rgba(" + r + "," + g + "," + b + ","; };
const lighten = (h) => {
  const [r, g, b] = hexRgb(h).map((c) => Math.round(c + (255 - c) * 0.55));
  return "rgb(" + r + "," + g + "," + b + ")";
};
const HUES = [
  { bg: "rgba(169,240,74,0.42)", bd: "rgba(169,240,74,0.75)", tx: "#EAFFC8" },
  { bg: "rgba(127,166,255,0.42)", bd: "rgba(127,166,255,0.75)", tx: "#DCE8FF" },
  { bg: "rgba(255,168,92,0.42)", bd: "rgba(255,168,92,0.75)", tx: "#FFE7D2" },
  { bg: "rgba(214,133,255,0.42)", bd: "rgba(214,133,255,0.75)", tx: "#F4E1FF" },
  { bg: "rgba(94,225,204,0.42)", bd: "rgba(94,225,204,0.75)", tx: "#D6FFF7" },
  { bg: "rgba(255,138,168,0.42)", bd: "rgba(255,138,168,0.78)", tx: "#FFE0E7" }
];
const hue2text = (h) => h.tx;
const STATUS = { new: { label: "новая", c: "#FFC98A", bg: "#1E1610", bd: "#3A2A1C" }, confirmed: { label: "подтверждена", c: "#8BEFCB", bg: "#0C1A16", bd: "#1E3A31" }, paid: { label: "оплачена", c: "#A9F04A", bg: "#141A0C", bd: "#2C3A1C" } };

class Component extends DCLogic {
  state = {
    authed: false, login: "", pass: "", authErr: "",
    tab: "prices", clubId: "vray", dayIdx: 0,
    openRec: null, hoverRec: null, timeText: null, edits: {}, logDay: 0, logHall: "all", logType: "all",
    created: [], nc: null, ncMsg: "",
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
  days() { const base = new Date(2026, 8, 3); return Array.from({ length: 120 }, (_, i) => { const d = new Date(base); d.setDate(base.getDate() + i); return d; }); }
  slots() { const c = this.club(); const out = []; for (let t = c.open; t + 60 <= c.close; t += 60 + c.gap) out.push(t); return out; }
  slotKey(t) { return this.state.clubId + "-" + this.state.dayIdx + "-" + t; }

  componentDidMount() {
    try { if (localStorage.getItem("vr-admin-auth") === "1") this.setState({ authed: true }); } catch (e) {}
  }

  authVals() {
    const st = this.state;
    const enter = () => {
      if (st.login.trim().toLowerCase() === "admin" && st.pass === "vr2026") {
        try { localStorage.setItem("vr-admin-auth", "1"); } catch (e) {}
        this.setState({ authed: true, authErr: "", pass: "" });
      } else this.setState({ authErr: "Неверный логин или пароль." });
    };
    return {
      locked: !st.authed,
      auth: {
        login: st.login, pass: st.pass,
        onLogin: (e) => this.setState({ login: e.target.value, authErr: "" }),
        onPass: (e) => this.setState({ pass: e.target.value, authErr: "" }),
        onKey: (e) => { if (e.key === "Enter") enter(); },
        onEnter: enter,
        onExit: () => { try { localStorage.removeItem("vr-admin-auth"); } catch (e) {} this.setState({ authed: false, pass: "", authErr: "" }); },
        err: st.authErr,
        errStyle: "font-size:13px; font-weight:600; color:#FF9BA6; margin-bottom:12px; display:" + (st.authErr ? "block" : "none")
      }
    };
  }

  newHall() {
    const halls = this.club().halls;
    return halls.find((h) => h.id === this.state.newPack.hall) || halls[0];
  }

  logVals(A, At, Atx, days) {
    const st = this.state, club = this.club();
    const ALL = LOG.concat(st.created).map((e) => ({ ...e, ...(st.edits[e.id] || {}) }));
    const chip = (on) => "padding:7px 12px; border-radius:9px; cursor:pointer; font-size:13px; font-weight:600; white-space:nowrap; border:1px solid " + (on ? A : "#2A2C33") + "; background:" + (on ? At + "0.16)" : "transparent") + "; color:" + (on ? Atx : "#9A9AA6");
    const rate = (h, d, key) => st.prices[h][isWeekend(d) ? "we" : "wd"][key];
    const hourly = (e) => {
      const d = days[e.day];
      return Math.round(((rate(e.hall, d, "vr") * e.vr + rate(e.hall, d, "ps5") * e.ps5) * e.dur) / 60);
    };
    const packOf = (e) => (e.pack ? st.packs.find((p) => p.name === e.pack && p.club === e.club && p.hall === e.hall && p.vr === e.vr && p.ps5 === e.ps5 && p.dur === e.dur) : null);
    const cost = (e) => { const p = packOf(e); return p ? p.price : hourly(e); };

    const rows = ALL.filter((e) => e.club === club.id)
      .filter((e) => st.logDay === "all" || e.day === st.logDay)
      .filter((e) => st.logHall === "all" || e.hall === st.logHall)
      .filter((e) => st.logType === "all" || (st.logType === "vr" ? e.vr > 0 : e.ps5 > 0))
      .sort((a, b) => a.day - b.day || a.time - b.time);
    const live = rows.filter((e) => st.cancelled.indexOf(e.id) === -1);
    const sum = (f) => live.reduce((a, e) => a + f(e), 0);

    const filters = [
      { label: "день", cur: st.logDay, key: "logDay", options: (() => {
          const base = days.slice(0, 7).map((dd, i) => ({ v: i, l: (i === 0 ? "сегодня" : DOW[dd.getDay()] + " " + dd.getDate()) }));
          const far = [];
          ALL.filter((e) => e.club === club.id && e.day > 6).forEach((e) => { if (far.indexOf(e.day) === -1) far.push(e.day); });
          if (typeof st.logDay === "number" && st.logDay > 6 && far.indexOf(st.logDay) === -1) far.push(st.logDay);
          far.sort((a, b) => a - b);
          return base
            .concat(far.map((i) => ({ v: i, l: days[i].getDate() + " " + MON[days[i].getMonth()] })))
            .concat([{ v: "all", l: "все дни" }]);
        })() },
      { label: "зал", cur: st.logHall, key: "logHall", options: [{ v: "all", l: "все залы" }].concat(club.halls.map((h) => ({ v: h.id, l: h.name }))) },
      { label: "тип", cur: st.logType, key: "logType", options: [{ v: "all", l: "всё" }, { v: "vr", l: "со шлемами" }, { v: "ps5", l: "с PS5" }] }
    ];

    const occDay = st.logDay === "all" ? 0 : st.logDay;
    const occSrc = ALL.filter((e) => e.club === club.id && e.day === occDay && st.cancelled.indexOf(e.id) === -1);
    const occHalls = club.halls
      .filter((h) => st.logHall === "all" || h.id === st.logHall)
      .map((h) => {
        const step = this.props.gridStep === "30 минут" ? 30 : 60;
        const slots = [];
        for (let t = club.open; t + step <= club.close; t += step) slots.push(t);
        const units = [];
        for (let i = 0; i < h.helmets; i++) units.push({ key: "vr", i, label: "Шлем " + (i + 1) });
        for (let i = 0; i < h.ps5; i++) units.push({ key: "ps5", i, label: "PS5 " + (i + 1) });

        const recs = occSrc.filter((e) => e.hall === h.id).sort((a, b) => a.time - b.time);
        const grid = units.map(() => slots.map(() => null));
        const legend = [];
        recs.forEach((e, ri) => {
          const hue = HUES[ri % HUES.length];
          const cover = slots.map((t, si) => (e.time < t + step && e.time + e.dur > t ? si : -1)).filter((x) => x > -1);
          let first = null;
          ["vr", "ps5"].forEach((key) => {
            let need = e[key];
            units.forEach((u, ui) => {
              if (need <= 0 || u.key !== key) return;
              if (cover.some((si) => grid[ui][si])) return;
              cover.forEach((si) => { grid[ui][si] = { hue, rec: e, head: false }; });
              if (!first || ui < first.ui) first = { ui, si: cover[0] };
              need--;
            });
          });
          if (first) grid[first.ui][first.si].head = true;
          legend.push({
            label: e.name + " · " + hhmm(e.time) + "–" + hhmm(e.time + e.dur) + " · " + [e.vr ? e.vr + " VR" : null, e.ps5 ? e.ps5 + " PS5" : null].filter(Boolean).join(" + "),
            onClick: () => this.setState({ openRec: e.id }),
            onEnter: () => this.setState({ hoverRec: e.id }),
            onLeave: () => this.setState({ hoverRec: null }),
            rowStyle: "display:flex; align-items:center; gap:7px; cursor:pointer; padding:4px 7px; margin:-4px -7px; border-radius:9px; transition:background 140ms ease; background:" + (st.hoverRec === e.id ? "#1C1F26" : "transparent"),
            style: "width:22px; height:12px; flex:none; border-radius:4px; border:1px solid " + hue.bd + "; background:" + hue.bg
          });
        });

        const tight = this.props.density === "Плотно";
        const ch = tight ? 15 : 24, cr = tight ? 4 : 7, cg = tight ? 2 : 4;
        const lab = "font-size:11px; color:#6E6E7A; display:flex; align-items:center; padding-right:4px; white-space:nowrap; font-variant-numeric:tabular-nums";
        const cells = [{ style: lab, text: "" }].concat(
          slots.map((t, i) => ({
            style: "font-size:" + (step === 30 ? 10 : 11) + "px; color:#8A8A96; text-align:center; font-variant-numeric:tabular-nums; padding-bottom:2px",
            text: step === 30 && i % 2 === 1 ? "" : hhmm(t)
          }))
        );
        units.forEach((u, ui) => {
          cells.push({ style: lab + (u.key === "ps5" ? "; color:#7FA6FF; font-weight:700" : ""), text: u.label });
          slots.forEach((t, si) => {
            const cell = grid[ui][si];
            const ps = u.key === "ps5";
            const rad = ps ? Math.round(ch / 2) : cr;
            const base = "height:" + ch + "px; border-radius:" + rad + "px; overflow:hidden; display:flex; align-items:center; justify-content:center; font-size:10px; font-weight:700; letter-spacing:0.02em; ";
            if (!cell) {
              cells.push({ text: "", style: base + "border:1px " + (ps ? "dashed #24262D" : "solid #1F2127") + "; background:repeating-linear-gradient(135deg, #0D0F12 0 4px, #0A0C0E 4px 8px)" });
              return;
            }
            cells.push({
              text: cell.head && !tight ? cell.rec.name : "",
              onClick: () => this.setState({ openRec: cell.rec.id }),
              onEnter: () => this.setState({ hoverRec: cell.rec.id }),
              onLeave: () => this.setState({ hoverRec: null }),
              style: "cursor:pointer; position:relative; transition:transform 160ms cubic-bezier(0.2,0.9,0.3,1), filter 160ms ease, box-shadow 160ms ease, opacity 160ms ease; "
                + (st.hoverRec === cell.rec.id
                    ? "box-shadow:0 0 0 2px #FFFFFF, 0 4px 14px rgba(0,0,0,0.45); transform:scale(1.05); filter:brightness(1.16); z-index:5; "
                    : st.hoverRec ? "opacity:0.45; " : "")
                + base + "color:" + hue2text(cell.hue) + "; border:" + (ps ? "1.5px dashed rgba(255,255,255,0.55)" : "1px solid " + cell.hue.bd) + "; background:" + cell.hue.bg + (ps ? "; box-shadow:inset 0 0 0 3px rgba(10,12,14,0.45)" : "")
            });
          });
        });
        const total = units.length * slots.length;
        const busy = grid.reduce((a, row) => a + row.filter(Boolean).length, 0);
        const pct = total ? Math.round((busy / total) * 100) : 0;
        cells.push({ style: lab, text: "свободно" });
        slots.forEach((t, si) => {
          const free = units.length - grid.filter((row) => row[si]).length;
          cells.push({
            text: free === 0 ? "0" : String(free),
            style: "height:" + ch + "px; display:flex; align-items:center; justify-content:center; font-size:" + (tight ? 10 : 12) + "px; font-weight:700; font-variant-numeric:tabular-nums; border-radius:" + cr + "px; color:" + (free === 0 ? "#FF9BA6" : free <= 2 ? "#FFC98A" : "#7C7C88") + "; background:" + (free === 0 ? "rgba(255,155,166,0.1)" : "transparent")
          });
        });

        return {
          name: h.name, cells, legend,
          legendEmpty: legend.length === 0,
          cap: helmets(h.helmets) + (h.ps5 ? " и " + h.ps5 + " PS5" : ", без PS5"),
          load: "загрузка " + pct + "%",
          loadStyle: "font-size:12px; font-weight:700; white-space:nowrap; flex:none; padding:5px 10px; border-radius:8px; border:1px solid " + (pct >= 60 ? At + "0.35)" : "#2A2C33") + "; background:" + (pct >= 60 ? At + "0.1)" : "#0C0E11") + "; color:" + (pct >= 60 ? Atx : "#8A8A96"),
          gridStyle: "display:grid; grid-template-columns:62px repeat(" + slots.length + ", minmax(26px, 1fr)); gap:" + cg + "px; align-items:center; min-width:" + (68 + slots.length * (tight ? 28 : 34)) + "px"
        };
      });

    const openRec = ALL.find((e) => e.id === st.openRec);
    const detail = (() => {
      if (!openRec) return { show: false, chips: [], rows: [] };
      const e = openRec, d = days[e.day];
      const c = CLUBS.find((x) => x.id === e.club);
      const hall = c.halls.find((x) => x.id === e.hall);
      const p = packOf(e), full = cost(e), pre = e.prepay || 0;
      const off = st.cancelled.indexOf(e.id) > -1;
      const row = (label, value, tone) => ({
        label, value,
        rowStyle: "display:flex; justify-content:space-between; align-items:baseline; gap:14px; padding:11px 14px; background:#0B0D10",
        valStyle: "font-size:14px; font-weight:700; text-align:right; font-variant-numeric:tabular-nums; color:" + (tone === "acc" ? Atx : tone === "warn" ? "#FFC98A" : tone === "bad" ? "#FF9BA6" : "#F2F2F5")
      });
      const hall2 = hall || c.halls[0];
      const patch = (k, v) => this.setState((s) => ({ edits: { ...s.edits, [e.id]: { ...(s.edits[e.id] || {}), [k]: v } } }));
      const dr = { name: e.name, phone: e.phone, dur: e.dur, vr: e.vr, ps5: e.ps5, prepay: e.prepay === "" ? "" : (e.prepay || 0), note: e.note || "", time: st.timeText != null ? st.timeText : hhmm(e.time) };
      const setDraft = (k, v) => patch(k, v);
      const fchip = (on) => "padding:8px 12px; border-radius:9px; cursor:pointer; font-size:13px; font-weight:600; white-space:nowrap; transition:all 120ms ease; border:1px solid " + (on ? A : "#2A2C33") + "; background:" + (on ? At + "0.16)" : "transparent") + "; color:" + (on ? Atx : "#9A9AA6");
      const inp = "width:100%; padding:11px 12px; border-radius:11px; border:1px solid #2A2C33; background:#0A0C0E; color:#F2F2F5; font-size:15px";
      return {
        show: true, name: e.name, phone: e.phone,
        note: e.note || "Комментариев нет.",
        stop: (ev) => ev.stopPropagation(),
        onClose: () => this.setState({ openRec: null, timeText: null }),
        summary: [
          { label: "Клуб и зал", value: c.name + " · " + hall2.name },
          { label: "Дата", value: DOW[d.getDay()] + ", " + d.getDate() + " " + MON[d.getMonth()] + (isWeekend(d) ? " · выходной тариф" : " · тариф будней") },
          { label: "Сеанс", value: hhmm(e.time) + "–" + hhmm(e.time + e.dur) + " · " + e.dur / 60 + " ч" },
          { label: "Состав", value: [e.vr ? helmets(e.vr) : null, e.ps5 ? e.ps5 + " PS5" : null].filter(Boolean).join(" + ") || "не выбрано" },
          { label: "Расчёт", value: p ? "пакет «" + p.name + "»" : "почасовая оплата" },
          { label: "Источник", value: e.src }
        ].map((r) => ({ ...r, rowStyle: "display:flex; justify-content:space-between; align-items:baseline; gap:14px; padding:10px 14px; background:#0B0D10", valStyle: "font-size:13px; font-weight:700; text-align:right; color:#F2F2F5" })),
        money: [
          { label: "Стоимость", value: money(full), tone: "acc" },
          { label: "Предоплата", value: pre ? money(pre) : "нет", tone: pre ? null : "warn" },
          { label: "К оплате на месте", value: money(Math.max(0, full - pre)), tone: full - pre > 0 ? "warn" : null }
        ].map((r) => ({
          label: r.label, value: r.value,
          rowStyle: "display:flex; justify-content:space-between; align-items:baseline; gap:14px; padding:11px 14px; background:#0B0D10",
          valStyle: "font-size:15px; font-weight:800; text-align:right; font-variant-numeric:tabular-nums; color:" + (r.tone === "acc" ? Atx : r.tone === "warn" ? "#FFC98A" : "#F2F2F5")
        })),
        edited: !!st.edits[e.id],
        onReset: () => this.setState((s) => { const n = { ...s.edits }; delete n[e.id]; return { edits: n, timeText: null }; }),
        form: {
          name: dr.name || "", phone: dr.phone || "", time: dr.time || "", note: dr.note || "",
          prepay: String(dr.prepay == null ? "" : dr.prepay),
          inpStyle: inp,
          onName: (ev) => setDraft("name", ev.target.value),
          onPhone: (ev) => setDraft("phone", ev.target.value),
          onTime: (ev) => {
            const v = ev.target.value;
            this.setState({ timeText: v });
            const m = v.match(/^(\d{1,2})[:.\s]?(\d{2})$/);
            if (m) {
              const mins = Math.max(c.open, Math.min(c.close - e.dur, parseInt(m[1], 10) * 60 + parseInt(m[2], 10)));
              patch("time", mins);
            }
          },
          onNote: (ev) => setDraft("note", ev.target.value),
          onPrepay: (ev) => { const dg = String(ev.target.value).replace(/\D/g, ""); setDraft("prepay", dg === "" ? "" : parseInt(dg, 10)); },
          durs: [60, 120, 180, 240, 300].map((v) => ({ label: v / 60 + " ч", style: fchip(dr.dur === v), onClick: () => setDraft("dur", v) })),
          vrs: Array.from({ length: hall2.helmets + 1 }, (_, i) => i).map((v) => ({ label: String(v), style: fchip(dr.vr === v), onClick: () => setDraft("vr", v) })),
          ps5s: Array.from({ length: hall2.ps5 + 1 }, (_, i) => i).map((v) => ({ label: String(v), style: fchip(dr.ps5 === v), onClick: () => setDraft("ps5", v) })),
          hasPs5: hall2.ps5 > 0
        },
        chips: [
          off ? { label: "отменена", tone: "off" } : null,
          { label: c.name },
          { label: hall ? hall.name : e.hall },
          { label: "источник: " + e.src }
        ].filter(Boolean).map((x) => ({
          label: x.label,
          style: "display:inline-flex; align-items:center; white-space:nowrap; padding:6px 10px; border-radius:9px; font-size:12px; font-weight:600; border:1px solid " + (x.tone ? "#3A2226" : "#2A2C33") + "; background:" + (x.tone ? "#1B1114" : "#0C0E11") + "; color:" + (x.tone ? "#FF9BA6" : "#9A9AA6")
        })),
        rows: [
          row("Дата", DOW[d.getDay()] + ", " + d.getDate() + " " + MON[d.getMonth()]),
          row("Время", hhmm(e.time) + "–" + hhmm(e.time + e.dur) + " (" + e.dur / 60 + " ч)"),
          row("Состав", [e.vr ? helmets(e.vr) : null, e.ps5 ? e.ps5 + " PS5" : null].filter(Boolean).join(" + ")),
          row("Тариф", p ? "пакет «" + p.name + "»" : isWeekend(d) ? "выходной, по часам" : "будни, по часам"),
          row("Стоимость", money(full), "acc"),
          row("Предоплата", pre ? money(pre) : "нет", pre ? null : "warn"),
          row("К оплате на месте", money(Math.max(0, full - pre)), full - pre > 0 ? "warn" : null)
        ],
        cancelLabel: off ? "Вернуть бронь" : "Отменить бронь",
        savedStyle: "font-size:12px; font-weight:700; color:" + Atx + "; display:" + (st.edits[e.id] ? "block" : "none"),
        resetStyle: "flex:1; padding:13px; border-radius:12px; cursor:pointer; font-size:14px; font-weight:600; transition:all 140ms ease; border:1px solid #2A2C33; background:transparent; color:" + (st.edits[e.id] ? "#C9C9D2" : "#4A4C55"),
        cancelStyle: "flex:none; padding:13px 16px; border-radius:12px; cursor:pointer; font-size:15px; font-weight:700; transition:all 140ms ease; border:1px solid " + (off ? "#2A2C33" : "#3A2226") + "; background:" + (off ? "transparent" : "#1B1114") + "; color:" + (off ? "#C9C9D2" : "#FF9BA6"),
        onCancel: () => this.setState((s) => ({ cancelled: off ? s.cancelled.filter((x) => x !== e.id) : s.cancelled.concat(e.id) }))
      };
    })();

    return {
      detail,
      occHalls,
      occNeedsDay: st.logDay === "all",
      occMeta: club.name + " · " + DOW[days[occDay].getDay()] + ", " + days[occDay].getDate() + " " + MON[days[occDay].getMonth()],
      occLegend: [
        { label: "цвет = отдельная запись, подпись под сеткой", style: "width:34px; height:12px; border-radius:4px; background:linear-gradient(90deg, rgba(169,240,74,0.42) 0 33%, rgba(127,166,255,0.42) 33% 66%, rgba(255,168,92,0.42) 66% 100%); border:1px solid #2A2C33" },
        { label: "PS5 — капсула с пунктиром", style: "width:26px; height:14px; border-radius:7px; border:1.5px dashed rgba(255,255,255,0.55); background:rgba(127,166,255,0.42); box-shadow:inset 0 0 0 3px rgba(10,12,14,0.45)" },
        { label: "свободно", style: "width:22px; height:12px; border-radius:4px; border:1px solid #1F2127; background:repeating-linear-gradient(135deg, #0D0F12 0 4px, #0A0C0E 4px 8px)" }
      ],
      logFilters: filters.map((f) => ({
        label: f.label,
        options: f.options.map((o) => ({ label: o.l, style: chip(f.cur === o.v), onClick: () => this.setState({ [f.key]: o.v }) }))
      })),
      logStats: [
        { label: "записей", value: String(live.length), note: rows.length !== live.length ? "+ " + (rows.length - live.length) + " отменено" : "по фильтрам" },
        { label: "сумма", value: money(sum(cost)), note: "по текущему тарифу" }
      ].map((s) => ({ ...s, valStyle: "font-size:24px; font-weight:800; font-variant-numeric:tabular-nums; margin-top:6px; color:" + Atx })),
    };
  }

  freeUnits(hallId, day, time, dur) {
    const st = this.state, club = this.club();
    const hall = club.halls.find((h) => h.id === hallId) || club.halls[0];
    const busy = LOG.concat(st.created).map((e) => ({ ...e, ...(st.edits[e.id] || {}) }))
      .filter((e) => e.club === club.id && e.hall === hall.id && e.day === day && st.cancelled.indexOf(e.id) === -1)
      .filter((e) => e.time < time + dur && e.time + e.dur > time);
    return {
      hall,
      vr: Math.max(0, hall.helmets - busy.reduce((a, e) => a + e.vr, 0)),
      ps5: Math.max(0, hall.ps5 - busy.reduce((a, e) => a + e.ps5, 0))
    };
  }

  createVals(A, At, Atx, days) {
    const st = this.state, club = this.club();
    const hall0 = club.halls[0];
    const btnStyle = "flex:none; padding:11px 16px; border-radius:11px; border:none; cursor:pointer; font-size:14px; font-weight:700; background:" + A + "; color:#08090A";
    const onOpen = () => this.setState({ nc: { hall: hall0.id, day: 0, time: club.open, dur: 60, vr: 2, ps5: 0, name: "", phone: "", prepay: "", note: "" }, ncMsg: "", ncMonth: null });
    const onClose = () => this.setState({ nc: null, ncMsg: "" });
    const stop = (ev) => ev.stopPropagation();
    if (!st.nc) return { create: { show: false, cal: { heads: [], cells: [], title: "", picked: "", prevStyle: "display:none", nextStyle: "display:none", onPrev: () => {}, onNext: () => {} }, groups: [], inputs: [], btnStyle, onOpen, onClose, stop, onSave: () => {}, msg: "", msgStyle: "display:none", total: "", totalLabel: "", sub: "", saveStyle: "display:none" } };

    const nc = st.nc;
    const hall = club.halls.find((h) => h.id === nc.hall) || hall0;
    const set = (k, v) => this.setState((s) => {
      const nx = { ...s.nc, [k]: v };
      const f = this.freeUnits(nx.hall, nx.day, nx.time, nx.dur);
      return { nc: { ...nx, vr: Math.min(nx.vr, f.vr), ps5: Math.min(nx.ps5, f.ps5) }, ncMsg: "" };
    });
    const chip = (on) => "padding:8px 12px; border-radius:9px; cursor:pointer; font-size:13px; font-weight:600; white-space:nowrap; border:1px solid " + (on ? A : "#2A2C33") + "; background:" + (on ? At + "0.16)" : "transparent") + "; color:" + (on ? Atx : "#9A9AA6");
    const chipOff = "padding:8px 12px; border-radius:9px; cursor:not-allowed; font-size:13px; font-weight:600; white-space:nowrap; border:1px solid #1F2127; background:repeating-linear-gradient(135deg, #0D0F12 0 5px, #0A0C0E 5px 10px); color:#4A4C55; text-decoration:line-through";
    const count = (n, free, cur, key) => Array.from({ length: n + 1 }, (_, i) => i).map((v) => (
      v > free
        ? { label: String(v), style: chipOff, onClick: () => {} }
        : { label: String(v), style: chip(cur === v), onClick: () => set(key, v) }
    ));
    const times = [];
    for (let t = club.open; t + nc.dur <= club.close; t += 60) times.push(t);
    const d = days[nc.day];
    const pr = st.prices[hall.id][isWeekend(d) ? "we" : "wd"];
    const total = Math.round(((pr.vr * nc.vr + pr.ps5 * nc.ps5) * nc.dur) / 60);

    const overlap = LOG.concat(st.created).map((e) => ({ ...e, ...(st.edits[e.id] || {}) }))
      .filter((e) => e.club === club.id && e.hall === hall.id && e.day === nc.day && st.cancelled.indexOf(e.id) === -1)
      .filter((e) => e.time < nc.time + nc.dur && e.time + e.dur > nc.time);
    const freeVr = Math.max(0, hall.helmets - overlap.reduce((a, e) => a + e.vr, 0));
    const freePs = Math.max(0, hall.ps5 - overlap.reduce((a, e) => a + e.ps5, 0));
    const noRoom = freeVr + freePs === 0;

    return {
      create: {
        show: true, btnStyle, onOpen, onClose, stop,
        sub: club.name + " · " + hhmm(nc.time) + "–" + hhmm(nc.time + nc.dur) + " · " + DOW[d.getDay()] + ", " + d.getDate() + " " + MON[d.getMonth()],
        cal: (() => {
          const key = (dd) => dd.getFullYear() + "-" + dd.getMonth();
          const months = [];
          days.forEach((dd) => { const k = key(dd); if (months.indexOf(k) === -1) months.push(k); });
          const active = st.ncMonth || key(d);
          const mi = Math.max(0, months.indexOf(active));
          const list = days.map((dd, i) => ({ dd, i })).filter((x) => key(x.dd) === months[mi]);
          const lead = (list[0].dd.getDay() + 6) % 7;
          const blanks = Array.from({ length: lead }, () => ({ label: "", style: "visibility:hidden; padding:10px 0", onClick: () => {} }));
          const cells = list.map(({ dd, i }) => {
            const on = nc.day === i;
            const we = isWeekend(dd);
            return {
              label: String(dd.getDate()),
              style: "padding:10px 0; border-radius:10px; text-align:center; font-size:15px; font-weight:600; font-variant-numeric:tabular-nums; cursor:pointer; border:1px solid " + (on ? A : "transparent") + "; background:" + (on ? At + "0.18)" : "transparent") + "; color:" + (on ? Atx : we ? "#8A8A96" : "#E2E2E8"),
              onClick: () => set("day", i)
            };
          });
          const navStyle = (ok) => "padding:7px 12px; border-radius:9px; border:1px solid #2A2C33; background:transparent; font-size:15px; cursor:" + (ok ? "pointer" : "not-allowed") + "; color:" + (ok ? "#C9C9D2" : "#3E3E48");
          return {
            title: MONN[list[0].dd.getMonth()] + " " + list[0].dd.getFullYear(),
            heads: ["пн", "вт", "ср", "чт", "пт", "сб", "вс"],
            cells: blanks.concat(cells),
            picked: (nc.day === 0 ? "Сегодня, " : "") + DOW[d.getDay()] + ", " + d.getDate() + " " + MONL[d.getMonth()] + (isWeekend(d) ? " · выходной тариф" : " · тариф будней"),
            prevStyle: navStyle(mi > 0),
            nextStyle: navStyle(mi < months.length - 1),
            onPrev: () => { if (mi > 0) this.setState({ ncMonth: months[mi - 1] }); },
            onNext: () => { if (mi < months.length - 1) this.setState({ ncMonth: months[mi + 1] }); }
          };
        })(),
        groups: [
          club.halls.length > 1 ? { label: "Зал", options: club.halls.map((h) => ({ label: h.name, style: chip(nc.hall === h.id), onClick: () => set("hall", h.id) })) } : null,
          { label: "Длительность", options: [60, 120, 180, 240, 300].map((v) => ({ label: v / 60 + " ч", style: chip(nc.dur === v), onClick: () => set("dur", v) })) },
          { label: "Начало сеанса", options: times.map((t) => ({ label: hhmm(t), style: chip(nc.time === t), onClick: () => set("time", t) })) },
          { label: "Шлемов · свободно " + freeVr + " из " + hall.helmets, options: count(hall.helmets, freeVr, nc.vr, "vr") },
          hall.ps5 ? { label: "PS5 · свободно " + freePs + " из " + hall.ps5, options: count(hall.ps5, freePs, nc.ps5, "ps5") } : null
        ].filter(Boolean),
        inputs: [
          { label: "Имя", value: nc.name, placeholder: "Кто бронирует", mode: "text", onChange: (ev) => set("name", ev.target.value) },
          { label: "Телефон", value: nc.phone, placeholder: "+7 (900) 000-00-00", mode: "tel", onChange: (ev) => set("phone", ev.target.value) },
          { label: "Предоплата, ₽", value: String(nc.prepay), placeholder: "0", mode: "numeric", onChange: (ev) => { const dg = String(ev.target.value).replace(/\D/g, ""); set("prepay", dg === "" ? "" : parseInt(dg, 10)); } },
          { label: "Комментарий", value: nc.note, placeholder: "Например, привезут торт", mode: "text", onChange: (ev) => set("note", ev.target.value) }
        ],
        totalLabel: isWeekend(d) ? "Стоимость · выходной тариф" : "Стоимость · тариф будней",
        total: money(total),
        msg: st.ncMsg || (noRoom ? "На это время в зале всё занято — выберите другое время, день или зал." : ""),
        msgStyle: "font-size:13px; font-weight:600; color:#FFB020" + (st.ncMsg || noRoom ? "" : "; display:none"),
        saveStyle: "width:100%; padding:14px; border-radius:12px; border:none; cursor:" + (noRoom ? "not-allowed" : "pointer") + "; font-size:15px; font-weight:800; background:" + (noRoom ? "#22242A" : A) + "; color:" + (noRoom ? "#6E6E7A" : "#08090A"),
        onSave: () => {
          if (nc.name.trim().length < 2) return this.setState({ ncMsg: "Укажите имя гостя." });
          if (nc.vr + nc.ps5 < 1) return this.setState({ ncMsg: "Добавьте хотя бы один шлем или одну PS5." });
          if (nc.vr > freeVr || nc.ps5 > freePs) return this.setState({ ncMsg: "На это время свободно " + freeVr + " шлемов и " + freePs + " PS5." });
          const rec = {
            id: "c" + Date.now(), club: club.id, hall: hall.id, day: nc.day, time: nc.time, dur: nc.dur,
            vr: nc.vr, ps5: nc.ps5, name: nc.name.trim(), phone: nc.phone.trim() || "телефон не указан",
            pack: "", src: "админка", prepay: nc.prepay === "" ? 0 : nc.prepay, note: nc.note.trim()
          };
          this.setState((s) => ({ created: s.created.concat(rec), nc: null, ncMsg: "", tab: "log", logDay: nc.day, openRec: rec.id }));
        }
      }
    };
  }

  renderVals() {
    const st = this.state, club = this.club();
    const custom = (this.props.accent || "").trim();
    const A = custom || (club.id === "vray" ? "#0FB981" : "#A9F04A");
    const At = custom ? rgbaPrefix(custom) : (club.id === "vray" ? "rgba(15,185,129," : "rgba(169,240,74,");
    const Atx = custom ? lighten(custom) : (club.id === "vray" ? "#8BEFCB" : "#DDFCAE");
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
        { id: "avail", label: "Доступность" }, { id: "log", label: "Записи" }
      ].map((t) => ({ label: t.label, style: tab(st.tab === t.id), onClick: () => this.setState({ tab: t.id }) })),

      isPrices: st.tab === "prices", isPacks: st.tab === "packs",
      isAvail: st.tab === "avail", isLog: st.tab === "log",

      ...this.logVals(A, At, Atx, days),
      ...this.createVals(A, At, Atx, days),
      ...this.authVals(),

      priceCards: club.halls.map((h) => ({
        title: h.name, meta: club.name,
        hint: helmets(h.helmets) + (h.ps5 ? " и " + h.ps5 + " PS5" : ""),
        rows: [
          { key: "vr", label: "VR-шлем", sub: "за 1 час, один шлем" },
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
          if (st.newPack.vr + st.newPack.ps5 < 1) return this.setState({ packMsg: "Укажите хотя бы один шлем или одну PS5." });
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

      dayChips: days.slice(0, 14).map((dd, i) => ({
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
