import 'package:flutter_test/flutter_test.dart';

import 'package:vr_booking_web/features/booking/domain/entity/station_entity.dart';
import 'package:vr_booking_web/features/booking/domain/service/station_picker_service.dart';

/// V-Ray «Весь клуб»: арена 12 шлемов (две половины по 6) + малый зал
/// (4 шлема в ряд и 2 PS5 отдельным рядом).
final List<StationEntity> _club = <StationEntity>[
  for (int i = 0; i < 12; i++)
    StationEntity(
      id: 'big-${i + 1}',
      roomId: 'big',
      roomName: 'Большой зал',
      type: StationType.vrHeadset,
      label: '#${i + 1}',
      rowIndex: i ~/ 6,
      positionInRow: i % 6,
      sortOrder: 1 + i,
      isActive: true,
    ),
  for (int i = 0; i < 4; i++)
    StationEntity(
      id: 'small-${i + 1}',
      roomId: 'small',
      roomName: 'Малый зал',
      type: StationType.vrHeadset,
      label: '#${i + 1}',
      rowIndex: 0,
      positionInRow: i,
      sortOrder: 20 + i,
      isActive: true,
    ),
  for (int i = 0; i < 2; i++)
    StationEntity(
      id: 'small-ps${i + 1}',
      roomId: 'small',
      roomName: 'Малый зал',
      type: StationType.ps5,
      label: 'PS5-${i + 1}',
      rowIndex: 1,
      positionInRow: i,
      sortOrder: 24 + i,
      isActive: true,
    ),
];

List<String> _pick(List<StationEntity> free, int n) => const StationPickerService()
    .compact(free, n)
    .map((StationEntity s) => s.id)
    .toList();

void main() {
  group('компактный подбор станций', () {
    test('4 во «Весь клуб» — все из одной половины арены, а не 2+2', () {
      expect(_pick(_club, 4), <String>['big-1', 'big-2', 'big-3', 'big-4']);
    });

    test('8 — одним залом: половина целиком и ещё два', () {
      expect(_pick(_club, 8), <String>[
        'big-1', 'big-2', 'big-3', 'big-4', 'big-5', 'big-6', 'big-7', 'big-8',
      ]);
    });

    test('14 — зала не хватает: вся арена и два шлема малого зала', () {
      final List<String> got = _pick(_club, 14);
      expect(got.length, 14);
      expect(got.where((String id) => id.startsWith('big-')).length, 12);
      expect(got.sublist(12), <String>['small-1', 'small-2']);
    });

    test('в первой половине занято — берём вторую, а не остатки первой', () {
      final Set<String> busy = <String>{'big-1', 'big-3', 'big-4'};
      final List<StationEntity> free =
          _club.where((StationEntity s) => !busy.contains(s.id)).toList();
      expect(_pick(free, 4), <String>['big-7', 'big-8', 'big-9', 'big-10']);
    });

    test('малый зал: 2 — шлемы из одного ряда, PS5 не подмешиваются', () {
      final List<StationEntity> small =
          _club.where((StationEntity s) => s.roomId == 'small').toList();
      expect(_pick(small, 2), <String>['small-1', 'small-2']);
    });

    test('0 или пустой список — ничего', () {
      expect(_pick(_club, 0), isEmpty);
      expect(_pick(const <StationEntity>[], 3), isEmpty);
    });
  });
}
