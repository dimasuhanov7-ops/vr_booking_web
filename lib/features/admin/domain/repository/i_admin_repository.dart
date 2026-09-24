import '../entity/admin_club_entity.dart';
import '../entity/availability_entity.dart';
import '../entity/booking_row_entity.dart';
import '../entity/hall_price_entity.dart';
import '../entity/package_entity.dart';

/// Контракт данных админки.
///
/// Чтение — стартовые данные всех вкладок, запись — цены, пакеты, статус броней
/// и доступность.
abstract interface class IAdminRepository {
  /// Вошедший пользователь — активный сотрудник (`booking_is_staff()`).
  ///
  /// Войти через Supabase Auth может любой, у кого есть аккаунт; писать в
  /// справочники и видеть брони RLS разрешает только сотрудникам.
  Future<bool> isStaff();

  /// Можно ли менять время и состав брони. В БД позиции брони сотруднику
  /// только читаются (RLS), поэтому в боевой сборке — нет.
  bool get canEditSchedule;

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

  /// Удалить пакет. Если по пакету уже есть брони (на него ссылается
  /// `booking_orders.package_id`), пакет не удаляется, а выключается —
  /// тогда возвращает `false`.
  Future<bool> deletePackage(String packageId);

  /// Отменить / вернуть бронь (`status` = `cancelled` / `confirmed`).
  Future<void> setOrderCancelled(String orderId, {required bool cancelled});

  /// Сохранить контакты, предоплату и комментарий брони.
  Future<void> updateOrderDetails({
    required String orderId,
    required String clientName,
    required String phone,
    required int prepay,
    required String note,
  });

  /// Создать бронь от имени сотрудника. Возвращает id заказа.
  ///
  /// [day] — дата в таймзоне клуба, [startMinutes] — начало от полуночи;
  /// [headsetsByHour] / [consolesByHour] — сколько станций нужно в каждый час
  /// сеанса (конкретные свободные станции подбирает репозиторий).
  /// Предоплата пишется отдельно — [updateOrderDetails].
  Future<String> createBooking({
    required String clubId,
    required String hallId,
    required DateTime day,
    required int startMinutes,
    required List<int> headsetsByHour,
    required List<int> consolesByHour,
    required String clientName,
    required String phone,
    required String note,
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
