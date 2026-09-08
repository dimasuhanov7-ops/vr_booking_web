import 'embed_channel_stub.dart'
    if (dart.library.js_interop) 'embed_channel_web.dart' as impl;

/// Исходящие сообщения родительскому окну, когда виджет открыт в `<iframe>`.
///
/// Все сообщения — `window.parent.postMessage({ type, ... }, '*')`. Если виджет
/// открыт не во фрейме, вызовы — no-op. Контракт и примеры: `docs/EMBED.md`.
abstract final class EmbedChannel {
  const EmbedChannel._();

  static const String _prefix = 'vr-booking';

  /// Виджет загрузился и готов к работе. Отправляется один раз.
  static void ready() => impl.send('$_prefix:ready', const <String, Object?>{});

  /// Текущая высота контента в CSS-пикселях — родитель подгоняет высоту iframe.
  static void height(double pixels) =>
      impl.send('$_prefix:height', <String, Object?>{'height': pixels.ceil()});

  /// Шаг мастера сменился (1..N). Для аналитики/скролла родителя.
  static void step(int number) =>
      impl.send('$_prefix:step', <String, Object?>{'step': number});

  /// Бронь успешно создана.
  static void success({
    required String orderId,
    required String clubSlug,
    required int stationCount,
    required int minutes,
    required num amount,
  }) =>
      impl.send('$_prefix:success', <String, Object?>{
        'orderId': orderId,
        'club': clubSlug,
        'stationCount': stationCount,
        'minutes': minutes,
        'amount': amount,
      });
}
