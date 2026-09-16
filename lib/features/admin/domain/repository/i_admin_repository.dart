import '../entity/admin_booking_request_entity.dart';
import '../entity/admin_club_entity.dart';
import '../entity/availability_entity.dart';
import '../entity/booking_row_entity.dart';
import '../entity/hall_price_entity.dart';
import '../entity/package_entity.dart';

/// Контракт данных админки.
///
/// Чтение — стартовые данные всех вкладок, запись — брони, цены, пакеты,
/// статус броней и доступность.
abstract interface class IAdminRepository {
  /// Есть ли у вошедшего пользователя доступ к броням (`booking_staff`).
  ///
  /// Войти в Supabase может любой сотрудник приложения-менеджера, но менять
  /// брони — только добавленные в список персонала бронирования.
  Future<bool> hasAccess();

  /// Клубы с залами и рабочими часами.
  Future<List<AdminClubEntity>> fetchClubs();

  /// Стартовые тарифы по всем залам.
  Future<List<HallPriceEntity>> fetchPrices();

  /// Стартовые пакеты.
  Future<List<PackageEntity>> fetchPackages();

  /// Единый список записей (брони + журнал).
  Future<List<BookingRowEntity>> fetchRows();

  /// Пауза приёма и закрытые залы/окна.
  Future<AvailabilityEntity> fetchAvailability();

  // -- запись ---------------------------------------------------------------

  /// Создать бронь от лица сотрудника — в одном или нескольких залах.
  ///
  /// Конкретные станции подбирает реализация по актуальной занятости.
  /// Возвращает id заказа. Отказ — `AdminFailure` с понятным текстом.
  Future<String> createBooking(AdminBookingRequest request);

  /// Обновить контакты, комментарий и предоплату брони.
  Future<void> updateOrderDetails({
    required String orderId,
    required String clientName,
    required String phone,
    required String note,
    required int prepay,
  });

  /// Сохранить одно поле тарифа клуба (цены в БД — по клубу, не по залу).
  Future<void> saveClubPrice({
    required String clubId,
    required PriceField field,
    required int value,
  });

  /// Задать ступень цены для шлемов: «от [fromQty] штук — другая цена за час».
  /// Цена ступени применяется ко всем шлемам сеанса сразу.
  Future<void> saveVrTier({
    required String clubId,
    required int fromQty,
    required int weekday,
    required int weekend,
  });

  /// Убрать ступень: остаётся одна цена независимо от количества.
  Future<void> clearVrTier(String clubId);

  /// Создать пакет. Возвращает присвоенный сервером id.
  Future<String> createPackage(PackageEntity draft);

  /// Обновить существующий пакет (поля, активность).
  Future<void> updatePackage(PackageEntity package);

  /// Удалить пакет.
  Future<void> deletePackage(String packageId);

  /// Отменить / вернуть бронь (`status` = `cancelled` / `confirmed`).
  Future<void> setOrderCancelled(String orderId, {required bool cancelled});

  /// Приём онлайн-броней клуба (пауза).
  Future<void> setIntakeOpen(String clubId, {required bool open});

  /// Закрыть / открыть зал целиком и бессрочно.
  Future<void> setHallClosed({
    required String clubId,
    required String hallId,
    required bool closed,
  });

  /// Закрыть / открыть часовое окно клуба на дату.
  Future<void> setSlotClosed({
    required String clubId,
    required DateTime day,
    required int startMinutes,
    required bool closed,
  });
}
