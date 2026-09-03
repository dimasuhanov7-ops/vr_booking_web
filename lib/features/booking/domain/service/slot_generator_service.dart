import '../entity/busy_interval_entity.dart';
import '../entity/club_entity.dart';
import '../entity/time_slot_entity.dart';
import 'club_clock.dart';

/// Строит сетку слотов и считает занятость.
class SlotGeneratorService {
  /// Создаёт сервис.
  const SlotGeneratorService();

  /// Генерирует старты сеансов на дату [day].
  ///
  /// Первый старт — в момент открытия клуба, дальше с шагом
  /// `длительность + club.slotGapMinutes`, пока сеанс целиком помещается до
  /// закрытия. Прошедшие слоты (для сегодняшней даты) отбрасываются.
  List<TimeSlotEntity> generateSlots({
    required ClubEntity club,
    required DateTime day,
    required int durationMinutes,
  }) {
    final ClubClock clock = ClubClock(club);
    final DateTime nowUtc = DateTime.now().toUtc();
    final Duration session = Duration(minutes: durationMinutes);
    final Duration step = Duration(minutes: durationMinutes + club.slotGapMinutes);

    final List<TimeSlotEntity> slots = <TimeSlotEntity>[];
    Duration cursor = club.openTime;

    while (cursor + session <= club.closeTime) {
      final DateTime startUtc = clock.toUtc(day, cursor);
      if (startUtc.isAfter(nowUtc)) {
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
