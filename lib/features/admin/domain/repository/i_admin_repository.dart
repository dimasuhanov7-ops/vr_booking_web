import '../entity/admin_club_entity.dart';
import '../entity/booking_row_entity.dart';
import '../entity/hall_price_entity.dart';
import '../entity/package_entity.dart';

/// Контракт данных админки.
///
/// В этой итерации — только чтение стартовых данных; правки (цены, пакеты,
/// доступность, отмены) живут в состоянии `AdminBloc` и на сервер не уходят.
abstract interface class IAdminRepository {
  /// Клубы с залами и рабочими часами.
  Future<List<AdminClubEntity>> fetchClubs();

  /// Стартовые тарифы по всем залам.
  Future<List<HallPriceEntity>> fetchPrices();

  /// Стартовые пакеты.
  Future<List<PackageEntity>> fetchPackages();

  /// Единый список записей (брони + журнал).
  Future<List<BookingRowEntity>> fetchRows();
}
