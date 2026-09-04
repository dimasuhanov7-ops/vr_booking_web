import '../../domain/entity/club_entity.dart';

/// DTO строки таблицы `public.booking_clubs`.
class ClubDto {
  /// Создаёт DTO.
  const ClubDto({
    required this.id,
    required this.slug,
    required this.name,
    required this.timezone,
    required this.openTime,
    required this.closeTime,
    required this.slotGapMinutes,
    required this.sortOrder,
  });

  /// Разбирает JSON от Supabase.
  factory ClubDto.fromJson(Map<String, dynamic> json) => ClubDto(
        id: json['id'] as String,
        slug: json['slug'] as String,
        name: json['name'] as String,
        timezone: json['timezone'] as String? ?? 'Europe/Moscow',
        openTime: _parseTime(json['open_time'] as String? ?? '11:00:00'),
        closeTime: _parseTime(json['close_time'] as String? ?? '23:00:00'),
        slotGapMinutes: (json['slot_gap_minutes'] as num?)?.toInt() ?? 0,
        sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
      );

  /// Идентификатор клуба.
  final String id;

  /// Код клуба.
  final String slug;

  /// Название.
  final String name;

  /// Таймзона IANA.
  final String timezone;

  /// Время открытия.
  final Duration openTime;

  /// Время закрытия.
  final Duration closeTime;

  /// Пауза между сеансами, минут.
  final int slotGapMinutes;

  /// Порядок отображения.
  final int sortOrder;

  /// В доменную сущность.
  ClubEntity toEntity() => ClubEntity(
        id: id,
        slug: slug,
        name: name,
        timezone: timezone,
        openTime: openTime,
        closeTime: closeTime,
        slotGapMinutes: slotGapMinutes,
        sortOrder: sortOrder,
      );

  static Duration _parseTime(String raw) {
    final List<String> parts = raw.split(':');
    return Duration(
      hours: int.parse(parts[0]),
      minutes: parts.length > 1 ? int.parse(parts[1]) : 0,
    );
  }
}
