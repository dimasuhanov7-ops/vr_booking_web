import '../../domain/entity/booking_failure.dart';
import '../../domain/entity/busy_interval_entity.dart';
import '../../domain/entity/club_entity.dart';
import '../../domain/entity/discount_entity.dart';
import '../../domain/entity/package_entity.dart';
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

  static const Duration _tz = Duration(hours: 5); // Asia/Yekaterinburg (Пермь)

  final List<ClubEntity> _clubs = const <ClubEntity>[
    ClubEntity(
      id: 'club-effect',
      slug: 'effect_vr',
      name: 'Effect VR',
      timezone: 'Asia/Yekaterinburg',
      openTime: Duration(hours: 11),
      closeTime: Duration(hours: 22, minutes: 30),
      slotGapMinutes: 10,
      sortOrder: 10,
    ),
    ClubEntity(
      id: 'club-vray',
      slug: 'v_ray',
      name: 'V-Ray',
      timezone: 'Asia/Yekaterinburg',
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
      // Арена — две половины по 6 шлемов (миграция online_booking_arena_halves).
      ..._room('v-big', 'Большой зал', headsets: 12, consoles: 0, base: 1, perRow: 6),
      ..._room('v-small', 'Малый зал', headsets: 4, consoles: 2, base: 20),
    ],
  };

  final List<ReservationRequestEntity> _created = <ReservationRequestEntity>[];

  /// id брони -> заявка: нужно, чтобы демо умело отменять по тому же ключу,
  /// что и сервер (id + телефон).
  final Map<String, ReservationRequestEntity> _byId =
      <String, ReservationRequestEntity>{};

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
  Future<List<PackageEntity>> fetchPackages(String clubId) => _delay(
        _packages.where((PackageEntity p) => p.clubId == clubId).toList(),
      );

  static const List<PackageEntity> _packages = <PackageEntity>[
    PackageEntity(id: 'p1', clubId: 'club-effect', roomId: 'e-main', name: 'Вдвоём',
        headsets: 2, consoles: 0, minutes: 120, price: 5000, note: '2 шлема на 2 часа', sortOrder: 10),
    PackageEntity(id: 'p2', clubId: 'club-effect', roomId: 'e-main', name: 'Компания',
        headsets: 4, consoles: 0, minutes: 120, price: 10000, note: 'все 4 шлема, 2 часа', sortOrder: 20),
    PackageEntity(id: 'p3', clubId: 'club-effect', roomId: 'e-main', name: 'Полный зал',
        headsets: 4, consoles: 2, minutes: 120, price: 14000, note: '4 шлема и 2 PS5, 2 часа', sortOrder: 30),
    PackageEntity(id: 'p4', clubId: 'club-vray', roomId: 'v-big', name: 'Команда',
        headsets: 6, consoles: 0, minutes: 120, price: 14000, note: '6 шлемов на арене, 2 часа', sortOrder: 10),
    PackageEntity(id: 'p5', clubId: 'club-vray', roomId: 'v-big', name: 'Арена',
        headsets: 12, consoles: 0, minutes: 120, price: 26000, note: 'все 12 шлемов, 2 часа', sortOrder: 20),
    PackageEntity(id: 'p6', clubId: 'club-vray', roomId: 'v-small', name: 'Малый зал целиком',
        headsets: 4, consoles: 2, minutes: 120, price: 14000, note: '4 шлема и 2 PS5, 2 часа', sortOrder: 30),
    PackageEntity(id: 'p7', clubId: 'club-vray', roomId: 'v-small', name: 'Шлемы и PS5',
        headsets: 2, consoles: 2, minutes: 60, price: 4300, note: '2 шлема и 2 PS5, 1 час', sortOrder: 40),
  ];

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
      for (final ReservationSegmentEntity seg in r.segments) {
        for (final String sid in seg.stationIds) {
          final StationEntity? s = stations
              .where((StationEntity st) => st.id == sid)
              .cast<StationEntity?>()
              .firstWhere((StationEntity? st) => true, orElse: () => null);
          if (s != null) {
            busy.add(BusyIntervalEntity(
              stationId: sid,
              roomId: s.roomId,
              startsAt: seg.startsAt,
              endsAt: seg.endsAt,
            ));
          }
        }
      }
    }
    return _delay(busy);
  }

  /// Демо-промокоды: как строки `booking_discounts`.
  static const List<DiscountEntity> _promos = <DiscountEntity>[
    DiscountEntity(
        id: 'd1', code: 'VRPARTY', kind: DiscountKind.percent, value: 10, minStations: 2),
    DiscountEntity(
        id: 'd2', code: 'MINUS500', kind: DiscountKind.fixed, value: 500, minStations: 1),
  ];

  @override
  Future<DiscountEntity?> resolveDiscount({
    String? code,
    required int stationCount,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 150));
    final String c = (code ?? '').trim().toUpperCase();
    if (c.isEmpty) return null; // автоскидок в демо нет
    for (final DiscountEntity d in _promos) {
      if (d.code != c) continue;
      if (stationCount < d.minStations) throw DiscountMinStationsFailure(d.minStations);
      return d;
    }
    throw const DiscountNotFoundFailure();
  }

  @override
  Future<String> createReservation(ReservationRequestEntity request) async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    bool overlaps(ReservationSegmentEntity a, ReservationSegmentEntity b) =>
        a.startsAt.isBefore(b.endsAt) && b.startsAt.isBefore(a.endsAt);
    final bool clash = _created.any((ReservationRequestEntity r) => r.segments.any(
        (ReservationSegmentEntity rs) => request.segments.any(
            (ReservationSegmentEntity qs) =>
                overlaps(rs, qs) &&
                rs.stationIds.any(qs.stationIds.contains))));
    if (clash) throw const SlotAlreadyTakenFailure();
    _created.add(request);
    final String id =
        'mock-${DateTime.now().millisecondsSinceEpoch.toRadixString(16)}';
    _byId[id] = request;
    return id;
  }

  @override
  Future<void> cancelReservation({
    required String orderId,
    required String clientPhone,
  }) async {
    // Демо: снимаем бронь из in-memory списка, если телефон совпал по
    // последним 10 цифрам (как в booking_phone_key на сервере).
    String key(String p) {
      final String d = p.replaceAll(RegExp(r'[^0-9]'), '');
      return d.length <= 10 ? d : d.substring(d.length - 10);
    }

    await Future<void>.delayed(const Duration(milliseconds: 250));
    final ReservationRequestEntity? r = _byId[orderId];
    if (r == null || key(r.clientPhone) != key(clientPhone)) {
      throw const BookingOrderNotFoundFailure();
    }
    _byId.remove(orderId);
    _created.remove(r);
  }

  Future<T> _delay<T>(T value) =>
      Future<T>.delayed(const Duration(milliseconds: 220), () => value);

  static List<StationEntity> _room(
    String roomId,
    String roomName, {
    required int headsets,
    required int consoles,
    required int base,
    int perRow = 4,
  }) {
    final List<StationEntity> out = <StationEntity>[];
    // Как в БД: арена на 12 шлемов — две половины по 6, остальные залы — по 4.
    final int perRow = headsets >= 12 ? 6 : 4;
    for (int i = 0; i < headsets; i++) {
      out.add(StationEntity(
        id: '$roomId-vr${i + 1}',
        roomId: roomId,
        roomName: roomName,
        type: StationType.vrHeadset,
        label: '#${i + 1}',
        rowIndex: i ~/ perRow,
        positionInRow: i % perRow,
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
        rowIndex: (headsets / perRow).ceil(),
        positionInRow: i,
        sortOrder: base + headsets + i,
        isActive: true,
      ));
    }
    return out;
  }
}
