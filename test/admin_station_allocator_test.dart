import 'package:flutter_test/flutter_test.dart';

import 'package:vr_booking_web/features/admin/domain/entity/admin_booking_request_entity.dart';
import 'package:vr_booking_web/features/admin/domain/service/admin_station_allocator.dart';
import 'package:vr_booking_web/features/booking/domain/entity/busy_interval_entity.dart';
import 'package:vr_booking_web/features/booking/domain/entity/reservation_request_entity.dart';
import 'package:vr_booking_web/features/booking/domain/entity/station_entity.dart';

/// V-Ray: арена 12 шлемов (две половины по 6) + малый зал 4 шлема и 2 PS5.
final List<StationEntity> _stations = <StationEntity>[
  for (int i = 0; i < 12; i++)
    StationEntity(
      id: 'big-${(i + 1).toString().padLeft(2, '0')}',
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

final DateTime _start = DateTime.utc(2026, 9, 11, 10);

List<ReservationSegmentEntity>? _allocate(
  List<Map<String, HallUnits>> hours, {
  List<BusyIntervalEntity> busy = const <BusyIntervalEntity>[],
}) =>
    const AdminStationAllocator().allocate(
      stations: _stations,
      busy: busy,
      startUtc: _start,
      hours: hours,
    );

void main() {
  group('бронь сотрудника: количества → станции', () {
    test('два зала одной бронью: 4 шлема на арене + 2 шлема и PS5 в малом', () {
      final List<ReservationSegmentEntity> segs = _allocate(<Map<String, HallUnits>>[
        <String, HallUnits>{
          'big': (headsets: 4, consoles: 0),
          'small': (headsets: 2, consoles: 1),
        },
      ])!;

      expect(segs, hasLength(1));
      expect(segs.single.stationIds, <String>[
        'big-01', 'big-02', 'big-03', 'big-04', 'small-1', 'small-2', 'small-ps1',
      ]);
      expect(segs.single.startsAt, _start);
      expect(segs.single.endsAt, _start.add(const Duration(hours: 1)));
    });

    test('состав меняется по часам: гость не пересаживается, часы склеиваются', () {
      final List<ReservationSegmentEntity> segs = _allocate(<Map<String, HallUnits>>[
        <String, HallUnits>{'big': (headsets: 4, consoles: 0)},
        <String, HallUnits>{'big': (headsets: 4, consoles: 0)},
        <String, HallUnits>{'big': (headsets: 2, consoles: 0)},
      ])!;

      expect(segs, hasLength(2));
      expect(segs[0].stationIds, <String>['big-01', 'big-02', 'big-03', 'big-04']);
      expect(segs[0].endsAt, _start.add(const Duration(hours: 2)));
      // Во третьем часе остаются те же первые двое, а не новые места.
      expect(segs[1].stationIds, <String>['big-01', 'big-02']);
    });

    test('станцию заняли во втором часе — замена рядом, остальные на местах', () {
      final List<ReservationSegmentEntity> segs = _allocate(
        <Map<String, HallUnits>>[
          <String, HallUnits>{'big': (headsets: 3, consoles: 0)},
          <String, HallUnits>{'big': (headsets: 3, consoles: 0)},
        ],
        busy: <BusyIntervalEntity>[
          BusyIntervalEntity(
            stationId: 'big-01',
            roomId: 'big',
            startsAt: _start.add(const Duration(hours: 1)),
            endsAt: _start.add(const Duration(hours: 2)),
          ),
        ],
      )!;

      expect(segs, hasLength(2));
      expect(segs[1].stationIds, containsAll(<String>['big-02', 'big-03']));
      expect(segs[1].stationIds, isNot(contains('big-01')));
      expect(segs[1].stationIds, hasLength(3));
    });

    test('мест не хватает — null, бронь не создаётся', () {
      expect(
        _allocate(<Map<String, HallUnits>>[
          <String, HallUnits>{'small': (headsets: 0, consoles: 3)},
        ]),
        isNull,
      );
    });

    test('час без станций разрывает бронь на отрезки, пустой отрезок не шлётся', () {
      final List<ReservationSegmentEntity> segs = _allocate(<Map<String, HallUnits>>[
        <String, HallUnits>{'big': (headsets: 2, consoles: 0)},
        <String, HallUnits>{},
        <String, HallUnits>{'big': (headsets: 2, consoles: 0)},
      ])!;

      expect(segs, hasLength(2));
      expect(segs[0].endsAt, _start.add(const Duration(hours: 1)));
      expect(segs[1].startsAt, _start.add(const Duration(hours: 2)));
    });
  });
}
