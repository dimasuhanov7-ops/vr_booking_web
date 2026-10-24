import 'package:flutter_test/flutter_test.dart';

import 'package:vr_booking_web/features/booking/domain/entity/club_entity.dart';
import 'package:vr_booking_web/features/booking/domain/entity/price_rate_entity.dart';
import 'package:vr_booking_web/features/booking/domain/entity/quote_entity.dart';
import 'package:vr_booking_web/features/booking/domain/entity/station_entity.dart';
import 'package:vr_booking_web/features/booking/domain/service/pricing_service.dart';

const ClubEntity _club = ClubEntity(
  id: 'club',
  slug: 'v_ray',
  name: 'V-Ray',
  timezone: 'Asia/Yekaterinburg',
  openTime: Duration(hours: 11),
  closeTime: Duration(hours: 23),
  slotGapMinutes: 0,
);

/// Тариф клуба (Большой зал): будни 800, от 6 шлемов — 700.
const List<PriceRateEntity> _clubRates = <PriceRateEntity>[
  PriceRateEntity(
      stationType: StationType.vrHeadset, dayKind: DayKind.weekday, pricePerHour: 800),
  PriceRateEntity(
      stationType: StationType.vrHeadset,
      dayKind: DayKind.weekday,
      pricePerHour: 700,
      minQty: 6),
  PriceRateEntity(
      stationType: StationType.ps5, dayKind: DayKind.weekday, pricePerHour: 300),
];

/// Малый зал: свои 500 за шлем и 250 за PS5.
const List<PriceRateEntity> _smallRates = <PriceRateEntity>[
  PriceRateEntity(
      stationType: StationType.vrHeadset,
      dayKind: DayKind.weekday,
      pricePerHour: 500,
      roomId: 'small'),
  PriceRateEntity(
      stationType: StationType.ps5,
      dayKind: DayKind.weekday,
      pricePerHour: 250,
      roomId: 'small'),
];

StationEntity _st(String room, StationType type, int n) => StationEntity(
      id: '$room$type$n',
      roomId: room,
      roomName: room == 'big' ? 'Большой зал' : 'Малый зал',
      type: type,
      label: '#$n',
      rowIndex: 0,
      positionInRow: n,
      sortOrder: n,
      isActive: true,
    );

/// Среда, 12:00 по Перми.
final DateTime _weekday = DateTime.utc(2026, 10, 14, 7);

num _total(
  List<PriceRateEntity> rates, {
  int big = 0,
  int smallVr = 0,
  int smallPs = 0,
}) {
  final List<StationEntity> picked = <StationEntity>[
    for (int n = 0; n < big; n++) _st('big', StationType.vrHeadset, n),
    for (int n = 0; n < smallVr; n++) _st('small', StationType.vrHeadset, n),
    for (int n = 0; n < smallPs; n++) _st('small', StationType.ps5, n),
  ];
  final QuoteEntity q = const PricingService().quote(
    club: _club,
    stations: picked,
    startsAtUtc: _weekday,
    hourCount: 1,
    isPickedAt: (StationEntity s, int h) => true,
    rates: rates,
  );
  return q.gross;
}

void main() {
  final List<PriceRateEntity> both = <PriceRateEntity>[..._clubRates, ..._smallRates];

  test('малый зал считается по своей цене, большой — по тарифу клуба', () {
    expect(_total(both, smallVr: 3), 3 * 500);
    expect(_total(both, smallVr: 2, smallPs: 2), 2 * 500 + 2 * 250);
    expect(_total(both, big: 2), 2 * 800);
  });

  test('«Весь клуб»: ступень большого зала не считает шлемы малого', () {
    // 6 шлемов арены → ступень «от 6» (700); 4 шлема малого — свои 500.
    expect(_total(both, big: 6, smallVr: 4), 6 * 700 + 4 * 500);
    // 5 шлемов арены — ещё 800: 4 шлема малого в ступень не попадают.
    expect(_total(both, big: 5, smallVr: 4), 5 * 800 + 4 * 500);
  });

  test('без цен залов всё как раньше: шлемы клуба считаются вместе', () {
    final List<PriceRateEntity> noRoom = <PriceRateEntity>[
      ..._clubRates,
      const PriceRateEntity(
          stationType: StationType.vrHeadset,
          dayKind: DayKind.weekday,
          pricePerHour: 600,
          minQty: 10),
    ];
    // 6 арены + 4 малого = 10 шлемов клуба → ступень «от 10» для всех.
    expect(_total(noRoom, big: 6, smallVr: 4), 10 * 600);
  });

  test('цена зала только на шлем: PS5 малого зала остаётся по тарифу клуба', () {
    final List<PriceRateEntity> vrOnly = <PriceRateEntity>[
      ..._clubRates,
      _smallRates.first,
    ];
    expect(_total(vrOnly, smallVr: 1, smallPs: 2), 500 + 2 * 300);
  });

  test('ratePerHour: цена зала перекрывает ступени и не зависит от числа', () {
    const PricingService svc = PricingService();
    expect(
      svc.ratePerHour(
          rates: both,
          type: StationType.vrHeadset,
          dayKind: DayKind.weekday,
          qty: 12,
          roomId: 'small'),
      500,
    );
    expect(
      svc.ratePerHour(
          rates: both,
          type: StationType.vrHeadset,
          dayKind: DayKind.weekday,
          qty: 12,
          roomId: 'big'),
      700,
    );
  });
}
