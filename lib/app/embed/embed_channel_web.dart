import 'dart:js_interop';

/// Мост из `web/index.html`: `window.__vrBooking.send(msg)` уже проверяет, что
/// виджет во фрейме, и глушит ошибки. Если моста нет — молча выходим.
@JS('window.__vrBooking')
external _VrBookingBridge? get _bridge;

extension type _VrBookingBridge._(JSObject _) implements JSObject {
  external void send(JSAny message);
}

/// Отправляет `{ type, ...data }` родительскому окну.
void send(String type, Map<String, Object?> data) {
  final _VrBookingBridge? bridge = _bridge;
  if (bridge == null) return;
  final Map<String, Object?> payload = <String, Object?>{'type': type, ...data};
  bridge.send(payload.jsify() as JSObject);
}
