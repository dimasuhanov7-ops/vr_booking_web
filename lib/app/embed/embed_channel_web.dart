import 'dart:async';
import 'dart:js_interop';

/// Мост из `web/index.html`: `window.__vrBooking.send(msg)` уже проверяет, что
/// виджет во фрейме, и глушит ошибки. Если моста нет — молча выходим.
@JS('window.__vrBooking')
external _VrBookingBridge? get _bridge;

extension type _VrBookingBridge._(JSObject _) implements JSObject {
  external void send(JSAny message);
  external bool? get isVk;
  external void onVkName(JSFunction callback);
}

/// Отправляет `{ type, ...data }` родительскому окну.
void send(String type, Map<String, Object?> data) {
  final _VrBookingBridge? bridge = _bridge;
  if (bridge == null) return;
  final Map<String, Object?> payload = <String, Object?>{'type': type, ...data};
  bridge.send(payload.jsify() as JSObject);
}

/// Открыт как VK Mini App (ВК добавил `vk_app_id` к адресу).
bool get isVk => _bridge?.isVk ?? false;

/// Имя из профиля ВК. Ждёт ответа VK Bridge не дольше [timeout]; `null`, если
/// это не ВК, имени нет или ВК не ответил.
Future<String?> vkUserName(Duration timeout) {
  final _VrBookingBridge? bridge = _bridge;
  if (bridge == null || !(bridge.isVk ?? false)) return Future<String?>.value();
  final Completer<String?> done = Completer<String?>();
  bridge.onVkName(((JSString name) {
    if (done.isCompleted) return;
    final String v = name.toDart.trim();
    done.complete(v.isEmpty ? null : v);
  }).toJS);
  return done.future.timeout(timeout, onTimeout: () => null);
}
