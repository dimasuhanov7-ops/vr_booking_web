/// Событие брони для календаря клиента: ссылка Google Календаря и файл `.ics`
/// (его понимают Apple Календарь, Outlook, Яндекс и др.).
///
/// Своего канала связи с клиентом пока нет (ни SMS, ни бота), поэтому
/// календарь — единственный способ, чтобы бронь не потерялась вне браузера:
/// напоминание приходит от самого календаря.
class BookingCalendarEvent {
  /// Создаёт событие.
  const BookingCalendarEvent({
    required this.uid,
    required this.title,
    required this.details,
    required this.location,
    required this.startsAtUtc,
    required this.endsAtUtc,
  });

  /// Постоянный идентификатор (id брони) — повторное добавление не задваивает.
  final String uid;

  /// Заголовок события.
  final String title;

  /// Описание: номер брони, состав, оплата.
  final String details;

  /// Место.
  final String location;

  /// Начало (UTC).
  final DateTime startsAtUtc;

  /// Конец (UTC).
  final DateTime endsAtUtc;

  /// Ссылка «добавить в Google Календарь».
  String get googleUrl => Uri.https('calendar.google.com', '/calendar/render', <String, String>{
        'action': 'TEMPLATE',
        'text': title,
        'dates': '${_stamp(startsAtUtc)}/${_stamp(endsAtUtc)}',
        'details': details,
        'location': location,
      }).toString();

  /// Содержимое файла `.ics` с напоминанием за 2 часа.
  String get ics => <String>[
        'BEGIN:VCALENDAR',
        'VERSION:2.0',
        'PRODID:-//VR Booking//RU',
        'CALSCALE:GREGORIAN',
        'METHOD:PUBLISH',
        'BEGIN:VEVENT',
        'UID:$uid@vr-booking',
        'DTSTAMP:${_stamp(DateTime.now().toUtc())}',
        'DTSTART:${_stamp(startsAtUtc)}',
        'DTEND:${_stamp(endsAtUtc)}',
        'SUMMARY:${_escape(title)}',
        'DESCRIPTION:${_escape(details)}',
        'LOCATION:${_escape(location)}',
        'BEGIN:VALARM',
        'ACTION:DISPLAY',
        'DESCRIPTION:${_escape(title)}',
        'TRIGGER:-PT2H',
        'END:VALARM',
        'END:VEVENT',
        'END:VCALENDAR',
        '',
      ].join('\r\n');

  /// `20261012T090000Z`.
  static String _stamp(DateTime utc) {
    final DateTime t = utc.toUtc();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${t.year.toString().padLeft(4, '0')}${two(t.month)}${two(t.day)}'
        'T${two(t.hour)}${two(t.minute)}${two(t.second)}Z';
  }

  /// Экранирование текста по RFC 5545.
  static String _escape(String s) => s
      .replaceAll(r'\', r'\\')
      .replaceAll(';', r'\;')
      .replaceAll(',', r'\,')
      .replaceAll('\n', r'\n');
}
