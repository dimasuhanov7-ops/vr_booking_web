import 'package:intl/intl.dart';

/// Форматирование для админки.
abstract final class AdminFormat {
  const AdminFormat._();

  static final DateFormat _dowShort = DateFormat('EEE', 'ru');
  static final DateFormat _dowFull = DateFormat('EEEE', 'ru');
  static final DateFormat _monShort = DateFormat('MMM', 'ru');
  static final DateFormat _dayMonL = DateFormat('d MMMM', 'ru');

  /// «14 000 ₽».
  static String money(num value) {
    final String digits = value.round().abs().toString();
    final StringBuffer out = StringBuffer();
    for (int i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) out.write(' ');
      out.write(digits[i]);
    }
    return '${value < 0 ? '−' : ''}$out ₽';
  }

  /// «09:30».
  static String hhmm(int minutes) {
    final int h = minutes ~/ 60;
    final int m = minutes % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }

  /// «09:30–11:00».
  static String span(int start, int end) => '${hhmm(start)}–${hhmm(end)}';

  /// Русское склонение.
  static String plural(int n, String one, String few, String many) {
    final int m10 = n % 10;
    final int m100 = n % 100;
    if (m10 == 1 && m100 != 11) return one;
    if (m10 >= 2 && m10 <= 4 && (m100 < 12 || m100 > 14)) return few;
    return many;
  }

  /// «5 шлемов».
  static String helmets(int n) =>
      '$n ${plural(n, 'шлем', 'шлема', 'шлемов')}';

  /// «6 мест».
  static String seats(int n) => '$n ${plural(n, 'место', 'места', 'мест')}';

  /// «3 активные».
  static String active(int n) =>
      '$n ${plural(n, 'активная', 'активные', 'активных')}';

  /// «1,5 ч» / «2 ч».
  static String hours(int minutes) {
    if (minutes % 60 == 0) return '${minutes ~/ 60} ч';
    return '${(minutes / 60).toStringAsFixed(1).replaceAll('.', ',')} ч';
  }

  /// «пт» — короткий день недели.
  static String dowShort(DateTime d) => _dowShort.format(d);

  /// «пятница».
  static String dowFull(DateTime d) => _dowFull.format(d);

  /// «сен».
  static String monShort(DateTime d) => _monShort.format(d);

  /// «8 сентября».
  static String dayMonthLong(DateTime d) => _dayMonL.format(d);
}
