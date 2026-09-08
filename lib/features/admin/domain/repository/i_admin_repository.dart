import '../entity/admin_club_entity.dart';
import '../entity/booking_row_entity.dart';
import '../entity/hall_price_entity.dart';
import '../entity/package_entity.dart';

/// Контракт данных админки.
///
/// Чтение — стартовые данные всех вкладок. Запись — цены, пакеты, статус броней
/// (доступность пока живёт только в состоянии `AdminBloc`).
abstract interface class IAdminRepository {
  /// Клубы с залами и рабочими часами.
  Future<List<AdminClubEntity>> fetchClubs();

  /// Стартовые тарифы по всем залам.
  Future<List<HallPriceEntity>> fetchPrices();

  /// Стартовые пакеты.
  Future<List<PackageEntity>> fetchPackages();

  /// Единый список записей (брони + журнал).
  Future<List<BookingRowEntity>> fetchRows();

  // -- запись ---------------------------------------------------------------

  /// Сохранить одно поле тарифа клуба (цены в БД — по клубу, не по залу).
  Future<void> saveClubPrice({
    required String clubId,
    required PriceField field,
    required int value,
  });

  /// Создать пакет. Возвращает присвоенный сервером id.
  Future<String> createPackage(PackageEntity draft);

  /// Обновить существующий пакет (поля, активность).
  Future<void> updatePackage(PackageEntity package);

  /// Удалить пакет.
  Future<void> deletePackage(String packageId);

  /// Отменить / вернуть бронь (`status` = `cancelled` / `confirmed`).
  Future<void> setOrderCancelled(String orderId, {required bool cancelled});
}
