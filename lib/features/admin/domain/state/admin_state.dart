part of 'admin_bloc.dart';

/// Вкладка админки.
enum AdminTab {
  /// Цены.
  prices,

  /// Пакеты.
  packages,

  /// Доступность.
  availability,

  /// Брони на день.
  bookings,

  /// Журнал записей.
  records;

  /// Подпись.
  String get label => switch (this) {
        AdminTab.prices => 'Цены',
        AdminTab.packages => 'Пакеты',
        AdminTab.availability => 'Доступность',
        AdminTab.bookings => 'Брони',
        AdminTab.records => 'Записи',
      };
}

/// Статус загрузки.
enum AdminStatus {
  /// Загрузка.
  loading,

  /// Готово.
  ready,
}

/// Фильтр журнала по типу станций.
enum AdminTypeFilter {
  /// Всё.
  all,

  /// Со шлемами.
  headsets,

  /// С PS5.
  consoles;

  /// Подпись.
  String get label => switch (this) {
        AdminTypeFilter.all => 'всё',
        AdminTypeFilter.headsets => 'со шлемами',
        AdminTypeFilter.consoles => 'с PS5',
      };
}

/// Фильтр журнала по статусу.
enum AdminStatusFilter {
  /// Любой.
  all,

  /// Новые.
  newRequest,

  /// Подтверждённые.
  confirmed,

  /// Оплаченные.
  paid;

  /// Подпись.
  String get label => switch (this) {
        AdminStatusFilter.all => 'любой',
        AdminStatusFilter.newRequest => 'новые',
        AdminStatusFilter.confirmed => 'подтверждённые',
        AdminStatusFilter.paid => 'оплаченные',
      };

  /// Соответствует ли записи.
  bool matches(RecordStatus s) => switch (this) {
        AdminStatusFilter.all => true,
        AdminStatusFilter.newRequest => s == RecordStatus.newRequest,
        AdminStatusFilter.confirmed => s == RecordStatus.confirmed,
        AdminStatusFilter.paid => s == RecordStatus.paid,
      };
}

/// Черновик нового пакета.
class NewPackageDraft extends Equatable {
  /// Создаёт черновик.
  const NewPackageDraft({
    this.name = '',
    this.hallId,
    this.headsets = 2,
    this.consoles = 0,
    this.minutes = 60,
    this.price = 5000,
    this.message = '',
  });

  /// Название.
  final String name;

  /// Выбранный зал.
  final String? hallId;

  /// VR-шлемов.
  final int headsets;

  /// PS5.
  final int consoles;

  /// Минут.
  final int minutes;

  /// Цена.
  final int price;

  /// Сообщение под формой (ошибка / подтверждение).
  final String message;

  /// Готова ли форма (только базовая валидность для активации кнопки).
  bool get isValid => name.trim().length > 1;

  /// Копия с изменениями.
  NewPackageDraft copyWith({
    String? name,
    String? hallId,
    int? headsets,
    int? consoles,
    int? minutes,
    int? price,
    String? message,
  }) =>
      NewPackageDraft(
        name: name ?? this.name,
        hallId: hallId ?? this.hallId,
        headsets: headsets ?? this.headsets,
        consoles: consoles ?? this.consoles,
        minutes: minutes ?? this.minutes,
        price: price ?? this.price,
        message: message ?? this.message,
      );

  @override
  List<Object?> get props =>
      <Object?>[name, hallId, headsets, consoles, minutes, price, message];
}

/// Состояние админки.
class AdminState extends Equatable {
  /// Создаёт состояние.
  const AdminState({
    this.status = AdminStatus.loading,
    this.tab = AdminTab.prices,
    this.clubId = 'vray',
    this.clubs = const <AdminClubEntity>[],
    this.prices = const <String, HallPriceEntity>{},
    this.packages = const <PackageEntity>[],
    this.rows = const <BookingRowEntity>[],
    this.cancelledRowIds = const <String>{},
    this.availDayIndex = 0,
    this.intakeOpen = true,
    this.closedHallIds = const <String>{},
    this.closedSlotKeys = const <String>{},
    this.filterDay = -1,
    this.filterHallId = '',
    this.filterType = AdminTypeFilter.all,
    this.filterStatus = AdminStatusFilter.all,
    this.newPackage = const NewPackageDraft(),
  });

  /// Статус загрузки.
  final AdminStatus status;

  /// Активная вкладка.
  final AdminTab tab;

  /// Выбранный клуб.
  final String clubId;

  /// Клубы.
  final List<AdminClubEntity> clubs;

  /// Тарифы по залам.
  final Map<String, HallPriceEntity> prices;

  /// Пакеты (всех клубов).
  final List<PackageEntity> packages;

  /// Записи (всех клубов).
  final List<BookingRowEntity> rows;

  /// Отменённые записи.
  final Set<String> cancelledRowIds;

  /// День в сетке закрытия слотов.
  final int availDayIndex;

  /// Приём заявок включён.
  final bool intakeOpen;

  /// Закрытые залы.
  final Set<String> closedHallIds;

  /// Закрытые слоты (`clubId-dayIndex-minutes`).
  final Set<String> closedSlotKeys;

  /// Фильтр дня журнала (`-1` — все).
  final int filterDay;

  /// Фильтр зала журнала (`''` — все).
  final String filterHallId;

  /// Фильтр типа станций.
  final AdminTypeFilter filterType;

  /// Фильтр статуса.
  final AdminStatusFilter filterStatus;

  /// Черновик нового пакета.
  final NewPackageDraft newPackage;

  /// Горизонт дней (как в макете).
  static const int horizonDays = 14;

  /// Выбранный клуб.
  AdminClubEntity get club =>
      clubs.firstWhere((AdminClubEntity c) => c.id == clubId, orElse: () => clubs.first);

  /// Slug клуба (для акцента).
  String get accentSlug => clubs.isEmpty ? 'effect_vr' : club.slug;

  /// Залы клуба.
  List<AdminHallEntity> get clubHalls => clubs.isEmpty ? const <AdminHallEntity>[] : club.halls;

  /// Тариф зала (или дефолт).
  HallPriceEntity priceOf(String hallId) =>
      prices[hallId] ??
      HallPriceEntity(
          hallId: hallId, vrWeekday: 0, vrWeekend: 0, ps5Weekday: 0, ps5Weekend: 0);

  /// Пакеты выбранного клуба.
  List<PackageEntity> get clubPackages =>
      packages.where((PackageEntity p) => p.clubId == clubId).toList(growable: false);

  /// Стартовые времена часовых слотов клуба.
  List<int> get slotStarts {
    if (clubs.isEmpty) return const <int>[];
    final AdminClubEntity c = club;
    final List<int> out = <int>[];
    for (int t = c.openMinutes; t + 60 <= c.closeMinutes; t += 60 + c.gapMinutes) {
      out.add(t);
    }
    return out;
  }

  /// Ключ слота выбранного дня.
  String slotKey(int minutes) => '$clubId-$availDayIndex-$minutes';

  /// Записи брони на сегодня для клуба.
  List<BookingRowEntity> get todayBookings => rows
      .where((BookingRowEntity r) => r.clubId == clubId && r.dayIndex == 0)
      .toList()
    ..sort((BookingRowEntity a, BookingRowEntity b) =>
        a.startMinutes.compareTo(b.startMinutes));

  /// Отфильтрованные записи журнала (без учёта отмен).
  List<BookingRowEntity> get filteredRows => rows
      .where((BookingRowEntity r) => r.clubId == clubId)
      .where((BookingRowEntity r) => filterDay < 0 || r.dayIndex == filterDay)
      .where((BookingRowEntity r) => filterHallId.isEmpty || r.hallId == filterHallId)
      .where((BookingRowEntity r) => switch (filterType) {
            AdminTypeFilter.all => true,
            AdminTypeFilter.headsets => r.headsets > 0,
            AdminTypeFilter.consoles => r.consoles > 0,
          })
      .where((BookingRowEntity r) => filterStatus.matches(r.status))
      .toList()
    ..sort((BookingRowEntity a, BookingRowEntity b) {
      final int d = a.dayIndex.compareTo(b.dayIndex);
      return d != 0 ? d : a.startMinutes.compareTo(b.startMinutes);
    });

  /// «Живые» (не отменённые) отфильтрованные записи.
  List<BookingRowEntity> get liveFilteredRows => filteredRows
      .where((BookingRowEntity r) => !cancelledRowIds.contains(r.id))
      .toList(growable: false);

  /// Отменена ли запись.
  bool isCancelled(String id) => cancelledRowIds.contains(id);

  /// Зал для формы нового пакета.
  String? get newPackageHallId =>
      newPackage.hallId ?? (clubHalls.isEmpty ? null : clubHalls.first.id);

  /// Копия с изменениями.
  AdminState copyWith({
    AdminStatus? status,
    AdminTab? tab,
    String? clubId,
    List<AdminClubEntity>? clubs,
    Map<String, HallPriceEntity>? prices,
    List<PackageEntity>? packages,
    List<BookingRowEntity>? rows,
    Set<String>? cancelledRowIds,
    int? availDayIndex,
    bool? intakeOpen,
    Set<String>? closedHallIds,
    Set<String>? closedSlotKeys,
    int? filterDay,
    String? filterHallId,
    AdminTypeFilter? filterType,
    AdminStatusFilter? filterStatus,
    NewPackageDraft? newPackage,
  }) {
    return AdminState(
      status: status ?? this.status,
      tab: tab ?? this.tab,
      clubId: clubId ?? this.clubId,
      clubs: clubs ?? this.clubs,
      prices: prices ?? this.prices,
      packages: packages ?? this.packages,
      rows: rows ?? this.rows,
      cancelledRowIds: cancelledRowIds ?? this.cancelledRowIds,
      availDayIndex: availDayIndex ?? this.availDayIndex,
      intakeOpen: intakeOpen ?? this.intakeOpen,
      closedHallIds: closedHallIds ?? this.closedHallIds,
      closedSlotKeys: closedSlotKeys ?? this.closedSlotKeys,
      filterDay: filterDay ?? this.filterDay,
      filterHallId: filterHallId ?? this.filterHallId,
      filterType: filterType ?? this.filterType,
      filterStatus: filterStatus ?? this.filterStatus,
      newPackage: newPackage ?? this.newPackage,
    );
  }

  @override
  List<Object?> get props => <Object?>[
        status,
        tab,
        clubId,
        clubs,
        prices,
        packages,
        rows,
        cancelledRowIds,
        availDayIndex,
        intakeOpen,
        closedHallIds,
        closedSlotKeys,
        filterDay,
        filterHallId,
        filterType,
        filterStatus,
        newPackage,
      ];
}
