import '../entity/club_entity.dart';

/// Перевод между «настенным» временем клуба и абсолютным моментом (UTC).
///
/// Клубы работают в фиксированных таймзонах без перехода на летнее время
/// (Пермь — `Asia/Yekaterinburg`, постоянный UTC+5), поэтому достаточно
/// фиксированного смещения. Для неизвестных таймзон используется смещение
/// локали браузера.
class ClubClock {
  /// Создаёт часы клуба.
  const ClubClock(this.club);

  /// Клуб, к которому привязаны часы.
  final ClubEntity club;

  static const Map<String, Duration> _fixedOffsets = <String, Duration>{
    'Europe/Moscow': Duration(hours: 3),
    'Europe/Kaliningrad': Duration(hours: 2),
    'Europe/Samara': Duration(hours: 4),
    'Asia/Yekaterinburg': Duration(hours: 5),
    'UTC': Duration.zero,
  };

  /// Смещение от UTC для IANA-таймзоны [timezone] (`booking_clubs.timezone`).
  static Duration offsetOf(String timezone) =>
      _fixedOffsets[timezone] ?? DateTime.now().timeZoneOffset;

  Duration get _offset => offsetOf(club.timezone);

  /// Собирает абсолютный момент из даты и «настенного» времени суток клуба.
  DateTime toUtc(DateTime day, Duration timeOfDay) {
    final DateTime wall = DateTime.utc(day.year, day.month, day.day).add(timeOfDay);
    return wall.subtract(_offset);
  }

  /// Возвращает «настенное» время клуба для абсолютного момента.
  DateTime toWall(DateTime instant) => instant.toUtc().add(_offset);

  /// Текущее «настенное» время клуба.
  DateTime nowWall() => toWall(DateTime.now());
}
