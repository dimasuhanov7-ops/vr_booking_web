import 'package:flutter/foundation.dart';


/// Разбор query-параметров запуска виджета.
///
/// Виджет открывается по URL (в т.ч. внутри `<iframe>`), поэтому вся настройка
/// экземпляра — через query, а не через `--dart-define`. Контракт: `docs/EMBED.md`.
@immutable
class LaunchParams {
  /// Создаёт набор параметров.
  const LaunchParams({
    this.adminMode = false,
    this.clubSlug,
    this.source = 'site',
    this.initialDate,
    this.initialDurationMinutes,
    this.utm = const <String, String>{},
  });

  /// Читает параметры из адресной строки (на не-web всегда пусто).
  factory LaunchParams.fromUri() {
    if (!kIsWeb) return const LaunchParams();
    final Map<String, String> p = Uri.base.queryParameters;

    return LaunchParams(
      adminMode: p['admin'] == '1',
      clubSlug: _clubSlug(p['club']),
      source: _source(p),
      initialDate: _date(p['date']),
      initialDurationMinutes: _duration(p['duration']),
      utm: utmFrom(p),
    );
  }

  /// Открыт служебный раздел персонала (`?admin=1`).
  final bool adminMode;

  /// Клуб зафиксирован (`?club=effect` | `?club=vray`) — выбор клуба скрыт.
  /// `null` — показываем список клубов.
  final String? clubSlug;

  /// Источник брони для `booking_orders.source`: `site` | `vk`.
  final String source;

  /// Предвыбранная дата (`?date=YYYY-MM-DD`), если валидна и не в прошлом.
  /// Окно записи клуба проверяет BLoC: оно задаётся в админке.
  final DateTime? initialDate;

  /// Предвыбранная длительность (`?duration=` в минутах, кратно часу).
  /// Если у клуба такой нет, BLoC возьмёт ближайшую из настройки клуба.
  final int? initialDurationMinutes;

  /// UTM-метки (`utm_source`, `utm_medium`, `utm_campaign`, `utm_content`,
  /// `utm_term`). Сайт передаёт в адрес виджета метки своей страницы —
  /// см. `docs/SITE_EMBED.md`.
  final Map<String, String> utm;

  /// Ключи UTM, которые принимает и сервер.
  static const List<String> utmKeys = <String>[
    'utm_source',
    'utm_medium',
    'utm_campaign',
    'utm_content',
    'utm_term',
  ];

  /// Slug'и `effect` / `vray` (и полные) -> канонический slug таблицы `booking_clubs`.
  static String? _clubSlug(String? raw) {
    switch (raw?.trim().toLowerCase()) {
      case 'effect':
      case 'effect_vr':
      case 'effectvr':
        return 'effect_vr';
      case 'vray':
      case 'v_ray':
      case 'v-ray':
        return 'v_ray';
      default:
        return null;
    }
  }

  static String _source(Map<String, String> p) =>
      p.containsKey('vk_app_id') || p['source'] == 'vk' ? 'vk' : 'site';

  static DateTime? _date(String? raw) {
    if (raw == null) return null;
    final DateTime? parsed = DateTime.tryParse(raw);
    if (parsed == null) return null;
    final DateTime day = DateTime(parsed.year, parsed.month, parsed.day);
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);
    if (day.isBefore(today)) return null;
    return day;
  }

  static int? _duration(String? raw) {
    final int? m = int.tryParse(raw ?? '');
    if (m == null || m < 60 || m > 480 || m % 60 != 0) return null;
    return m;
  }

  /// UTM-метки из query: только [utmKeys], без пустых, не длиннее 100 символов.
  static Map<String, String> utmFrom(Map<String, String> p) => <String, String>{
        for (final String k in utmKeys)
          if ((p[k] ?? '').trim().isNotEmpty)
            k: p[k]!.trim().length > 100
                ? p[k]!.trim().substring(0, 100)
                : p[k]!.trim(),
      };
}
