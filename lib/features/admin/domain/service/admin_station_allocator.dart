import '../../../booking/domain/entity/busy_interval_entity.dart';
import '../../../booking/domain/entity/reservation_request_entity.dart';
import '../../../booking/domain/entity/station_entity.dart';
import '../../../booking/domain/service/station_picker_service.dart';
import '../entity/admin_booking_request_entity.dart';

/// Превращает «сколько шлемов и PS5 в каком зале по часам» в конкретные станции.
///
/// Сотрудник в админке думает количествами, а база бронирует станции. Правила:
/// * станция свободна в часе, если на неё нет занятости в этом окне;
/// * гость не пересаживается: станции прошлого часа остаются за ним, пока
///   свободны и нужны;
/// * новые станции берутся компактно — одним рядом или залом
///   ([StationPickerService]);
/// * подряд идущие часы с одинаковым набором склеиваются в один отрезок.
class AdminStationAllocator {
  /// Создаёт распределитель.
  const AdminStationAllocator({
    this.picker = const StationPickerService(),
  });

  /// Компактный подбор новых станций.
  final StationPickerService picker;

  /// Отрезки брони или `null`, если в каком-то часе не хватает свободных станций.
  ///
  /// [hours] — состав по часам (см. [AdminBookingRequest.hours]),
  /// [startUtc] — начало сеанса.
  List<ReservationSegmentEntity>? allocate({
    required List<StationEntity> stations,
    required List<BusyIntervalEntity> busy,
    required DateTime startUtc,
    required List<Map<String, HallUnits>> hours,
  }) {
    final List<Set<String>> perHour = <Set<String>>[];
    Set<String> previous = <String>{};

    for (int h = 0; h < hours.length; h++) {
      final DateTime from = startUtc.add(Duration(hours: h));
      final DateTime to = from.add(const Duration(hours: 1));
      final Set<String> chosen = <String>{};

      for (final MapEntry<String, HallUnits> hall in hours[h].entries) {
        for (final bool ps5 in const <bool>[false, true]) {
          final int need = ps5 ? hall.value.consoles : hall.value.headsets;
          if (need <= 0) continue;

          final List<StationEntity> free = stations
              .where((StationEntity s) =>
                  s.isActive &&
                  s.roomId == hall.key &&
                  (s.type == StationType.ps5) == ps5 &&
                  !busy.any((BusyIntervalEntity b) =>
                      b.stationId == s.id && b.overlaps(from, to)))
              .toList();
          final List<StationEntity> kept = free
              .where((StationEntity s) => previous.contains(s.id))
              .take(need)
              .toList();
          final List<StationEntity> added = picker.compact(
            free.where((StationEntity s) => !previous.contains(s.id)).toList(),
            need - kept.length,
          );
          if (kept.length + added.length < need) return null;

          chosen
            ..addAll(kept.map((StationEntity s) => s.id))
            ..addAll(added.map((StationEntity s) => s.id));
        }
      }
      perHour.add(chosen);
      previous = chosen;
    }

    bool same(Set<String> a, Set<String> b) =>
        a.length == b.length && a.containsAll(b);

    final List<ReservationSegmentEntity> out = <ReservationSegmentEntity>[];
    int runStart = 0;
    for (int h = 1; h <= perHour.length; h++) {
      if (h < perHour.length && same(perHour[h - 1], perHour[h])) continue;
      final Set<String> ids = perHour[runStart];
      if (ids.isNotEmpty) {
        out.add(ReservationSegmentEntity(
          stationIds: ids.toList()..sort(),
          startsAt: startUtc.add(Duration(hours: runStart)),
          endsAt: startUtc.add(Duration(hours: h)),
        ));
      }
      runStart = h;
    }
    return out;
  }
}
