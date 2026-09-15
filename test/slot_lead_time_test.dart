import 'package:flutter_test/flutter_test.dart';

import 'package:vr_booking_web/features/booking/domain/entity/club_entity.dart';
import 'package:vr_booking_web/features/booking/domain/entity/time_slot_entity.dart';
import 'package:vr_booking_web/features/booking/domain/service/slot_generator_service.dart';

/// V-Ray в Перми: 11:00–23:00, UTC+5, без паузы между сеансами.
const ClubEntity _vray = ClubEntity(
  id: 'club-vray',
  slug: 'v_ray',
  name: 'V-Ray',
  timezone: 'Asia/Yekaterinburg',
  openTime: Duration(hours: 11),
  closeTime: Duration(hours: 23),
  slotGapMinutes: 0,
  sortOrder: 20,
);

final DateTime _day = DateTime(2026, 9, 10);

/// Первый доступный старт по пермскому времени, если «сейчас» — [h]:[m] по Перми.
int _firstHourAt(int h, int m) {
  final DateTime nowUtc = DateTime.utc(2026, 9, 10, h - 5, m);
  final List<TimeSlotEntity> slots = const SlotGeneratorService().generateSlots(
    club: _vray,
    day: _day,
    durationMinutes: 60,
    now: nowUtc,
  );
  return slots.first.startsAt.toUtc().hour + 5;
}

void main() {
  group('запись закрывается за 30 минут до начала', () {
    test('13:32 — слот 14:00 уже закрыт, первый 15:00', () {
      expect(_firstHourAt(13, 32), 15);
    });

    test('13:29 — слот 14:00 ещё открыт', () {
      expect(_firstHourAt(13, 29), 14);
    });

    test('ровно 13:30 — слот 14:00 ещё открыт (как на сервере)', () {
      expect(_firstHourAt(13, 30), 14);
    });
  });
}
