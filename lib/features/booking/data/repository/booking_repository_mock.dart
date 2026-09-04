import '../../domain/entity/booking_failure.dart';
import '../../domain/entity/busy_interval_entity.dart';
import '../../domain/entity/club_entity.dart';
import '../../domain/entity/discount_entity.dart';
import '../../domain/entity/price_rate_entity.dart';
import '../../domain/entity/reservation_request_entity.dart';
import '../../domain/entity/room_entity.dart';
import '../../domain/entity/station_entity.dart';
import '../../domain/repository/i_booking_repository.dart';

/// In-memory реализация [IBookingRepository] для демонстрации UI без Supabase.
/// Данные повторяют сид миграции. Включается `--dart-define=USE_MOCK=true`.
class BookingRepositoryMock implements IBookingRepository {
  /// Создаёт mock-репозиторий.
  BookingRepositoryMock();

  static const Duration _tz = Duration(hours: 3); // Europe/Moscow

  final List<ClubEntity> _clubs = const <ClubEntity>[
    ClubEntity(
      id: 'club-effect',
      slug: 'effect_vr',
      name: 'Effect VR',
      timezone: 'Europe/Moscow',
      openTime: Duration(hours: 11),
      closeTime: Duration(hours: 22, minutes: 30),
      slotGapMinutes: 10,
      sortOrder: 10,
    ),
    ClubEntity(
      id: 'club-vray',
      slug: 'v_ray',
      name: 'V-Ray',
      timezone: 'Europe/Moscow',
      openTime: Duration(hours: 11),
      closeTime: Duration(hours: 23),
      slotGapMinutes: 0,
      sortOrder: 20,
    ),
  ];

  late final Map<String, List<RoomEntity>> _rooms = <String, List<RoomEntity>>{
    'club-effect': const <RoomEntity>[
      RoomEntity(id: 'e-main', clubId: 'club-effect', name: 'Зал', sortOrder: 0),
    ],
    'club-vray': const <RoomEntity>[
      RoomEntity(id: 'v-big', clubId: 'club-vray', name: 'Большой зал', sortOrder: 0),
      RoomEntity(id: 'v-small', clubId: 'club-vray', name: 'Малый зал', sortOrder: 1),
    ],
  };

  late final Map<String, List<StationEntity>> _stations =
      <String, List<StationEntity>>{
    'club-effect': _room('e-main', 'Зал', headsets: 4, consoles: 2, base: 1),
    'club-vray': <StationEntity>[
      ..._room('v-big', 'Большой зал', headsets: 12, consoles: 0, base: 1),
      ..._room('v-small', 'Малый зал', headsets: 4, consoles: 2, base: 20),
    ],
  };

  final List<ReservationRequestEntity> _created = <ReservationRequestEntity>[];

  @override
  Future<List<ClubEntity>> fetchClubs() => _delay(_clubs);

  @override
  Future<List<RoomEntity>> fetchRooms(String clubId) =>
      _delay(_rooms[clubId] ?? const <RoomEntity>[]);

  @override
  Future<List<StationEntity>> fetchStations(String clubId) =>
      _delay(_stations[clubId] ?? const <StationEntity>[]);

  @override
  Future<List<PriceRateEntity>> fetchPrices(String clubId) => _delay(const <PriceRateEntity>[
        PriceRateEntity(stationType: StationType.vrHeadset, dayKind: DayKind.weekday, pricePerHour: 600),
        PriceRateEntity(stationType: StationType.vrHeadset, dayKind: DayKind.weekend, pricePerHour: 1000),
        PriceRateEntity(stationType: StationType.ps5, dayKind: DayKind.weekday, pricePerHour: 300),
        PriceRateEntity(stationType: StationType.ps5, dayKind: DayKind.weekend, pricePerHour: 400),
      ]);

  @override
  Future<List<BusyIntervalEntity>> fetchBusyIntervals({
    required String clubId,
    required DateTime day,
  }) {
    final List<StationEntity> stations = _stations[clubId] ?? const <StationEntity>[];
    final List<BusyIntervalEntity> busy = <BusyIntervalEntity>[];
    DateTime utc(int h, int m) =>
        DateTime.utc(day.year, day.month, day.day, h, m).subtract(_tz);

    for (int i = 0; i < stations.length; i++) {
      final StationEntity s = stations[i];
      if (i.isEven) {
        busy.add(BusyIntervalEntity(
            stationId: s.id, roomId: s.roomId, startsAt: utc(13, 0), endsAt: utc(14, 30)));
      }
      if (i % 3 == 0) {
        busy.add(BusyIntervalEntity(
            stationId: s.id, roomId: s.roomId, startsAt: utc(18, 0), endsAt: utc(20, 0)));
      }
    }
    for (final ReservationRequestEntity r in _created) {
      for (final String sid in r.stationIds) {
        final StationEntity? s = stations
            .where((StationEntity st) => st.id == sid)
            .cast<StationEntity?>()
            .firstWhere((StationEntity? st) => true, orElse: () => null);
        if (s != null) {
          busy.add(BusyIntervalEntity(
            stationId: sid,
            roomId: s.roomId,
            startsAt: r.startsAt,
            endsAt: r.startsAt.add(Duration(minutes: r.minutes)),
          ));
        }
      }
    }
    return _delay(busy);
  }

  @override
  Future<DiscountEntity?> resolveDiscount({
    String? code,
    required int stationCount,
  }) async =>
      null; // скидок пока нет

  @override
  Future<String> createReservation(ReservationRequestEntity request) async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    final bool clash = _created.any((ReservationRequestEntity r) =>
        r.startsAt == request.startsAt &&
        r.stationIds.any(request.stationIds.contains));
    if (clash) throw const SlotAlreadyTakenFailure();
    _created.add(request);
    return 'mock-${DateTime.now().millisecondsSinceEpoch.toRadixString(16)}';
  }

  Future<T> _delay<T>(T value) =>
      Future<T>.delayed(const Duration(milliseconds: 220), () => value);

  static List<StationEntity> _room(
    String roomId,
    String roomName, {
    required int headsets,
    required int consoles,
    required int base,
  }) {
    final List<StationEntity> out = <StationEntity>[];
    for (int i = 0; i < headsets; i++) {
      out.add(StationEntity(
        id: '$roomId-vr${i + 1}',
        roomId: roomId,
        roomName: roomName,
        type: StationType.vrHeadset,
        label: '#${i + 1}',
        rowIndex: i ~/ 4,
        positionInRow: i % 4,
        sortOrder: base + i,
        isActive: true,
      ));
    }
    for (int i = 0; i < consoles; i++) {
      out.add(StationEntity(
        id: '$roomId-ps${i + 1}',
        roomId: roomId,
        roomName: roomName,
        type: StationType.ps5,
        label: 'PS5-${i + 1}',
        rowIndex: (headsets / 4).ceil(),
        positionInRow: i,
        sortOrder: base + headsets + i,
        isActive: true,
      ));
    }
    return out;
  }
}
