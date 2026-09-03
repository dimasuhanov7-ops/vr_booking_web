import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vr_booking_web/features/booking/domain/entity/club_entity.dart';
import 'package:vr_booking_web/features/booking/domain/entity/price_rate_entity.dart';
import 'package:vr_booking_web/features/booking/domain/entity/station_entity.dart';
import 'package:vr_booking_web/features/booking/domain/service/pricing_service.dart';
import 'package:vr_booking_web/features/booking/domain/service/slot_generator_service.dart';

const ClubEntity _effect = ClubEntity(
  id: 'c1',
  slug: 'effect_vr',
  name: 'Effect VR',
  timezone: 'Europe/Moscow',
  openTime: Duration(hours: 11),
  closeTime: Duration(hours: 22, minutes: 30),
  slotGapMinutes: 10,
);

void main() {
  test('SlotGeneratorService: шаг = длительность + пауза', () {
    const SlotGeneratorService svc = SlotGeneratorService();
    final DateTime day = DateTime.now().add(const Duration(days: 4));
    final slots = svc.generateSlots(
      club: _effect,
      day: DateTime(day.year, day.month, day.day),
      durationMinutes: 60,
    );
    // 11:00..21:30, шаг 70 мин: 11:00, 12:10, 13:20, 14:30, 15:40, 16:50, 18:00, 19:10, 20:20, 21:30 => 10
    expect(slots.length, 10);
    expect(slots.first.duration, const Duration(minutes: 60));
  });

  test('PricingService: будни VR 600/ч, 90 мин = 900', () {
    const PricingService pricing = PricingService();
    // ближайший будний день
    DateTime day = DateTime.now().add(const Duration(days: 1));
    while (day.weekday == DateTime.saturday || day.weekday == DateTime.sunday) {
      day = day.add(const Duration(days: 1));
    }
    final DateTime startUtc =
        DateTime.utc(day.year, day.month, day.day, 12).subtract(const Duration(hours: 3));
    const StationEntity station = StationEntity(
      id: 's1',
      roomId: 'r1',
      roomName: 'Зал',
      type: StationType.vrHeadset,
      label: '#1',
      rowIndex: 0,
      positionInRow: 0,
      sortOrder: 1,
      isActive: true,
    );
    final num price = pricing.priceOf(
      club: _effect,
      station: station,
      startsAtUtc: startUtc,
      minutes: 90,
      rates: const <PriceRateEntity>[
        PriceRateEntity(
            stationType: StationType.vrHeadset,
            dayKind: DayKind.weekday,
            pricePerHour: 600),
      ],
    );
    expect(price, 900);
  });

  testWidgets('MaterialApp собирается', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold()));
    expect(find.byType(Scaffold), findsOneWidget);
  });
}
