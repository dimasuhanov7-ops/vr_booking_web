// Публичные именованные параметры конструктора BLoC — часть публичного API фичи.
// ignore_for_file: prefer_initializing_formals

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../entity/admin_club_entity.dart';
import '../entity/booking_row_entity.dart';
import '../entity/hall_price_entity.dart';
import '../entity/package_entity.dart';
import '../repository/i_admin_repository.dart';

part 'admin_event.dart';
part 'admin_state.dart';

/// Управляет состоянием админки: клуб, вкладка, правки цен/пакетов/доступности,
/// фильтры журнала, отмены. Всё локально — на сервер ничего не уходит.
class AdminBloc extends Bloc<AdminEvent, AdminState> {
  /// Создаёт BLoC.
  AdminBloc({required IAdminRepository repository})
      : _repository = repository,
        super(const AdminState()) {
    on<AdminStarted>(_onStarted);
    on<AdminClubChanged>(_onClubChanged);
    on<AdminTabChanged>(_onTabChanged);
    on<AdminPriceChanged>(_onPriceChanged);
    on<AdminPackageFieldChanged>(_onPackageFieldChanged);
    on<AdminPackageToggled>(_onPackageToggled);
    on<AdminPackageDeleted>(_onPackageDeleted);
    on<AdminNewPackageChanged>(_onNewPackageChanged);
    on<AdminNewPackageSubmitted>(_onNewPackageSubmitted);
    on<AdminIntakeToggled>(_onIntakeToggled);
    on<AdminHallClosureToggled>(_onHallClosureToggled);
    on<AdminAvailDayChanged>(_onAvailDayChanged);
    on<AdminSlotClosureToggled>(_onSlotClosureToggled);
    on<AdminDayClosureChanged>(_onDayClosureChanged);
    on<AdminFilterChanged>(_onFilterChanged);
    on<AdminRowCancelToggled>(_onRowCancelToggled);
  }

  final IAdminRepository _repository;

  Future<void> _onStarted(AdminStarted event, Emitter<AdminState> emit) async {
    emit(state.copyWith(status: AdminStatus.loading));
    final List<AdminClubEntity> clubs = await _repository.fetchClubs();
    final List<HallPriceEntity> prices = await _repository.fetchPrices();
    final List<PackageEntity> packages = await _repository.fetchPackages();
    final List<BookingRowEntity> rows = await _repository.fetchRows();
    emit(state.copyWith(
      status: AdminStatus.ready,
      clubs: clubs,
      prices: <String, HallPriceEntity>{
        for (final HallPriceEntity p in prices) p.hallId: p,
      },
      packages: packages,
      rows: rows,
    ));
  }

  void _onClubChanged(AdminClubChanged event, Emitter<AdminState> emit) {
    if (event.clubId == state.clubId) return;
    emit(state.copyWith(
      clubId: event.clubId,
      availDayIndex: 0,
      filterDay: -1,
      filterHallId: '',
      filterType: AdminTypeFilter.all,
      filterStatus: AdminStatusFilter.all,
      newPackage: const NewPackageDraft(),
    ));
  }

  void _onTabChanged(AdminTabChanged event, Emitter<AdminState> emit) =>
      emit(state.copyWith(tab: event.tab));

  void _onPriceChanged(AdminPriceChanged event, Emitter<AdminState> emit) {
    final HallPriceEntity current = state.priceOf(event.hallId);
    emit(state.copyWith(prices: <String, HallPriceEntity>{
      ...state.prices,
      event.hallId: current.withField(event.field, event.value),
    }));
  }

  void _onPackageFieldChanged(
    AdminPackageFieldChanged event,
    Emitter<AdminState> emit,
  ) {
    emit(state.copyWith(
      packages: state.packages
          .map((PackageEntity p) => p.id == event.packageId
              ? p.withField(event.field, event.value)
              : p)
          .toList(growable: false),
    ));
  }

  void _onPackageToggled(AdminPackageToggled event, Emitter<AdminState> emit) {
    emit(state.copyWith(
      packages: state.packages
          .map((PackageEntity p) =>
              p.id == event.packageId ? p.copyWith(isEnabled: !p.isEnabled) : p)
          .toList(growable: false),
    ));
  }

  void _onPackageDeleted(AdminPackageDeleted event, Emitter<AdminState> emit) {
    emit(state.copyWith(
      packages: state.packages
          .where((PackageEntity p) => p.id != event.packageId)
          .toList(growable: false),
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

  void _onNewPackageSubmitted(
    AdminNewPackageSubmitted event,
    Emitter<AdminState> emit,
  ) {
    final NewPackageDraft d = state.newPackage;
    final String? hallId = state.newPackageHallId;
    if (hallId == null) return;
    final AdminHallEntity hall =
        state.clubHalls.firstWhere((AdminHallEntity h) => h.id == hallId);

    String? error;
    if (d.name.trim().length < 2) {
      error = 'Название от двух символов.';
    } else if (d.headsets + d.consoles < 1) {
      error = 'Укажите хотя бы одну станцию — шлем или PS5.';
    } else if (d.headsets > hall.headsets) {
      error = 'В «${hall.name}» только ${_plural(hall.headsets, 'шлем', 'шлема', 'шлемов')}.';
    } else if (d.consoles > hall.consoles) {
      error = hall.consoles > 0
          ? 'В «${hall.name}» только ${hall.consoles} PS5.'
          : 'В «${hall.name}» нет PS5.';
    }

    if (error != null) {
      emit(state.copyWith(newPackage: d.copyWith(message: error)));
      return;
    }

    final PackageEntity created = PackageEntity(
      id: 'p${DateTime.now().millisecondsSinceEpoch}',
      clubId: state.clubId,
      hallId: hallId,
      name: d.name.trim(),
      headsets: d.headsets,
      consoles: d.consoles,
      minutes: d.minutes,
      price: d.price,
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

  void _onIntakeToggled(AdminIntakeToggled event, Emitter<AdminState> emit) =>
      emit(state.copyWith(intakeOpen: !state.intakeOpen));

  void _onHallClosureToggled(
    AdminHallClosureToggled event,
    Emitter<AdminState> emit,
  ) {
    final Set<String> next = Set<String>.of(state.closedHallIds);
    if (!next.remove(event.hallId)) next.add(event.hallId);
    emit(state.copyWith(closedHallIds: next));
  }

  void _onAvailDayChanged(AdminAvailDayChanged event, Emitter<AdminState> emit) =>
      emit(state.copyWith(availDayIndex: event.dayIndex));

  void _onSlotClosureToggled(
    AdminSlotClosureToggled event,
    Emitter<AdminState> emit,
  ) {
    final String key = state.slotKey(event.startMinutes);
    final Set<String> next = Set<String>.of(state.closedSlotKeys);
    if (!next.remove(key)) next.add(key);
    emit(state.copyWith(closedSlotKeys: next));
  }

  void _onDayClosureChanged(
    AdminDayClosureChanged event,
    Emitter<AdminState> emit,
  ) {
    final Set<String> keys =
        state.slotStarts.map(state.slotKey).toSet();
    final Set<String> next = Set<String>.of(state.closedSlotKeys)..removeAll(keys);
    if (event.closeAll) next.addAll(keys);
    emit(state.copyWith(closedSlotKeys: next));
  }

  void _onFilterChanged(AdminFilterChanged event, Emitter<AdminState> emit) {
    emit(state.copyWith(
      filterDay: event.day,
      filterHallId: event.hallId,
      filterType: event.type,
      filterStatus: event.status,
    ));
  }

  void _onRowCancelToggled(
    AdminRowCancelToggled event,
    Emitter<AdminState> emit,
  ) {
    final Set<String> next = Set<String>.of(state.cancelledRowIds);
    if (!next.remove(event.rowId)) next.add(event.rowId);
    emit(state.copyWith(cancelledRowIds: next));
  }

  static String _plural(int n, String one, String few, String many) {
    final int m10 = n % 10;
    final int m100 = n % 100;
    if (m10 == 1 && m100 != 11) return one;
    if (m10 >= 2 && m10 <= 4 && (m100 < 12 || m100 > 14)) return few;
    return many;
  }
}
