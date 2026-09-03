import 'package:intl/intl.dart';

import '../domain/entity/club_entity.dart';
import '../domain/service/club_clock.dart';

/// Форматирование для виджета бронирования.
abstract final class BookingFormat {
  const BookingFormat._();

  static final DateFormat _dayLong = DateFormat('EEEE, d MMMM', 'ru');
  static final DateFormat _dayShort = DateFormat('EEE, d MMM', 'ru');
  static final DateFormat _monthTitle = DateFormat('LLLL yyyy', 'ru');

  /// «1 200 ₽».
  static String money(num value) {
    final String digits = value.round().abs().toString();
    final StringBuffer out = StringBuffer();
    for (int i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) out.write(' ');
      out.write(digits[i]);
    }
    return '${value < 0 ? '−' : ''}$out ₽';
  }

  /// Русское склонение.
  static String plural(int n, String one, String few, String many) {
    final int m10 = n % 10;
    final int m100 = n % 100;
    if (m10 == 1 && m100 != 11) return one;
    if (m10 >= 2 && m10 <= 4 && (m100 < 12 || m100 > 14)) return few;
    return many;
  }

  /// «понедельник, 8 сентября».
  static String dayLong(DateTime date) => _dayLong.format(date);

  /// «пн, 8 сен».
  static String dayShort(DateTime date) => _dayShort.format(date);

  /// «сегодня» / «завтра» / короткая дата.
  static String daySmart(DateTime date) {
    final DateTime now = DateTime.now();
    final DateTime t = DateTime(now.year, now.month, now.day);
    final int diff = DateTime(date.year, date.month, date.day).difference(t).inDays;
    if (diff == 0) return 'сегодня';
    if (diff == 1) return 'завтра';
    return dayShort(date);
  }

  /// «сентябрь 2026».
  static String monthTitle(DateTime date) {
    final String s = _monthTitle.format(date);
    return s[0].toUpperCase() + s.substring(1);
  }

  /// «HH:mm» в «настенном» времени клуба для абсолютного момента.
  static String clockAt(ClubEntity club, DateTime utc) {
    final DateTime w = ClubClock(club).toWall(utc);
    return '${w.hour.toString().padLeft(2, '0')}:${w.minute.toString().padLeft(2, '0')}';
  }

  /// «11:00–12:00».
  static String range(ClubEntity club, DateTime startUtc, DateTime endUtc) =>
      '${clockAt(club, startUtc)}–${clockAt(club, endUtc)}';

  /// «Настенная» дата клуба для абсолютного момента.
  static DateTime wallDay(ClubEntity club, DateTime utc) {
    final DateTime w = ClubClock(club).toWall(utc);
    return DateTime(w.year, w.month, w.day);
  }

  /// «1 ч» / «1,5 ч» / «2 ч» / «3 ч».
  static String duration(int minutes) => switch (minutes) {
        60 => '1 ч',
        90 => '1,5 ч',
        120 => '2 ч',
        180 => '3 ч',
        _ => '${minutes ~/ 60} ч',
      };

  /// Маска телефона `+7 (900) 000-00-00`.
  static String phoneMask(String raw) {
    String d = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (d.startsWith('8')) d = '7${d.substring(1)}';
    if (!d.startsWith('7')) d = '7$d';
    d = d.substring(0, d.length > 11 ? 11 : d.length);
    final String p = d.substring(1);
    final StringBuffer out = StringBuffer('+7');
    if (p.isNotEmpty) out.write(' (${p.substring(0, p.length.clamp(0, 3))}');
    if (p.length >= 3) out.write(')');
    if (p.length > 3) out.write(' ${p.substring(3, p.length.clamp(3, 6))}');
    if (p.length > 6) out.write('-${p.substring(6, p.length.clamp(6, 8))}');
    if (p.length > 8) out.write('-${p.substring(8, p.length.clamp(8, 10))}');
    return out.toString();
  }
}
