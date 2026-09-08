import 'dart:js_interop';

@JS('window.localStorage')
external _Storage? get _ls;

extension type _Storage._(JSObject _) implements JSObject {
  external String? getItem(String key);
  external void setItem(String key, String value);
  external void removeItem(String key);
}

String? read(String key) {
  try {
    return _ls?.getItem(key);
  } catch (_) {
    return null;
  }
}

void write(String key, String value) {
  try {
    _ls?.setItem(key, value);
  } catch (_) {
    // приватный режим / квота — молча игнорируем
  }
}

void remove(String key) {
  try {
    _ls?.removeItem(key);
  } catch (_) {}
}
