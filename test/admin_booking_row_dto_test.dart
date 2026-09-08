import 'package:flutter_test/flutter_test.dart';
import 'package:vr_booking_web/features/admin/data/dto/booking_row_dto.dart';
import 'package:vr_booking_web/features/admin/domain/entity/booking_row_entity.dart';

/// Смещение Москвы — как в [AdminRepository].
const Duration _tz = Duration(hours: 3);

/// «Сегодня» в таймзоне клуба для тестов.
final DateTime _today = DateTime(2026, 9, 10);

/// Позиция брони в формате PostgREST (время — UTC, клуб на +3).
Map<String, dynamic> _item(String startsAt, String endsAt, {bool ps5 = false}) =>
    <String, dynamic>{
      'starts_at': startsAt,
      'ends_at': endsAt,
      'booking_stations': <String, dynamic>{
        'type': ps5 ? 'ps5' : 'vr_headset',
        'room_id': 'room-1',
      },
    };

Map<String, dynamic> _order(List<Map<String, dynamic>> items) => <String, dynamic>{
      'id': 'order-1',
      'club_id': 'club-1',
      'client_name': 'Проверка',
      'client_phone': '+7 900 123-45-67',
      'status': 'confirmed',
      'source': 'site',
      'booking_order_items': items,
    };

BookingRowEntity _parse(Map<String, dynamic> order) {
  final BookingRowEntity? row =
      BookingRowDto.fromOrderJson(order, today: _today, tz: _tz);
  expect(row, isNotNull, reason: 'заказ с позициями должен разбираться');
  return row!;
}

void main() {
  test('однородная бронь: состав по часам не выставляется', () {
    // 4 шлема на 2 часа, 20:00–22:00 по клубу (17:00–19:00 UTC).
    final BookingRowEntity row = _parse(_order(<Map<String, dynamic>>[
      for (int i = 0; i < 4; i++)
        _item('2026-09-10T17:00:00Z', '2026-09-10T19:00:00Z'),
    ]));

    expect(row.durationMinutes, 120);
    expect(row.startMinutes, 20 * 60);
    expect(row.dayIndex, 0);
    expect(row.headsets, 4);
    expect(row.consoles, 0);
    expect(row.variesByHour, isFalse);
    expect(row.hourHeadsets, isNull);
  });

  test('разный состав по часам: 12 -> 6 -> 6 не схлопывается в 24 за час', () {
    // Отрезок 1: станции #1..#6 держатся все 3 часа.
    // Отрезок 2: станции #7..#12 — только первый час.
    final BookingRowEntity row = _parse(_order(<Map<String, dynamic>>[
      for (int i = 0; i < 6; i++)
        _item('2026-09-10T17:00:00Z', '2026-09-10T20:00:00Z'),
      for (int i = 0; i < 6; i++)
        _item('2026-09-10T17:00:00Z', '2026-09-10T18:00:00Z'),
    ]));

    expect(row.durationMinutes, 180, reason: 'габарит — по всем позициям');
    expect(row.hourCount, 3);
    expect(row.variesByHour, isTrue);
    expect(row.hourHeadsets, <int>[12, 6, 6]);
    expect(row.headsetsAt(0), 12);
    expect(row.headsetsAt(1), 6);
    expect(row.headsetsAt(2), 6);
    expect(row.maxHeadsets, 12, reason: 'габарит брони в сетке занятости');
    expect(row.headsets, 12, reason: 'шапка — состав первого часа');
    // 12 + 6 + 6 = 24 станции-часа, а не 24 станции за один час.
    expect(row.stationHours, 24);
  });

  test('состав может и расти: 2 -> 5 во втором часе', () {
    final BookingRowEntity row = _parse(_order(<Map<String, dynamic>>[
      for (int i = 0; i < 2; i++)
        _item('2026-09-10T17:00:00Z', '2026-09-10T19:00:00Z'),
      for (int i = 0; i < 3; i++)
        _item('2026-09-10T18:00:00Z', '2026-09-10T19:00:00Z'),
    ]));

    expect(row.hourHeadsets, <int>[2, 5]);
    expect(row.headsets, 2);
    expect(row.maxHeadsets, 5);
  });

  test('VR и PS5 считаются раздельно', () {
    final BookingRowEntity row = _parse(_order(<Map<String, dynamic>>[
      for (int i = 0; i < 4; i++)
        _item('2026-09-10T17:00:00Z', '2026-09-10T19:00:00Z'),
      _item('2026-09-10T17:00:00Z', '2026-09-10T18:00:00Z', ps5: true),
      _item('2026-09-10T17:00:00Z', '2026-09-10T18:00:00Z', ps5: true),
    ]));

    expect(row.hourHeadsets, <int>[4, 4]);
    expect(row.hourConsoles, <int>[2, 0]);
    expect(row.variesByHour, isTrue);
    expect(row.consolesAt(0), 2);
    expect(row.consolesAt(1), 0);
  });

  test('источник staff помечается как «админка», cancelled — как отменённая', () {
    final Map<String, dynamic> order = _order(<Map<String, dynamic>>[
      _item('2026-09-10T17:00:00Z', '2026-09-10T18:00:00Z'),
    ])
      ..['source'] = 'staff'
      ..['status'] = 'cancelled';

    final BookingRowEntity row = _parse(order);
    expect(row.source, RecordSource.admin);
    expect(row.isCancelled, isTrue);
  });

  test('заказ без позиций пропускается', () {
    expect(
      BookingRowDto.fromOrderJson(_order(<Map<String, dynamic>>[]),
          today: _today, tz: _tz),
      isNull,
    );
  });
}
