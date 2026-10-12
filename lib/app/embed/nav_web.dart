import 'dart:js_interop';

@JS('window.location')
external _Location get _location;

@JS('window.open')
external JSAny? _open(String url, String target);

@JS('Blob')
extension type _Blob._(JSObject _) implements JSObject {
  external factory _Blob(JSArray<JSString> parts, _BlobOptions options);
}

extension type _BlobOptions._(JSObject _) implements JSObject {
  external factory _BlobOptions({String type});
}

@JS('URL.createObjectURL')
external String _createObjectUrl(_Blob blob);

@JS('URL.revokeObjectURL')
external void _revokeObjectUrl(String url);

@JS('document.createElement')
external _Anchor _createElement(String tag);

extension type _Anchor._(JSObject _) implements JSObject {
  external set href(String value);
  external set download(String value);
  external void click();
}

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

void downloadText(String fileName, String mime, String content) {
  try {
    final _Blob blob = _Blob(<JSString>[content.toJS].toJS, _BlobOptions(type: mime));
    final String url = _createObjectUrl(blob);
    final _Anchor a = _createElement('a')
      ..href = url
      ..download = fileName;
    a.click();
    _revokeObjectUrl(url);
  } catch (_) {}
}
