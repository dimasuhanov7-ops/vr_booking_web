import '../entity/booking_row_entity.dart';
import '../entity/hall_price_entity.dart';
import '../entity/package_entity.dart';

/// Расчёты админки: почасовая стоимость, сравнение с пакетом, превью длительности.
/// Всё реактивно от текущих тарифов (`prices`), как в макете.
class AdminPricingService {
  /// Создаёт сервис.
  const AdminPricingService();

  /// Базовая дата, от которой считается `dayIndex` (сегодня).
  static DateTime baseDate() {
    final DateTime n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  /// Дата по индексу дня.
  DateTime dateOf(int dayIndex) => baseDate().add(Duration(days: dayIndex));

  /// Выходной ли день (сб/вс).
  bool isWeekend(int dayIndex) {
    final int wd = dateOf(dayIndex).weekday;
    return wd == DateTime.saturday || wd == DateTime.sunday;
  }

  /// Стоимость сеанса по часам.
  int hourlyCost({
    required int headsets,
    required int consoles,
    required int minutes,
    required HallPriceEntity price,
    required bool weekend,
  }) {
    final num raw = (price.vrRate(weekend: weekend) * headsets +
            price.ps5Rate(weekend: weekend) * consoles) *
        minutes /
        60;
    return raw.round();
  }

  /// Точное совпадение записи с пакетом (клуб, зал, состав, длительность).
  PackageEntity? matchPackage(
    BookingRowEntity row,
    List<PackageEntity> packages,
  ) {
    if (row.packageName == null) return null;
    for (final PackageEntity p in packages) {
      if (p.name == row.packageName &&
          p.clubId == row.clubId &&
          p.hallId == row.hallId &&
          p.headsets == row.headsets &&
          p.consoles == row.consoles &&
          p.minutes == row.durationMinutes) {
        return p;
      }
    }
    return null;
  }

  /// Итоговая стоимость записи: цена пакета (если состав совпал) либо по часам.
  int rowCost({
    required BookingRowEntity row,
    required HallPriceEntity price,
    required List<PackageEntity> packages,
  }) {
    final PackageEntity? pkg = matchPackage(row, packages);
    if (pkg != null) return pkg.price;
    return hourlyCost(
      headsets: row.headsets,
      consoles: row.consoles,
      minutes: row.durationMinutes,
      price: price,
      weekend: isWeekend(row.dayIndex),
    );
  }

  /// «По часам вышло бы» для пакета — по будничному тарифу зала.
  int packageHourly({
    required PackageEntity pkg,
    required HallPriceEntity price,
  }) {
    final num raw =
        (price.vrWeekday * pkg.headsets + price.ps5Weekday * pkg.consoles) *
            pkg.minutes /
            60;
    return raw.round();
  }
}
