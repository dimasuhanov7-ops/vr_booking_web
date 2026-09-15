import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vr_booking_web/features/booking/data/repository/booking_repository_mock.dart';
import 'package:vr_booking_web/features/booking/domain/entity/hall_option_entity.dart';
import 'package:vr_booking_web/features/booking/domain/entity/package_advice_entity.dart';
import 'package:vr_booking_web/features/booking/domain/entity/package_entity.dart';
import 'package:vr_booking_web/features/booking/domain/entity/station_entity.dart';
import 'package:vr_booking_web/features/booking/domain/service/package_advisor_service.dart';
import 'package:vr_booking_web/features/booking/domain/service/station_picker_service.dart';
import 'package:vr_booking_web/features/booking/domain/state/booking_bloc.dart';

PackageEntity _pack(
  String id, {
  required int headsets,
  int consoles = 0,
  int minutes = 60,
  required num price,
}) =>
    PackageEntity(
      id: id,
      clubId: 'club-vray',
      roomId: 'v-big',
      name: id,
      headsets: headsets,
      consoles: consoles,
      minutes: minutes,
      price: price,
      note: '',
    );

StationEntity _vr(int n, {int perRow = 6}) => StationEntity(
      id: 'vr$n',
      roomId: 'big',
      roomName: 'Большой зал',
      type: StationType.vrHeadset,
      label: '#$n',
      rowIndex: (n - 1) ~/ perRow,
      positionInRow: (n - 1) % perRow,
      sortOrder: n,
      isActive: true,
    );

/// Моки с пакетами «на час», которые дешевле тарифа будней (600 ₽/шлем).
class _CheapPackagesRepository extends BookingRepositoryMock {
  @override
  Future<List<PackageEntity>> fetchPackages(String clubId) async =>
      <PackageEntity>[
        _pack('half', headsets: 6, price: 2800),
        _pack('arena', headsets: 12, price: 5000),
      ];
}

DateTime _weekdayAhead() {
  DateTime d = DateTime.now().add(const Duration(days: 6));
  while (d.weekday == DateTime.saturday || d.weekday == DateTime.sunday) {
    d = d.add(const Duration(days: 1));
  }
  return DateTime(d.year, d.month, d.day);
}

/// V-Ray → большой зал → первый слот (11:00, все шлемы свободны) → [pick] шлемов.
Future<void> _pickInArena(BookingBloc bloc, int pick) async {
  bloc.add(const BookingStarted());
  await Future<void>.delayed(const Duration(milliseconds: 1500));
  final HallOptionEntity big = bloc.state.hallOptions
      .firstWhere((HallOptionEntity h) => h.name == 'Большой зал');
  bloc.add(BookingHallSelected(big));
  await Future<void>.delayed(const Duration(milliseconds: 700));
  bloc.add(BookingSlotSelected(bloc.state.slots.first));
  await Future<void>.delayed(const Duration(milliseconds: 50));
  bloc.add(BookingQuickPicked(pick));
  await Future<void>.delayed(const Duration(milliseconds: 50));
}

void main() {
  const PackageAdvisorService advisor = PackageAdvisorService();

  group('PackageAdvisorService.upgrade', () {
    test('5 шлемов по 800 = 4000, пакет 6 шлемов за 3600 — советует', () {
      final PackageAdviceEntity? a = advisor.upgrade(
        packages: <PackageEntity>[_pack('half', headsets: 6, price: 3600)],
        headsets: 5,
        consoles: 0,
        minutes: 60,
        currentPrice: 4000,
      );
      expect(a?.package.id, 'half');
      expect(a?.saving, 400);
    });

    test('пакет дороже текущего выбора — молчит', () {
      expect(
        advisor.upgrade(
          packages: <PackageEntity>[_pack('half', headsets: 6, price: 4100)],
          headsets: 5,
          consoles: 0,
          minutes: 60,
          currentPrice: 4000,
        ),
        isNull,
      );
    });

    test('другая длительность или меньший состав — не сравнивает', () {
      expect(
        advisor.upgrade(
          packages: <PackageEntity>[
            _pack('long', headsets: 6, minutes: 120, price: 3000),
            _pack('same', headsets: 5, price: 3000),
            _pack('fewer', headsets: 4, price: 1000),
            _pack('no-ps', headsets: 6, price: 3000),
          ],
          headsets: 5,
          consoles: 1,
          minutes: 60,
          currentPrice: 4000,
        ),
        isNull,
      );
    });

    test('та же цена за больший состав — советует с нулевой экономией', () {
      final PackageAdviceEntity? a = advisor.upgrade(
        packages: <PackageEntity>[_pack('half', headsets: 6, price: 4000)],
        headsets: 5,
        consoles: 0,
        minutes: 60,
        currentPrice: 4000,
      );
      expect(a?.saving, 0);
    });

    test('из нескольких — самый выгодный', () {
      final PackageAdviceEntity? a = advisor.upgrade(
        packages: <PackageEntity>[
          _pack('half', headsets: 6, price: 3600),
          _pack('arena', headsets: 12, price: 3000),
        ],
        headsets: 5,
        consoles: 0,
        minutes: 60,
        currentPrice: 4000,
      );
      expect(a?.package.id, 'arena');
    });
  });

  group('PackageAdvisorService.priceFor', () {
    test('состав совпал с пакетом дешевле, чем по часам, — цена пакета', () {
      final PackageEntity? p = advisor.priceFor(
        packages: <PackageEntity>[
          _pack('pricey', headsets: 6, price: 5000),
          _pack('half', headsets: 6, price: 3600),
        ],
        selected: null,
        headsets: 6,
        consoles: 0,
        minutes: 60,
        gross: 4800,
      );
      expect(p?.id, 'half');
    });

    test('пакет не дешевле почасового — считаем по часам', () {
      expect(
        advisor.priceFor(
          packages: <PackageEntity>[_pack('half', headsets: 6, price: 4800)],
          selected: null,
          headsets: 6,
          consoles: 0,
          minutes: 60,
          gross: 4800,
        ),
        isNull,
      );
    });

    test('выбранный клиентом пакет применяется при совпадении состава', () {
      final PackageEntity chosen = _pack('chosen', headsets: 6, price: 7000);
      expect(
        advisor.priceFor(
          packages: <PackageEntity>[chosen],
          selected: chosen,
          headsets: 6,
          consoles: 0,
          minutes: 60,
          gross: 4800,
        ),
        chosen,
      );
    });
  });

  test('StationPickerService.extend: шестой шлем — из той же половины арены', () {
    final List<StationEntity> all = <StationEntity>[
      for (int n = 1; n <= 12; n++) _vr(n),
    ];
    const StationPickerService picker = StationPickerService();

    final List<StationEntity> first = all.take(5).toList();
    expect(
      picker.extend(all.skip(5).toList(), first, 1).map((StationEntity s) => s.label),
      <String>['#6'],
    );

    final List<StationEntity> second = all.sublist(6, 11); // #7–#11
    final List<StationEntity> free = <StationEntity>[...all.take(6), all[11]];
    expect(
      picker.extend(free, second, 1).map((StationEntity s) => s.label),
      <String>['#12'],
    );
  });

  blocTest<BookingBloc, BookingState>(
    '5 шлемов: подсказка о пакете на 6, «Взять» добавляет шестой рядом',
    build: () => BookingBloc(
      repository: _CheapPackagesRepository(),
      lockedClubSlug: 'v_ray',
      initialDate: _weekdayAhead(),
    ),
    act: (BookingBloc bloc) async {
      await _pickInArena(bloc, 5);
      final PackageAdviceEntity? advice = bloc.state.packageAdvice;
      expect(bloc.state.quote.net, 3000, reason: '5 × 600 ₽ по будням');
      expect(advice?.package.id, 'half');
      expect(advice?.saving, 200);
      bloc.add(BookingPackageUpgraded(advice!.package));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    },
    wait: const Duration(milliseconds: 100),
    verify: (BookingBloc bloc) {
      final Set<String> ids = bloc.state.pickedIds;
      expect(ids.length, 6);
      expect(ids, containsAll(<String>['v-big-vr1', 'v-big-vr5', 'v-big-vr6']));
      expect(bloc.state.quote.net, 2800);
      expect(bloc.state.quote.packageId, 'half');
      expect(bloc.state.packageAdvice, isNull);
    },
  );

  blocTest<BookingBloc, BookingState>(
    '6 шлемов руками без карточки пакета — цена всё равно пакетная',
    build: () => BookingBloc(
      repository: _CheapPackagesRepository(),
      lockedClubSlug: 'v_ray',
      initialDate: _weekdayAhead(),
    ),
    act: (BookingBloc bloc) => _pickInArena(bloc, 6),
    wait: const Duration(milliseconds: 100),
    verify: (BookingBloc bloc) {
      expect(bloc.state.selectedPackageId, isNull);
      expect(bloc.state.quote.gross, 3600);
      expect(bloc.state.quote.net, 2800);
      expect(bloc.state.quote.packageId, 'half');
      expect(bloc.state.packageAdvice, isNull,
          reason: 'арена за 5000 дороже текущих 2800');
    },
  );
}
