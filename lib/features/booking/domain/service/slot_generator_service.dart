import '../entity/busy_interval_entity.dart';
import '../entity/club_entity.dart';
import '../entity/time_slot_entity.dart';
import 'club_clock.dart';

/// Строит сетку слотов и считает занятость.
class SlotGeneratorService {
  /// Создаёт сервис.
  const SlotGeneratorService();

  /// За сколько до начала сеанса закрывается запись.
  ///
  /// Зашито и в БД: `booking_create_order` отвечает `TOO_LATE_TO_BOOK`
  /// (миграция `20260918120200_online_booking_lead_time`). Менять вместе.
  static const Duration bookingLead = Duration(minutes: 30);

  /// Генерирует старты сеансов на дату [day].
  ///
  /// Первый старт — в момент открытия клуба, дальше с шагом
  /// `длительность + club.slotGapMinutes`, пока сеанс целиком помещается до
  /// закрытия. Слоты, до начала которых меньше [bookingLead], отбрасываются.
  /// [now] — для тестов, по умолчанию текущее время.
  List<TimeSlotEntity> generateSlots({
    required ClubEntity club,
    required DateTime day,
    required int durationMinutes,
    DateTime? now,
  }) {
    final ClubClock clock = ClubClock(club);
    final DateTime cutoff = (now ?? DateTime.now()).toUtc().add(bookingLead);
    final Duration session = Duration(minutes: durationMinutes);
    final Duration step = Duration(minutes: durationMinutes + club.slotGapMinutes);

    final List<TimeSlotEntity> slots = <TimeSlotEntity>[];
    Duration cursor = club.openTime;

    while (cursor + session <= club.closeTime) {
      final DateTime startUtc = clock.toUtc(day, cursor);
      // Ровно за 30 минут ещё можно — как и на сервере (start < now + 30 мин).
      if (!startUtc.isBefore(cutoff)) {
        slots.add(TimeSlotEntity(startsAt: startUtc, endsAt: startUtc.add(session)));
      }
      cursor += step;
    }
    return slots;
  }

  /// Список id станций, свободных в слоте [slot].
  Set<String> freeStationIds({
    required Iterable<String> stationIds,
    required TimeSlotEntity slot,
    required List<BusyIntervalEntity> busyIntervals,
  }) {
    return stationIds
        .where((String id) => !busyIntervals.any((BusyIntervalEntity b) =>
            b.stationId == id && b.overlaps(slot.startsAt, slot.endsAt)))
        .toSet();
  }

  /// Сколько станций из [stationIds] свободно в слоте.
  int freeCount({
    required Iterable<String> stationIds,
    required TimeSlotEntity slot,
    required List<BusyIntervalEntity> busyIntervals,
  }) =>
      freeStationIds(
        stationIds: stationIds,
        slot: slot,
        busyIntervals: busyIntervals,
      ).length;
}
