{{flutter_js}}
{{flutter_build_config}}

// Движок (CanvasKit) — только со своего хостинга. Без canvasKitBaseUrl
// загрузчик Flutter берёт его с www.gstatic.com: из РФ это бывает медленно,
// а boot.js при этом заранее качает локальную копию — выходило два раза.
//
// tool/build_web.* переносит canvaskit/ в engine-<ревизия движка>/ и
// подставляет путь сюда и в boot.js: новый Flutter — новый адрес, поэтому
// движок можно кэшировать на год. Без скрипта сборки остаётся canvaskit/.
//
// Service worker Flutter (устаревший) не регистрируем: виджету он не нужен.
// Файл flutter_service_worker.js в сборке остаётся — это «уборщик», который
// снимает старую регистрацию у тех, кто заходил раньше.
_flutter.loader.load({
  config: { canvasKitBaseUrl: 'canvaskit/' },
});
