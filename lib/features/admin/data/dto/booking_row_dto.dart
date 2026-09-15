import '../../domain/entity/booking_row_entity.dart';

/// Разбор заказа `booking_orders` (с позициями и пакетом) в записи админки.
///
/// Вынесено из репозитория, потому что здесь живут два нетривиальных правила.
///
/// Одна бронь может держать **разное число станций в разные часы**. В БД это
/// отрезки — у позиций разные `starts_at`/`ends_at`. Габариты брони считаем по
/// всем позициям, а состав — почасово; иначе бронь «12 шлемов первый час,
/// 6 второй и третий» выглядела бы как 24 шлема на один час.
///
/// Одна бронь может держать станции **в нескольких залах** («Весь клуб» в
/// виджете, бронь сотрудника на два зала). Админка считает занятость по залу,
/// поэтому такая бронь раскладывается на запись для каждого зала. Раньше вся
/// бронь приписывалась залу первой позиции, и сетка второго зала её не видела.
abstract final class BookingRowDto {
  const BookingRowDto._();

  /// Собирает записи из строки `booking_orders` с вложенными
  /// `booking_order_items` → `booking_stations`.
  ///
  /// [tz] — смещение таймзоны клуба, [today] — «сегодня» в этой же таймзоне
  /// (от него считается [BookingRowEntity.dayIndex]).
  /// Бронь в одном зале — одна запись с `id` заказа; в нескольких — запись на
  /// зал с `id` вида `<заказ>#<зал>` и общим [BookingRowEntity.orderId].
  /// Заказ без позиций — пустой список.
  static List<BookingRowEntity> fromOrderJson(
    Map<String, dynamic> json, {
    required DateTime today,
    required Duration tz,
  }) {
    final List<dynamic> raw =
        json['booking_order_items'] as List<dynamic>? ?? const <dynamic>[];
    if (raw.isEmpty) return const <BookingRowEntity>[];

    // Позиции по залам, в порядке появления.
    final Map<String, List<_Item>> byHall = <String, List<_Item>>{};
    for (final dynamic it in raw) {
      final Map<String, dynamic> im = it as Map<String, dynamic>;
      final Map<String, dynamic>? st =
          im['booking_stations'] as Map<String, dynamic>?;
      final String hallId = st?['room_id'] as String? ?? '';
      byHall.putIfAbsent(hallId, () => <_Item>[]).add(_Item(
            start: DateTime.parse(im['starts_at'] as String).toUtc().add(tz),
            end: DateTime.parse(im['ends_at'] as String).toUtc().add(tz),
            isPs5: st?['type'] == 'ps5',
          ));
    }

    final String orderId = json['id'] as String;
    final bool split = byHall.length > 1;
    return <BookingRowEntity>[
      for (final MapEntry<String, List<_Item>> e in byHall.entries)
        _row(
          json,
          e.value,
          id: split ? '$orderId#${e.key}' : orderId,
          orderId: orderId,
          hallId: e.key,
          today: today,
        ),
    ];
  }

  /// Запись одного зала заказа.
  static BookingRowEntity _row(
    Map<String, dynamic> json,
    List<_Item> items, {
    required String id,
    required String orderId,
    required String hallId,
    required DateTime today,
  }) {
    DateTime minStart = items.first.start;
    DateTime maxEnd = items.first.end;
    for (final _Item it in items) {
      if (it.start.isBefore(minStart)) minStart = it.start;
      if (it.end.isAfter(maxEnd)) maxEnd = it.end;
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
      id: id,
      orderId: orderId,
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
      hourHeadsets: varies ? vrByHour : null,
      hourConsoles: varies ? psByHour : null,
      note: json['comment'] as String? ?? '',
      prepay: (json['prepay'] as num?)?.toInt() ?? 0,
    );
  }

  static RecordStatus _status(String raw) => switch (raw) {
        'completed' => RecordStatus.paid,
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
  });

  final DateTime start;
  final DateTime end;
  final bool isPs5;
}
