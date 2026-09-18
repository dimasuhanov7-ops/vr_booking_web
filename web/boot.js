// Старт виджета: заставка, мост к родительской странице, подсказка браузеру
// про CanvasKit и видимые ошибки загрузки.
//
// Вынесено из index.html отдельным файлом: встроенные <script> блокирует любая
// политика безопасности хостинга без 'unsafe-inline' (например, заголовок из
// .htaccess сайта на Joomla). Тогда заставка не снималась, даже если виджет под
// ней уже работал. Файл с того же адреса пропускает любая политика с 'self'.
(function () {
  // ---- Мост «виджет -> родительская страница» (docs/EMBED.md) ----
  function send(msg) {
    try {
      if (window.parent !== window) window.parent.postMessage(msg, '*');
    } catch (e) {}
  }
  // Пока грузится Flutter — примерная высота, чтобы iframe не был нулевым.
  window.addEventListener('load', function () {
    send({ type: 'vr-booking:height', height: 680 });
  });
  window.__vrBooking = { send: send };

  // ---- CanvasKit параллельно с main.dart.js ----
  // Штатно движок берётся за CanvasKit (2–3 МБ) только после main.dart.js.
  // Браузеры на Chromium берут вариант chromium — выбираем тот же файл, что
  // возьмёт движок: ошибка здесь — лишние мегабайты мимо кэша.
  var chromium = /Chrome\/|Chromium\/|CriOS\/|Edg\//.test(navigator.userAgent);
  var pre = document.createElement('link');
  pre.rel = 'preload';
  pre.as = 'fetch';
  pre.type = 'application/wasm';
  pre.crossOrigin = 'anonymous';
  pre.href = chromium
    ? 'canvaskit/chromium/canvaskit.wasm'
    : 'canvaskit/canvaskit.wasm';
  document.head.appendChild(pre);

  // ---- Заставка ----
  var started = false;
  var problems = [];

  function boot() {
    return document.getElementById('boot');
  }

  function show(text) {
    var b = boot();
    var box = b && b.querySelector('.err');
    if (!box) return;
    box.textContent = text;
    box.hidden = false;
  }

  // Причина сбоя видна прямо на экране: консоли на телефоне нет, а без неё
  // «вечная заставка» ничего не объясняет.
  function report(text) {
    if (started) return;
    if (problems.indexOf(text) >= 0) return;
    if (problems.length < 3) problems.push(text);
    show('Не удалось загрузить бронирование: ' + problems.join(' · '));
  }

  window.addEventListener('flutter-first-frame', function () {
    started = true;
    var b = boot();
    if (!b) return;
    b.classList.add('hide');
    setTimeout(function () {
      b.remove();
    }, 300);
  });

  // Ошибки скриптов и недоехавшие файлы движка.
  window.addEventListener(
    'error',
    function (e) {
      var t = e.target;
      if (t && t !== window && t.tagName) {
        var tag = t.tagName.toLowerCase();
        if (tag === 'script') report('не загрузился ' + t.src);
        else if (tag === 'link' && t.rel === 'preload') report('не загрузился ' + t.href);
        return;
      }
      report(e.message || 'ошибка скрипта');
    },
    true
  );

  window.addEventListener('unhandledrejection', function (e) {
    var r = e.reason;
    report((r && (r.message || String(r))) || 'ошибка загрузки');
  });

  // Политика безопасности сайта (CSP) режет скрипты, WebAssembly или запросы.
  document.addEventListener('securitypolicyviolation', function (e) {
    report(
      'политика безопасности сайта блокирует ' +
        e.violatedDirective +
        (e.blockedURI ? ' (' + e.blockedURI + ')' : '')
    );
  });

  setTimeout(function () {
    if (!started && problems.length === 0) {
      show('Загрузка идёт дольше обычного. Если так и останется — обновите страницу.');
    }
  }, 20000);
})();
