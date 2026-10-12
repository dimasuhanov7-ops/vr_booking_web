import 'package:equatable/equatable.dart';

/// Зал клуба в админке.
class AdminHallEntity extends Equatable {
  /// Создаёт зал.
  const AdminHallEntity({
    required this.id,
    required this.name,
    required this.headsets,
    required this.consoles,
  });

  /// Идентификатор зала.
  final String id;

  /// Название зала.
  final String name;

  /// Число VR-шлемов.
  final int headsets;

  /// Число приставок PS5.
  final int consoles;

  /// Всего станций.
  int get capacity => headsets + consoles;

  @override
  List<Object?> get props => <Object?>[id, name, headsets, consoles];
}

/// Клуб в админке (со списком залов и рабочими часами).
class AdminClubEntity extends Equatable {
  /// Создаёт клуб.
  const AdminClubEntity({
    required this.id,
    required this.slug,
    required this.name,
    required this.hoursLabel,
    required this.openMinutes,
    required this.closeMinutes,
    required this.gapMinutes,
    required this.halls,
    this.leadMinutes = 30,
    this.horizonDays = 30,
    this.durations = defaultDurations,
    this.privacyUrl = '',
  });

  /// Длительности по умолчанию, минут.
  static const List<int> defaultDurations = <int>[60, 120, 180, 240, 300];

  /// Длительности, которые можно включить клиенту (до 8 часов).
  static const List<int> allowedDurations = <int>[60, 120, 180, 240, 300, 360, 420, 480];

  /// Варианты паузы между сеансами, минут (в базе — от 0 до 60).
  static const List<int> gapOptions = <int>[0, 10, 15, 20, 30];

  /// За сколько минут до начала закрывать запись (в базе — до 240).
  static const List<int> leadOptions = <int>[0, 15, 30, 60, 120];

  /// На сколько дней вперёд открывать запись (в базе — до 180).
  static const List<int> horizonOptions = <int>[7, 14, 30, 60, 90];

  /// Идентификатор клуба.
  final String id;

  /// Код клуба (`effect_vr` / `v_ray`) — для выбора акцента.
  final String slug;

  /// Название клуба.
  final String name;

  /// Часы работы для подписи («11:00 – 22:30»).
  final String hoursLabel;

  /// Открытие, минут от полуночи.
  final int openMinutes;

  /// Закрытие, минут от полуночи.
  final int closeMinutes;

  /// Пауза между сеансами, минут.
  final int gapMinutes;

  /// Залы клуба.
  final List<AdminHallEntity> halls;

  /// За сколько минут до начала закрывается онлайн-запись.
  final int leadMinutes;

  /// На сколько дней вперёд открыта онлайн-запись.
  final int horizonDays;

  /// Длительности сеанса, которые видит клиент, минут, по возрастанию.
  final List<int> durations;

  /// Ссылка на политику конфиденциальности под формой ('' — нет).
  final String privacyUrl;

  /// Ссылка годится для сохранения: пусто или адрес сайта.
  static bool isValidPrivacyUrl(String url) {
    final String u = url.trim();
    if (u.isEmpty) return true;
    final Uri? parsed = Uri.tryParse(u);
    return u.length <= 300 &&
        !u.contains(RegExp(r'\s')) &&
        parsed != null &&
        (parsed.scheme == 'https' || parsed.scheme == 'http') &&
        parsed.host.isNotEmpty;
  }

  /// Копия с другими настройками записи.
  AdminClubEntity copyWith({
    int? gapMinutes,
    int? leadMinutes,
    int? horizonDays,
    List<int>? durations,
    String? privacyUrl,
  }) =>
      AdminClubEntity(
        id: id,
        slug: slug,
        name: name,
        hoursLabel: hoursLabel,
        openMinutes: openMinutes,
        closeMinutes: closeMinutes,
        gapMinutes: gapMinutes ?? this.gapMinutes,
        halls: halls,
        leadMinutes: leadMinutes ?? this.leadMinutes,
        horizonDays: horizonDays ?? this.horizonDays,
        durations: durations ?? this.durations,
        privacyUrl: privacyUrl ?? this.privacyUrl,
      );

  @override
  List<Object?> get props => <Object?>[
        id,
        slug,
        name,
        hoursLabel,
        openMinutes,
        closeMinutes,
        gapMinutes,
        halls,
        leadMinutes,
        horizonDays,
        durations,
        privacyUrl,
      ];
}
