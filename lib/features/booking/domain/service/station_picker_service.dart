import '../entity/station_entity.dart';

/// Подбор станций «компактно»: компания должна играть рядом.
///
/// Раньше «взять N» брало первые N свободных по сквозному порядку, и в варианте
/// «Весь клуб» 4 шлема расползались по двум залам. Теперь N берутся из одного
/// ряда (половины арены), если там хватает свободных, иначе из одного зала, и
/// только если не хватает и зала — из нескольких залов по порядку.
class StationPickerService {
  /// Создаёт сервис.
  const StationPickerService();

  /// До [count] станций из свободных [free], сгруппированных как можно плотнее.
  ///
  /// Порядок внутри результата — как на плане зала: зал, ряд, место в ряду.
  List<StationEntity> compact(List<StationEntity> free, int count) {
    if (count <= 0 || free.isEmpty) return const <StationEntity>[];

    // Порядок залов — по первой станции зала, как они идут на плане.
    final Map<String, int> roomOrder = <String, int>{};
    for (final StationEntity s in free) {
      roomOrder.update(
        s.roomId,
        (int v) => v < s.sortOrder ? v : s.sortOrder,
        ifAbsent: () => s.sortOrder,
      );
    }
    final List<StationEntity> sorted = List<StationEntity>.of(free)
      ..sort((StationEntity a, StationEntity b) {
        final int room = roomOrder[a.roomId]!.compareTo(roomOrder[b.roomId]!);
        if (room != 0) return room;
        final int roomId = a.roomId.compareTo(b.roomId);
        if (roomId != 0) return roomId;
        final int row = a.rowIndex.compareTo(b.rowIndex);
        if (row != 0) return row;
        final int pos = a.positionInRow.compareTo(b.positionInRow);
        return pos != 0 ? pos : a.sortOrder.compareTo(b.sortOrder);
      });
    if (count >= sorted.length) return sorted;

    // Первая группа по порядку, где хватает свободных.
    List<StationEntity>? firstFit(String Function(StationEntity) key) {
      final Map<String, List<StationEntity>> groups =
          <String, List<StationEntity>>{};
      for (final StationEntity s in sorted) {
        groups.putIfAbsent(key(s), () => <StationEntity>[]).add(s);
      }
      for (final List<StationEntity> g in groups.values) {
        if (g.length >= count) return g.take(count).toList();
      }
      return null;
    }

    return firstFit((StationEntity s) => '${s.roomId}#${s.rowIndex}') ??
        firstFit((StationEntity s) => s.roomId) ??
        sorted.take(count).toList();
  }

  /// До [count] станций из [free] в добавок к уже выбранным [picked].
  ///
  /// Сначала — из рядов, где компания уже сидит (5 шлемов в половине арены →
  /// шестой из той же половины), остальные — компактно из прочих свободных.
  List<StationEntity> extend(
    List<StationEntity> free,
    List<StationEntity> picked,
    int count,
  ) {
    if (count <= 0 || free.isEmpty) return const <StationEntity>[];
    String row(StationEntity s) => '${s.roomId}#${s.rowIndex}';

    final Set<String> rows = picked.map(row).toSet();
    final List<StationEntity> near = compact(
      free.where((StationEntity s) => rows.contains(row(s))).toList(),
      count,
    );
    if (near.length >= count) return near;
    final List<StationEntity> rest =
        free.where((StationEntity s) => !near.contains(s)).toList();
    return <StationEntity>[...near, ...compact(rest, count - near.length)];
  }
}
