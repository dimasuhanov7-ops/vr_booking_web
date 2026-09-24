import 'package:flutter_test/flutter_test.dart';

import 'package:vr_booking_web/features/booking/domain/entity/club_entity.dart';
import 'package:vr_booking_web/features/booking/domain/entity/price_rate_entity.dart';
import 'package:vr_booking_web/features/booking/domain/entity/quote_entity.dart';
import 'package:vr_booking_web/features/booking/domain/entity/station_entity.dart';
import 'package:vr_booking_web/features/booking/domain/service/club_clock.dart';
import 'package:vr_booking_web/features/booking/domain/service/pricing_service.dart';
import 'package:vr_booking_web/features/booking/domain/service/slot_generator_service.dart';

/// Клуб в Перми — как на проде (`booking_clubs.timezone`).
const ClubEntity _vray = ClubEntity(
  id: 'c2',
  slug: 'v_ray',
  name: 'V-Ray',
  timezone: 'Asia/Yekaterinburg',
  openTime: Duration.zero,
  closeTime: Duration(hours: 24),
  slotGapMinutes: 0,
);

StationEntity _vr(int n) => StationEntity(
      id: 'vr$n',
      roomId: 'r1',
      roomName: 'Большой зал',
      type: StationType.vrHeadset,
      label: '#$n',
      rowIndex: 0,
      positionInRow: n,
      sortOrder: n,
      isActive: true,
    );

/// Будни: 800 ₽/ч до 5 шлемов, 700 ₽/ч от 6 шлемов.
const List<PriceRateEntity> _tiers = <PriceRateEntity>[
  PriceRateEntity(
      stationType: StationType.vrHeadset,
      dayKind: DayKind.weekday,
      pricePerHour: 800),
  PriceRateEntity(
      stationType: StationType.vrHeadset,
      dayKind: DayKind.weekday,
      pricePerHour: 700,
      minQty: 6),
];

/// Полдень ближайшего буднего дня по Перми, в UTC.
DateTime _weekdayNoonUtc() {
  DateTime day = DateTime.now().add(const Duration(days: 1));
  while (day.weekday == DateTime.saturday || day.weekday == DateTime.sunday) {
    day = day.add(const Duration(days: 1));
  }
  return ClubClock(_vray).toUtc(day, const Duration(hours: 12));
}

void main() {
  const PricingService pricing = PricingService();

  test('ClubClock: Пермь = UTC+5', () {
    expect(ClubClock.offsetOf('Asia/Yekaterinburg'), const Duration(hours: 5));
    final DateTime utc =
        ClubClock(_vray).toUtc(DateTime(2026, 9, 10), const Duration(hours: 11));
    expect(utc, DateTime.utc(2026, 9, 10, 6));
  });

  test('ступень тарифа: берётся наибольшая, что не больше количества', () {
    final DateTime start = _weekdayNoonUtc();
    num rateFor(int qty) => pricing.priceOf(
          club: _vray,
          station: _vr(1),
          startsAtUtc: start,
          minutes: 60,
          rates: _tiers,
          qty: qty,
        );
    expect(rateFor(1), 800);
    expect(rateFor(5), 800);
    expect(rateFor(6), 700);
    expect(rateFor(12), 700);
  });

  test('цена по часам: 6 шлемов в 1-м часе, 3 во 2-м — ступени разные', () {
    final List<StationEntity> six = <StationEntity>[
      for (int i = 1; i <= 6; i++) _vr(i),
    ];
    // Шлемы 1–3 заняты оба часа, 4–6 — только первый.
    final QuoteEntity q = pricing.quote(
      club: _vray,
      stations: six,
      startsAtUtc: _weekdayNoonUtc(),
      minutesOf: (StationEntity s) => s.positionInRow <= 3 ? 120 : 60,
      qtyByHourOf: (StationEntity s) =>
          s.positionInRow <= 3 ? <int>[6, 3] : <int>[6],
      rates: _tiers,
    );
    // Час 1: 6 × 700; час 2: 3 × 800.
    expect(q.gross, 6 * 700 + 3 * 800);
  });

  test('слоты: запись закрывается за 30 минут до начала', () {
    const SlotGeneratorService svc = SlotGeneratorService();
    final DateTime nowWall = ClubClock(_vray).nowWall();
    final slots = svc.generateSlots(
      club: _vray,
      day: DateTime(nowWall.year, nowWall.month, nowWall.day),
      durationMinutes: 60,
    );
    final DateTime earliest =
        DateTime.now().toUtc().add(SlotGeneratorService.leadTime);
    expect(slots.every((s) => !s.startsAt.isBefore(earliest)), isTrue);
  });
}
