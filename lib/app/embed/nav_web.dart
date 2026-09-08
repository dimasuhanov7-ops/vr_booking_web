import 'dart:js_interop';

@JS('window.location')
external _Location get _location;

@JS('window.open')
external JSAny? _open(String url, String target);

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

void openExternal(String url) {
  if (url.isEmpty) return;
  try {
    _open(url, '_blank');
  } catch (_) {}
}
