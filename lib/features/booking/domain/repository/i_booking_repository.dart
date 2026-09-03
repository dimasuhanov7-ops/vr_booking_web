import '../entity/busy_interval_entity.dart';
import '../entity/club_entity.dart';
import '../entity/discount_entity.dart';
import '../entity/price_rate_entity.dart';
import '../entity/reservation_request_entity.dart';
import '../entity/room_entity.dart';
import '../entity/station_entity.dart';

/// Контракт доступа к данным бронирования. Доменный слой знает только его.
abstract interface class IBookingRepository {
  /// Клубы, открытые для онлайн-бронирования.
  Future<List<ClubEntity>> fetchClubs();

  /// Залы клуба.
  Future<List<RoomEntity>> fetchRooms(String clubId);

  /// Все станции клуба (по всем залам) — включая неактивные.
  Future<List<StationEntity>> fetchStations(String clubId);

  /// Тарифы клуба (цена за час по типу станции и типу дня).
  Future<List<PriceRateEntity>> fetchPrices(String clubId);

  /// Занятые интервалы всех станций клуба на дату [day].
  Future<List<BusyIntervalEntity>> fetchBusyIntervals({
    required String clubId,
    required DateTime day,
  });

  /// Проверяет промокод / подбирает автоскидку. `null`, если скидки нет.
  Future<DiscountEntity?> resolveDiscount({
    String? code,
    required int stationCount,
  });

  /// Создаёт групповую бронь одной транзакцией. Возвращает id брони.
  /// Бросает [SlotAlreadyTakenFailure] при конфликте (`23P01`).
  Future<String> createReservation(ReservationRequestEntity request);
}
