# Встраивание виджета через `<iframe>`

Виджет — самостоятельная страница. На сайте клуба и в VK Mini Apps подключается
`<iframe>`'ом. Настройка экземпляра — только через query-параметры URL
(не `--dart-define`): один бандл обслуживает оба клуба и оба канала.

## URL-параметры

| Параметр | Значения | Назначение |
|---|---|---|
| `club` | `effect` \| `vray` | Зафиксировать клуб — экран выбора клуба скрыт, мастер из **3 шагов**. Принимает также `effect_vr` / `v_ray` / `v-ray`. Неизвестное значение игнорируется (показываем оба клуба). |
| `source` | `site` \| `vk` | Пишется в `booking_orders.source`. По умолчанию `site`; `vk` также включается автоматически при `vk_app_id` в URL (VK Mini App). |
| `date` | `YYYY-MM-DD` | Предвыбрать дату. Игнорируется, если в прошлом или дальше горизонта записи (30 дней). |
| `duration` | `60` \| `120` \| `180` \| `240` | Предвыбрать длительность сеанса (минуты). Другое значение игнорируется. |
| `admin` | `1` | Служебная панель персонала. **Не для публичного доступа** (пока без авторизации). |

Примеры:
```
https://book.effectvr.ru/?club=effect
https://book.effectvr.ru/?club=effect&source=site
https://book.effectvr.ru/?club=effect&date=2026-09-20&duration=120   ← CTA «Дни рождения»
https://<vk-mini-app-host>/?club=vray&source=vk
```

## Сообщения виджета родительскому окну

`window.parent.postMessage({ type, ... }, '*')` — только когда виджет во фрейме.
Все типы с префиксом `vr-booking:`. Слушать с проверкой `event.origin`.

| `type` | Поля | Когда |
|---|---|---|
| `vr-booking:ready` | — | Flutter загрузился, первый кадр отрисован. |
| `vr-booking:height` | `height` (int, CSS-px) | При изменении высоты контента (выбор клуба/зала/слота/станций, баннер конфликта, экран успеха). Значение уже устоявшееся (дебаунс ~120 мс, переходные всплески отфильтрованы). До старта Flutter один раз приходит `height: 680` из `index.html`. |
| `vr-booking:step` | `step` (int, 1..3\|4) | Сменился шаг мастера. |
| `vr-booking:success` | `orderId`, `club` (slug), `stationCount`, `minutes`, `amount` (₽, справочно) | Бронь успешно создана. Момент для цели в Метрике. |

Модель: **iframe тянется по контенту, скроллит родительская страница.**
Внутреннего скролла у виджета нет.

### Пример на стороне сайта

```html
<iframe id="vr-booking"
        src="https://book.effectvr.ru/?club=effect&source=site"
        style="width:100%;max-width:480px;border:0;display:block;height:680px"
        loading="lazy"
        title="Онлайн-бронирование Effect VR"></iframe>
<script>
  var frame = document.getElementById('vr-booking');
  var ORIGIN = 'https://book.effectvr.ru';
  window.addEventListener('message', function (e) {
    if (e.origin !== ORIGIN) return;
    var m = e.data || {};
    if (m.type === 'vr-booking:height' && m.height) {
      frame.style.height = m.height + 'px';
    }
    if (m.type === 'vr-booking:success') {
      // ym(XXXXXX, 'reachGoal', 'booking', { order: m.orderId, amount: m.amount });
    }
  });
</script>
```

## Что нужно на инфраструктуре

- Поддомен на HTTPS (иначе iframe со https-страницы не загрузится).
- Если сузите CORS `booking-intake` c `*` — добавьте в allowlist origin виджета
  (`https://book.effectvr.ru`) и VK. См. `docs/INTEGRATION.md`.
- Если добавите `Content-Security-Policy: frame-ancestors` на страницу с iframe —
  это на стороне **сайта**, виджет тут ничего не диктует. Виджет со своей стороны
  `X-Frame-Options` не ставит (см. `web/_headers`, `web/.htaccess`).

## Стабильность контракта

Имена сообщений (`vr-booking:*`), их поля и набор URL-параметров — публичный
контракт этого файла. Ломающие изменения — только по согласованию, новые
поля/типы добавляются обратносовместимо.
