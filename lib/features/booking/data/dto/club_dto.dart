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
    this.intakeOpen = true,
    this.leadMinutes = 30,
    this.horizonDays = 30,
    this.durations = ClubEntity.defaultDurations,
    this.privacyUrl,
  });

  /// Разбирает JSON от Supabase.
  factory ClubDto.fromJson(Map<String, dynamic> json) => ClubDto(
        id: json['id'] as String,
        slug: json['slug'] as String,
        name: json['name'] as String,
        timezone: json['timezone'] as String? ?? 'Asia/Yekaterinburg',
        openTime: _parseTime(json['open_time'] as String? ?? '11:00:00'),
        closeTime: _parseTime(json['close_time'] as String? ?? '23:00:00'),
        slotGapMinutes: (json['slot_gap_minutes'] as num?)?.toInt() ?? 0,
        sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
        intakeOpen: json['intake_open'] as bool? ?? true,
        leadMinutes: (json['lead_minutes'] as num?)?.toInt() ?? 30,
        horizonDays: (json['horizon_days'] as num?)?.toInt() ?? 30,
        durations: _durations(json['durations']),
        privacyUrl: _url(json['privacy_url']),
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

  /// Принимает ли клуб онлайн-брони (пауза из админки).
  final bool intakeOpen;

  /// За сколько минут до начала закрывается запись.
  final int leadMinutes;

  /// На сколько дней вперёд открыта запись.
  final int horizonDays;

  /// Длительности сеанса, минут.
  final List<int> durations;

  /// Ссылка на политику конфиденциальности.
  final String? privacyUrl;

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
        intakeOpen: intakeOpen,
        leadMinutes: leadMinutes,
        horizonDays: horizonDays,
        durations: durations,
        privacyUrl: privacyUrl,
      );

  /// Список длительностей; мусор и пустой список — значения по умолчанию.
  static List<int> _durations(Object? raw) {
    if (raw is! List<dynamic>) return ClubEntity.defaultDurations;
    final List<int> out = raw
        .whereType<num>()
        .map((num v) => v.toInt())
        .where((int v) => v >= 60 && v % 60 == 0)
        .toSet()
        .toList()
      ..sort();
    return out.isEmpty ? ClubEntity.defaultDurations : out;
  }

  static String? _url(Object? raw) {
    final String s = (raw as String? ?? '').trim();
    return s.startsWith('https://') || s.startsWith('http://') ? s : null;
  }

  static Duration _parseTime(String raw) {
    final List<String> parts = raw.split(':');
    return Duration(
      hours: int.parse(parts[0]),
      minutes: parts.length > 1 ? int.parse(parts[1]) : 0,
    );
  }
}
