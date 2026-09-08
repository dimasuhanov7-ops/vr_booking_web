// Публичные именованные параметры конструктора BLoC сознательно оставлены
// не initializing formals — они часть публичного API фичи.
// ignore_for_file: prefer_initializing_formals

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../entity/account_entity.dart';
import '../entity/booking_failure.dart';
import '../entity/busy_interval_entity.dart';
import '../entity/club_entity.dart';
import '../entity/hall_option_entity.dart';
import '../entity/package_entity.dart';
import '../entity/price_rate_entity.dart';
import '../entity/quote_entity.dart';
import '../entity/reservation_request_entity.dart';
import '../entity/station_entity.dart';
import '../entity/time_slot_entity.dart';
import '../repository/i_account_store.dart';
import '../repository/i_booking_repository.dart';
import '../service/club_clock.dart';
import '../service/pricing_service.dart';
import '../service/slot_generator_service.dart';

part 'booking_event.dart';
part 'booking_state.dart';

/// Управляет сценарием бронирования (клуб → зал/дата/время → станции → контакты).
class BookingBloc extends Bloc<BookingEvent, BookingState> {
  /// Создаёт BLoC.
  BookingBloc({
    required IBookingRepository repository,
    IAccountStore? accountStore,
    SlotGeneratorService slotGenerator = const SlotGeneratorService(),
    PricingService pricingService = const PricingService(),
    String source = 'site',
    String? lockedClubSlug,
    DateTime? initialDate,
    int? initialDurationMinutes,
  })  : _repository = repository,
        _account = accountStore,
        _slots = slotGenerator,
        _pricing = pricingService,
        _source = source,
        _lockedClubSlug = lockedClubSlug,
        _pendingDate = initialDate,
        _pendingDuration = initialDurationMinutes,
        super(const BookingState()) {
    on<BookingStarted>(_onStarted);
    on<BookingClubSelected>(_onClubSelected);
    on<BookingHallSelected>(_onHallSelected);
    on<BookingDateSelected>(_onDateSelected);
    on<BookingDurationSelected>(_onDurationSelected);
    on<BookingSlotSelected>(_onSlotSelected);
    on<BookingStationToggled>(_onStationToggled);
    on<BookingPackageSelected>(_onPackageSelected);
    on<BookingQuickPicked>(_onQuickPicked);
    on<BookingSelectionCleared>(_onSelectionCleared);
    on<BookingHourCopied>(_onHourCopied);
    on<BookingContactChanged>(_onContactChanged);
    on<BookingAvailabilityRefreshed>(_onAvailabilityRefreshed);
    on<BookingSubmitted>(_onSubmitted);
    on<BookingConflictResolved>(_onConflictResolved);
    on<BookingConflictDismissed>(_onConflictDismissed);
    on<BookingResetRequested>(_onResetRequested);
    on<BookingAccountLoginToggled>(_onAccountLoginToggled);
    on<BookingAccountLoginPhoneChanged>(_onAccountLoginPhoneChanged);
    on<BookingAccountLoginSubmitted>(_onAccountLoginSubmitted);
    on<BookingAccountLoggedOut>(_onAccountLoggedOut);
    on<BookingAccountListToggled>(_onAccountListToggled);
  }

  final IBookingRepository _repository;
  final IAccountStore? _account;
  final SlotGeneratorService _slots;
  final PricingService _pricing;
  final String _source;

  /// Slug клуба из `?club=` — селектор клуба скрыт, клуб выбирается сразу.
  final String? _lockedClubSlug;

  /// Предвыбор из `?date=` / `?duration=` — применяется один раз при выборе клуба.
  DateTime? _pendingDate;
  int? _pendingDuration;

  /// Допустимые длительности сеанса, минут.
  static const List<int> durations = <int>[60, 120, 180, 240, 300];

  // ---------------------------------------------------------------------------

  Future<void> _onStarted(BookingStarted event, Emitter<BookingState> emit) async {
    // Запомненный клиент и его брони с этого устройства.
    final AccountEntity? account = _account?.readAccount();
    final List<SavedBookingEntity> saved =
        _account?.readBookings() ?? const <SavedBookingEntity>[];
    if (account != null || saved.isNotEmpty) {
      emit(state.copyWith(
        account: account,
        savedBookings: saved,
        clientName: account?.name ?? state.clientName,
        clientPhone: account?.phone ?? state.clientPhone,
      ));
    }

    emit(state.copyWith(status: BookingStatus.loading));
    try {
      final List<ClubEntity> clubs = await _repository.fetchClubs();
      final ClubEntity? locked = _lockedClubSlug == null
          ? null
          : clubs
              .where((ClubEntity c) => c.slug == _lockedClubSlug)
              .cast<ClubEntity?>()
              .firstWhere((ClubEntity? c) => true, orElse: () => null);

      emit(state.copyWith(
        status: BookingStatus.ready,
        clubs: clubs,
        clubLocked: locked != null,
      ));

      if (locked != null) add(BookingClubSelected(locked));
    } on BookingFailure catch (e) {
      emit(state.copyWith(status: BookingStatus.failure, errorMessage: e.message));
    }
  }

  Future<void> _onClubSelected(
    BookingClubSelected event,
    Emitter<BookingState> emit,
  ) async {
    final DateTime date = _pendingDate ?? state.date ?? _today();
    final int duration = _pendingDuration ?? state.durationMinutes;
    _pendingDate = null;
    _pendingDuration = null;

    emit(state.copyWith(
      status: BookingStatus.loading,
      club: event.club,
      date: date,
      durationMinutes: duration,
      hallOptions: const <HallOptionEntity>[],
      stations: const <StationEntity>[],
      packages: const <PackageEntity>[],
      clearPicks: true,
      takenIds: const <String>{},
      conflictShown: false,
      quote: QuoteEntity.empty,
      clearSlot: true,
      clearHall: true,
      clearPackage: true,
    ));
    try {
      final List<StationEntity> stations =
          await _repository.fetchStations(event.club.id);
      final List<PriceRateEntity> prices =
          await _repository.fetchPrices(event.club.id);
      // Пакеты необязательны: если бэкенд их ещё не отдаёт — просто без пакетов.
      List<PackageEntity> packages = const <PackageEntity>[];
      try {
        packages = await _repository.fetchPackages(event.club.id);
      } on BookingFailure {
        packages = const <PackageEntity>[];
      }
      final List<HallOptionEntity> options = _buildHallOptions(stations);

      emit(state.copyWith(
        status: BookingStatus.ready,
        stations: stations,
        prices: prices,
        packages: packages,
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
      clearPicks: true,
      takenIds: const <String>{},
      conflictShown: false,
      quote: QuoteEntity.empty,
      clearSlot: true,
      clearPackage: true,
    ));
    await _reloadSchedule(emit);
  }

  Future<void> _onDateSelected(
    BookingDateSelected event,
    Emitter<BookingState> emit,
  ) async {
    emit(state.copyWith(
      date: event.date,
      clearPicks: true,
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
      clearPicks: true,
      takenIds: const <String>{},
      conflictShown: false,
      quote: QuoteEntity.empty,
      clearSlot: true,
      clearPackage: true,
    ));
    await _reloadSchedule(emit);
  }

  Future<void> _onPackageSelected(
    BookingPackageSelected event,
    Emitter<BookingState> emit,
  ) async {
    final PackageEntity? pkg = event.package;
    if (pkg == null || pkg.id == state.selectedPackageId) {
      emit(state.copyWith(
        clearPicks: true,
        takenIds: const <String>{},
        conflictShown: false,
        quote: QuoteEntity.empty,
        clearPackage: true,
      ));
      return;
    }

    // Длительность пакета может отличаться — пересобираем сетку слотов,
    // сохраняя момент старта.
    emit(state.copyWith(
      durationMinutes: pkg.minutes,
      selectedPackageId: pkg.id,
      clearPicks: true,
      takenIds: const <String>{},
      conflictShown: false,
      quote: QuoteEntity.empty,
    ));
    await _reloadSchedule(emit, keepSelection: true);
    if (state.slot == null) return;

    // Подбираем нужное число свободных станций по типам в текущем слоте.
    final List<StationEntity> free = state.freeHallStations;
    final List<String> vr = free
        .where((StationEntity s) => s.type != StationType.ps5)
        .take(pkg.headsets)
        .map((StationEntity s) => s.id)
        .toList();
    final List<String> ps = free
        .where((StationEntity s) => s.type == StationType.ps5)
        .take(pkg.consoles)
        .map((StationEntity s) => s.id)
        .toList();
    emit(_withHours(<int, Set<String>>{0: <String>{...vr, ...ps}}));
  }

  void _onSlotSelected(BookingSlotSelected event, Emitter<BookingState> emit) {
    emit(state.copyWith(
      slot: event.slot,
      clearPicks: true,
      takenIds: const <String>{},
      conflictShown: false,
      quote: QuoteEntity.empty,
    ));
  }

  void _onStationToggled(
    BookingStationToggled event,
    Emitter<BookingState> emit,
  ) {
    final int h = event.hour.clamp(0, state.hourCount - 1);
    final bool picked = state.pickedAt(h).contains(event.stationId);
    // Добавлять можно только свободную; убирать — всегда.
    if (!picked && !state.isFreeAt(h, event.stationId)) return;
    final Map<int, Set<String>> next = _cloneHours(state.pickedByHour);
    final Set<String> cur = Set<String>.of(state.pickedAt(h));
    if (!cur.remove(event.stationId)) cur.add(event.stationId);
    next[h] = cur;
    emit(_withHours(next));
  }

  void _onQuickPicked(BookingQuickPicked event, Emitter<BookingState> emit) {
    final int h = event.hour.clamp(0, state.hourCount - 1);
    final List<String> free =
        state.freeHallStationsAt(h).map((StationEntity s) => s.id).toList();
    final int n = event.count < 0 ? free.length : event.count.clamp(0, free.length);
    final Map<int, Set<String>> next = _cloneHours(state.pickedByHour);
    next[h] = free.take(n).toSet();
    emit(_withHours(next));
  }

  void _onSelectionCleared(
    BookingSelectionCleared event,
    Emitter<BookingState> emit,
  ) {
    if (event.hour == null) {
      emit(state.copyWith(
        clearPicks: true,
        takenIds: const <String>{},
        conflictShown: false,
        quote: QuoteEntity.empty,
      ));
      return;
    }
    final int h = event.hour!.clamp(0, state.hourCount - 1);
    final Map<int, Set<String>> next = _cloneHours(state.pickedByHour);
    next[h] = <String>{};
    emit(_withHours(next));
  }

  void _onHourCopied(BookingHourCopied event, Emitter<BookingState> emit) {
    final int to = event.to.clamp(0, state.hourCount - 1);
    final Map<int, Set<String>> next = _cloneHours(state.pickedByHour);
    next[to] = state
        .pickedAt(event.from)
        .where((String id) => state.isFreeAt(to, id))
        .toSet();
    emit(_withHours(next));
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
          segments: _segments(),
          startsAt: slot.startsAt,
          minutes: state.hourCount * 60,
          clientName: state.clientName.trim(),
          clientPhone: state.clientPhone.trim(),
          peopleCount: int.tryParse(state.peopleInput.trim()),
          comment: null,
          source: _source,
          packageId: state.packageApplies ? state.selectedPackageId : null,
        ),
      );
      _rememberBooking(orderId, club, slot);
      emit(state.copyWith(
        status: BookingStatus.ready,
        view: BookingStage.done,
        createdOrderId: orderId,
        account: _account != null
            ? AccountEntity(
                phone: state.clientPhone.trim(), name: state.clientName.trim())
            : null,
        savedBookings: _account?.readBookings(),
      ));
    } on SlotAlreadyTakenFailure {
      await _handleConflict(emit);
    } on BookingFailure catch (e) {
      emit(state.copyWith(status: BookingStatus.ready, errorMessage: e.message));
    }
  }

  /// Пишет клиента и бронь в локальное хранилище (`localStorage`).
  /// Не должно ронять бронь — любая ошибка форматирования/хранилища глотается.
  void _rememberBooking(String orderId, ClubEntity club, TimeSlotEntity slot) {
    final IAccountStore? store = _account;
    if (store == null) return;
    try {
      final String phone = state.clientPhone.trim();
      final String name = state.clientName.trim();
      store.writeAccount(AccountEntity(phone: phone, name: name));

      final int n = state.pickedIds.length;
      final DateTime from = ClubClock(club).toWall(slot.startsAt);
      final DateTime to = ClubClock(club).toWall(slot.endsAt);
      String two(int v) => v.toString().padLeft(2, '0');
      final String day = '${_dow(from.weekday)}, ${from.day} ${_mon(from.month)}';
      final String rub = _rubles(state.quote.net.round());

      store.addBooking(SavedBookingEntity(
        orderId: orderId,
        phone: phone,
        name: name,
        title: '${club.name} · ${state.hall?.name ?? ''}',
        meta: '$day · ${two(from.hour)}:${two(from.minute)}–'
            '${two(to.hour)}:${two(to.minute)} · $n ${_mest(n)}',
        total: '$rub ₽',
      ));
    } catch (_) {
      // локальная память броней — не критично
    }
  }

  static const List<String> _dowShort = <String>['пн', 'вт', 'ср', 'чт', 'пт', 'сб', 'вс'];
  static const List<String> _monShort = <String>[
    'янв', 'фев', 'мар', 'апр', 'мая', 'июн', 'июл', 'авг', 'сен', 'окт', 'ноя', 'дек'
  ];
  static String _dow(int weekday) => _dowShort[(weekday - 1) % 7];
  static String _mon(int month) => _monShort[(month - 1) % 12];

  static String _rubles(int v) {
    final String s = v.abs().toString();
    final StringBuffer out = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) out.write(' ');
      out.write(s[i]);
    }
    return out.toString();
  }

  static String _mest(int n) {
    final int m10 = n % 10;
    final int m100 = n % 100;
    if (m10 == 1 && m100 != 11) return 'место';
    if (m10 >= 2 && m10 <= 4 && (m100 < 12 || m100 > 14)) return 'места';
    return 'мест';
  }

  void _onAccountLoginToggled(
    BookingAccountLoginToggled event,
    Emitter<BookingState> emit,
  ) {
    emit(state.copyWith(accountLoginOpen: !state.accountLoginOpen));
  }

  void _onAccountLoginPhoneChanged(
    BookingAccountLoginPhoneChanged event,
    Emitter<BookingState> emit,
  ) {
    emit(state.copyWith(accountLoginPhone: event.phone));
  }

  void _onAccountLoginSubmitted(
    BookingAccountLoginSubmitted event,
    Emitter<BookingState> emit,
  ) {
    final String phone = state.accountLoginPhone.trim();
    if (phone.replaceAll(RegExp(r'[^0-9]'), '').length != 11) return;
    final IAccountStore? store = _account;
    final List<SavedBookingEntity> saved =
        store?.readBookings() ?? state.savedBookings;
    final List<SavedBookingEntity> mine =
        saved.where((SavedBookingEntity b) => b.phone == phone).toList();
    // Имя — из последней брони на этом номере, иначе текущее из формы.
    final String resolvedName =
        mine.isNotEmpty ? mine.last.name : state.clientName;
    final AccountEntity account =
        AccountEntity(phone: phone, name: resolvedName);
    store?.writeAccount(account);
    emit(state.copyWith(
      account: account,
      savedBookings: saved,
      clientName: resolvedName.isNotEmpty ? resolvedName : state.clientName,
      clientPhone: phone,
      accountLoginOpen: false,
      accountLoginPhone: '',
      accountListOpen: true,
    ));
  }

  void _onAccountLoggedOut(
    BookingAccountLoggedOut event,
    Emitter<BookingState> emit,
  ) {
    _account?.clearAccount();
    emit(state.copyWith(
      clearAccount: true,
      accountListOpen: false,
      accountLoginOpen: false,
    ));
  }

  void _onAccountListToggled(
    BookingAccountListToggled event,
    Emitter<BookingState> emit,
  ) {
    emit(state.copyWith(accountListOpen: !state.accountListOpen));
  }

  Future<void> _handleConflict(Emitter<BookingState> emit) async {
    try {
      final List<BusyIntervalEntity> busy = await _repository.fetchBusyIntervals(
        clubId: state.club!.id,
        day: state.date!,
      );
      // Пересобираем выбор по каждому часу, убирая ставшие занятыми станции.
      final BookingState probe = state.copyWith(busy: busy);
      final Set<String> taken = <String>{};
      final Map<int, Set<String>> kept = <int, Set<String>>{};
      for (int h = 0; h < state.hourCount; h++) {
        final Set<String> was = state.pickedAt(h);
        final Set<String> ok = <String>{};
        for (final String id in was) {
          if (probe.isFreeAt(h, id)) {
            ok.add(id);
          } else {
            taken.add(id);
          }
        }
        kept[h] = ok;
      }

      emit(state.copyWith(
        status: BookingStatus.ready,
        busy: busy,
        pickedByHour: kept,
        takenIds: taken,
        conflictShown: taken.isNotEmpty,
        quote: _quote(kept),
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
      final Map<int, Set<String>> next = _cloneHours(state.pickedByHour);
      for (int h = 0; h < state.hourCount; h++) {
        if (state.isFreeAt(h, alt.id)) {
          next[h] = <String>{...state.pickedAt(h), alt.id};
        }
      }
      emit(_withHours(next).copyWith(conflictShown: false, takenIds: const <String>{}));
      return;
    }
    if (state.pickedIds.isEmpty) {
      emit(state.copyWith(
        conflictShown: false,
        takenIds: const <String>{},
        clearPicks: true,
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
      clearPicks: true,
      quote: QuoteEntity.empty,
      clearSlot: true,
    ));
  }

  void _onResetRequested(
    BookingResetRequested event,
    Emitter<BookingState> emit,
  ) {
    final List<ClubEntity> clubs = state.clubs;
    final bool locked = state.clubLocked;
    final AccountEntity? account = state.account;
    emit(BookingState(
      status: BookingStatus.ready,
      clubs: clubs,
      clubLocked: locked,
      account: account,
      savedBookings: state.savedBookings,
      clientName: account?.name ?? '',
      clientPhone: account?.phone ?? '',
    ));
    if (locked && _lockedClubSlug != null) {
      final ClubEntity? match = clubs
          .where((ClubEntity c) => c.slug == _lockedClubSlug)
          .cast<ClubEntity?>()
          .firstWhere((ClubEntity? c) => true, orElse: () => null);
      if (match != null) add(BookingClubSelected(match));
    }
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
      Map<int, Set<String>> keptHours = const <int, Set<String>>{};
      if (keepSelection && state.slot != null) {
        keptSlot = slots
            .where((TimeSlotEntity s) => s.startsAt == state.slot!.startsAt)
            .cast<TimeSlotEntity?>()
            .firstWhere((TimeSlotEntity? s) => true, orElse: () => null);
        if (keptSlot != null) {
          final BookingState probe =
              state.copyWith(busy: busy, slot: keptSlot);
          keptHours = <int, Set<String>>{
            for (final MapEntry<int, Set<String>> e in state.pickedByHour.entries)
              e.key: e.value
                  .where((String id) =>
                      e.key < probe.hourCount && probe.isFreeAt(e.key, id))
                  .toSet(),
          };
        }
      }

      final bool clearPicks = keptHours.isEmpty;
      emit(state.copyWith(
        status: BookingStatus.ready,
        busy: busy,
        slots: slots,
        slot: keptSlot,
        clearSlot: !keepSelection || keptSlot == null,
        clearPicks: clearPicks,
        pickedByHour: clearPicks ? null : keptHours,
        quote: clearPicks ? QuoteEntity.empty : _quote(keptHours),
      ));
    } on BookingFailure catch (e) {
      emit(state.copyWith(status: BookingStatus.failure, errorMessage: e.message));
    }
  }

  /// Глубокая копия карты выбора по часам.
  static Map<int, Set<String>> _cloneHours(Map<int, Set<String>> src) =>
      <int, Set<String>>{
        for (final MapEntry<int, Set<String>> e in src.entries)
          e.key: Set<String>.of(e.value),
      };

  /// Отрезки брони: подряд идущие часы с одинаковым составом склеиваем в один.
  List<ReservationSegmentEntity> _segments() {
    final TimeSlotEntity slot = state.slot!;

    // Состав каждого часа (только свободные станции).
    final List<List<String>> perHour = <List<String>>[
      for (int h = 0; h < state.hourCount; h++)
        (state.pickedAt(h).where((String id) => state.isFreeAt(h, id)).toList()
          ..sort()),
    ];

    bool sameIds(List<String> a, List<String> b) =>
        a.length == b.length && a.every(b.contains);

    final List<ReservationSegmentEntity> out = <ReservationSegmentEntity>[];
    int runStart = 0;
    for (int h = 1; h <= perHour.length; h++) {
      final bool boundary = h == perHour.length || !sameIds(perHour[h - 1], perHour[h]);
      if (!boundary) continue;
      final List<String> ids = perHour[runStart];
      if (ids.isNotEmpty) {
        out.add(ReservationSegmentEntity(
          stationIds: ids,
          startsAt: slot.startsAt.add(Duration(minutes: runStart * 60)),
          endsAt: slot.startsAt.add(Duration(minutes: h * 60)),
        ));
      }
      runStart = h;
    }
    return out;
  }

  BookingState _withHours(Map<int, Set<String>> hours) {
    final bool empty = hours.values.every((Set<String> s) => s.isEmpty);
    return state.copyWith(
      pickedByHour: hours,
      conflictShown: false,
      takenIds: const <String>{},
      quote: empty ? QuoteEntity.empty : _quote(hours),
    );
  }

  QuoteEntity _quote(Map<int, Set<String>> hours) {
    final ClubEntity? club = state.club;
    final TimeSlotEntity? slot = state.slot;
    if (club == null || slot == null) return QuoteEntity.empty;

    final BookingState s = state.copyWith(pickedByHour: hours);
    final Set<String> all = s.pickedIds;
    if (all.isEmpty) return QuoteEntity.empty;

    final List<StationEntity> picked = s.stations
        .where((StationEntity st) => all.contains(st.id))
        .toList(growable: false);
    final QuoteEntity q = _pricing.quote(
      club: club,
      stations: picked,
      startsAtUtc: slot.startsAt,
      minutesOf: (StationEntity st) => 60 * s.stationHours(st.id),
      rates: state.prices,
      showRoomInLabel: state.hall?.isCombo ?? false,
    );

    // Пакет: одинаковый состав на весь сеанс и совпадение — фиксируем цену пакета.
    final PackageEntity? pkg = state.selectedPackage;
    if (pkg != null && state.durationMinutes == pkg.minutes && !s.hasHourOverrides) {
      final int vr =
          picked.where((StationEntity st) => st.type != StationType.ps5).length;
      final int ps =
          picked.where((StationEntity st) => st.type == StationType.ps5).length;
      if (vr == pkg.headsets && ps == pkg.consoles) {
        return QuoteEntity(
          lines: q.lines,
          gross: q.gross,
          netOverride: pkg.price,
          discountLabel: 'Пакет «${pkg.name}»',
        );
      }
    }
    return q;
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
