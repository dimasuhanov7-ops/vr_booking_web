// Публичные именованные параметры конструктора BLoC — часть публичного API фичи.
// ignore_for_file: prefer_initializing_formals

import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../../app/config/booking_config.dart';
import '../entity/admin_booking_request_entity.dart';
import '../entity/admin_club_entity.dart';
import '../entity/admin_failure.dart';
import '../entity/audit_entry_entity.dart';
import '../entity/availability_entity.dart';
import '../entity/booking_row_entity.dart';
import '../entity/hall_price_entity.dart';
import '../entity/package_entity.dart';
import '../entity/promo_entity.dart';
import '../repository/i_admin_repository.dart';

part 'admin_event.dart';
part 'admin_state.dart';

/// Управляет состоянием админки: клуб, вкладка, брони, цены, пакеты,
/// доступность, отмены.
///
/// Изменения уходят в [IAdminRepository]. Поля, которые набирают с клавиатуры
/// (цены, пакеты, контакты брони), сохраняются после паузы в наборе
/// ([saveDelay]) — иначе в БД улетало бы каждое промежуточное значение
/// («1», «12», «120» вместо «1200»), а ответы могли прийти не по порядку.
/// Брони периодически перечитываются ([autoRefresh]), чтобы сотрудник видел
/// новые онлайн-записи без перезапуска.
class AdminBloc extends Bloc<AdminEvent, AdminState> {
  /// Создаёт BLoC.
  AdminBloc({
    required IAdminRepository repository,
    this.autoRefresh = const Duration(minutes: 1),
    this.saveDelay = const Duration(milliseconds: 800),
  })  : _repository = repository,
        super(const AdminState()) {
    on<AdminStarted>(_onStarted);
    on<AdminRefreshRequested>(_onRefreshRequested);
    on<AdminAuditRequested>(_onAuditRequested);
    on<AdminClubChanged>(_onClubChanged);
    on<AdminTabChanged>(_onTabChanged);
    on<AdminVrTiersChanged>(_onVrTiersChanged);
    on<AdminPriceChanged>(_onPriceChanged);
    on<AdminPackageFieldChanged>(_onPackageFieldChanged);
    on<AdminPackageToggled>(_onPackageToggled);
    on<AdminPackageDeleted>(_onPackageDeleted);
    on<AdminNewPackageChanged>(_onNewPackageChanged);
    on<AdminNewPackageSubmitted>(_onNewPackageSubmitted);
    on<AdminPromoToggled>(_onPromoToggled);
    on<AdminPromoDeleted>(_onPromoDeleted);
    on<AdminNewPromoChanged>(_onNewPromoChanged);
    on<AdminNewPromoSubmitted>(_onNewPromoSubmitted);
    on<AdminIntakeToggled>(_onIntakeToggled);
    on<AdminHallClosureToggled>(_onHallClosureToggled);
    on<AdminAvailDayChanged>(_onAvailDayChanged);
    on<AdminSlotClosureToggled>(_onSlotClosureToggled);
    on<AdminDayClosureChanged>(_onDayClosureChanged);
    on<AdminFilterChanged>(_onFilterChanged);
    on<AdminRowCancelToggled>(_onRowCancelToggled);
    on<AdminRowOpened>(_onRowOpened);
    on<AdminRowClosed>(_onRowClosed);
    on<AdminRowEdited>(_onRowEdited);
    on<AdminVisitMarked>(_onVisitMarked);
    on<AdminSearchChanged>(_onSearchChanged);
    on<AdminSearchResultOpened>(_onSearchResultOpened);
    on<AdminRowRescheduled>(_onRowRescheduled);
    on<AdminNewBookingOpened>(_onNewBookingOpened);
    on<AdminNewBookingClosed>(_onNewBookingClosed);
    on<AdminNewBookingChanged>(_onNewBookingChanged);
    on<AdminNewBookingMonthChanged>(_onNewBookingMonthChanged);
    on<AdminNewBookingSubmitted>(_onNewBookingSubmitted);
    on<_AdminDeferredSave>(
      (_AdminDeferredSave event, Emitter<AdminState> emit) =>
          _persist(event.action, emit),
    );
  }

  final IAdminRepository _repository;

  /// Период автообновления броней и доступности; `null` — не обновлять.
  final Duration? autoRefresh;

  /// Пауза после последнего ввода, после которой поле сохраняется.
  final Duration saveDelay;

  Timer? _refreshTimer;

  /// Подписка на изменения в базе (Realtime) и склейка их пачек.
  StreamSubscription<void>? _changesSub;
  Timer? _changesDebounce;
  final Map<String, Timer> _saveTimers = <String, Timer>{};
  final Map<String, Future<void> Function()> _pendingSaves =
      <String, Future<void> Function()>{};

  @override
  Future<void> close() async {
    _refreshTimer?.cancel();
    _changesDebounce?.cancel();
    await _changesSub?.cancel();
    for (final Timer t in _saveTimers.values) {
      t.cancel();
    }
    // Экран закрыли сразу после ввода — набранное всё равно сохраняем.
    final List<Future<void> Function()> saves = _pendingSaves.values.toList();
    _saveTimers.clear();
    _pendingSaves.clear();
    for (final Future<void> Function() save in saves) {
      try {
        await save();
      } catch (_) {
        // Экрана уже нет — показать ошибку негде.
      }
    }
    return super.close();
  }

  /// Сохранить после паузы в наборе. Повторный вызов с тем же [key]
  /// откладывает сохранение и заменяет действие последним значением.
  void _saveLater(String key, Future<void> Function() action) {
    _saveTimers.remove(key)?.cancel();
    _pendingSaves[key] = action;
    _saveTimers[key] = Timer(saveDelay, () {
      _saveTimers.remove(key);
      final Future<void> Function()? save = _pendingSaves.remove(key);
      if (save != null && !isClosed) add(_AdminDeferredSave(save));
    });
  }

  /// Отменить отложенное сохранение (значение стало невалидным или объект удалён).
  void _dropSave(String key) {
    _saveTimers.remove(key)?.cancel();
    _pendingSaves.remove(key);
  }

  Future<void> _onStarted(AdminStarted event, Emitter<AdminState> emit) async {
    emit(state.copyWith(status: AdminStatus.loading, clearSaveError: true));
    final List<AdminClubEntity> clubs;
    final List<HallPriceEntity> prices;
    final List<PackageEntity> packages;
    final List<BookingRowEntity> rows;
    final AvailabilityEntity avail;
    try {
      clubs = await _repository.fetchClubs();
      prices = await _repository.fetchPrices();
      packages = await _repository.fetchPackages();
      rows = await _repository.fetchRows();
      avail = await _repository.fetchAvailability();
    } on AdminFailure catch (e) {
      emit(state.copyWith(status: AdminStatus.failure, saveError: e.message));
      return;
    } catch (_) {
      // Без этого при плохой связи экран навсегда оставался на крутилке.
      emit(state.copyWith(
        status: AdminStatus.failure,
        saveError: 'Не удалось загрузить данные. Проверьте интернет.',
      ));
      return;
    }

    // Промокоды — не повод не пустить в панель: без них просто пустой список.
    List<PromoEntity> promos = const <PromoEntity>[];
    try {
      promos = await _repository.fetchPromos();
    } catch (_) {}

    final bool hasClub = clubs.any((AdminClubEntity c) => c.id == state.clubId);
    final String clubId =
        hasClub ? state.clubId : (clubs.isEmpty ? state.clubId : clubs.first.id);
    final ({Set<String> halls, Set<String> slots}) closed = _closures(avail);

    emit(state.copyWith(
      status: AdminStatus.ready,
      scheduleEditable: _repository.canEditSchedule,
      clubId: hasClub ? null : (clubs.isEmpty ? null : clubs.first.id),
      clubs: clubs,
      prices: <String, HallPriceEntity>{
        for (final HallPriceEntity p in prices) p.hallId: p,
      },
      packages: packages,
      promos: promos,
      rows: rows,
      cancelledRowIds: <String>{
        for (final BookingRowEntity r in rows)
          if (r.isCancelled) r.id,
      },
      intakeOpen: !avail.pausedClubIds.contains(clubId),
      closedHallIds: closed.halls,
      closedSlotKeys: closed.slots,
      closures: avail.closures,
      pausedClubIds: avail.pausedClubIds,
      refreshedAt: DateTime.now(),
    ));

    final Duration? every = autoRefresh;
    if (every != null) {
      _refreshTimer?.cancel();
      _refreshTimer = Timer.periodic(every, (_) {
        if (!isClosed) add(const AdminRefreshRequested());
      });
    }

    // Брони с сайта, из другого телефона или менеджера и закрытия времени
    // приходят сразу, а не с минутным автообновлением. Одна бронь — это
    // несколько событий (заказ и его места): склеиваем их в одно обновление.
    _changesSub ??= _repository.watchChanges().listen((_) {
      _changesDebounce?.cancel();
      _changesDebounce = Timer(const Duration(milliseconds: 700), () {
        if (!isClosed) add(const AdminRefreshRequested());
      });
    });
  }

  /// Перечитать брони и доступность — цены и пакеты не трогаем, чтобы не
  /// перетереть то, что сотрудник как раз вводит.
  Future<void> _onRefreshRequested(
    AdminRefreshRequested event,
    Emitter<AdminState> emit,
  ) async {
    if (state.status != AdminStatus.ready || state.refreshing) return;
    emit(state.copyWith(refreshing: true));
    try {
      final List<BookingRowEntity> rows = await _repository.fetchRows();
      final AvailabilityEntity avail = await _repository.fetchAvailability();
      final ({Set<String> halls, Set<String> slots}) closed = _closures(avail);
      final String? open = state.openRowId;
      emit(state.copyWith(
        refreshing: false,
        refreshedAt: DateTime.now(),
        rows: rows,
        cancelledRowIds: <String>{
          for (final BookingRowEntity r in rows)
            if (r.isCancelled) r.id,
        },
        intakeOpen: !avail.pausedClubIds.contains(state.clubId),
        closedHallIds: closed.halls,
        closedSlotKeys: closed.slots,
      closures: avail.closures,
        pausedClubIds: avail.pausedClubIds,
        // Открытую карточку закрываем, только если брони больше нет.
        clearOpenRow:
            open != null && !rows.any((BookingRowEntity r) => r.id == open),
      ));
    } on AdminFailure catch (e) {
      emit(state.copyWith(refreshing: false, saveError: e.message));
    } catch (_) {
      emit(state.copyWith(
        refreshing: false,
        saveError: 'Не удалось обновить данные. Проверьте интернет.',
      ));
    }
  }

  /// Закрытия из БД: залы закрыты бессрочно, окна привязаны к дате и
  /// переводятся в ключи «клуб-день-минуты».
  static ({Set<String> halls, Set<String> slots}) _closures(
    AvailabilityEntity avail,
  ) {
    final DateTime today = _today();
    final Set<String> halls = <String>{};
    final Set<String> slots = <String>{};
    for (final ClosureEntity c in avail.closures) {
      if (c.isWholeHall) {
        halls.add(c.hallId!);
        continue;
      }
      if (c.day == null || c.fromMinutes == null) continue;
      final int dayIndex = DateTime(c.day!.year, c.day!.month, c.day!.day)
          .difference(today)
          .inDays;
      slots.add('${c.clubId}-$dayIndex-${c.fromMinutes}');
    }
    return (halls: halls, slots: slots);
  }

  /// Сегодня без времени — база для [AdminState.availDay] и индексов дней.
  static DateTime _today() {
    final DateTime n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  /// Оптимистичная запись: если провалилась — показываем ошибку в шапке вкладки.
  Future<void> _persist(
    Future<void> Function() action,
    Emitter<AdminState> emit, {
    bool refresh = false,
  }) async {
    try {
      await action();
      if (state.saveError != null || state.saveNotice != null) {
        emit(state.copyWith(clearSaveError: true, clearSaveNotice: true));
      }
      // Закрытия видны и на вкладке «Записи», а там они считаются по списку
      // из базы: перечитываем сразу, не дожидаясь события Realtime.
      if (refresh && !isClosed) add(const AdminRefreshRequested());
    } on AdminFailure catch (e) {
      // Репозиторий уже перевёл ошибку на язык сотрудника — в том числе
      // отличил протухшую сессию от обрыва связи.
      emit(state.copyWith(saveError: e.message));
    } catch (_) {
      emit(state.copyWith(saveError: 'Не удалось сохранить. Проверьте связь и права.'));
    }
  }

  void _onClubChanged(AdminClubChanged event, Emitter<AdminState> emit) {
    if (event.clubId == state.clubId) return;
    emit(state.copyWith(
      clubId: event.clubId,
      // Пауза приёма — свойство клуба, а не панели: показываем статус того,
      // на кого переключились.
      intakeOpen: !state.pausedClubIds.contains(event.clubId),
      availDayIndex: 0,
      filterDay: 0,
      filterHallId: '',
      filterType: AdminTypeFilter.all,
      newPackage: const NewPackageDraft(),
      clearOpenRow: true,
      clearNewBooking: true,
      clearNewBookingMonth: true,
    ));
  }

  void _onTabChanged(AdminTabChanged event, Emitter<AdminState> emit) {
    emit(state.copyWith(tab: event.tab, clearSaveNotice: true));
    // Журнал не держим живым: перечитываем при каждом открытии вкладки.
    if (event.tab == AdminTab.log) add(const AdminAuditRequested());
  }

  Future<void> _onAuditRequested(
    AdminAuditRequested event,
    Emitter<AdminState> emit,
  ) async {
    if (state.auditLoading) return;
    emit(state.copyWith(auditLoading: true, clearAuditError: true));
    try {
      final List<AuditEntryEntity> entries = await _repository.fetchAuditLog();
      emit(state.copyWith(auditEntries: entries, auditLoading: false));
    } on AdminFailure catch (e) {
      emit(state.copyWith(auditLoading: false, auditError: e.message));
    } catch (_) {
      emit(state.copyWith(
        auditLoading: false,
        auditError: 'Не удалось загрузить журнал. Проверьте связь.',
      ));
    }
  }

  void _onPriceChanged(AdminPriceChanged event, Emitter<AdminState> emit) {
    // Цены в БД — по клубу: правка распространяется на все залы клуба.
    final String clubId = state.clubId;
    final Map<String, HallPriceEntity> next =
        Map<String, HallPriceEntity>.of(state.prices);
    for (final AdminHallEntity h in state.club.halls) {
      next[h.id] = state.priceOf(h.id).withField(event.field, event.value);
    }
    emit(state.copyWith(prices: next));
    _saveLater(
      'price-$clubId-${event.field.name}',
      () => _repository.saveClubPrice(
        clubId: clubId,
        field: event.field,
        value: event.value,
      ),
    );
  }

  void _onVrTiersChanged(AdminVrTiersChanged event, Emitter<AdminState> emit) {
    final String clubId = state.clubId;
    final Map<String, HallPriceEntity> next =
        Map<String, HallPriceEntity>.of(state.prices);
    for (final AdminHallEntity h in state.club.halls) {
      next[h.id] = state.priceOf(h.id).withTiers(event.tiers);
    }
    emit(state.copyWith(prices: next));
    // Сохраняем уже упорядоченные ступени (withTiers убрал повторы и порог 1).
    final List<VrTierEntity> tiers = state.priceOf(state.club.halls.first.id).vrTiers;
    _saveLater(
      'price-$clubId-tiers',
      () => _repository.saveVrTiers(clubId: clubId, tiers: tiers),
    );
  }

  void _onPackageFieldChanged(
    AdminPackageFieldChanged event,
    Emitter<AdminState> emit,
  ) {
    PackageEntity? changed;
    emit(state.copyWith(
      packages: state.packages.map((PackageEntity p) {
        if (p.id != event.packageId) return p;
        return changed = p.withField(event.field, event.value);
      }).toList(growable: false),
    ));
    final PackageEntity? p = changed;
    if (p == null) return;
    // Невалидный пакет база не примет: не отправляем, карточка это покажет.
    if (packageProblem(p) != null) {
      _dropSave('pkg-${p.id}');
      return;
    }
    _saveLater('pkg-${p.id}', () => _repository.updatePackage(p));
  }

  /// Что не так с пакетом, или `null`, если его можно сохранить.
  String? packageProblem(PackageEntity p) {
    AdminHallEntity? hall;
    for (final AdminClubEntity c in state.clubs) {
      for (final AdminHallEntity h in c.halls) {
        if (h.id == p.hallId) hall = h;
      }
    }
    if (p.headsets + p.consoles < 1) return 'Нужно хотя бы одно устройство.';
    if (!AdminState.durations.contains(p.minutes)) {
      return 'Длительность — целыми часами, от 1 до 5.';
    }
    if (hall != null &&
        (p.headsets > hall.headsets || p.consoles > hall.consoles)) {
      return 'Не вмещается в «${hall.name}».';
    }
    return null;
  }

  Future<void> _onPackageToggled(
    AdminPackageToggled event,
    Emitter<AdminState> emit,
  ) async {
    PackageEntity? changed;
    emit(state.copyWith(
      packages: state.packages.map((PackageEntity p) {
        if (p.id != event.packageId) return p;
        return changed = p.copyWith(isEnabled: !p.isEnabled);
      }).toList(growable: false),
    ));
    final PackageEntity? p = changed;
    if (p == null) return;
    _dropSave('pkg-${p.id}');
    await _persist(() => _repository.updatePackage(p), emit);
  }

  Future<void> _onPackageDeleted(
    AdminPackageDeleted event,
    Emitter<AdminState> emit,
  ) async {
    _dropSave('pkg-${event.packageId}');
    final List<PackageEntity> before = state.packages;
    emit(state.copyWith(
      packages: before
          .where((PackageEntity p) => p.id != event.packageId)
          .toList(growable: false),
    ));
    bool? deleted;
    await _persist(() async {
      deleted = await _repository.deletePackage(event.packageId);
    }, emit);
    if (deleted == true) return;
    if (deleted == null) {
      // Запись не прошла (ошибку уже показал _persist) — пакет возвращаем.
      emit(state.copyWith(packages: before));
      return;
    }
    // По пакету уже есть брони — сервер его выключил, а не удалил: возвращаем
    // в список выключенным, чтобы сотрудник видел, что произошло.
    emit(state.copyWith(
      packages: before
          .map((PackageEntity p) =>
              p.id == event.packageId ? p.copyWith(isEnabled: false) : p)
          .toList(growable: false),
      saveNotice: 'Пакет уже бронировали, поэтому он выключен, а не удалён: '
          'в виджете его больше нет, старые брони его сохраняют.',
    ));
  }

  void _onNewPackageChanged(
    AdminNewPackageChanged event,
    Emitter<AdminState> emit,
  ) {
    emit(state.copyWith(
      newPackage: state.newPackage.copyWith(
        name: event.name,
        hallId: event.hallId,
        headsets: event.headsets,
        consoles: event.consoles,
        minutes: event.minutes,
        price: event.price,
        message: '',
      ),
    ));
  }

  Future<void> _onNewPackageSubmitted(
    AdminNewPackageSubmitted event,
    Emitter<AdminState> emit,
  ) async {
    final NewPackageDraft d = state.newPackage;
    final String? hallId = state.newPackageHallId;
    if (hallId == null) return;
    final AdminHallEntity hall =
        state.clubHalls.firstWhere((AdminHallEntity h) => h.id == hallId);
    final String name = d.name.trim();

    String? error;
    if (name.length < 2) {
      error = 'Название от двух символов.';
    } else if (state.clubPackages.any(
        (PackageEntity p) => p.name.trim().toLowerCase() == name.toLowerCase())) {
      error = 'Пакет «$name» уже есть — выберите другое название.';
    } else if (d.headsets + d.consoles < 1) {
      error = 'Укажите хотя бы одно устройство — шлем или PS5.';
    } else if (d.headsets > hall.headsets) {
      error = 'В «${hall.name}» только ${_plural(hall.headsets, 'шлем', 'шлема', 'шлемов')}.';
    } else if (d.consoles > hall.consoles) {
      error = hall.consoles > 0
          ? 'В «${hall.name}» только ${hall.consoles} PS5.'
          : 'В «${hall.name}» нет PS5.';
    } else if (!AdminState.durations.contains(d.minutes)) {
      error = 'Длительность — целыми часами, от 1 до 5.';
    }

    if (error != null) {
      emit(state.copyWith(newPackage: d.copyWith(message: error)));
      return;
    }

    final PackageEntity draft = PackageEntity(
      id: 'new',
      clubId: state.clubId,
      hallId: hallId,
      name: name,
      headsets: d.headsets,
      consoles: d.consoles,
      minutes: d.minutes,
      price: d.price,
      isEnabled: true,
    );
    final String id;
    try {
      id = await _repository.createPackage(draft);
    } on AdminFailure catch (e) {
      emit(state.copyWith(newPackage: d.copyWith(message: e.message)));
      return;
    } catch (_) {
      emit(state.copyWith(
        newPackage: d.copyWith(
            message: 'Не удалось сохранить пакет. Проверьте связь и права.'),
      ));
      return;
    }
    final PackageEntity created = PackageEntity(
      id: id,
      clubId: draft.clubId,
      hallId: draft.hallId,
      name: draft.name,
      headsets: draft.headsets,
      consoles: draft.consoles,
      minutes: draft.minutes,
      price: draft.price,
      isEnabled: true,
    );
    emit(state.copyWith(
      packages: <PackageEntity>[...state.packages, created],
      newPackage: NewPackageDraft(
        hallId: hallId,
        message: 'Пакет «${created.name}» добавлен в «${hall.name}».',
      ),
    ));
  }

  Future<void> _onPromoToggled(
    AdminPromoToggled event,
    Emitter<AdminState> emit,
  ) async {
    final List<PromoEntity> before = state.promos;
    PromoEntity? changed;
    emit(state.copyWith(
      promos: before.map((PromoEntity p) {
        if (p.id != event.promoId) return p;
        return changed = p.copyWith(isActive: !p.isActive);
      }).toList(growable: false),
    ));
    if (changed == null) return;
    bool ok = false;
    await _persist(() async {
      await _repository.setPromoActive(changed!.id, active: changed!.isActive);
      ok = true;
    }, emit);
    if (!ok) emit(state.copyWith(promos: before));
  }

  Future<void> _onPromoDeleted(
    AdminPromoDeleted event,
    Emitter<AdminState> emit,
  ) async {
    final List<PromoEntity> before = state.promos;
    emit(state.copyWith(
      promos: before
          .where((PromoEntity p) => p.id != event.promoId)
          .toList(growable: false),
    ));
    bool? deleted;
    await _persist(() async {
      deleted = await _repository.deletePromo(event.promoId);
    }, emit);
    if (deleted == true) return;
    if (deleted == null) {
      emit(state.copyWith(promos: before));
      return;
    }
    emit(state.copyWith(
      promos: before
          .map((PromoEntity p) =>
              p.id == event.promoId ? p.copyWith(isActive: false) : p)
          .toList(growable: false),
      saveNotice: 'По промокоду уже есть брони, поэтому он выключен, а не '
          'удалён: клиенты его больше не применят, старые брони сохранят скидку.',
    ));
  }

  void _onNewPromoChanged(AdminNewPromoChanged event, Emitter<AdminState> emit) {
    emit(state.copyWith(
      newPromo: state.newPromo.copyWith(
        code: event.code,
        kind: event.kind,
        value: event.value,
        minStations: event.minStations,
        message: '',
        isError: false,
      ),
    ));
  }

  /// Буквы (латиница, кириллица), цифры, дефис и подчёркивание.
  static final RegExp _promoCodeChars = RegExp(r'^[A-ZА-ЯЁ0-9_-]+$');

  Future<void> _onNewPromoSubmitted(
    AdminNewPromoSubmitted event,
    Emitter<AdminState> emit,
  ) async {
    final NewPromoDraft d = state.newPromo;
    if (d.submitting) return;
    final String code = d.normalizedCode;

    String? error;
    if (code.length < 3 || code.length > 32) {
      error = 'Код — от 3 до 32 символов.';
    } else if (!_promoCodeChars.hasMatch(code)) {
      error = 'В коде только буквы, цифры, «-» и «_», без пробелов.';
    } else if (state.promos.any((PromoEntity p) => p.code.toUpperCase() == code)) {
      error = 'Промокод $code уже есть.';
    } else if (d.kind == PromoKind.percent && (d.value < 1 || d.value > 100)) {
      error = 'Процент — от 1 до 100.';
    } else if (d.value < 1) {
      error = 'Укажите сумму скидки.';
    } else if (d.minStations < 1) {
      error = 'Минимум — одно место.';
    }
    if (error != null) {
      emit(state.copyWith(newPromo: d.copyWith(message: error, isError: true)));
      return;
    }

    emit(state.copyWith(newPromo: d.copyWith(submitting: true, message: '')));
    final PromoEntity draft = PromoEntity(
      id: 'new',
      code: code,
      kind: d.kind,
      value: d.value,
      minStations: d.minStations,
    );
    final String id;
    try {
      id = await _repository.createPromo(draft);
    } on AdminFailure catch (e) {
      emit(state.copyWith(
        newPromo: d.copyWith(message: e.message, isError: true, submitting: false),
      ));
      return;
    } catch (_) {
      emit(state.copyWith(
        newPromo: d.copyWith(
          message: 'Не удалось сохранить промокод. Проверьте связь и права.',
          isError: true,
          submitting: false,
        ),
      ));
      return;
    }
    final PromoEntity created = PromoEntity(
      id: id,
      code: code,
      kind: draft.kind,
      value: draft.value,
      minStations: draft.minStations,
    );
    emit(state.copyWith(
      promos: <PromoEntity>[...state.promos, created]
        ..sort((PromoEntity a, PromoEntity b) => a.code.compareTo(b.code)),
      newPromo: NewPromoDraft(
        kind: d.kind,
        value: d.value,
        message: 'Промокод $code (${created.effectLabel}) добавлен — '
            'клиенты могут вводить его в виджете.',
      ),
    ));
  }

  Future<void> _onIntakeToggled(
    AdminIntakeToggled event,
    Emitter<AdminState> emit,
  ) async {
    final bool open = !state.intakeOpen;
    final String clubId = state.clubId;
    emit(state.copyWith(
      intakeOpen: open,
      pausedClubIds: open
          ? (Set<String>.of(state.pausedClubIds)..remove(clubId))
          : <String>{...state.pausedClubIds, clubId},
    ));
    await _persist(
      () => _repository.setIntakeOpen(clubId, open: open),
      emit,
    );
  }

  Future<void> _onHallClosureToggled(
    AdminHallClosureToggled event,
    Emitter<AdminState> emit,
  ) async {
    final Set<String> next = Set<String>.of(state.closedHallIds);
    final bool closed = !next.remove(event.hallId);
    if (closed) next.add(event.hallId);
    emit(state.copyWith(closedHallIds: next));
    await _persist(
      () => _repository.setHallClosed(
        clubId: state.clubId,
        hallId: event.hallId,
        closed: closed,
      ),
      emit,
      refresh: true,
    );
  }

  void _onAvailDayChanged(AdminAvailDayChanged event, Emitter<AdminState> emit) =>
      emit(state.copyWith(availDayIndex: event.dayIndex));

  Future<void> _onSlotClosureToggled(
    AdminSlotClosureToggled event,
    Emitter<AdminState> emit,
  ) async {
    final String key = state.slotKey(event.startMinutes);
    final Set<String> next = Set<String>.of(state.closedSlotKeys);
    final bool closed = !next.remove(key);
    if (closed) next.add(key);
    emit(state.copyWith(closedSlotKeys: next));
    await _persist(
      () => _repository.setSlotClosed(
        clubId: state.clubId,
        day: state.availDay,
        startMinutes: event.startMinutes,
        closed: closed,
      ),
      emit,
      refresh: true,
    );
  }

  Future<void> _onDayClosureChanged(
    AdminDayClosureChanged event,
    Emitter<AdminState> emit,
  ) async {
    final List<int> starts = state.slotStarts;
    final Set<String> keys = starts.map(state.slotKey).toSet();
    final Set<String> was = state.closedSlotKeys;
    final Set<String> next = Set<String>.of(was)..removeAll(keys);
    if (event.closeAll) next.addAll(keys);
    emit(state.copyWith(closedSlotKeys: next));

    // Пишем только фактические изменения: закрыть весь день, где половина
    // слотов уже закрыта, не должно порождать дублей в booking_availability.
    final DateTime day = state.availDay;
    await _persist(() async {
      for (final int m in starts) {
        final bool before = was.contains(state.slotKey(m));
        if (before == event.closeAll) continue;
        await _repository.setSlotClosed(
          clubId: state.clubId,
          day: day,
          startMinutes: m,
          closed: event.closeAll,
        );
      }
    }, emit, refresh: true);
  }

  void _onFilterChanged(AdminFilterChanged event, Emitter<AdminState> emit) {
    emit(state.copyWith(
      filterDay: event.day,
      filterHallId: event.hallId,
      filterType: event.type,
    ));
  }

  Future<void> _onRowCancelToggled(
    AdminRowCancelToggled event,
    Emitter<AdminState> emit,
  ) async {
    // Бронь на несколько залов — несколько строк одного заказа: отменяем и
    // возвращаем их вместе, в базе это одна запись.
    final String orderId = state.rowById(event.rowId)?.orderId ?? event.rowId;
    final Set<String> ids = <String>{
      for (final BookingRowEntity r in state.rows)
        if (r.orderId == orderId) r.id,
      event.rowId,
    };
    final bool cancel = !state.cancelledRowIds.contains(event.rowId);
    final Set<String> next = Set<String>.of(state.cancelledRowIds);
    if (cancel) {
      next.addAll(ids);
    } else {
      next.removeAll(ids);
    }
    emit(state.copyWith(cancelledRowIds: next));
    await _persist(
      () => _repository.setOrderCancelled(orderId, cancelled: cancel),
      emit,
    );
  }

  // -- карточка брони -----------------------------------------------------

  void _onRowOpened(AdminRowOpened event, Emitter<AdminState> emit) =>
      emit(state.copyWith(openRowId: event.rowId));

  void _onRowClosed(AdminRowClosed event, Emitter<AdminState> emit) =>
      emit(state.copyWith(clearOpenRow: true));

  void _onSearchChanged(AdminSearchChanged event, Emitter<AdminState> emit) =>
      emit(state.copyWith(searchQuery: event.query));

  void _onSearchResultOpened(
    AdminSearchResultOpened event,
    Emitter<AdminState> emit,
  ) {
    final BookingRowEntity? row = state.rowById(event.rowId);
    if (row == null) return;
    // Бронь могла найтись в другом клубе — переключаемся на него и на её день
    // (прошедший день сетка не показывает, карточка откроется всё равно).
    emit(state.copyWith(
      clubId: row.clubId,
      intakeOpen: !state.pausedClubIds.contains(row.clubId),
      filterDay: row.dayIndex >= 0 ? row.dayIndex : state.filterDay,
      openRowId: row.id,
      searchQuery: '',
      clearNewBooking: true,
      clearNewBookingMonth: true,
    ));
  }

  /// Контакты, комментарий и предоплата брони — сразу в журнал (во все строки
  /// заказа) и после паузы в наборе — в БД.
  void _onRowEdited(AdminRowEdited event, Emitter<AdminState> emit) {
    final BookingRowEntity? base = state.rowById(event.rowId);
    if (base == null) return;
    final String orderId = base.orderId;
    final List<BookingRowEntity> next = <BookingRowEntity>[
      for (final BookingRowEntity r in state.rows)
        r.orderId == orderId
            ? r.copyWith(
                clientName: event.clientName,
                phone: event.phone,
                prepay: event.prepay,
                note: event.note,
              )
            : r,
    ];
    emit(state.copyWith(rows: next));

    final BookingRowEntity edited =
        next.firstWhere((BookingRowEntity r) => r.id == event.rowId);
    final String name = edited.clientName.trim();
    final String phone = edited.phone.trim();
    // Такое база не примет (имя от 2 символов, телефон от 5): не отправляем,
    // карточка подсказывает, что поправить.
    if (name.length < 2 || (phone.isNotEmpty && phone.length < 5)) {
      _dropSave('order-$orderId');
      return;
    }
    _saveLater(
      'order-$orderId',
      () => _repository.updateOrderDetails(
        orderId: orderId,
        clientName: name,
        phone: phone,
        note: edited.note,
        prepay: edited.prepay,
      ),
    );
  }

  /// Визит отмечается у заказа целиком: у брони в нескольких залах строка на
  /// каждый зал, и «пришёл» относится ко всем сразу.
  Future<void> _onVisitMarked(
    AdminVisitMarked event,
    Emitter<AdminState> emit,
  ) async {
    final BookingRowEntity? base = state.rowById(event.rowId);
    if (base == null || state.isCancelled(base.id) || base.status == event.status) {
      return;
    }
    final String orderId = base.orderId;
    List<BookingRowEntity> withStatus(RecordStatus s) => state.rows
        .map((BookingRowEntity r) => r.orderId == orderId ? r.copyWith(status: s) : r)
        .toList(growable: false);

    emit(state.copyWith(rows: withStatus(event.status)));
    bool saved = false;
    await _persist(() async {
      await _repository.setOrderVisit(orderId, status: event.status);
      saved = true;
    }, emit);
    if (!saved) emit(state.copyWith(rows: withStatus(base.status)));
  }

  /// Перенос брони / смена состава (`booking_reschedule_order`).
  ///
  /// Бронь в нескольких залах так не переносится: функция заменяет все места
  /// заказа отрезками одного зала, и места во втором зале пропали бы молча.
  Future<void> _onRowRescheduled(
    AdminRowRescheduled event,
    Emitter<AdminState> emit,
  ) async {
    final BookingRowEntity? base = state.rowById(event.rowId);
    if (base == null) return;
    if (state.rows.where((BookingRowEntity r) => r.orderId == base.orderId).length > 1) {
      emit(state.copyWith(
        saveError: 'Бронь в нескольких залах так не переносится: отмените её и '
            'создайте новую запись.',
      ));
      return;
    }
    if (event.headsetsByHour.every((int v) => v == 0) &&
        event.consolesByHour.every((int v) => v == 0)) {
      emit(state.copyWith(saveError: 'Нужно хотя бы одно устройство.'));
      return;
    }
    bool saved = false;
    await _persist(() async {
      await _repository.rescheduleOrder(
        orderId: base.orderId,
        clubId: base.clubId,
        hallId: base.hallId,
        day: _today().add(Duration(days: event.dayIndex)),
        startMinutes: event.startMinutes,
        headsetsByHour: event.headsetsByHour,
        consolesByHour: event.consolesByHour,
      );
      saved = true;
    }, emit);
    // Время и состав знает только сервер (места подбирает он) — перечитываем.
    if (saved && !isClosed) add(const AdminRefreshRequested());
  }

  // -- новая запись ------------------------------------------------------

  void _onNewBookingOpened(AdminNewBookingOpened event, Emitter<AdminState> emit) {
    final List<AdminHallEntity> halls = state.clubHalls;
    if (halls.isEmpty) return;
    // На сегодня сеансы могли закончиться — тогда сразу предлагаем завтра.
    int day = 0;
    List<int> starts = state.sessionStarts(0, 60);
    if (starts.isEmpty) {
      day = 1;
      starts = state.sessionStarts(1, 60);
    }
    final int start = starts.isEmpty ? state.club.openMinutes : starts.first;
    final FreeUnits free = state.freeUnits(
      hallId: halls.first.id,
      dayIndex: day,
      startMinutes: start,
      durationMinutes: 60,
    );
    emit(state.copyWith(
      newBooking: NewBookingDraft(
        dayIndex: day,
        startMinutes: start,
        units: <String, HallUnits>{
          halls.first.id: (headsets: 2.clamp(0, free.headsets), consoles: 0),
        },
      ),
      clearNewBookingMonth: true,
    ));
  }

  void _onNewBookingClosed(AdminNewBookingClosed event, Emitter<AdminState> emit) =>
      emit(state.copyWith(clearNewBooking: true, clearNewBookingMonth: true));

  void _onNewBookingChanged(
    AdminNewBookingChanged event,
    Emitter<AdminState> emit,
  ) {
    final NewBookingDraft? current = state.newBooking;
    if (current == null || current.saving) return;
    final int h = event.hour;

    NewBookingDraft next = current.copyWith(
      dayIndex: event.dayIndex,
      startMinutes: event.startMinutes,
      durationMinutes: event.durationMinutes,
      name: event.name,
      phone: event.phone,
      prepay: event.prepay,
      note: event.note,
      message: '',
    );

    // Смена длительности/дня/времени — сбрасываем переопределения по часам.
    if (event.durationMinutes != null ||
        event.dayIndex != null ||
        event.startMinutes != null) {
      next = next.copyWith(clearHourly: true);
    }

    // Состав зала в часе [h]. Зал не указан — первый зал клуба.
    if (event.headsets != null || event.consoles != null) {
      final String hallId = event.hallId ??
          (state.clubHalls.isEmpty ? '' : state.clubHalls.first.id);
      final HallUnits cur = next.unitsAt(hallId, h);
      final HallUnits upd = (
        headsets: event.headsets ?? cur.headsets,
        consoles: event.consoles ?? cur.consoles,
      );
      next = h == 0
          ? next.copyWith(units: <String, HallUnits>{...next.units, hallId: upd})
          : next.copyWith(hourUnits: <int, Map<String, HallUnits>>{
              ...next.hourUnits,
              h: <String, HallUnits>{...?next.hourUnits[h], hallId: upd},
            });
    }

    // «Как в 1-м часе» — весь состав первого часа, по всем залам.
    final int? copyTo = event.copyHourFromFirst;
    if (copyTo != null && copyTo > 0) {
      next = next.copyWith(hourUnits: <int, Map<String, HallUnits>>{
        ...next.hourUnits,
        copyTo: <String, HallUnits>{
          for (final String id in next.hallIds) id: next.unitsAt(id, 0),
        },
      });
    }

    // Только реальные начала сеансов: в рабочих часах и, на сегодня, ещё не
    // начавшиеся — прошедшее время база всё равно отклонит.
    final List<int> starts =
        state.sessionStarts(next.dayIndex, next.durationMinutes);
    if (starts.isNotEmpty && !starts.contains(next.startMinutes)) {
      final int cur = next.startMinutes;
      next = next.copyWith(
        startMinutes:
            starts.firstWhere((int t) => t >= cur, orElse: () => starts.last),
      );
    }

    // Клампим состав каждого зала в каждом часе по свободной ёмкости.
    for (int hh = 0; hh < next.hourCount; hh++) {
      for (final AdminHallEntity hall in state.clubHalls) {
        final HallUnits cur = next.unitsAt(hall.id, hh);
        if (cur.headsets + cur.consoles == 0) continue;
        final FreeUnits free = state.freeUnits(
          hallId: hall.id,
          dayIndex: next.dayIndex,
          startMinutes: next.startMinutes + hh * 60,
          durationMinutes: 60,
        );
        final HallUnits clamped = (
          headsets: cur.headsets.clamp(0, free.headsets),
          consoles: cur.consoles.clamp(0, free.consoles),
        );
        if (clamped == cur) continue;
        next = hh == 0
            ? next.copyWith(
                units: <String, HallUnits>{...next.units, hall.id: clamped})
            : next.copyWith(hourUnits: <int, Map<String, HallUnits>>{
                ...next.hourUnits,
                hh: <String, HallUnits>{...?next.hourUnits[hh], hall.id: clamped},
              });
      }
    }
    emit(state.copyWith(newBooking: next));
  }

  void _onNewBookingMonthChanged(
    AdminNewBookingMonthChanged event,
    Emitter<AdminState> emit,
  ) =>
      emit(state.copyWith(newBookingMonth: DateTime(event.month.year, event.month.month)));

  /// Создание брони сотрудником — в одном или нескольких залах.
  ///
  /// Сохраняется в БД (`booking_create_order`, источник `staff`), конкретные
  /// станции подбирает репозиторий. В журнал бронь попадает строкой на каждый
  /// зал — так же, как её разберёт `BookingRowDto` при следующей загрузке.
  Future<void> _onNewBookingSubmitted(
    AdminNewBookingSubmitted event,
    Emitter<AdminState> emit,
  ) async {
    final NewBookingDraft? d = state.newBooking;
    if (d == null || d.saving) return;

    String? error;
    final String phone = d.phone.trim();
    if (d.name.trim().length < 2) {
      error = 'Укажите имя гостя.';
    } else if (phone.isNotEmpty && phone.length < 5) {
      // В БД телефон не короче 5 символов; пустой — «не указан».
      error = 'Проверьте телефон — в нём слишком мало цифр.';
    } else if (!state
        .sessionStarts(d.dayIndex, d.durationMinutes)
        .contains(d.startMinutes)) {
      error = 'Это время уже прошло — выберите другое начало или день.';
    } else {
      bool anyStation = false;
      hours:
      for (int h = 0; h < d.hourCount; h++) {
        for (final AdminHallEntity hall in state.clubHalls) {
          final HallUnits u = d.unitsAt(hall.id, h);
          if (u.headsets + u.consoles == 0) continue;
          anyStation = true;
          final FreeUnits free = state.freeUnits(
            hallId: hall.id,
            dayIndex: d.dayIndex,
            startMinutes: d.startMinutes + h * 60,
            durationMinutes: 60,
          );
          if (u.headsets > free.headsets || u.consoles > free.consoles) {
            error = '${h + 1}-й час, ${hall.name}: свободно '
                '${free.headsets} шлемов и ${free.consoles} PS5.';
            break hours;
          }
        }
      }
      if (error == null && !anyStation) {
        error = 'Добавьте хотя бы один шлем или одну PS5.';
      }
    }
    if (error != null) {
      emit(state.copyWith(newBooking: d.copyWith(message: error)));
      return;
    }

    final List<Map<String, HallUnits>> hours = <Map<String, HallUnits>>[
      for (int h = 0; h < d.hourCount; h++)
        <String, HallUnits>{
          for (final AdminHallEntity hall in state.clubHalls)
            if (d.unitsAt(hall.id, h).headsets + d.unitsAt(hall.id, h).consoles > 0)
              hall.id: d.unitsAt(hall.id, h),
        },
    ];

    emit(state.copyWith(newBooking: d.copyWith(saving: true, message: '')));
    final String orderId;
    try {
      orderId = await _repository.createBooking(AdminBookingRequest(
        clubId: state.clubId,
        day: _today().add(Duration(days: d.dayIndex)),
        startMinutes: d.startMinutes,
        hours: hours,
        clientName: d.name.trim(),
        phone: phone,
        note: d.note.trim(),
        prepay: d.prepay,
      ));
    } on AdminFailure catch (e) {
      _failNewBooking(e.message, emit);
      return;
    } catch (_) {
      _failNewBooking('Не удалось сохранить бронь. Проверьте связь.', emit);
      return;
    }

    final List<AdminHallEntity> used = state.clubHalls
        .where((AdminHallEntity hall) =>
            hours.any((Map<String, HallUnits> m) => m.containsKey(hall.id)))
        .toList();
    final bool split = used.length > 1;
    final List<BookingRowEntity> created = <BookingRowEntity>[
      for (final AdminHallEntity hall in used)
        _draftRow(
          d,
          hall.id,
          id: split ? '$orderId#${hall.id}' : orderId,
          orderId: orderId,
        ),
    ];
    emit(state.copyWith(
      rows: <BookingRowEntity>[...state.rows, ...created],
      tab: AdminTab.records,
      filterDay: d.dayIndex,
      openRowId: created.first.id,
      clearNewBooking: true,
      clearNewBookingMonth: true,
    ));
  }

  /// Бронь не сохранилась — оставляем форму с объяснением.
  void _failNewBooking(String message, Emitter<AdminState> emit) {
    final NewBookingDraft? now = state.newBooking;
    if (now == null) return;
    emit(state.copyWith(newBooking: now.copyWith(saving: false, message: message)));
  }

  /// Запись журнала для зала [hallId] только что созданной брони.
  BookingRowEntity _draftRow(
    NewBookingDraft d,
    String hallId, {
    required String id,
    required String orderId,
  }) {
    final List<int> vr = <int>[
      for (int h = 0; h < d.hourCount; h++) d.unitsAt(hallId, h).headsets,
    ];
    final List<int> ps = <int>[
      for (int h = 0; h < d.hourCount; h++) d.unitsAt(hallId, h).consoles,
    ];
    bool uniform(List<int> l) => l.every((int v) => v == l.first);
    final bool varies = !(uniform(vr) && uniform(ps));
    return BookingRowEntity(
      id: id,
      orderId: orderId,
      clubId: state.clubId,
      hallId: hallId,
      dayIndex: d.dayIndex,
      startMinutes: d.startMinutes,
      durationMinutes: d.durationMinutes,
      headsets: vr.first,
      consoles: ps.first,
      hourHeadsets: varies ? vr : null,
      hourConsoles: varies ? ps : null,
      clientName: d.name.trim(),
      // Так же пишет репозиторий: в БД телефон обязателен.
      phone: d.phone.trim().isEmpty ? 'не указан' : d.phone.trim(),
      status: RecordStatus.confirmed,
      source: RecordSource.admin,
      prepay: d.prepay,
      note: d.note.trim(),
    );
  }

  static String _plural(int n, String one, String few, String many) {
    final int m10 = n % 10;
    final int m100 = n % 100;
    if (m10 == 1 && m100 != 11) return one;
    if (m10 >= 2 && m10 <= 4 && (m100 < 12 || m100 > 14)) return few;
    return many;
  }
}
