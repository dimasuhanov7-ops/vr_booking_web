import 'package:flutter_test/flutter_test.dart';

import 'package:vr_booking_web/features/booking/domain/entity/club_entity.dart';
import 'package:vr_booking_web/features/booking/domain/entity/time_slot_entity.dart';
import 'package:vr_booking_web/features/booking/domain/service/club_clock.dart';
import 'package:vr_booking_web/features/booking/domain/service/slot_generator_service.dart';

const ClubEntity _effect = ClubEntity(
  id: 'club-effect',
  slug: 'effect_vr',
  name: 'Effect VR',
  timezone: 'Asia/Yekaterinburg',
  openTime: Duration(hours: 11),
  closeTime: Duration(hours: 22, minutes: 30),
  slotGapMinutes: 10,
  sortOrder: 10,
);

/// Старты сеансов как «ЧЧ:ММ» по часам клуба.
List<String> _starts(int durationMinutes) {
  final DateTime day = DateTime(2026, 10, 14); // будний день в горизонте записи
  final List<TimeSlotEntity> slots = const SlotGeneratorService().generateSlots(
    club: _effect,
    day: day,
    durationMinutes: durationMinutes,
    now: DateTime.utc(2026, 10, 13, 12),
  );
  String two(int v) => v.toString().padLeft(2, '0');
  return slots.map((TimeSlotEntity s) {
    final DateTime w = ClubClock(_effect).toWall(s.startsAt);
    return '${two(w.hour)}:${two(w.minute)}';
  }).toList(growable: false);
}

void main() {
  test('сетка стартов часовая независимо от длительности сеанса', () {
    // Час: 11:00, 12:10, 13:20 … — шаг 60 + 10 минут уборки.
    expect(_starts(60).take(3), <String>['11:00', '12:10', '13:20']);
    // Два часа начинаются с тех же стартов, а не только с 11:00 и 13:10:
    // в 12:10 зал свободен и два часа подряд до закрытия влезают.
    expect(_starts(120).take(3), <String>['11:00', '12:10', '13:20']);
    expect(_starts(180).take(3), <String>['11:00', '12:10', '13:20']);
  });

  test('сеанс целиком помещается до закрытия', () {
    // Клуб закрывается в 22:30. Последний старт на 4 часа — 18:00 (конец 22:00),
    // следующий в 19:10 закончился бы в 23:10.
    expect(_starts(240).last, '18:00');
    expect(_starts(60).last, '21:30');
  });
}
