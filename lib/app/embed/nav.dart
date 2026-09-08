import 'nav_stub.dart' if (dart.library.js_interop) 'nav_web.dart' as impl;

/// Навигация уровня браузера — за пределами Flutter-роутинга (у приложения
/// раздел выбирается из query-строки один раз на старте, см. [нет роутера]).
abstract final class Nav {
  const Nav._();

  /// Уйти из админки к публичному виджету: сбросить `?admin=1` и перезагрузить.
  /// На не-web — no-op.
  static void toWidget() => impl.toWidget();
}
