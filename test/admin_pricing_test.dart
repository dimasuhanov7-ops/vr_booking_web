import 'package:flutter_test/flutter_test.dart';

import 'package:vr_booking_web/features/admin/domain/entity/booking_row_entity.dart';
import 'package:vr_booking_web/features/admin/domain/entity/hall_price_entity.dart';
import 'package:vr_booking_web/features/admin/domain/entity/package_entity.dart';
import 'package:vr_booking_web/features/admin/domain/service/admin_pricing_service.dart';

const AdminPricingService _svc = AdminPricingService();

HallPriceEntity _price(int vrWd) => HallPriceEntity(
      hallId: 'v-big',
      vrWeekday: vrWd,
      vrWeekend: vrWd + 300,
      ps5Weekday: 1000,
      ps5Weekend: 1200,
    );

const PackageEntity _team = PackageEntity(
  id: 'p4',
  clubId: 'vray',
  hallId: 'v-big',
  name: 'Команда',
  headsets: 6,
  consoles: 0,
  minutes: 120,
  price: 14000,
  isEnabled: true,
);

BookingRowEntity _row({String? pack, int vr = 6, int minutes = 120}) => BookingRowEntity(
      id: 'r1',
      clubId: 'vray',
      hallId: 'v-big',
      dayIndex: 0,
      startMinutes: 720,
      durationMinutes: minutes,
      headsets: vr,
      consoles: 0,
      clientName: 'Тест',
      phone: '+7',
      status: RecordStatus.confirmed,
      source: RecordSource.widget,
      packageName: pack,
    );

void main() {
  test('packageHourly реактивен от ставки VR', () {
    expect(_svc.packageHourly(pkg: _team, price: _price(1400)), 16800);
    expect(_svc.packageHourly(pkg: _team, price: _price(1500)), 18000);
  });

  test('rowCost: точное совпадение с пакетом -> цена пакета', () {
    final int cost = _svc.rowCost(
      row: _row(pack: 'Команда'),
      price: _price(1400),
      packages: const <PackageEntity>[_team],
    );
    expect(cost, 14000);
  });

  test('rowCost: состав не совпал с пакетом -> по часам', () {
    final int cost = _svc.rowCost(
      row: _row(pack: 'Команда', vr: 7), // 7 != 6 в пакете
      price: _price(1400),
      packages: const <PackageEntity>[_team],
    );
    // будни/выходные зависят от сегодняшнего дня — проверяем один из вариантов
    expect(cost == (1400 * 7 * 2) || cost == (1700 * 7 * 2), isTrue);
  });

  test('rowCost без пакета -> по часам', () {
    final int cost = _svc.rowCost(
      row: _row(minutes: 60, vr: 4),
      price: _price(1400),
      packages: const <PackageEntity>[],
    );
    expect(cost == 5600 || cost == 6800, isTrue);
  });
}
