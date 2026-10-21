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

  // ---- VK Mini App ----
  // ВК добавляет к адресу vk_app_id и др. (vk_user_id, vk_platform…). Тогда
  // подключаем VK Bridge (web/vk-bridge.min.js, с нашего же адреса — политика
  // безопасности чужие скрипты не пускает) и сразу говорим ВК, что приложение
  // запущено: иначе мобильный ВК держит свою заставку и считает приложение
  // зависшим. Имя из профиля — для формы; приходит асинхронно, Dart ждёт его
  // не дольше пары секунд (см. EmbedChannel.vkUserName).
  window.__vrBooking.isVk = /[?&]vk_app_id=/.test(location.search);
  window.__vrBooking.vkName = null;
  var vkNameWaiters = [];
  function vkNameKnown(name) {
    window.__vrBooking.vkName = name || '';
    while (vkNameWaiters.length) vkNameWaiters.shift()(window.__vrBooking.vkName);
  }
  // Dart вызывает: колбэк получает имя (или '' — если имени нет).
  window.__vrBooking.onVkName = function (cb) {
    if (window.__vrBooking.vkName !== null) cb(window.__vrBooking.vkName);
    else vkNameWaiters.push(cb);
  };
  if (window.__vrBooking.isVk) {
    var vkScript = document.createElement('script');
    vkScript.src = 'vk-bridge.min.js';
    vkScript.onload = function () {
      var bridge = window.vkBridge;
      if (!bridge) return vkNameKnown('');
      bridge.send('VKWebAppInit').catch(function () {});
      // Тёмное оформление и под него — панель ВК (на части платформ не
      // поддерживается: ошибку глушим).
      bridge
        .send('VKWebAppSetViewSettings', {
          status_bar_style: 'light',
          action_bar_color: '#08090A',
          navigation_bar_color: '#08090A',
        })
        .catch(function () {});
      bridge
        .send('VKWebAppGetUserInfo')
        .then(function (u) {
          vkNameKnown(((u && u.first_name) || '').trim());
        })
        .catch(function () {
          vkNameKnown('');
        });
    };
    vkScript.onerror = function () {
      vkNameKnown('');
    };
    document.head.appendChild(vkScript);
  }

  // ---- CanvasKit параллельно с main.dart.js ----
  // Штатно движок берётся за CanvasKit (2–3 МБ) только после main.dart.js.
  // Папка — та же, что canvasKitBaseUrl в flutter_bootstrap.js (скрипт сборки
  // подставляет engine-<ревизия>/ в оба файла).
  var ENGINE = 'canvaskit/';
  // Вариант chromium движок берёт там же, где он сам решает: есть
  // ImageDecoder и Intl.v8BreakIterator с Intl.Segmenter. Признаки — те же,
  // иначе preload скачает не тот файл, и это мегабайты мимо кэша.
  var chromium = typeof ImageDecoder !== 'undefined' &&
    (navigator.vendor === 'Google Inc.' || navigator.userAgent.indexOf('Edg/') >= 0) &&
    typeof Intl.v8BreakIterator !== 'undefined' &&
    typeof Intl.Segmenter !== 'undefined';
  var pre = document.createElement('link');
  pre.rel = 'preload';
  pre.as = 'fetch';
  pre.type = 'application/wasm';
  pre.crossOrigin = 'anonymous';
  pre.href = ENGINE + (chromium ? 'chromium/canvaskit.wasm' : 'canvaskit.wasm');
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
      // Имя файла важно: «Invalid or unexpected token» в main.dart.js почти
      // всегда значит, что сервер отдал сжатые байты без Content-Encoding.
      var where = e.filename ? ' в ' + e.filename.split('/').pop() : '';
      report((e.message || 'ошибка скрипта') + where);
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
