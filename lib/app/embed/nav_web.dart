import 'dart:js_interop';

@JS('window.location')
external _Location get _location;

extension type _Location._(JSObject _) implements JSObject {
  external String get origin;
  external String get pathname;
  external set href(String value);
}

void toWidget() {
  try {
    _location.href = '${_location.origin}${_location.pathname}';
  } catch (_) {
    // недоступно — молча игнорируем
  }
}

void toAdmin() {
  try {
    _location.href = '${_location.origin}${_location.pathname}?admin=1';
  } catch (_) {}
}
