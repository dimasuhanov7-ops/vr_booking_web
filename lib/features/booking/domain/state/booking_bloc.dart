// Публичные именованные параметры конструктора BLoC сознательно оставлены
// не initializing formals — они часть публичного API фичи.
// ignore_for_file: prefer_initializing_formals

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../entity/booking_failure.dart';
import '../entity/busy_interval_entity.dart';
import '../entity/club_entity.dart';
import '../entity/hall_option_entity.dart';
import '../entity/price_rate_entity.dart';
import '../entity/quote_entity.dart';
import '../entity/reservation_request_entity.dart';
import '../entity/station_entity.dart';
import '../entity/time_slot_entity.dart';
import '../repository/i_booking_repository.dart';
import '../service/pricing_service.dart';
import '../service/slot_generator_service.dart';

part 'booking_event.dart';
part 'booking_state.dart';

/// Управляет сценарием бронирования (клуб → зал/дата/время → станции → контакты).
class BookingBloc extends Bloc<BookingEvent, BookingState> {
  /// Создаёт BLoC.
  BookingBloc({
    required IBookingRepository repository,
    SlotGeneratorService slotGenerator = const SlotGeneratorService(),
    PricingService pricingService = const PricingService(),
    String source = 'site',
  })  : _repository = repository,
        _slots = slotGenerator,
        _pricing = pricingService,
        _source = source,
        super(const BookingState()) {
    on<BookingStarted>(_onStarted);
    on<BookingClubSelected>(_onClubSelected);
    on<BookingHallSelected>(_onHallSelected);
    on<BookingDateSelected>(_onDateSelected);
    on<BookingDurationSelected>(_onDurationSelected);
    on<BookingSlotSelected>(_onSlotSelected);
    on<BookingStationToggled>(_onStationToggled);
    on<BookingQuickPicked>(_onQuickPicked);
    on<BookingSelectionCleared>(_onSelectionCleared);
    on<BookingContactChanged>(_onContactChanged);
    on<BookingAvailabilityRefreshed>(_onAvailabilityRefreshed);
    on<BookingSubmitted>(_onSubmitted);
    on<BookingConflictResolved>(_onConflictResolved);
    on<BookingConflictDismissed>(_onConflictDismissed);
    on<BookingResetRequested>(_onResetRequested);
  }

  final IBookingRepository _repository;
  final SlotGeneratorService _slots;
  final PricingService _pricing;
  final String _source;

  /// Допустимые длительности сеанса, минут.
  static const List<int> durations = <int>[60, 90, 120, 180];

  // ---------------------------------------------------------------------------

  Future<void> _onStarted(BookingStarted event, Emitter<BookingState> emit) async {
    emit(state.copyWith(status: BookingStatus.loading));
    try {
      final List<ClubEntity> clubs = await _repository.fetchClubs();
      emit(state.copyWith(status: BookingStatus.ready, clubs: clubs));
    } on BookingFailure catch (e) {
      emit(state.copyWith(status: BookingStatus.failure, errorMessage: e.message));
    }
  }

  Future<void> _onClubSelected(
    BookingClubSelected event,
    Emitter<BookingState> emit,
  ) async {
    final DateTime date = state.date ?? _today();
    emit(state.copyWith(
      status: BookingStatus.loading,
      club: event.club,
      date: date,
      hallOptions: const <HallOptionEntity>[],
      stations: const <StationEntity>[],
      pickedIds: const <String>{},
      takenIds: const <String>{},
      conflictShown: false,
      quote: QuoteEntity.empty,
      clearSlot: true,
    ));
    try {
      final List<StationEntity> stations =
          await _repository.fetchStations(event.club.id);
      final List<PriceRateEntity> prices =
          await _repository.fetchPrices(event.club.id);
      final List<HallOptionEntity> options = _buildHallOptions(stations);

      emit(state.copyWith(
        status: BookingStatus.ready,
        stations: stations,
        prices: prices,
        hallOptions: options,
      ));

      if (options.length == 1) {
        add(BookingHallSelected(options.first));
      }
    } on BookingFailure catch (e) {
      emit(state.copyWith(status: BookingStatus.failure, errorMessage: e.message));
    }
  }

  Future<void> _onHallSelected(
    BookingHallSelected event,
    Emitter<BookingState> emit,
  ) async {
    emit(state.copyWith(
      hall: event.hall,
      pickedIds: const <String>{},
      takenIds: const <String>{},
      conflictShown: false,
      quote: QuoteEntity.empty,
      clearSlot: true,
    ));
    await _reloadSchedule(emit);
  }

  Future<void> _onDateSelected(
    BookingDateSelected event,
    Emitter<BookingState> emit,
  ) async {
    emit(state.copyWith(
      date: event.date,
      pickedIds: const <String>{},
      takenIds: const <String>{},
      conflictShown: false,
      quote: QuoteEntity.empty,
      clearSlot: true,
    ));
    await _reloadSchedule(emit);
  }

  Future<void> _onDurationSelected(
    BookingDurationSelected event,
    Emitter<BookingState> emit,
  ) async {
    emit(state.copyWith(
      durationMinutes: event.minutes,
      pickedIds: const <String>{},
      takenIds: const <String>{},
      conflictShown: false,
      quote: QuoteEntity.empty,
      clearSlot: true,
    ));
    await _reloadSchedule(emit);
  }

  void _onSlotSelected(BookingSlotSelected event, Emitter<BookingState> emit) {
    emit(state.copyWith(
      slot: event.slot,
      pickedIds: const <String>{},
      takenIds: const <String>{},
      conflictShown: false,
      quote: QuoteEntity.empty,
    ));
  }

  void _onStationToggled(
    BookingStationToggled event,
    Emitter<BookingState> emit,
  ) {
    if (!state.isFree(event.stationId)) return;
    final Set<String> next = Set<String>.of(state.pickedIds);
    if (!next.remove(event.stationId)) next.add(event.stationId);
    emit(_withPicked(next));
  }

  void _onQuickPicked(BookingQuickPicked event, Emitter<BookingState> emit) {
    final List<String> free =
        state.freeHallStations.map((StationEntity s) => s.id).toList();
    final int n = event.count < 0 ? free.length : event.count.clamp(0, free.length);
    emit(_withPicked(free.take(n).toSet()));
  }

  void _onSelectionCleared(
    BookingSelectionCleared event,
    Emitter<BookingState> emit,
  ) {
    emit(_withPicked(const <String>{}));
  }

  void _onContactChanged(
    BookingContactChanged event,
    Emitter<BookingState> emit,
  ) {
    emit(state.copyWith(
      clientName: event.name ?? state.clientName,
      clientPhone: event.phone ?? state.clientPhone,
      peopleInput: event.people ?? state.peopleInput,
    ));
  }

  Future<void> _onAvailabilityRefreshed(
    BookingAvailabilityRefreshed event,
    Emitter<BookingState> emit,
  ) async {
    await _reloadSchedule(emit, keepSelection: true);
  }

  Future<void> _onSubmitted(
    BookingSubmitted event,
    Emitter<BookingState> emit,
  ) async {
    if (!state.canSubmit) return;
    final ClubEntity club = state.club!;
    final TimeSlotEntity slot = state.slot!;

    emit(state.copyWith(status: BookingStatus.submitting, conflictShown: false));
    try {
      final String orderId = await _repository.createReservation(
        ReservationRequestEntity(
          clubId: club.id,
          stationIds: state.pickedIds.toList(growable: false),
          startsAt: slot.startsAt,
          minutes: state.durationMinutes,
          clientName: state.clientName.trim(),
          clientPhone: state.clientPhone.trim(),
          peopleCount: int.tryParse(state.peopleInput.trim()),
          comment: null,
          source: _source,
        ),
      );
      emit(state.copyWith(
        status: BookingStatus.ready,
        view: BookingStage.done,
        createdOrderId: orderId,
      ));
    } on SlotAlreadyTakenFailure {
      await _handleConflict(emit);
    } on BookingFailure catch (e) {
      emit(state.copyWith(status: BookingStatus.ready, errorMessage: e.message));
    }
  }

  Future<void> _handleConflict(Emitter<BookingState> emit) async {
    try {
      final List<BusyIntervalEntity> busy = await _repository.fetchBusyIntervals(
        clubId: state.club!.id,
        day: state.date!,
      );
      final TimeSlotEntity slot = state.slot!;
      final Set<String> taken = state.pickedIds.where((String id) {
        return busy.any((BusyIntervalEntity b) =>
            b.stationId == id && b.overlaps(slot.startsAt, slot.endsAt));
      }).toSet();
      final Set<String> kept = Set<String>.of(state.pickedIds)..removeAll(taken);

      emit(state.copyWith(
        status: BookingStatus.ready,
        busy: busy,
        pickedIds: kept,
        takenIds: taken,
        conflictShown: taken.isNotEmpty,
        quote: _quoteFor(kept),
      ));
    } on BookingFailure catch (e) {
      emit(state.copyWith(status: BookingStatus.ready, errorMessage: e.message));
    }
  }

  void _onConflictResolved(
    BookingConflictResolved event,
    Emitter<BookingState> emit,
  ) {
    final StationEntity? alt = state.conflictAlternative;
    if (alt != null) {
      final Set<String> next = Set<String>.of(state.pickedIds)..add(alt.id);
      emit(_withPicked(next).copyWith(conflictShown: false, takenIds: const <String>{}));
      return;
    }
    if (state.pickedIds.isEmpty) {
      emit(state.copyWith(
        conflictShown: false,
        takenIds: const <String>{},
        pickedIds: const <String>{},
        quote: QuoteEntity.empty,
        clearSlot: true,
      ));
      return;
    }
    emit(state.copyWith(conflictShown: false, takenIds: const <String>{}));
  }

  void _onConflictDismissed(
    BookingConflictDismissed event,
    Emitter<BookingState> emit,
  ) {
    emit(state.copyWith(
      conflictShown: false,
      takenIds: const <String>{},
      pickedIds: const <String>{},
      quote: QuoteEntity.empty,
      clearSlot: true,
    ));
  }

  void _onResetRequested(
    BookingResetRequested event,
    Emitter<BookingState> emit,
  ) {
    emit(BookingState(status: BookingStatus.ready, clubs: state.clubs));
  }

  // ---------------------------------------------------------------------------

  Future<void> _reloadSchedule(
    Emitter<BookingState> emit, {
    bool keepSelection = false,
  }) async {
    final ClubEntity? club = state.club;
    final DateTime? date = state.date;
    if (club == null || date == null || state.hall == null) return;

    emit(state.copyWith(status: BookingStatus.loading));
    try {
      final List<BusyIntervalEntity> busy = await _repository.fetchBusyIntervals(
        clubId: club.id,
        day: date,
      );
      final List<TimeSlotEntity> slots = _slots.generateSlots(
        club: club,
        day: date,
        durationMinutes: state.durationMinutes,
      );

      TimeSlotEntity? keptSlot;
      Set<String> keptPicked = const <String>{};
      if (keepSelection && state.slot != null) {
        keptSlot = slots
            .where((TimeSlotEntity s) => s.startsAt == state.slot!.startsAt)
            .cast<TimeSlotEntity?>()
            .firstWhere((TimeSlotEntity? s) => true, orElse: () => null);
        if (keptSlot != null) {
          keptPicked = state.pickedIds.where((String id) {
            return !busy.any((BusyIntervalEntity b) =>
                b.stationId == id && b.overlaps(keptSlot!.startsAt, keptSlot.endsAt));
          }).toSet();
        }
      }

      emit(state.copyWith(
        status: BookingStatus.ready,
        busy: busy,
        slots: slots,
        slot: keptSlot,
        clearSlot: !keepSelection || keptSlot == null,
        pickedIds: keptPicked,
        quote: keptPicked.isEmpty ? QuoteEntity.empty : _quoteFor(keptPicked),
      ));
    } on BookingFailure catch (e) {
      emit(state.copyWith(status: BookingStatus.failure, errorMessage: e.message));
    }
  }

  BookingState _withPicked(Set<String> picked) {
    return state.copyWith(
      pickedIds: picked,
      conflictShown: false,
      takenIds: const <String>{},
      quote: picked.isEmpty ? QuoteEntity.empty : _quoteFor(picked),
    );
  }

  QuoteEntity _quoteFor(Set<String> pickedIds) {
    final ClubEntity? club = state.club;
    final TimeSlotEntity? slot = state.slot;
    if (club == null || slot == null || pickedIds.isEmpty) return QuoteEntity.empty;
    final List<StationEntity> picked = state.stations
        .where((StationEntity s) => pickedIds.contains(s.id))
        .toList(growable: false);
    return _pricing.quote(
      club: club,
      stations: picked,
      startsAtUtc: slot.startsAt,
      minutes: state.durationMinutes,
      rates: state.prices,
      showRoomInLabel: state.hall?.isCombo ?? false,
    );
  }

  List<HallOptionEntity> _buildHallOptions(List<StationEntity> stations) {
    final Map<String, List<StationEntity>> byRoom = <String, List<StationEntity>>{};
    for (final StationEntity s in stations) {
      byRoom.putIfAbsent(s.roomId, () => <StationEntity>[]).add(s);
    }
    // Порядок залов — по минимальному sortOrder станций (сид задаёт возрастание).
    final List<String> roomIds = byRoom.keys.toList()
      ..sort((String a, String b) => byRoom[a]!
          .map((StationEntity s) => s.sortOrder)
          .reduce((int x, int y) => x < y ? x : y)
          .compareTo(byRoom[b]!
              .map((StationEntity s) => s.sortOrder)
              .reduce((int x, int y) => x < y ? x : y)));

    int headsets(List<StationEntity> list) =>
        list.where((StationEntity s) => s.type == StationType.vrHeadset).length;
    int consoles(List<StationEntity> list) =>
        list.where((StationEntity s) => s.type == StationType.ps5).length;

    final List<HallOptionEntity> options = roomIds.map((String rid) {
      final List<StationEntity> list = byRoom[rid]!;
      return HallOptionEntity(
        id: rid,
        name: list.first.roomName,
        roomIds: <String>[rid],
        headsets: headsets(list),
        consoles: consoles(list),
      );
    }).toList();

    if (options.length > 1) {
      options.add(HallOptionEntity(
        id: 'combo',
        name: 'Весь клуб',
        roomIds: roomIds,
        headsets: headsets(stations),
        consoles: consoles(stations),
        isCombo: true,
      ));
    }
    return options;
  }

  DateTime _today() {
    final DateTime n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }
}
