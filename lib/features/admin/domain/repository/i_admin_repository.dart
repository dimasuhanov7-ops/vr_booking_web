import '../entity/admin_booking_request_entity.dart';
import '../entity/admin_club_entity.dart';
import '../entity/audit_entry_entity.dart';
import '../entity/availability_entity.dart';
import '../entity/booking_row_entity.dart';
import '../entity/hall_price_entity.dart';
import '../entity/package_entity.dart';
import '../entity/promo_entity.dart';

/// Контракт данных админки.
///
/// Чтение — стартовые данные всех вкладок, запись — брони, цены, пакеты,
/// статус броней и доступность.
abstract interface class IAdminRepository {
  /// Есть ли у вошедшего пользователя доступ к броням (`booking_is_staff()`).
  ///
  /// Войти в Supabase может любой сотрудник приложения-менеджера, но менять
  /// брони — только добавленные в список персонала бронирования.
  Future<bool> hasAccess();

  /// Можно ли менять время и состав брони ([rescheduleOrder]).
  bool get canEditSchedule;

  /// Клубы с залами и рабочими часами.
  Future<List<AdminClubEntity>> fetchClubs();

  /// Стартовые тарифы по всем залам.
  Future<List<HallPriceEntity>> fetchPrices();

  /// Стартовые пакеты.
  Future<List<PackageEntity>> fetchPackages();

  /// Промокоды (общие для всех клубов). Пока не применена миграция
  /// `online_booking_discounts_admin`, сервер отдаёт пустой список.
  Future<List<PromoEntity>> fetchPromos();

  /// Единый список записей (брони + журнал).
  Future<List<BookingRowEntity>> fetchRows();

  /// Последние [limit] записей журнала действий, новые сверху.
  Future<List<AuditEntryEntity>> fetchAuditLog({int limit = 200});

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

  /// Сигналы об изменениях броней, закрытий и паузы приёма — откуда угодно:
  /// с сайта, из другого телефона, из менеджера. Данные в событии не
  /// передаются: это повод перечитать их. Подписка живёт, пока есть слушатель.
  Stream<void> watchChanges();

  /// Записать ступени цены шлемов клуба целиком: «от N штук — другая цена».
  /// Ступени, которых нет в [tiers], удаляются; пустой список — одна цена.
  Future<void> saveVrTiers({
    required String clubId,
    required List<VrTierEntity> tiers,
  });

  /// Создать пакет. Возвращает присвоенный сервером id.
  Future<String> createPackage(PackageEntity draft);

  /// Обновить существующий пакет (поля, активность).
  Future<void> updatePackage(PackageEntity package);

  /// Удалить пакет. Если по пакету уже есть брони (на него ссылается
  /// `booking_orders.package_id`), пакет не удаляется, а выключается —
  /// тогда возвращает `false`.
  Future<bool> deletePackage(String packageId);

  /// Завести промокод. Возвращает присвоенный сервером id.
  Future<String> createPromo(PromoEntity draft);

  /// Включить / выключить промокод.
  Future<void> setPromoActive(String promoId, {required bool active});

  /// Удалить промокод. Если по нему уже есть брони
  /// (`booking_orders.discount_id`), он не удаляется, а выключается — тогда
  /// возвращает `false`.
  Future<bool> deletePromo(String promoId);

  /// Отменить / вернуть бронь (`status` = `cancelled` / `confirmed`).
  Future<void> setOrderCancelled(String orderId, {required bool cancelled});

  /// Отметить визит: [status] — `confirmed` (ждём), `visited` (пришёл) или
  /// `noShow` (не пришёл). Отменённую бронь меняет [setOrderCancelled].
  Future<void> setOrderVisit(String orderId, {required RecordStatus status});

  /// Перенести бронь / сменить состав: новое начало [startMinutes] в день
  /// [day] и нужное число станций по часам (станции подбирает репозиторий,
  /// предпочитая те, что уже у брони).
  Future<void> rescheduleOrder({
    required String orderId,
    required String clubId,
    required String hallId,
    required DateTime day,
    required int startMinutes,
    required List<int> headsetsByHour,
    required List<int> consolesByHour,
  });

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
