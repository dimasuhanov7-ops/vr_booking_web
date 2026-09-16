import 'package:flutter_test/flutter_test.dart';

import 'package:vr_booking_web/features/admin/domain/entity/hall_price_entity.dart';
import 'package:vr_booking_web/features/admin/domain/service/admin_pricing_service.dart';
import 'package:vr_booking_web/features/booking/domain/entity/club_entity.dart';
import 'package:vr_booking_web/features/booking/domain/entity/price_rate_entity.dart';
import 'package:vr_booking_web/features/booking/domain/entity/quote_entity.dart';
import 'package:vr_booking_web/features/booking/domain/entity/station_entity.dart';
import 'package:vr_booking_web/features/booking/domain/service/pricing_service.dart';

const ClubEntity _club = ClubEntity(
  id: 'club',
  slug: 'effect_vr',
  name: 'Effect VR',
  timezone: 'Asia/Yekaterinburg',
  openTime: Duration(hours: 11),
  closeTime: Duration(hours: 23),
  slotGapMinutes: 0,
  sortOrder: 10,
);

/// Будни: 800 ₽ за шлем, от 7 шлемов — 700 ₽; PS5 без ступеней.
const List<PriceRateEntity> _rates = <PriceRateEntity>[
  PriceRateEntity(
      stationType: StationType.vrHeadset, dayKind: DayKind.weekday, pricePerHour: 800),
  PriceRateEntity(
      stationType: StationType.vrHeadset,
      dayKind: DayKind.weekday,
      pricePerHour: 700,
      minQty: 7),
  PriceRateEntity(
      stationType: StationType.ps5, dayKind: DayKind.weekday, pricePerHour: 300),
];

StationEntity _vr(int n) => StationEntity(
      id: 'vr$n',
      roomId: 'hall',
      roomName: 'Зал',
      type: StationType.vrHeadset,
      label: '#$n',
      rowIndex: 0,
      positionInRow: n - 1,
      sortOrder: n,
      isActive: true,
    );

/// Среда — будний день.
final DateTime _weekday = DateTime.utc(2026, 10, 14, 7); // 12:00 по Перми

QuoteEntity _quoteFor(int headsets, {int hourCount = 1, int secondHour = -1}) {
  final List<StationEntity> stations = <StationEntity>[
    for (int n = 1; n <= headsets; n++) _vr(n),
  ];
  final int kept = secondHour < 0 ? headsets : secondHour;
  return const PricingService().quote(
    club: _club,
    stations: stations,
    startsAtUtc: _weekday,
    hourCount: hourCount,
    isPickedAt: (StationEntity s, int h) =>
        h == 0 || int.parse(s.id.substring(2)) <= kept,
    rates: _rates,
  );
}

void main() {
  group('ступени цены в виджете', () {
    test('до порога — базовая цена', () {
      expect(_quoteFor(6).gross, 4800); // 6 × 800
    });

    test('от порога дешевеют все шлемы, а не только лишние', () {
      expect(_quoteFor(7).gross, 4900); // 7 × 700, а не 4800 + 700
      expect(_quoteFor(8).gross, 5600);
    });

    test('ступень считается по каждому часу отдельно', () {
      // 8 шлемов в первый час (по 700) и 5 во второй (по 800):
      // 8 × 700 + 5 × 800 = 9600.
      expect(_quoteFor(8, hourCount: 2, secondHour: 5).gross, 9600);
    });

    test('PS5 без ступеней считается по своей цене', () {
      const PricingService pricing = PricingService();
      expect(
        pricing.ratePerHour(
            rates: _rates, type: StationType.ps5, dayKind: DayKind.weekday, qty: 9),
        300,
      );
    });

    test('цена часа выбирает верхнюю подходящую ступень', () {
      const PricingService pricing = PricingService();
      int rate(int qty) => pricing
          .ratePerHour(
            rates: _rates,
            type: StationType.vrHeadset,
            dayKind: DayKind.weekday,
            qty: qty,
          )
          .round();
      expect(<int>[rate(1), rate(6), rate(7), rate(12)], <int>[800, 800, 700, 700]);
    });
  });

  group('ступени в админке', () {
    const HallPriceEntity price = HallPriceEntity(
      hallId: 'hall',
      vrWeekday: 800,
      vrWeekend: 1000,
      ps5Weekday: 300,
      ps5Weekend: 400,
      vrTierFrom: 7,
      vrTierWeekday: 700,
      vrTierWeekend: 900,
    );

    test('ставка зависит от количества и типа дня', () {
      expect(price.vrRate(weekend: false, qty: 6), 800);
      expect(price.vrRate(weekend: false, qty: 7), 700);
      expect(price.vrRate(weekend: true, qty: 7), 900);
      expect(price.vrRate(weekend: false), 800, reason: 'по умолчанию один шлем');
    });

    test('стоимость сеанса в админке считает ступень', () {
      const AdminPricingService pricing = AdminPricingService();
      expect(
        pricing.hourlyCost(
            headsets: 8, consoles: 0, minutes: 60, price: price, weekend: false),
        5600,
      );
    });

    test('выключенная ступень не влияет', () {
      const HallPriceEntity flat = HallPriceEntity(
        hallId: 'hall',
        vrWeekday: 800,
        vrWeekend: 1000,
        ps5Weekday: 300,
        ps5Weekend: 400,
      );
      expect(flat.hasVrTier, isFalse);
      expect(flat.vrRate(weekend: false, qty: 12), 800);
    });

    test('включение ступени берёт базовые цены, выключение — обнуляет', () {
      const HallPriceEntity flat = HallPriceEntity(
        hallId: 'hall',
        vrWeekday: 800,
        vrWeekend: 1000,
        ps5Weekday: 300,
        ps5Weekend: 400,
      );
      final HallPriceEntity on = flat.withTier(7);
      expect(<int>[on.vrTierFrom, on.vrTierWeekday, on.vrTierWeekend],
          <int>[7, 800, 1000]);
      expect(on.withTier(0).hasVrTier, isFalse);
    });
  });
}
