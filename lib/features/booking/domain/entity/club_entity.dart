import 'package:equatable/equatable.dart';

/// Клуб, доступный для онлайн-бронирования.
class ClubEntity extends Equatable {
  /// Создаёт сущность клуба.
  const ClubEntity({
    required this.id,
    required this.slug,
    required this.name,
    required this.timezone,
    required this.openTime,
    required this.closeTime,
    required this.slotGapMinutes,
    this.sortOrder = 0,
    this.intakeOpen = true,
    this.leadMinutes = 30,
    this.horizonDays = 30,
    this.durations = defaultDurations,
    this.privacyUrl,
  });

  /// Длительности по умолчанию, если бэкенд их не прислал (минуты).
  static const List<int> defaultDurations = <int>[60, 120, 180, 240, 300];

  /// Идентификатор клуба.
  final String id;

  /// Машиночитаемый код (`effect_vr`, `v_ray`).
  final String slug;

  /// Отображаемое название.
  final String name;

  /// Таймзона клуба (IANA, например `Asia/Yekaterinburg` — Пермь).
  final String timezone;

  /// Время открытия приёма броней (локальное время клуба).
  final Duration openTime;

  /// Время, до которого должна завершиться бронь (локальное время клуба).
  final Duration closeTime;

  /// Пауза между сеансами: шаг сетки слотов = длительность + пауза.
  final int slotGapMinutes;

  /// Порядок отображения в списке клубов.
  final int sortOrder;

  /// Принимает ли клуб онлайн-брони. `false` — пауза, включённая в админке:
  /// форму показываем, но предупреждаем сразу, а не в конце.
  final bool intakeOpen;

  /// За сколько минут до начала закрывается онлайн-запись (настройка клуба
  /// в админке; сервер проверяет то же — `TOO_LATE_TO_BOOK`).
  final int leadMinutes;

  /// На сколько дней вперёд открыта запись (`TOO_FAR_AHEAD` на сервере).
  final int horizonDays;

  /// Какие длительности сеанса предлагать, минут, по возрастанию.
  final List<int> durations;

  /// Ссылка на политику конфиденциальности клуба (может не быть).
  final String? privacyUrl;

  /// Ближайшая к [minutes] длительность из [durations] — для предвыбора
  /// из `?duration=` и при смене клуба.
  int nearestDuration(int minutes) {
    if (durations.isEmpty) return minutes;
    if (durations.contains(minutes)) return minutes;
    int best = durations.first;
    for (final int d in durations) {
      if ((d - minutes).abs() < (best - minutes).abs()) best = d;
    }
    return best;
  }

  @override
  List<Object?> get props => <Object?>[
        id,
        slug,
        name,
        timezone,
        openTime,
        closeTime,
        slotGapMinutes,
        sortOrder,
        intakeOpen,
        leadMinutes,
        horizonDays,
        durations,
        privacyUrl,
      ];
}
