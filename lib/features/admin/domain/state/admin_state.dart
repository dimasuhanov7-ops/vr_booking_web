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
  records,

  /// Журнал действий сотрудников (`booking_audit_log`).
  log;

  /// Подпись.
  String get label => switch (this) {
        AdminTab.prices => 'Цены',
        AdminTab.packages => 'Пакеты',
        AdminTab.availability => 'Доступность',
        AdminTab.records => 'Записи',
        AdminTab.log => 'Журнал',
      };
}

/// Статус загрузки.
enum AdminStatus {
  /// Загрузка.
  loading,

  /// Готово.
  ready,

  /// Загрузить данные не удалось или доступа нет — см. [AdminState.loadError].
  error,
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

/// Черновик нового промокода.
class NewPromoDraft extends Equatable {
  /// Создаёт черновик.
  const NewPromoDraft({
    this.code = '',
    this.kind = PromoKind.percent,
    this.value = 10,
    this.minStations = 1,
    this.message = '',
    this.isError = false,
    this.submitting = false,
  });

  /// Код.
  final String code;

  /// Процент или сумма.
  final PromoKind kind;

  /// Процент или ₽.
  final int value;

  /// От скольких станций действует.
  final int minStations;

  /// Сообщение под формой.
  final String message;

  /// [message] — ошибка (иначе подтверждение).
  final bool isError;

  /// Промокод уходит на сервер — кнопка заблокирована.
  final bool submitting;

  /// Код в том виде, в каком он сохранится.
  String get normalizedCode => code.trim().toUpperCase();

  /// Можно ли нажимать «Добавить».
  bool get isValid => normalizedCode.length >= 3 && value > 0 && !submitting;

  /// Копия с изменениями.
  NewPromoDraft copyWith({
    String? code,
    PromoKind? kind,
    int? value,
    int? minStations,
    String? message,
    bool? isError,
    bool? submitting,
  }) =>
      NewPromoDraft(
        code: code ?? this.code,
        kind: kind ?? this.kind,
        value: value ?? this.value,
        minStations: minStations ?? this.minStations,
        message: message ?? this.message,
        isError: isError ?? this.isError,
        submitting: submitting ?? this.submitting,
      );

  @override
  List<Object?> get props =>
      <Object?>[code, kind, value, minStations, message, isError, submitting];
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
    this.hourHeadsets = const <int, int>{},
    this.hourConsoles = const <int, int>{},
    this.name = '',
    this.phone = '',
    this.prepay = 0,
    this.note = '',
    this.message = '',
    this.submitting = false,
  });

  /// Зал.
  final String hallId;

  /// День (смещение от сегодняшнего).
  final int dayIndex;

  /// Начало, минут от полуночи.
  final int startMinutes;

  /// Длительность, минут.
  final int durationMinutes;

  /// VR-шлемов в 1-м часе (база).
  final int headsets;

  /// PS5 в 1-м часе (база).
  final int consoles;

  /// Переопределения шлемов для часов ≥ 1 (наследуются от предыдущего часа).
  final Map<int, int> hourHeadsets;

  /// Переопределения PS5 для часов ≥ 1.
  final Map<int, int> hourConsoles;

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

  /// Запись уже уходит на сервер: кнопка неактивна.
  final bool submitting;

  /// Число часовых отрезков.
  int get hourCount => (durationMinutes / 60).round().clamp(1, 12);

  /// Шлемов в час [h] (с наследованием от нижних часов).
  int headsetsAt(int h) {
    for (int k = h; k >= 1; k--) {
      final int? v = hourHeadsets[k];
      if (v != null) return v;
    }
    return headsets;
  }

  /// PS5 в час [h].
  int consolesAt(int h) {
    for (int k = h; k >= 1; k--) {
      final int? v = hourConsoles[k];
      if (v != null) return v;
    }
    return consoles;
  }

  /// Разный ли состав по часам.
  bool get variesByHour {
    for (int h = 1; h < hourCount; h++) {
      if (headsetsAt(h) != headsets || consolesAt(h) != consoles) return true;
    }
    return false;
  }

  /// Копия с изменениями.
  NewBookingDraft copyWith({
    String? hallId,
    int? dayIndex,
    int? startMinutes,
    int? durationMinutes,
    int? headsets,
    int? consoles,
    Map<int, int>? hourHeadsets,
    Map<int, int>? hourConsoles,
    bool clearHourly = false,
    String? name,
    String? phone,
    int? prepay,
    String? note,
    String? message,
    bool? submitting,
  }) =>
      NewBookingDraft(
        hallId: hallId ?? this.hallId,
        dayIndex: dayIndex ?? this.dayIndex,
        startMinutes: startMinutes ?? this.startMinutes,
        durationMinutes: durationMinutes ?? this.durationMinutes,
        headsets: headsets ?? this.headsets,
        consoles: consoles ?? this.consoles,
        hourHeadsets: clearHourly
            ? const <int, int>{}
            : (hourHeadsets ?? this.hourHeadsets),
        hourConsoles: clearHourly
            ? const <int, int>{}
            : (hourConsoles ?? this.hourConsoles),
        name: name ?? this.name,
        phone: phone ?? this.phone,
        prepay: prepay ?? this.prepay,
        note: note ?? this.note,
        message: message ?? this.message,
        submitting: submitting ?? this.submitting,
      );

  @override
  List<Object?> get props => <Object?>[
        hallId,
        dayIndex,
        startMinutes,
        durationMinutes,
        headsets,
        consoles,
        hourHeadsets,
        hourConsoles,
        name,
        phone,
        prepay,
        note,
        message,
        submitting,
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
    this.promos = const <PromoEntity>[],
    this.newPromo = const NewPromoDraft(),
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
    this.pausedClubIds = const <String>{},
    this.filterDay = 0,
    this.filterHallId = '',
    this.filterType = AdminTypeFilter.all,
    this.newPackage = const NewPackageDraft(),
    this.searchQuery = '',
    this.auditEntries = const <AuditEntryEntity>[],
    this.auditLoading = false,
    this.auditError,
    this.saveError,
    this.saveNotice,
    this.loadError,
    this.loadNeedsReauth = false,
    this.scheduleEditable = true,
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

  /// Промокоды (общие для всех клубов).
  final List<PromoEntity> promos;

  /// Черновик нового промокода.
  final NewPromoDraft newPromo;

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

  /// Клубы с приостановленным приёмом онлайн-броней. Нужен, чтобы при смене
  /// клуба показать его собственный статус, а не статус предыдущего.
  final Set<String> pausedClubIds;

  /// День, по которому смотрим записи (смещение от сегодняшнего). По умолчанию
  /// и после обновления страницы — сегодня (`0`).
  final int filterDay;

  /// Фильтр зала журнала (`''` — все).
  final String filterHallId;

  /// Фильтр типа станций.
  final AdminTypeFilter filterType;

  /// Черновик нового пакета.
  final NewPackageDraft newPackage;

  /// Строка поиска брони по имени или телефону (вкладка «Записи»).
  final String searchQuery;

  /// Журнал действий (вкладка «Журнал»), новые сверху.
  final List<AuditEntryEntity> auditEntries;

  /// Журнал загружается.
  final bool auditLoading;

  /// Почему журнал не загрузился.
  final String? auditError;

  /// Записи журнала выбранного клуба и общие (без клуба).
  List<AuditEntryEntity> get clubAuditEntries => auditEntries
      .where((AuditEntryEntity e) => e.clubId == null || e.clubId == clubId)
      .toList(growable: false);

  /// Текст ошибки сохранения (последняя неудачная запись), `null` — ок.
  final String? saveError;

  /// Пояснение к сохранению, которое не ошибка (например, пакет выключен
  /// вместо удаления). Показывается нейтральной плашкой.
  final String? saveNotice;

  /// Почему не загрузилась панель (при [AdminStatus.error]).
  final String? loadError;

  /// Помочь может только повторный вход (нет прав / сессия истекла).
  final bool loadNeedsReauth;

  /// Можно ли править время и состав брони (в боевой сборке — нет, см.
  /// `IAdminRepository.canEditSchedule`).
  final bool scheduleEditable;

  /// Горизонт дней для ленты «Доступности».
  static const int horizonDays = 14;

  /// Горизонт дней для календаря новой брони (длиннее публичного — см. конфиг).
  static const int calendarDays = BookingConfig.staffHorizonDays;

  /// Длительности сеанса (минуты), общие с виджетом бронирования.
  static const List<int> durations = BookingConfig.sessionDurations;

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

  /// Дата, выбранная на вкладке «Доступность» (от сегодняшнего дня).
  DateTime get availDay {
    final DateTime now = DateTime.now();
    return DateTime(now.year, now.month, now.day)
        .add(Duration(days: availDayIndex));
  }

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

  /// Брони всех клубов, найденные по [searchQuery]: сначала ближайшие
  /// будущие, затем прошедшие от недавних к давним. Не больше 30.
  List<BookingRowEntity> get searchResults {
    if (searchQuery.trim().isEmpty) return const <BookingRowEntity>[];
    final List<BookingRowEntity> found = effectiveRows
        .where((BookingRowEntity r) => matchesSearch(r, searchQuery))
        .toList();
    int rank(BookingRowEntity r) => r.dayIndex >= 0 ? 0 : 1;
    found.sort((BookingRowEntity a, BookingRowEntity b) {
      final int byRank = rank(a).compareTo(rank(b));
      if (byRank != 0) return byRank;
      final int byDay = rank(a) == 0
          ? a.dayIndex.compareTo(b.dayIndex)
          : b.dayIndex.compareTo(a.dayIndex);
      return byDay != 0 ? byDay : a.startMinutes.compareTo(b.startMinutes);
    });
    return found.take(30).toList(growable: false);
  }

  /// Подходит ли бронь под запрос: часть имени или не меньше трёх цифр
  /// телефона. «8 912…» и «+7 912…» считаются одним номером.
  static bool matchesSearch(BookingRowEntity r, String query) {
    final String q = query.trim().toLowerCase();
    if (q.isEmpty) return false;
    if (r.clientName.toLowerCase().contains(q)) return true;
    final String qd = q.replaceAll(RegExp(r'\D'), '');
    if (qd.length < 3) return false;
    final String pd = r.phone.replaceAll(RegExp(r'\D'), '');
    if (pd.contains(qd)) return true;
    return qd.length >= 4 &&
        (qd.startsWith('8') || qd.startsWith('7')) &&
        pd.contains(qd.substring(1));
  }

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
    List<PromoEntity>? promos,
    NewPromoDraft? newPromo,
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
    Set<String>? pausedClubIds,
    int? filterDay,
    String? filterHallId,
    AdminTypeFilter? filterType,
    NewPackageDraft? newPackage,
    String? searchQuery,
    List<AuditEntryEntity>? auditEntries,
    bool? auditLoading,
    String? auditError,
    bool clearAuditError = false,
    String? saveError,
    bool clearSaveError = false,
    String? saveNotice,
    bool clearSaveNotice = false,
    String? loadError,
    bool? loadNeedsReauth,
    bool? scheduleEditable,
  }) {
    return AdminState(
      status: status ?? this.status,
      tab: tab ?? this.tab,
      clubId: clubId ?? this.clubId,
      clubs: clubs ?? this.clubs,
      prices: prices ?? this.prices,
      packages: packages ?? this.packages,
      promos: promos ?? this.promos,
      newPromo: newPromo ?? this.newPromo,
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
      pausedClubIds: pausedClubIds ?? this.pausedClubIds,
      filterDay: filterDay ?? this.filterDay,
      filterHallId: filterHallId ?? this.filterHallId,
      filterType: filterType ?? this.filterType,
      newPackage: newPackage ?? this.newPackage,
      searchQuery: searchQuery ?? this.searchQuery,
      auditEntries: auditEntries ?? this.auditEntries,
      auditLoading: auditLoading ?? this.auditLoading,
      auditError: clearAuditError ? null : (auditError ?? this.auditError),
      saveError: clearSaveError ? null : (saveError ?? this.saveError),
      saveNotice: clearSaveNotice ? null : (saveNotice ?? this.saveNotice),
      loadError: loadError ?? this.loadError,
      loadNeedsReauth: loadNeedsReauth ?? this.loadNeedsReauth,
      scheduleEditable: scheduleEditable ?? this.scheduleEditable,
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
        promos,
        newPromo,
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
        pausedClubIds,
        filterDay,
        filterHallId,
        filterType,
        newPackage,
        searchQuery,
        auditEntries,
        auditLoading,
        auditError,
        saveError,
        saveNotice,
        loadError,
        loadNeedsReauth,
        scheduleEditable,
      ];
}
