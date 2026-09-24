part of 'admin_bloc.dart';

/// Вкладка админки. Порядок — как в панели вкладок.
enum AdminTab {
  /// Записи: занятость и брони на день — главный экран сотрудника.
  records,

  /// Цены.
  prices,

  /// Пакеты.
  packages,

  /// Доступность.
  availability,

  /// Журнал действий сотрудников (`booking_audit_log`).
  log;

  /// Подпись.
  String get label => switch (this) {
        AdminTab.records => 'Записи',
        AdminTab.prices => 'Цены',
        AdminTab.packages => 'Пакеты',
        AdminTab.availability => 'Доступность',
        AdminTab.log => 'Журнал',
      };
}

/// Статус загрузки.
enum AdminStatus {
  /// Загрузка.
  loading,

  /// Готово.
  ready,

  /// Не удалось загрузить стартовые данные.
  failure,
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
///
/// Состав задаётся по залам: одна бронь может держать станции в нескольких
/// залах сразу — например, компания на арене и пара человек в малом зале.
class NewBookingDraft extends Equatable {
  /// Создаёт черновик.
  const NewBookingDraft({
    this.dayIndex = 0,
    this.startMinutes = 660,
    this.durationMinutes = 60,
    this.units = const <String, HallUnits>{},
    this.hourUnits = const <int, Map<String, HallUnits>>{},
    this.name = '',
    this.phone = '',
    this.prepay = 0,
    this.note = '',
    this.message = '',
    this.saving = false,
  });

  /// День (смещение от сегодняшнего).
  final int dayIndex;

  /// Начало, минут от полуночи.
  final int startMinutes;

  /// Длительность, минут.
  final int durationMinutes;

  /// Состав 1-го часа (база): зал → шлемы и PS5.
  final Map<String, HallUnits> units;

  /// Переопределения состава для часов ≥ 1: час → зал → шлемы и PS5.
  /// Зал без переопределения в часе наследует состав предыдущего часа.
  final Map<int, Map<String, HallUnits>> hourUnits;

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

  /// Бронь отправляется на сервер — форма заблокирована.
  final bool saving;

  /// Число часовых отрезков.
  int get hourCount => (durationMinutes / 60).round().clamp(1, 12);

  /// Залы, упомянутые в черновике.
  Set<String> get hallIds => <String>{
        ...units.keys,
        for (final Map<String, HallUnits> m in hourUnits.values) ...m.keys,
      };

  /// Состав зала [hallId] в час [h] (с наследованием от нижних часов).
  HallUnits unitsAt(String hallId, int h) {
    for (int k = h; k >= 1; k--) {
      final HallUnits? v = hourUnits[k]?[hallId];
      if (v != null) return v;
    }
    return units[hallId] ?? (headsets: 0, consoles: 0);
  }

  /// Станций во всех залах в час [h].
  int totalAt(int h) {
    int sum = 0;
    for (final String id in hallIds) {
      final HallUnits u = unitsAt(id, h);
      sum += u.headsets + u.consoles;
    }
    return sum;
  }

  /// Разный ли состав по часам (хотя бы в одном зале).
  bool get variesByHour {
    for (int h = 1; h < hourCount; h++) {
      for (final String id in hallIds) {
        if (unitsAt(id, h) != unitsAt(id, 0)) return true;
      }
    }
    return false;
  }

  /// Копия с изменениями.
  NewBookingDraft copyWith({
    int? dayIndex,
    int? startMinutes,
    int? durationMinutes,
    Map<String, HallUnits>? units,
    Map<int, Map<String, HallUnits>>? hourUnits,
    bool clearHourly = false,
    String? name,
    String? phone,
    int? prepay,
    String? note,
    String? message,
    bool? saving,
  }) =>
      NewBookingDraft(
        dayIndex: dayIndex ?? this.dayIndex,
        startMinutes: startMinutes ?? this.startMinutes,
        durationMinutes: durationMinutes ?? this.durationMinutes,
        units: units ?? this.units,
        hourUnits: clearHourly
            ? const <int, Map<String, HallUnits>>{}
            : (hourUnits ?? this.hourUnits),
        name: name ?? this.name,
        phone: phone ?? this.phone,
        prepay: prepay ?? this.prepay,
        note: note ?? this.note,
        message: message ?? this.message,
        saving: saving ?? this.saving,
      );

  @override
  List<Object?> get props => <Object?>[
        dayIndex,
        startMinutes,
        durationMinutes,
        units,
        hourUnits,
        name,
        phone,
        prepay,
        note,
        message,
        saving,
      ];
}

/// Свободная ёмкость зала на пересечении с интервалом.
typedef FreeUnits = ({int headsets, int consoles});

/// Состояние админки.
class AdminState extends Equatable {
  /// Создаёт состояние.
  const AdminState({
    this.status = AdminStatus.loading,
    this.tab = AdminTab.records,
    this.clubId = 'vray',
    this.clubs = const <AdminClubEntity>[],
    this.prices = const <String, HallPriceEntity>{},
    this.packages = const <PackageEntity>[],
    this.promos = const <PromoEntity>[],
    this.newPromo = const NewPromoDraft(),
    this.rows = const <BookingRowEntity>[],
    this.cancelledRowIds = const <String>{},
    this.openRowId,
    this.newBooking,
    this.newBookingMonth,
    this.availDayIndex = 0,
    this.intakeOpen = true,
    this.closedHallIds = const <String>{},
    this.closedSlotKeys = const <String>{},
    this.closures = const <ClosureEntity>[],
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
    this.refreshing = false,
    this.refreshedAt,
    this.saveNotice,
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

  /// Записи (всех клубов): с сервера и созданные в этой сессии. Бронь на
  /// несколько залов — строка на зал с общим [BookingRowEntity.orderId].
  final List<BookingRowEntity> rows;

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

  /// Все закрытия из «Доступности» — нужны и на вкладке «Записи», чтобы
  /// сотрудник видел закрытое время там же, где брони.
  final List<ClosureEntity> closures;

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

  /// Текст ошибки (последняя неудачная запись или загрузка), `null` — ок.
  final String? saveError;

  /// Идёт обновление броней с сервера.
  final bool refreshing;

  /// Когда брони последний раз пришли с сервера.
  final DateTime? refreshedAt;

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

  /// Пояснение к сохранению, которое не ошибка (например, пакет выключен
  /// вместо удаления). Показывается нейтральной плашкой.
  final String? saveNotice;

  /// Можно ли править время и состав брони (`IAdminRepository.canEditSchedule`).
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

  /// Начала сеансов длительностью [durationMinutes] на день [dayIndex]: шаг —
  /// час плюс перерыв клуба. На сегодня — только ещё не начавшиеся: прошедшее
  /// время база отклонит (`STARTS_IN_PAST`).
  List<int> sessionStarts(int dayIndex, int durationMinutes) {
    if (clubs.isEmpty) return const <int>[];
    final AdminClubEntity c = club;
    final DateTime now = DateTime.now();
    final int nowMinutes = now.hour * 60 + now.minute;
    return <int>[
      for (int t = c.openMinutes;
          t + durationMinutes <= c.closeMinutes;
          t += 60 + c.gapMinutes)
        if (dayIndex > 0 || t > nowMinutes) t,
    ];
  }

  /// Ключ слота выбранного дня.
  String slotKey(int minutes) => '$clubId-$availDayIndex-$minutes';

  /// Дата, выбранная на вкладке «Доступность» (от сегодняшнего дня).
  DateTime get availDay {
    final DateTime now = DateTime.now();
    return DateTime(now.year, now.month, now.day)
        .add(Duration(days: availDayIndex));
  }

  /// Запись по id.
  BookingRowEntity? rowById(String id) {
    for (final BookingRowEntity r in rows) {
      if (r.id == id) return r;
    }
    return null;
  }

  /// Брони всех клубов, найденные по [searchQuery]: сначала ближайшие
  /// будущие, затем прошедшие от недавних к давним. Не больше 30.
  List<BookingRowEntity> get searchResults {
    if (searchQuery.trim().isEmpty) return const <BookingRowEntity>[];
    final List<BookingRowEntity> found = rows
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

  /// Открытая запись.
  BookingRowEntity? get openRow => openRowId == null ? null : rowById(openRowId!);

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
  /// Закрытия текущего клуба, влияющие на день [dayIndex], по возрастанию времени.
  ///
  /// Сюда попадают и бессрочно закрытые залы: на вкладке «Записи» сотруднику
  /// нужно видеть, что зал вообще не работает, а не только окна на дату.
  List<ClosureEntity> closuresOn(int dayIndex) {
    final DateTime date = _todayDate().add(Duration(days: dayIndex));
    final List<ClosureEntity> out = closures.where((ClosureEntity c) {
      if (c.clubId != clubId) return false;
      final DateTime? d = c.day;
      if (d == null) return c.isWholeHall;
      return DateTime(d.year, d.month, d.day) == date;
    }).toList();
    out.sort((ClosureEntity a, ClosureEntity b) =>
        (a.fromMinutes ?? -1).compareTo(b.fromMinutes ?? -1));
    return out;
  }

  /// Закрыт ли сеанс [minutes]…[minutes] + [session] в зале [hallId].
  bool isClosedHour({
    required String hallId,
    required int dayIndex,
    required int minutes,
    int session = 60,
  }) {
    for (final ClosureEntity c in closuresOn(dayIndex)) {
      if (c.hallId != null && c.hallId != hallId) continue;
      if (c.isWholeHall) return true;
      final int from = c.fromMinutes ?? 0;
      final int to = c.toMinutes ?? 1440;
      if (minutes < to && minutes + session > from) return true;
    }
    return false;
  }

  static DateTime _todayDate() {
    final DateTime n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  List<BookingRowEntity> occupancyRows(String hallId) => rows
      .where((BookingRowEntity r) =>
          r.clubId == clubId &&
          r.hallId == hallId &&
          r.dayIndex == occupancyDayIndex &&
          !cancelledRowIds.contains(r.id))
      .toList()
    ..sort((BookingRowEntity a, BookingRowEntity b) =>
        a.startMinutes.compareTo(b.startMinutes));

  /// Брони выбранного клуба на день сетки — по заказам (строки брони на
  /// несколько залов собраны вместе), по времени начала. Для списка под сеткой.
  List<List<BookingRowEntity>> get dayOrders {
    final Map<String, List<BookingRowEntity>> byOrder =
        <String, List<BookingRowEntity>>{};
    for (final BookingRowEntity r in rows) {
      if (r.clubId != clubId || r.dayIndex != occupancyDayIndex) continue;
      byOrder.putIfAbsent(r.orderId, () => <BookingRowEntity>[]).add(r);
    }
    int startOf(List<BookingRowEntity> parts) => parts
        .map((BookingRowEntity r) => r.startMinutes)
        .reduce((int a, int b) => a < b ? a : b);
    return byOrder.values.toList()
      ..sort((List<BookingRowEntity> a, List<BookingRowEntity> b) =>
          startOf(a).compareTo(startOf(b)));
  }

  /// Отменена ли запись.
  bool isCancelled(String id) => cancelledRowIds.contains(id);

  /// Зал для формы нового пакета.
  String? get newPackageHallId =>
      newPackage.hallId ?? (clubHalls.isEmpty ? null : clubHalls.first.id);

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
    for (final BookingRowEntity r in rows) {
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
    List<ClosureEntity>? closures,
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
    bool? refreshing,
    DateTime? refreshedAt,
    String? saveNotice,
    bool clearSaveNotice = false,
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
      cancelledRowIds: cancelledRowIds ?? this.cancelledRowIds,
      openRowId: clearOpenRow ? null : (openRowId ?? this.openRowId),
      newBooking: clearNewBooking ? null : (newBooking ?? this.newBooking),
      newBookingMonth:
          clearNewBookingMonth ? null : (newBookingMonth ?? this.newBookingMonth),
      availDayIndex: availDayIndex ?? this.availDayIndex,
      intakeOpen: intakeOpen ?? this.intakeOpen,
      closedHallIds: closedHallIds ?? this.closedHallIds,
      closedSlotKeys: closedSlotKeys ?? this.closedSlotKeys,
      closures: closures ?? this.closures,
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
      refreshing: refreshing ?? this.refreshing,
      refreshedAt: refreshedAt ?? this.refreshedAt,
      saveNotice: clearSaveNotice ? null : (saveNotice ?? this.saveNotice),
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
        cancelledRowIds,
        openRowId,
        newBooking,
        newBookingMonth,
        availDayIndex,
        intakeOpen,
        closedHallIds,
        closedSlotKeys,
        closures,
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
        refreshing,
        refreshedAt,
        saveNotice,
        scheduleEditable,
      ];
}
