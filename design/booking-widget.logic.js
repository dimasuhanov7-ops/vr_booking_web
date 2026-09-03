// Извлечено дословно из Claude Design canvas «Виджет бронирования VR.dc.html»
// (проект 8d5d5ffe-dca2-44b9-9385-3fac38fbaae5), снято 2026-09-03.
// Логика прототипа дизайна: данные клубов, расчёт цен/скидок и вычисление
// inline-стилей для всех состояний. Эталон для presentation-слоя vr_booking_web.
// Разметка-компаньон: booking-widget.template.html

const CLUBS = [
  { id: "effect", name: "Effect VR", tag: "один зал", desc: "Один зал: 4 шлема и 2 приставки PS5. Хорошо для компании до шести человек.",
    hours: "Ежедневно 11:00 – 22:30", close: 22 * 60 + 30,
    halls: [{ id: "e-main", name: "Зал", helmets: 4, ps5: 2, rows: [4, 2] }] },
  { id: "vray", name: "V-Ray", tag: "два зала", desc: "Флагманский зал на 12 шлемов для больших групп и праздников плюс отдельный зал с PS5.",
    hours: "Ежедневно 11:00 – 23:00", close: 23 * 60, gap: 0,
    halls: [
      { id: "v-big", name: "Большой зал", helmets: 12, ps5: 0, rows: [4, 4, 4] },
      { id: "v-small", name: "Малый зал", helmets: 4, ps5: 2, rows: [4, 2] },
      { id: "v-all", name: "Весь клуб", helmets: 16, ps5: 2, rows: [], combo: ["v-big", "v-small"] }
    ] }
];
const OPEN = 11 * 60;
const RATE = { vr: 700, ps5: 500 };
const DOW = ["вс", "пн", "вт", "ср", "чт", "пт", "сб"];
const MON = ["янв", "фев", "мар", "апр", "мая", "июн", "июл", "авг", "сен", "окт", "ноя", "дек"];
const MONN = ["январь", "февраль", "март", "апрель", "май", "июнь", "июль", "август", "сентябрь", "октябрь", "ноябрь", "декабрь"];
const MONL = ["января", "февраля", "марта", "апреля", "мая", "июня", "июля", "августа", "сентября", "октября", "ноября", "декабря"];
const PROMOS = { VRPARTY: 15, DR2026: 10 };
const DUR = { 60: "1 ч", 90: "1,5 ч", 120: "2 ч", 180: "3 ч" };
const maskPhone = (raw) => {
  let d = raw.replace(/\D/g, "");
  if (d.startsWith("8")) d = "7" + d.slice(1);
  if (!d.startsWith("7")) d = "7" + d;
  d = d.slice(0, 11);
  const p = d.slice(1);
  let out = "+7";
  if (p.length) out += " (" + p.slice(0, 3);
  if (p.length >= 3) out += ")";
  if (p.length > 3) out += " " + p.slice(3, 6);
  if (p.length > 6) out += "-" + p.slice(6, 8);
  if (p.length > 8) out += "-" + p.slice(8, 10);
  return out;
};

const hash = (s) => { let h = 2166136261; for (let i = 0; i < s.length; i++) { h ^= s.charCodeAt(i); h = Math.imul(h, 16777619); } return (h >>> 0) / 4294967295; };
const hhmm = (m) => String(Math.floor(m / 60)).padStart(2, "0") + ":" + String(m % 60).padStart(2, "0");
const plural = (n, one, few, many) => { const m10 = n % 10, m100 = n % 100; if (m10 === 1 && m100 !== 11) return one; if (m10 >= 2 && m10 <= 4 && (m100 < 12 || m100 > 14)) return few; return many; };
const money = (n) => n.toLocaleString("ru-RU").replace(/,/g, " ") + " ₽";

class Component extends DCLogic {
  state = {
    clubId: null, hallId: null, dateIdx: 0, duration: 60, slot: null, picked: [],
    name: "", phone: "", people: "", promoInput: "", promo: null, promoErr: "",
    scenario: "normal", vw: "mobile", view: "form", stolen: null, conflictShown: false, freed: false
  };

  club() { return CLUBS.find((c) => c.id === this.state.clubId) || null; }
  hall() { const c = this.club(); if (!c) return null; return c.halls.find((h) => h.id === this.state.hallId) || null; }
  dates() {
    const base = new Date(2026, 8, 3);
    return Array.from({ length: 90 }, (_, i) => { const d = new Date(base); d.setDate(base.getDate() + i); return d; });
  }
  monthKey(d) { return d.getFullYear() + "-" + d.getMonth(); }
  subHalls(hall) {
    const c = this.club();
    if (!hall.combo || !c) return [hall];
    return hall.combo.map((id) => c.halls.find((h) => h.id === id));
  }
  stationsOf(hall) {
    if (hall.combo) return this.subHalls(hall).reduce((a, h) => a.concat(this.stationsOf(h)), []);
    const out = [];
    for (let i = 0; i < hall.helmets; i++) out.push({ id: hall.id + "-vr" + (i + 1), type: "vr", name: "#" + (i + 1) });
    for (let i = 0; i < hall.ps5; i++) out.push({ id: hall.id + "-ps" + (i + 1), type: "ps5", name: "PS5-" + (i + 1) });
    return out;
  }
  slotList() {
    const c = this.club(); if (!c) return [];
    const step = this.state.duration + (c.gap ?? 10), out = [];
    for (let t = OPEN; t + this.state.duration <= c.close; t += step) out.push(t);
    return out;
  }
  isBusy(slot, stId) {
    if (this.state.scenario === "busy" && !this.state.freed) return true;
    if (this.state.stolen === stId && slot === this.state.slot) return true;
    const key = this.state.clubId + this.state.dateIdx + slot + stId;
    const evening = slot >= 18 * 60 ? 0.22 : 0;
    return hash(key) < 0.28 + evening;
  }
  freeAt(slot) {
    const h = this.hall(); if (!h) return 0;
    return this.stationsOf(h).filter((s) => !this.isBusy(slot, s.id)).length;
  }
  priceOf(id) {
    const t = id.indexOf("-ps") > -1 ? "ps5" : "vr";
    return (RATE[t] * this.state.duration) / 30;
  }
  totals() {
    const gross = this.state.picked.reduce((a, id) => a + this.priceOf(id), 0);
    const n = this.state.picked.length;
    const autoOn = this.props.autoDiscount ?? false;
    const minSt = this.props.autoDiscountFrom ?? 6;
    const autoPct = this.props.autoDiscountPercent ?? 10;
    const auto = autoOn && n >= minSt ? autoPct : 0;
    const promo = this.state.promo ? PROMOS[this.state.promo] : 0;
    const pct = Math.max(auto, promo);
    const label = pct === 0 ? "" : (promo >= auto && promo > 0 ? "Промокод " + this.state.promo + " · −" + pct + "%" : "Компания от " + minSt + " станций · −" + pct + "%");
    return { gross, pct, label, disc: Math.round((gross * pct) / 100), net: gross - Math.round((gross * pct) / 100) };
  }

  pick(club) {
    this.setState({ clubId: club.id, hallId: club.halls[0].id, slot: null, picked: [], stolen: null, conflictShown: false });
  }
  toggleStation(id) {
    this.setState((s) => ({ picked: s.picked.includes(id) ? s.picked.filter((x) => x !== id) : s.picked.concat(id), conflictShown: false }));
  }

  renderVals() {
    const st = this.state, club = this.club(), hall = this.hall(), T = this.totals();
    const slots = club ? this.slotList() : [];
    const dayFree = slots.map((s) => this.freeAt(s));
    const dayEmpty = !!hall && slots.length > 0 && dayFree.every((f) => f === 0);
    const A = club && club.id === "vray" ? "#0FB981" : "#A9F04A";
    const At = club && club.id === "vray" ? "rgba(15,185,129," : "rgba(169,240,74,";
    const Atx = club && club.id === "vray" ? "#8BEFCB" : "#DDFCAE";
    const chip = (on, extra) => "padding:10px 14px; border-radius:11px; border:1px solid " + (on ? A : "#2A2A33") + "; background:" + (on ? At + "0.18)" : "transparent") + "; color:" + (on ? Atx : "#9A9AA6") + "; font-size:14px; font-weight:600; cursor:pointer; white-space:nowrap;" + (extra || "");
    const tiny = (on) => "padding:6px 10px; border-radius:8px; border:1px solid " + (on ? "#A9F04A" : "#2A2A33") + "; background:" + (on ? "rgba(169,240,74,0.2)" : "transparent") + "; color:" + (on ? "#DDFCAE" : "#8A8A96") + "; font-size:12px; font-weight:600; cursor:pointer";
    const dates = this.dates();
    const d = dates[st.dateIdx];
    const activeMonth = st.month || this.monthKey(d);
    const freeIds = hall && st.slot ? this.stationsOf(hall).filter((s) => !this.isBusy(st.slot, s.id)).map((s) => s.id) : [];

    const stepNo = !club ? 1 : !st.slot ? 2 : st.picked.length === 0 ? 3 : 4;
    const titles = {
      1: "Куда идём играть?",
      2: "Когда и на сколько",
      3: "Кто где стоит",
      4: "Последний шаг"
    };
    const hints = {
      1: "Два клуба, разная вместимость. Оплата на месте — сейчас только держим за вами станции.",
      2: "Сначала выберите время: под каждым слотом видно, сколько станций в этом зале свободно.",
      3: "Отметьте станции для своей компании — одна станция на человека.",
      4: "Оставьте контакты, мы перезвоним только если что-то изменится."
    };

    const pipRow = (free, total) => Array.from({ length: Math.min(total, 12) }, (_, i) => ({
      style: "width:5px; height:5px; border-radius:2px; background:" + (i < free ? A : "#33333D")
    }));

    return {
      scenarios: [
        { id: "normal", label: "Обычный" }, { id: "busy", label: "Всё занято" }, { id: "conflict", label: "Конфликт брони" }
      ].map((s) => ({ label: s.label, style: tiny(st.scenario === s.id), onClick: () => this.setState({ scenario: s.id, freed: false, stolen: null, conflictShown: false }) })),
      viewports: [{ id: "mobile", label: "Мобильный" }, { id: "desktop", label: "Десктоп" }]
        .map((v) => ({ label: v.label, style: tiny(st.vw === v.id), onClick: () => this.setState({ vw: v.id }) })),
      frameStyle: "position:relative; width:100%; max-width:" + (st.vw === "mobile" ? "412px" : "760px") + "; border:1px solid #26262E; border-radius:22px; background:#101015; box-shadow:0 30px 80px rgba(0,0,0,0.55); overflow:hidden; transition:max-width .25s ease",

      isForm: st.view === "form", isDone: st.view === "done",
      stepNo, stepTitle: titles[stepNo], stepHint: hints[stepNo],
      hallTotal: hall ? hall.helmets + hall.ps5 : 0,

      clubCards: CLUBS.map((c) => {
        const on = st.clubId === c.id;
        const A = c.id === "vray" ? "#0FB981" : "#A9F04A";
        const Atint = c.id === "vray" ? "rgba(15,185,129," : "rgba(169,240,74,";
        const real = c.halls.filter((h) => !h.combo);
        const cap = c.halls.reduce((a, h) => Math.max(a, h.helmets + h.ps5), 0);
        const vr = real.reduce((a, h) => a + h.helmets, 0), ps = real.reduce((a, h) => a + h.ps5, 0);
        return {
          name: c.name, tag: c.tag, desc: c.desc, capacity: cap, hours: c.hours,
          style: "border:1px solid " + (on ? A : "#26262E") + "; border-radius:18px; padding:16px; background:" + (on ? "linear-gradient(180deg, " + Atint + "0.16), " + Atint + "0.04))" : "#15151A") + "; cursor:pointer; transition:border-color .15s, background .15s",
          tagStyle: "font-size:10px; letter-spacing:0.1em; text-transform:uppercase; padding:3px 7px; border-radius:6px; background:" + (on ? A : "#26262E") + "; color:" + (on ? "#08090A" : "#9A9AA6"),
          kit: [
            { label: vr + " " + plural(vr, "VR-шлем", "VR-шлема", "VR-шлемов"), glyphStyle: "width:20px; height:12px; border-radius:6px 6px 3px 3px; border:1.5px solid " + A + "; background:linear-gradient(180deg, " + Atint + "0.35), transparent)" },
            ps ? { label: ps + " PS5", glyphStyle: "width:18px; height:11px; border-radius:3px; border:1.5px solid #6E6E7A; border-left-width:5px; border-right-width:5px" } : null
          ].filter(Boolean),
          onClick: () => this.pick(c)
        };
      }),

      showWhen: !!club, showHalls: !!club && club.halls.length > 1,
      hallCards: club ? club.halls.map((h) => ({
        name: h.name, kitLabel: h.combo ? "оба зала · " + (h.helmets + h.ps5) + " мест" : h.helmets + " " + plural(h.helmets, "шлем", "шлема", "шлемов") + (h.ps5 ? " + " + h.ps5 + " PS5" : ""),
        style: h.combo
          ? "flex:1 0 100%; text-align:left; padding:9px 12px; border-radius:10px; cursor:pointer; font-size:13px; font-weight:500; border:1px dashed " + (st.hallId === h.id ? A : "#2E2E36") + "; background:" + (st.hallId === h.id ? At + "0.10)" : "transparent") + "; color:" + (st.hallId === h.id ? Atx : "#7C7C88")
          : chip(st.hallId === h.id, " flex:1; min-width:150px; text-align:left; padding:13px 14px"),
        nameStyle: h.combo ? "font-size:13px; font-weight:600" : "font-size:15px; font-weight:700",
        kitStyle: h.combo ? "font-size:12px; color:#6E6E7A; margin-top:1px" : "font-size:12px; color:#8A8A96; margin-top:3px",
        onClick: () => this.setState({ hallId: h.id, slot: null, picked: [], stolen: null, conflictShown: false })
      })) : [],

      dateOpen: !!st.dateOpen,
      dateLabel: d ? DOW[d.getDay()] + ", " + d.getDate() + " " + MONL[d.getMonth()] : "",
      openDate: () => this.setState({ dateOpen: true, month: this.monthKey(d) }),
      closeDate: () => this.setState({ dateOpen: false }),
      cal: (() => {
        const months = [];
        dates.forEach((dd) => { const k = this.monthKey(dd); if (!months.includes(k)) months.push(k); });
        const mi = Math.max(0, months.indexOf(activeMonth));
        const list = dates.map((dd, i) => ({ dd, i })).filter((x) => this.monthKey(x.dd) === months[mi]);
        const first = list[0].dd;
        const lead = (first.getDay() + 6) % 7;
        const blanks = Array.from({ length: lead }, () => ({ label: "", style: "visibility:hidden; padding:10px 0", onClick: () => {} }));
        const cells = list.map(({ dd, i }) => {
          const on = st.dateIdx === i;
          const weekend = dd.getDay() === 0 || dd.getDay() === 6;
          return {
            label: String(dd.getDate()),
            style: "padding:11px 0; border-radius:10px; text-align:center; font-size:15px; font-weight:600; font-variant-numeric:tabular-nums; cursor:pointer; border:1px solid " + (on ? A : "transparent") + "; background:" + (on ? At + "0.18)" : "transparent") + "; color:" + (on ? Atx : weekend ? "#8A8A96" : "#E2E2E8"),
            onClick: () => this.setState({ dateIdx: i, dateOpen: false, slot: null, picked: [], stolen: null, freed: false, conflictShown: false })
          };
        });
        return {
          title: MONN[first.getMonth()] + " " + first.getFullYear(),
          heads: ["пн", "вт", "ср", "чт", "пт", "сб", "вс"],
          cells: blanks.concat(cells),
          prevStyle: "padding:8px 12px; border-radius:9px; border:1px solid #2A2A33; background:transparent; font-size:15px; cursor:" + (mi > 0 ? "pointer" : "not-allowed") + "; color:" + (mi > 0 ? "#C9C9D2" : "#3E3E48"),
          nextStyle: "padding:8px 12px; border-radius:9px; border:1px solid #2A2A33; background:transparent; font-size:15px; cursor:" + (mi < months.length - 1 ? "pointer" : "not-allowed") + "; color:" + (mi < months.length - 1 ? "#C9C9D2" : "#3E3E48"),
          onPrev: () => { if (mi > 0) this.setState({ month: months[mi - 1] }); },
          onNext: () => { if (mi < months.length - 1) this.setState({ month: months[mi + 1] }); }
        };
      })(),

      durationChips: [60, 120, 180].map((m) => ({
        label: DUR[m], style: chip(st.duration === m, " flex:1; text-align:center; padding:10px 8px"),
        onClick: () => this.setState({ duration: m, slot: null, picked: [] })
      })),

      dayEmpty, hasSlots: !!hall && !dayEmpty,
      slotChips: slots.map((s) => {
        const free = dayFree[slots.indexOf(s)], total = hall ? hall.helmets + hall.ps5 : 0, on = st.slot === s, out = free === 0;
        return {
          time: hhmm(s), pips: pipRow(free, total),
          freeLabel: out ? "занято" : free + " из " + total,
          freeStyle: "font-size:11px; margin-top:6px; color:" + (out ? "#6E6E7A" : on ? Atx : "#8A8A96") + (out ? "; text-decoration:line-through" : ""),
          style: "display:flex; flex-direction:column; align-items:flex-start; padding:11px 12px 10px; border-radius:13px; cursor:" + (out ? "not-allowed" : "pointer") + "; border:1px solid " + (on ? A : out ? "#232329" : "#2A2A33") + "; color:" + (on ? "#F2F2F5" : out ? "#55555F" : "#C9C9D2") + "; background:" + (on ? At + "0.2)" : out ? "repeating-linear-gradient(135deg, #16161B 0 5px, #121217 5px 10px)" : "#15151A"),
          onClick: out ? () => {} : () => this.setState({ slot: s, picked: [], conflictShown: false })
        };
      }),

      quickPicks: (() => {
        const opts = [2, 4, 6, 8, 12].filter((n) => n <= freeIds.length);
        if (freeIds.length > 0 && !opts.includes(freeIds.length)) opts.push(freeIds.length);
        return opts.map((n) => ({
          label: n === freeIds.length ? "все " + n : String(n),
          style: chip(st.picked.length === n, " flex:none; padding:9px 15px; font-size:15px"),
          onClick: () => this.setState({ picked: freeIds.slice(0, n), conflictShown: false })
        })).concat(st.picked.length ? [{
          label: "сбросить", style: "flex:none; padding:9px 13px; border-radius:11px; border:1px dashed #3A3A46; background:transparent; color:#8A8A96; font-size:14px; cursor:pointer",
          onClick: () => this.setState({ picked: [], conflictShown: false })
        }] : []);
      })(),

      showPlan: !!hall && !!st.slot,
      planHint: hall && st.slot ? "Свободно " + this.freeAt(st.slot) + " из " + (hall.helmets + hall.ps5) + " · выбрано " + st.picked.length : "",
      planGroups: hall ? (() => {
        const subs = this.subHalls(hall);
        const combo = !!hall.combo;
        const flat = [];
        subs.forEach((h, hi) => { const sts = this.stationsOf(h); let k = 0; h.rows.forEach((n, ri) => { flat.push({ n, ri, hi, hall: h, items: sts.slice(k, k + n) }); k += n; }); });
        const mapRow = ({ n, ri, hall: h, items }) => {
          const isPs = items[0] && items[0].type === "ps5";
          return {
            label: isPs ? "приставки PS5 · диван" : "ряд " + (ri + 1) + " · VR",
            gridStyle: "display:grid; grid-template-columns:repeat(" + (st.vw === "mobile" ? Math.min(n, 4) : n) + ", 1fr); gap:8px",
            items: items.map((s) => {
              const busy = this.isBusy(st.slot, s.id), sel = st.picked.includes(s.id);
              const stolen = st.stolen === s.id;
              return {
                name: s.name,
                badge: stolen ? "заняли" : busy ? "занято" : sel ? "✓ моя" : "свободно",
                badgeStyle: "font-size:10px; margin-top:3px; letter-spacing:0.04em; color:" + (sel ? Atx : busy ? "#6E6E7A" : "#7C7C88") + (busy ? "; text-decoration:line-through" : ""),
                visorStyle: s.type === "ps5"
                  ? "width:34px; height:16px; border-radius:4px; border:2px solid " + (sel ? Atx : busy ? "#3A3A44" : "#6E6E7A") + "; border-left-width:8px; border-right-width:8px"
                  : "width:38px; height:22px; border-radius:11px 11px 5px 5px; border:2px solid " + (sel ? Atx : busy ? "#3A3A44" : "#7E7E8C") + "; background:" + (sel ? "linear-gradient(180deg, " + At + "0.45), transparent)" : busy ? "transparent" : "linear-gradient(180deg, rgba(255,255,255,0.09), transparent)"),
                style: "display:flex; flex-direction:column; align-items:center; padding:12px 6px 10px; border-radius:14px; animation:podIn .18s ease both; cursor:" + (busy ? "not-allowed" : "pointer") + "; border:" + (sel ? "2px solid " + A : "1px solid " + (busy ? "#232329" : "#33333D")) + "; background:" + (sel ? At + "0.22)" : busy ? "repeating-linear-gradient(135deg, #17171C 0 5px, #131318 5px 10px)" : "#191920") + "; color:" + (sel ? "#F2F2F5" : busy ? "#55555F" : "#C9C9D2"),
                onClick: busy ? () => {} : () => this.toggleStation(s.id)
              };
            })
          };
        };
        return subs.map((h, hi) => {
          const rows = flat.filter((r) => r.hi === hi);
          const sts = this.stationsOf(h);
          const free = sts.filter((s) => !this.isBusy(st.slot, s.id)).length;
          return {
            showHeader: combo, name: h.name,
            meta: free + " из " + sts.length + " свободно",
            style: combo
              ? "border:1px solid #2A2A33; border-radius:14px; padding:14px 12px 12px; background:" + (hi % 2 === 0 ? "rgba(255,255,255,0.022)" : "rgba(255,255,255,0.05)")
              : "",
            rows: rows.map(mapRow)
          };
        });
      })() : [],

      legend: [
        { label: "свободно", mark: "", swatchStyle: "width:18px; height:18px; border-radius:6px; border:1px solid #33333D; background:#191920" },
        { label: "занято — штриховка", mark: "", swatchStyle: "width:18px; height:18px; border-radius:6px; border:1px solid #232329; background:repeating-linear-gradient(135deg, #17171C 0 4px, #2E2E38 4px 8px)" },
        { label: "выбрано мной — рамка и ✓", mark: "✓", swatchStyle: "width:18px; height:18px; border-radius:6px; border:2px solid " + A + "; background:" + At + "0.22); font-size:10px; color:" + Atx + "; display:flex; align-items:center; justify-content:center" }
      ],

      showContacts: st.picked.length > 0,
      fields: [
        { key: "name", label: "Имя", placeholder: "Как к вам обращаться", value: st.name },
        { key: "phone", label: "Телефон", placeholder: "+7 (900) 000-00-00", value: st.phone, mask: true },
        { key: "people", label: "Сколько будет всего, с учётом игроков", placeholder: String(st.picked.length || ""), value: st.people }
      ].map((f) => ({ ...f, onChange: (e) => this.setState({ [f.key]: f.mask ? maskPhone(e.target.value) : e.target.value }) })),

      promo: {
        value: st.promoInput,
        onChange: (e) => this.setState({ promoInput: e.target.value.toUpperCase(), promoErr: "" }),
        onApply: () => {
          const code = st.promoInput.trim().toUpperCase();
          if (PROMOS[code]) this.setState({ promo: code, promoErr: "" });
          else this.setState({ promo: null, promoErr: "Такого кода нет — но скидка от 6 станций сработает сама." });
        },
        msg: st.promo ? "Код " + st.promo + " принят: −" + PROMOS[st.promo] + "%" : st.promoErr || ((this.props.autoDiscount ?? false) ? "Скидка от " + (this.props.autoDiscountFrom ?? 6) + " станций начисляется автоматически." : "Если есть промокод — введите его здесь."),
        msgStyle: "font-size:12px; margin-top:9px; line-height:1.45; color:" + (st.promo ? "#CDF98F" : st.promoErr ? "#FFB020" : "#6E6E7A")
      },

      sum: (() => {
        const end = st.slot ? st.slot + st.duration : 0;
        const combo = hall && !!hall.combo;
        const lines = st.picked.map((id) => ({
          label: (combo ? (id.indexOf("v-big") === 0 ? "Большой зал · " : "Малый зал · ") : "") + (id.indexOf("-ps") > -1 ? "PS5 " : "VR-шлем ") + id.split("-").pop().replace(/[a-z]/g, ""),
          price: money(this.priceOf(id))
        }));
        const ppl = st.people || String(st.picked.length);
        return {
          club: club ? club.name : "", hall: hall ? hall.name : "",
          dateLong: d ? DOW[d.getDay()] + ", " + d.getDate() + " " + MONL[d.getMonth()] : "",
          timeRange: st.slot ? hhmm(st.slot) + "–" + hhmm(end) : "",
          durationLabel: DUR[st.duration] || st.duration + " мин",
          lines, people: ppl + " " + plural(parseInt(ppl, 10) || 0, "человека", "человек", "человек"),
          hasDiscount: T.pct > 0, discountLabel: T.label, discountSum: money(T.disc),
          total: money(T.net), contact: (st.name || "—") + ", " + (st.phone || "телефон не указан")
        };
      })(),

      bar: (() => {
        const n = st.picked.length;
        const ready = n > 0 && st.name.trim().length > 1 && st.phone.trim().length > 5;
        const line = !club ? "Выберите клуб" : !st.slot ? club.name + " · " + (hall ? hall.name : "") : n === 0 ? "Отметьте станции на плане" : n + " " + plural(n, "станция", "станции", "станций") + " · " + hhmm(st.slot) + "–" + hhmm(st.slot + st.duration);
        const active = n > 0;
        return {
          line, total: n ? money(T.net) : "—",
          old: T.pct > 0 ? money(T.gross) : "",
          oldStyle: "font-size:13px; color:#6E6E7A; text-decoration:line-through" + (T.pct > 0 ? "" : "; display:none"),
          cta: n === 0 ? "Далее" : ready ? "Забронировать" : "Заполните контакты",
          btnStyle: "flex:none; padding:14px 20px; border-radius:13px; border:none; font-size:15px; font-weight:700; cursor:" + (ready ? "pointer" : "not-allowed") + "; background:" + (ready ? A : active ? "#2A2A33" : "#202027") + "; color:" + (ready ? "#08090A" : "#6E6E7A"),
          onClick: !ready ? () => {} : () => {
            if (st.scenario === "conflict" && !st.conflictShown) {
              this.setState((s) => ({ stolen: s.picked[0], picked: s.picked.slice(1), conflictShown: true }));
            } else this.setState({ view: "done" });
          }
        };
      })(),

      conflict: (() => {
        const stolenName = st.stolen ? st.stolen.split("-").pop().replace("vr", "шлем ").replace("ps", "PS5-") : "";
        const alt = hall && st.slot ? this.stationsOf(hall).find((s) => !this.isBusy(st.slot, s.id) && !st.picked.includes(s.id)) : null;
        return {
          show: st.conflictShown && !!st.stolen,
          title: "Одну станцию забрали, пока вы оформляли",
          text: stolenName + " на " + hhmm(st.slot || 0) + " только что забронировали. "
            + (st.picked.length === 0
                ? (alt ? "Это была ваша единственная станция — свободна " + alt.name + " в этом же зале." : "Свободных станций в этом зале на это время больше нет.")
                : "Остальные " + st.picked.length + " " + plural(st.picked.length, "станцию", "станции", "станций") + " держим за вами"
                  + (alt ? " — свободна " + alt.name + " в этом же зале." : ", свободных в этом зале больше нет.")),
          keepLabel: alt ? "Взять " + alt.name : st.picked.length === 0 ? "Выбрать другое время" : "Продолжить без неё",
          onKeep: () => {
            if (alt) this.setState((s) => ({ picked: s.picked.concat(alt.id), conflictShown: false }));
            else if (st.picked.length === 0) this.setState({ slot: null, picked: [], conflictShown: false, stolen: null });
            else this.setState({ conflictShown: false });
          },
          onDismiss: () => this.setState({ slot: null, picked: [], conflictShown: false, stolen: null })
        };
      })(),

      empty: {
        title: "На " + (d ? d.getDate() + " " + MONL[d.getMonth()] : "эту дату") + " всё занято",
        text: "В этом зале не осталось ни одной свободной станции. Ближайшие варианты:",
        actions: [
          { label: "Посмотреть " + (dates[st.dateIdx + 1] ? dates[st.dateIdx + 1].getDate() + " " + MONL[dates[st.dateIdx + 1].getMonth()] : "следующий день"), primary: true, onClick: () => this.setState({ dateIdx: Math.min(st.dateIdx + 1, 9), freed: true, slot: null, picked: [] }) },
          club && club.halls.length > 1
            ? { label: "Другой зал " + club.name, onClick: () => this.setState({ hallId: club.halls.find((h) => h.id !== st.hallId).id, freed: true, slot: null, picked: [] }) }
            : { label: "Посмотреть другой клуб", onClick: () => this.pick(CLUBS.find((c) => c.id !== st.clubId)) },
          { label: "Сеанс на 1 час — слотов больше", onClick: () => this.setState({ duration: 60, freed: true, slot: null, picked: [] }) }
        ].map((a) => ({
          label: a.label, onClick: a.onClick,
          style: "padding:12px 14px; border-radius:11px; cursor:pointer; font-size:14px; font-weight:600; border:1px solid " + (a.primary ? A : "#2A2A33") + "; background:" + (a.primary ? A : "transparent") + "; color:" + (a.primary ? "#08090A" : "#C9C9D2")
        }))
      },

      bookingNo: "VR-" + (1200 + st.dateIdx * 7 + st.picked.length),
      reset: () => this.setState({ view: "form", clubId: null, hallId: null, slot: null, picked: [], name: "", phone: "", people: "", promo: null, promoInput: "", stolen: null, conflictShown: false }),

      notes: [
        { title: "Время → станции", text: "Сначала слот: под каждым временем строка точек — сколько станций свободно из всех в зале. Дальше открывается план зала, где видно, кто где стоит." },
        { title: "Свободно / занято / моё", text: "Занятые станции заштрихованы и подписаны зачёркнутым «занято». Выбранные получают двойную рамку и подпись «✓ моя». Разница читается без цвета." },
        { title: "Всё занято", text: "Переключатель «Всё занято» вверху: вместо пустой сетки — три конкретных выхода (следующий день, другой зал, сеанс на 1 час)." },
        { title: "Конфликт брони", text: "Переключатель «Конфликт брони», затем нажмите «Забронировать»: одну станцию забирают, остальной выбор сохраняется, сразу предлагается свободная замена в том же зале." }
      ]
    };
  }
}
