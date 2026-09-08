part of 'admin_bloc.dart';

/// Вкладка админки.
enum AdminTab {
  /// Цены.
  prices,

  /// Пакеты.
  packages,

  /// Доступность.
  availability,

  /// Журнал записей.
  records;

  /// Подпись.
  String get label => switch (this) {
        AdminTab.prices => 'Цены',
        AdminTab.packages => 'Пакеты',
        AdminTab.availability => 'Доступность',
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

/// Черновик новой брони, создаваемой сотрудником в админке.
class NewBookingDraft extends Equatable {
  /// Создаёт черновик.
  const NewBookingDraft({
    required this.hallId,
    this.dayIndex = 0,
    this.startMinutes = 660,
    this.durationMinutes = 60,
    this.headsets = 2,
    this.consoles = 0,
    this.name = '',
    this.phone = '',
    this.prepay = 0,
    this.note = '',
    this.message = '',
  });

  /// Зал.
  final String hallId;

  /// День (смещение от сегодняшнего).
  final int dayIndex;

  /// Начало, минут от полуночи.
  final int startMinutes;

  /// Длительность, минут.
  final int durationMinutes;

  /// VR-шлемов.
  final int headsets;

  /// PS5.
  final int consoles;

  /// Имя гостя.
  final String name;

  /// Телефон.
  final String phone;

  /// Предоплата, ₽.
  final int prepay;

  /// Комментарий.
  final String note;

  /// Сообщение под формой (ошибка / подсказка).
  final String message;

  /// Копия с изменениями.
  NewBookingDraft copyWith({
    String? hallId,
    int? dayIndex,
    int? startMinutes,
    int? durationMinutes,
    int? headsets,
    int? consoles,
    String? name,
    String? phone,
    int? prepay,
    String? note,
    String? message,
  }) =>
      NewBookingDraft(
        hallId: hallId ?? this.hallId,
        dayIndex: dayIndex ?? this.dayIndex,
        startMinutes: startMinutes ?? this.startMinutes,
        durationMinutes: durationMinutes ?? this.durationMinutes,
        headsets: headsets ?? this.headsets,
        consoles: consoles ?? this.consoles,
        name: name ?? this.name,
        phone: phone ?? this.phone,
        prepay: prepay ?? this.prepay,
        note: note ?? this.note,
        message: message ?? this.message,
      );

  @override
  List<Object?> get props => <Object?>[
        hallId,
        dayIndex,
        startMinutes,
        durationMinutes,
        headsets,
        consoles,
        name,
        phone,
        prepay,
        note,
        message,
      ];
}

/// Свободная ёмкость зала на пересечении с интервалом.
typedef FreeUnits = ({int headsets, int consoles});

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
    this.rowEdits = const <String, BookingRowEntity>{},
    this.cancelledRowIds = const <String>{},
    this.openRowId,
    this.newBooking,
    this.newBookingMonth,
    this.availDayIndex = 0,
    this.intakeOpen = true,
    this.closedHallIds = const <String>{},
    this.closedSlotKeys = const <String>{},
    this.filterDay = -1,
    this.filterHallId = '',
    this.filterType = AdminTypeFilter.all,
    this.newPackage = const NewPackageDraft(),
    this.saveError,
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

  /// Записи (всех клубов), как пришли с сервера + созданные в этой сессии.
  final List<BookingRowEntity> rows;

  /// Правки записей (оверлей поверх [rows], ключ — id записи).
  final Map<String, BookingRowEntity> rowEdits;

  /// Отменённые записи.
  final Set<String> cancelledRowIds;

  /// Открытая карточка брони (id записи) или `null`.
  final String? openRowId;

  /// Черновик новой брони (drawer открыт) или `null`.
  final NewBookingDraft? newBooking;

  /// Видимый месяц календаря в drawer «Новая запись» (первое число).
  final DateTime? newBookingMonth;

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

  /// Черновик нового пакета.
  final NewPackageDraft newPackage;

  /// Текст ошибки сохранения (последняя неудачная запись), `null` — ок.
  final String? saveError;

  /// Горизонт дней для ленты «Доступности».
  static const int horizonDays = 14;

  /// Горизонт дней для календаря новой брони.
  static const int calendarDays = 120;

  /// Длительности сеанса (минуты), общие с виджетом бронирования.
  static const List<int> durations = <int>[60, 120, 180, 240, 300];

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

  /// Записи с наложенными правками ([rowEdits]).
  List<BookingRowEntity> get effectiveRows =>
      rows.map((BookingRowEntity r) => rowEdits[r.id] ?? r).toList(growable: false);

  /// Запись по id с учётом правок.
  BookingRowEntity? rowById(String id) {
    for (final BookingRowEntity r in rows) {
      if (r.id == id) return rowEdits[id] ?? r;
    }
    return null;
  }

  /// Есть ли несохранённая правка у записи.
  bool isEdited(String id) => rowEdits.containsKey(id);

  /// Открытая запись (с учётом правок).
  BookingRowEntity? get openRow => openRowId == null ? null : rowById(openRowId!);

  /// Отфильтрованные записи журнала (без учёта отмен).
  List<BookingRowEntity> get filteredRows => effectiveRows
      .where((BookingRowEntity r) => r.clubId == clubId)
      .where((BookingRowEntity r) => filterDay < 0 || r.dayIndex == filterDay)
      .where((BookingRowEntity r) => filterHallId.isEmpty || r.hallId == filterHallId)
      .where((BookingRowEntity r) => switch (filterType) {
            AdminTypeFilter.all => true,
            AdminTypeFilter.headsets => r.headsets > 0,
            AdminTypeFilter.consoles => r.consoles > 0,
          })
      .toList()
    ..sort((BookingRowEntity a, BookingRowEntity b) {
      final int d = a.dayIndex.compareTo(b.dayIndex);
      return d != 0 ? d : a.startMinutes.compareTo(b.startMinutes);
    });

  /// «Живые» (не отменённые) отфильтрованные записи.
  List<BookingRowEntity> get liveFilteredRows => filteredRows
      .where((BookingRowEntity r) => !cancelledRowIds.contains(r.id))
      .toList(growable: false);

  /// День, по которому строится сетка занятости (0, если фильтр «все дни»).
  int get occupancyDayIndex => filterDay < 0 ? 0 : filterDay;

  /// Записи выбранного клуба на день сетки занятости (живые).
  List<BookingRowEntity> occupancyRows(String hallId) => effectiveRows
      .where((BookingRowEntity r) =>
          r.clubId == clubId &&
          r.hallId == hallId &&
          r.dayIndex == occupancyDayIndex &&
          !cancelledRowIds.contains(r.id))
      .toList()
    ..sort((BookingRowEntity a, BookingRowEntity b) =>
        a.startMinutes.compareTo(b.startMinutes));

  /// Отменена ли запись.
  bool isCancelled(String id) => cancelledRowIds.contains(id);

  /// Зал для формы нового пакета.
  String? get newPackageHallId =>
      newPackage.hallId ?? (clubHalls.isEmpty ? null : clubHalls.first.id);

  /// Зал черновика новой брони.
  AdminHallEntity? get newBookingHall {
    final NewBookingDraft? d = newBooking;
    if (d == null || clubHalls.isEmpty) return null;
    return clubHalls.firstWhere((AdminHallEntity h) => h.id == d.hallId,
        orElse: () => clubHalls.first);
  }

  /// Свободные станции зала на пересечении с интервалом (исключая отменённые
  /// и, при [ignoreRowId], указанную запись — для проверки при её же правке).
  FreeUnits freeUnits({
    required String hallId,
    required int dayIndex,
    required int startMinutes,
    required int durationMinutes,
    String? ignoreRowId,
  }) {
    final AdminHallEntity hall = clubHalls.firstWhere(
      (AdminHallEntity h) => h.id == hallId,
      orElse: () => clubHalls.first,
    );
    final int end = startMinutes + durationMinutes;
    int vr = 0;
    int ps = 0;
    for (final BookingRowEntity r in effectiveRows) {
      if (r.clubId != clubId ||
          r.hallId != hallId ||
          r.dayIndex != dayIndex ||
          r.id == ignoreRowId ||
          cancelledRowIds.contains(r.id)) {
        continue;
      }
      if (r.startMinutes < end && r.endMinutes > startMinutes) {
        vr += r.headsets;
        ps += r.consoles;
      }
    }
    return (
      headsets: (hall.headsets - vr).clamp(0, hall.headsets),
      consoles: (hall.consoles - ps).clamp(0, hall.consoles),
    );
  }

  /// Копия с изменениями.
  AdminState copyWith({
    AdminStatus? status,
    AdminTab? tab,
    String? clubId,
    List<AdminClubEntity>? clubs,
    Map<String, HallPriceEntity>? prices,
    List<PackageEntity>? packages,
    List<BookingRowEntity>? rows,
    Map<String, BookingRowEntity>? rowEdits,
    Set<String>? cancelledRowIds,
    String? openRowId,
    bool clearOpenRow = false,
    NewBookingDraft? newBooking,
    bool clearNewBooking = false,
    DateTime? newBookingMonth,
    bool clearNewBookingMonth = false,
    int? availDayIndex,
    bool? intakeOpen,
    Set<String>? closedHallIds,
    Set<String>? closedSlotKeys,
    int? filterDay,
    String? filterHallId,
    AdminTypeFilter? filterType,
    NewPackageDraft? newPackage,
    String? saveError,
    bool clearSaveError = false,
  }) {
    return AdminState(
      status: status ?? this.status,
      tab: tab ?? this.tab,
      clubId: clubId ?? this.clubId,
      clubs: clubs ?? this.clubs,
      prices: prices ?? this.prices,
      packages: packages ?? this.packages,
      rows: rows ?? this.rows,
      rowEdits: rowEdits ?? this.rowEdits,
      cancelledRowIds: cancelledRowIds ?? this.cancelledRowIds,
      openRowId: clearOpenRow ? null : (openRowId ?? this.openRowId),
      newBooking: clearNewBooking ? null : (newBooking ?? this.newBooking),
      newBookingMonth:
          clearNewBookingMonth ? null : (newBookingMonth ?? this.newBookingMonth),
      availDayIndex: availDayIndex ?? this.availDayIndex,
      intakeOpen: intakeOpen ?? this.intakeOpen,
      closedHallIds: closedHallIds ?? this.closedHallIds,
      closedSlotKeys: closedSlotKeys ?? this.closedSlotKeys,
      filterDay: filterDay ?? this.filterDay,
      filterHallId: filterHallId ?? this.filterHallId,
      filterType: filterType ?? this.filterType,
      newPackage: newPackage ?? this.newPackage,
      saveError: clearSaveError ? null : (saveError ?? this.saveError),
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
        rowEdits,
        cancelledRowIds,
        openRowId,
        newBooking,
        newBookingMonth,
        availDayIndex,
        intakeOpen,
        closedHallIds,
        closedSlotKeys,
        filterDay,
        filterHallId,
        filterType,
        newPackage,
        saveError,
      ];
}
