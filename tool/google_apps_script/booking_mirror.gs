/**
 * Приёмник зеркала броней VR-клубов для Google Таблицы.
 *
 * Ставится в саму таблицу: «Расширения» → «Apps Script». Edge Function
 * `booking-mirror` в Supabase присылает сюда строки броней, скрипт добавляет
 * новые и обновляет существующие (по колонке «ID заказа»). Настройка —
 * docs/MIRROR.md.
 *
 * Безопасность:
 *  - без секрета (Script Properties → MIRROR_SECRET) запрос отклоняется;
 *  - значения, начинающиеся с = + - @, пишутся как текст: имя и комментарий
 *    вводит клиент, и «=IMPORTXML(...)» не должно стать формулой;
 *  - LockService: два одновременных вызова не создадут дубль строки.
 */

const SHEET_NAME = 'Брони';

// Порядок колонок совпадает со строками из booking-mirror/index.ts.
const HEADER = [
  'Дата', 'Время', 'Клуб', 'Залы и состав', 'Гость', 'Телефон', 'Человек',
  'Статус', 'Источник', 'Стоимость, ₽', 'Предоплата, ₽', 'Комментарий',
  'Создана', 'Обновлено', 'ID заказа',
];
const ID_COL = 15; // «ID заказа», 1-based

/**
 * Запустить один раз вручную: создаёт секрет и печатает его в журнал.
 * Секрет нужно вставить в Supabase как GOOGLE_SCRIPT_SECRET.
 */
function setupSecret() {
  const secret = Utilities.getUuid().replace(/-/g, '') + Utilities.getUuid().replace(/-/g, '');
  PropertiesService.getScriptProperties().setProperty('MIRROR_SECRET', secret);
  Logger.log('GOOGLE_SCRIPT_SECRET = ' + secret);
}

function doPost(e) {
  let body;
  try {
    body = JSON.parse(e.postData.contents);
  } catch (err) {
    return reply({ error: 'BAD_JSON' });
  }

  const expected = PropertiesService.getScriptProperties().getProperty('MIRROR_SECRET');
  if (!expected || body.secret !== expected) {
    return reply({ error: 'UNAUTHORIZED' });
  }

  const rows = Array.isArray(body.rows) ? body.rows.map(safeRow) : [];
  const lock = LockService.getScriptLock();
  lock.waitLock(30000);
  try {
    const sheet = ensureSheet();
    if (body.mode === 'resync') removeDuplicates(sheet);
    const result = upsert(sheet, rows);
    return reply({ ok: true, updated: result.updated, appended: result.appended });
  } finally {
    lock.releaseLock();
  }
}

/** Лист «Брони» с шапкой; создаёт, если его нет. */
function ensureSheet() {
  const ss = SpreadsheetApp.getActiveSpreadsheet();
  let sheet = ss.getSheetByName(SHEET_NAME);
  if (!sheet) sheet = ss.insertSheet(SHEET_NAME);

  const head = sheet.getRange(1, 1, 1, HEADER.length);
  if (head.getValues()[0].join('|') !== HEADER.join('|')) {
    head.setValues([HEADER]).setFontWeight('bold');
    sheet.setFrozenRows(1);
  }
  return sheet;
}

/** Обновить строки с тем же ID заказа, остальные дописать в конец. */
function upsert(sheet, rows) {
  const width = HEADER.length;
  const last = sheet.getLastRow();
  const data = last > 1
    ? sheet.getRange(2, 1, last - 1, width).getValues().map(safeRow)
    : [];

  const index = {};
  data.forEach(function (r, i) {
    const id = String(r[ID_COL - 1]);
    if (id && !(id in index)) index[id] = i;
  });

  let updated = 0;
  let appended = 0;
  rows.forEach(function (r) {
    const id = String(r[ID_COL - 1]);
    if (!id) return;
    if (id in index) {
      data[index[id]] = r;
      updated++;
    } else {
      index[id] = data.length;
      data.push(r);
      appended++;
    }
  });

  if (data.length) sheet.getRange(2, 1, data.length, width).setValues(data);
  return { updated: updated, appended: appended };
}

/** Лишние строки одного заказа (если кто-то скопировал строку руками). */
function removeDuplicates(sheet) {
  const last = sheet.getLastRow();
  if (last < 3) return;
  const ids = sheet.getRange(2, ID_COL, last - 1, 1).getValues();
  const seen = {};
  const extra = [];
  ids.forEach(function (r, i) {
    const id = String(r[0]);
    if (!id) return;
    if (seen[id]) extra.push(i + 2);
    else seen[id] = true;
  });
  extra.reverse().forEach(function (row) {
    sheet.deleteRow(row);
  });
}

function safeRow(r) {
  const row = Array.isArray(r) ? r.slice(0, HEADER.length) : [];
  while (row.length < HEADER.length) row.push('');
  return row.map(safeCell);
}

/** Текст, похожий на формулу, — с апострофом: так таблица хранит его как текст. */
function safeCell(v) {
  if (typeof v === 'string' && /^[=+\-@]/.test(v)) return "'" + v;
  return v;
}

function reply(obj) {
  return ContentService
    .createTextOutput(JSON.stringify(obj))
    .setMimeType(ContentService.MimeType.JSON);
}
