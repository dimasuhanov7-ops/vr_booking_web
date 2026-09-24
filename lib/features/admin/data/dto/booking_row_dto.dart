import '../../domain/entity/booking_row_entity.dart';

/// Разбор заказа `booking_orders` (с позициями и пакетом) в запись админки.
///
/// Вынесено из репозитория, потому что здесь живёт нетривиальное правило:
/// одна бронь может держать **разное число станций в разные часы**. В БД это
/// отрезки — у позиций разные `starts_at`/`ends_at`. Габариты брони считаем по
/// всем позициям, а состав — почасово; иначе бронь «12 шлемов первый час,
/// 6 второй и третий» выглядела бы как 24 шлема на один час.
abstract final class BookingRowDto {
  const BookingRowDto._();

  /// Собирает запись из строки `booking_orders` с вложенными
  /// `booking_order_items` → `booking_stations`.
  ///
  /// [tz] — смещение таймзоны клуба, [today] — «сегодня» в этой же таймзоне
  /// (от него считается [BookingRowEntity.dayIndex]).
  /// Возвращает `null`, если у заказа нет позиций.
  static BookingRowEntity? fromOrderJson(
    Map<String, dynamic> json, {
    required DateTime today,
    required Duration tz,
  }) {
    final List<dynamic> raw =
        json['booking_order_items'] as List<dynamic>? ?? const <dynamic>[];
    if (raw.isEmpty) return null;

    final List<_Item> items = <_Item>[];
    for (final dynamic it in raw) {
      final Map<String, dynamic> im = it as Map<String, dynamic>;
      final Map<String, dynamic>? st =
          im['booking_stations'] as Map<String, dynamic>?;
      items.add(_Item(
        start: DateTime.parse(im['starts_at'] as String).toUtc().add(tz),
        end: DateTime.parse(im['ends_at'] as String).toUtc().add(tz),
        isPs5: st?['type'] == 'ps5',
        roomId: st?['room_id'] as String? ?? '',
      ));
    }

    DateTime minStart = items.first.start;
    DateTime maxEnd = items.first.end;
    String hallId = '';
    for (final _Item it in items) {
      if (it.start.isBefore(minStart)) minStart = it.start;
      if (it.end.isAfter(maxEnd)) maxEnd = it.end;
      // Бронь «весь клуб» держит станции из разных залов — админка знает только
      // один hallId, берём зал первой позиции.
      if (hallId.isEmpty) hallId = it.roomId;
    }

    final int duration = maxEnd.difference(minStart).inMinutes;
    final int hours = (duration / 60).round().clamp(1, 12);

    // Станция занята в часе, если её отрезок покрывает этот час целиком.
    final List<int> vrByHour = List<int>.filled(hours, 0);
    final List<int> psByHour = List<int>.filled(hours, 0);
    for (int h = 0; h < hours; h++) {
      final DateTime from = minStart.add(Duration(minutes: h * 60));
      final DateTime to = from.add(const Duration(minutes: 60));
      for (final _Item it in items) {
        if (it.start.isAfter(from) || it.end.isBefore(to)) continue;
        if (it.isPs5) {
          psByHour[h]++;
        } else {
          vrByHour[h]++;
        }
      }
    }

    bool uniform(List<int> l) => l.every((int v) => v == l.first);
    final bool varies = !(uniform(vrByHour) && uniform(psByHour));

    final DateTime day = DateTime(minStart.year, minStart.month, minStart.day);
    final Map<String, dynamic>? pkg =
        json['booking_packages'] as Map<String, dynamic>?;
    final String status = json['status'] as String? ?? 'confirmed';

    return BookingRowEntity(
      id: json['id'] as String,
      clubId: json['club_id'] as String,
      hallId: hallId,
      dayIndex: day.difference(today).inDays,
      startMinutes: minStart.hour * 60 + minStart.minute,
      durationMinutes: duration,
      headsets: vrByHour.first,
      consoles: psByHour.first,
      clientName: json['client_name'] as String? ?? '',
      phone: json['client_phone'] as String? ?? '',
      status: _status(status),
      source: _source(json['source'] as String? ?? 'site'),
      packageName: pkg?['name'] as String?,
      isCancelled: status == 'cancelled',
      prepay: (json['prepay'] as num?)?.toInt() ?? 0,
      note: json['comment'] as String? ?? '',
      hourHeadsets: varies ? vrByHour : null,
      hourConsoles: varies ? psByHour : null,
    );
  }

  static RecordStatus _status(String raw) => switch (raw) {
        'completed' => RecordStatus.visited,
        'no_show' => RecordStatus.noShow,
        'confirmed' => RecordStatus.confirmed,
        // Отменённая помечается отдельно (isCancelled), статус не «теряем».
        'cancelled' => RecordStatus.confirmed,
        _ => RecordStatus.newRequest,
      };

  static RecordSource _source(String raw) => switch (raw) {
        'staff' => RecordSource.admin,
        _ => RecordSource.widget,
      };
}

/// Позиция брони: окно и тип станции.
class _Item {
  const _Item({
    required this.start,
    required this.end,
    required this.isPs5,
    required this.roomId,
  });

  final DateTime start;
  final DateTime end;
  final bool isPs5;
  final String roomId;
}
