import 'local_store_stub.dart'
    if (dart.library.js_interop) 'local_store_web.dart' as impl;

/// Тонкая синхронная обёртка над `window.localStorage`.
///
/// Виджет хранит здесь только удобства на устройстве клиента (имя+телефон,
/// список своих броней). Всё в try/catch: приватный режим / отключённое
/// хранилище не должны ронять виджет. На не-web — no-op.
abstract final class LocalStore {
  const LocalStore._();

  /// Значение по ключу или `null`.
  static String? read(String key) => impl.read(key);

  /// Записать значение.
  static void write(String key, String value) => impl.write(key, value);

  /// Удалить ключ.
  static void remove(String key) => impl.remove(key);
}
