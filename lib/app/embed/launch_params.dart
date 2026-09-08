import 'package:flutter/foundation.dart';

import '../../features/booking/domain/state/booking_bloc.dart';
import '../config/booking_config.dart';

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
    );
  }

  /// Открыт служебный раздел персонала (`?admin=1`).
  final bool adminMode;

  /// Клуб зафиксирован (`?club=effect` | `?club=vray`) — выбор клуба скрыт.
  /// `null` — показываем список клубов.
  final String? clubSlug;

  /// Источник брони для `booking_orders.source`: `site` | `vk`.
  final String source;

  /// Предвыбранная дата (`?date=YYYY-MM-DD`), если валидна и в горизонте записи.
  final DateTime? initialDate;

  /// Предвыбранная длительность (`?duration=` в минутах), если из [BookingBloc.durations].
  final int? initialDurationMinutes;

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
    if (day.difference(today).inDays > BookingConfig.bookingHorizonDays) return null;
    return day;
  }

  static int? _duration(String? raw) {
    final int? m = int.tryParse(raw ?? '');
    return BookingBloc.durations.contains(m) ? m : null;
  }
}
