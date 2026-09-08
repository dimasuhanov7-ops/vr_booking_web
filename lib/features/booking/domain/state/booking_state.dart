part of 'booking_bloc.dart';

/// Что показываем: форму или экран успеха.
enum BookingStage {
  /// Форма бронирования.
  form,

  /// Бронь создана.
  done,
}

/// Статус загрузки/операции.
enum BookingStatus {
  /// Ничего не загружалось.
  initial,

  /// Идёт загрузка.
  loading,

  /// Готово, ждём действий.
  ready,

  /// Идёт создание брони.
  submitting,

  /// Ошибка загрузки.
  failure,
}

/// Состояние виджета бронирования (один прокручиваемый экран).
class BookingState extends Equatable {
  /// Создаёт состояние.
  const BookingState({
    this.view = BookingStage.form,
    this.status = BookingStatus.initial,
    this.clubLocked = false,
    this.clubs = const <ClubEntity>[],
    this.club,
    this.stations = const <StationEntity>[],
    this.prices = const <PriceRateEntity>[],
    this.packages = const <PackageEntity>[],
    this.selectedPackageId,
    this.hallOptions = const <HallOptionEntity>[],
    this.hall,
    this.date,
    this.durationMinutes = 60,
    this.slots = const <TimeSlotEntity>[],
    this.busy = const <BusyIntervalEntity>[],
    this.slot,
    this.pickedByHour = const <int, Set<String>>{},
    this.takenIds = const <String>{},
    this.conflictShown = false,
    this.clientName = '',
    this.clientPhone = '',
    this.peopleInput = '',
    this.quote = QuoteEntity.empty,
    this.account,
    this.savedBookings = const <SavedBookingEntity>[],
    this.accountLoginOpen = false,
    this.accountLoginPhone = '',
    this.accountListOpen = false,
    this.createdOrderId,
    this.errorMessage,
  });

  /// Форма / успех.
  final BookingStage view;

  /// Статус.
  final BookingStatus status;

  /// Клуб зафиксирован через `?club=` — селектор клуба не показываем.
  final bool clubLocked;

  /// Клубы.
  final List<ClubEntity> clubs;

  /// Выбранный клуб.
  final ClubEntity? club;

  /// Все станции клуба.
  final List<StationEntity> stations;

  /// Тарифы клуба.
  final List<PriceRateEntity> prices;

  /// Пакеты клуба.
  final List<PackageEntity> packages;

  /// Выбранный пакет (по id) — влияет на цену, пока состав совпадает.
  final String? selectedPackageId;

  /// Варианты «зала» (залы + «Весь клуб»).
  final List<HallOptionEntity> hallOptions;

  /// Выбранный вариант зала.
  final HallOptionEntity? hall;

  /// Выбранная дата.
  final DateTime? date;

  /// Длительность сеанса, минут.
  final int durationMinutes;

  /// Слоты выбранной даты/длительности.
  final List<TimeSlotEntity> slots;

  /// Занятые интервалы клуба на дату.
  final List<BusyIntervalEntity> busy;

  /// Выбранный слот.
  final TimeSlotEntity? slot;

  /// Выбранные станции по каждому часу сеанса (0-й час, 1-й, …).
  ///
  /// Хранится «разрежённо»: если для часа записи нет — он наследует выбор
  /// ближайшего часа ниже (см. [pickedAt]). Так простой случай «одни и те же
  /// станции на весь сеанс» — это одна запись под ключом `0`, а «12 в первый
  /// час, 6 во второй» — записи под `0` и `1`.
  final Map<int, Set<String>> pickedByHour;

  /// Станции, которые заняли при конфликте брони.
  final Set<String> takenIds;

  /// Показывать плашку конфликта.
  final bool conflictShown;

  /// Имя клиента.
  final String clientName;

  /// Телефон клиента.
  final String clientPhone;

  /// Ввод числа людей (строка).
  final String peopleInput;

  /// Итоговый расчёт.
  final QuoteEntity quote;

  /// Запомненный клиент (`localStorage`), если есть.
  final AccountEntity? account;

  /// Локально сохранённые брони (этого устройства).
  final List<SavedBookingEntity> savedBookings;

  /// Открыта панель входа по телефону.
  final bool accountLoginOpen;

  /// Ввод телефона в панели входа.
  final String accountLoginPhone;

  /// Открыт список «мои брони».
  final bool accountListOpen;

  /// Брони запомненного клиента.
  List<SavedBookingEntity> get myBookings {
    final AccountEntity? a = account;
    if (a == null) return const <SavedBookingEntity>[];
    return savedBookings
        .where((SavedBookingEntity b) => b.phone == a.phone)
        .toList(growable: false);
  }

  /// Идентификатор созданной брони.
  final String? createdOrderId;

  /// Текст ошибки.
  final String? errorMessage;

  /// Всего шагов мастера: 3 при зафиксированном клубе, иначе 4.
  int get stepCount => clubLocked ? 3 : 4;

  /// Текущий шаг мастера (1..[stepCount]) — для заголовка.
  int get stepNo {
    final int shift = clubLocked ? 1 : 0;
    if (!clubLocked && club == null) return 1;
    if (slot == null) return 2 - shift;
    if (pickedIds.isEmpty) return 3 - shift;
    return 4 - shift;
  }

  /// Число часовых отрезков сеанса (60/120/180/… → 1/2/3/…).
  int get hourCount => (durationMinutes / 60).round().clamp(1, 12);

  /// Многочасовой сеанс с возможностью разного состава по часам.
  bool get multiHour => hourCount > 1;

  /// Станции, выбранные в час [h]. Если для часа нет явной записи —
  /// наследуется выбор ближайшего часа ниже (в т.ч. 0-го).
  Set<String> pickedAt(int h) {
    for (int k = h; k >= 0; k--) {
      final Set<String>? v = pickedByHour[k];
      if (v != null) return v;
    }
    return const <String>{};
  }

  /// Задан ли для часа [h] собственный выбор (не наследованный).
  bool isHourTouched(int h) => pickedByHour.containsKey(h);

  /// Все станции за сеанс — объединение по часам.
  Set<String> get pickedIds {
    final Set<String> out = <String>{};
    for (int h = 0; h < hourCount; h++) {
      out.addAll(pickedAt(h));
    }
    return out;
  }

  /// Сколько часов забронирована станция [id].
  int stationHours(String id) {
    int n = 0;
    for (int h = 0; h < hourCount; h++) {
      if (pickedAt(h).contains(id)) n++;
    }
    return n;
  }

  /// Число выбранных станций в час [h].
  int pickedCountAt(int h) => pickedAt(h).length;

  /// Час-сеанс менялся руками (не «как везде»).
  bool get hasHourOverrides {
    final Set<String> h0 = pickedAt(0);
    for (int h = 1; h < hourCount; h++) {
      final Set<String> hh = pickedAt(h);
      if (hh.length != h0.length || !hh.containsAll(h0)) return true;
    }
    return false;
  }

  /// Окно часа [h] внутри выбранного слота (UTC).
  (DateTime, DateTime)? hourWindow(int h) {
    final TimeSlotEntity? s = slot;
    if (s == null) return null;
    final DateTime start = s.startsAt.add(Duration(minutes: h * 60));
    return (start, start.add(const Duration(minutes: 60)));
  }

  /// Свободна ли станция в конкретном часе сеанса.
  bool isFreeAt(int h, String stationId) {
    final (DateTime, DateTime)? w = hourWindow(h);
    if (w == null) return false;
    return !busy.any((BusyIntervalEntity b) =>
        b.stationId == stationId && b.overlaps(w.$1, w.$2));
  }

  /// Свободные станции варианта зала в час [h].
  List<StationEntity> freeHallStationsAt(int h) => hallStations
      .where((StationEntity s) => s.isActive && isFreeAt(h, s.id))
      .toList();

  /// Станции выбранного варианта зала, по порядку.
  List<StationEntity> get hallStations {
    final HallOptionEntity? h = hall;
    if (h == null) return const <StationEntity>[];
    final Set<String> rooms = h.roomIds.toSet();
    return stations.where((StationEntity s) => rooms.contains(s.roomId)).toList()
      ..sort((StationEntity a, StationEntity b) => a.sortOrder.compareTo(b.sortOrder));
  }

  /// Id станций варианта зала.
  List<String> get hallStationIds =>
      hallStations.map((StationEntity s) => s.id).toList(growable: false);

  /// Свободна ли станция на весь выбранный слот (во все часы).
  bool isFree(String stationId) {
    if (slot == null) return false;
    for (int h = 0; h < hourCount; h++) {
      if (!isFreeAt(h, stationId)) return false;
    }
    return true;
  }

  /// Свободные станции варианта зала в выбранном слоте.
  List<StationEntity> get freeHallStations =>
      hallStations.where((StationEntity s) => s.isActive && isFree(s.id)).toList();

  /// Сколько станций варианта зала свободно в конкретном слоте.
  int freeCountAt(TimeSlotEntity s) {
    return hallStations
        .where((StationEntity st) =>
            st.isActive &&
            !busy.any((BusyIntervalEntity b) =>
                b.stationId == st.id && b.overlaps(s.startsAt, s.endsAt)))
        .length;
  }

  /// В зале на выбранную дату нет ни одного свободного слота.
  bool get dayEmpty =>
      hall != null && slots.isNotEmpty && slots.every((TimeSlotEntity s) => freeCountAt(s) == 0);

  /// Всего станций в варианте зала.
  int get hallCapacity => hall?.capacity ?? 0;

  /// Пакеты, доступные для выбранного зала (по комнате пакета).
  List<PackageEntity> get hallPackages {
    final HallOptionEntity? h = hall;
    if (h == null || h.isCombo) return const <PackageEntity>[];
    final String? roomId = h.roomIds.length == 1 ? h.roomIds.first : null;
    return packages
        .where((PackageEntity p) => p.roomId == null || p.roomId == roomId)
        .toList(growable: false);
  }

  /// Выбранный пакет как сущность.
  PackageEntity? get selectedPackage {
    final String? id = selectedPackageId;
    if (id == null) return null;
    for (final PackageEntity p in packages) {
      if (p.id == id) return p;
    }
    return null;
  }

  /// Можно ли применить пакет [p] к текущему слоту: хватает ли свободных
  /// станций каждого типа и укладывается ли длительность в сетку до закрытия.
  ({bool ok, String reason}) packageFit(PackageEntity p) {
    final ClubEntity? c = club;
    final TimeSlotEntity? s = slot;
    if (c == null || s == null) return (ok: false, reason: 'Выберите время');

    int freeVr = 0;
    int freePs = 0;
    for (final StationEntity st in hallStations) {
      if (!st.isActive) continue;
      if (!(isFree(st.id) || pickedIds.contains(st.id))) continue;
      if (st.type == StationType.ps5) {
        freePs++;
      } else {
        freeVr++;
      }
    }
    if (freeVr < p.headsets || freePs < p.consoles) {
      return (ok: false, reason: 'на это время не хватает свободных мест');
    }

    final DateTime wall = ClubClock(c).toWall(s.startsAt);
    final int startWall = wall.hour * 60 + wall.minute;
    final int step = p.minutes + c.slotGapMinutes;
    if (startWall + p.minutes > c.closeTime.inMinutes) {
      return (ok: false, reason: 'не влезает до закрытия — выберите время раньше');
    }
    if ((startWall - c.openTime.inMinutes) % step != 0) {
      return (ok: false, reason: 'для пакета на ${p.minutes ~/ 60} ч выберите слот раньше');
    }
    return (ok: true, reason: '');
  }

  /// Текущий выбор станций и длительность совпадают с выбранным пакетом.
  /// Пакет — одинаковый состав на весь сеанс, поэтому при разных станциях
  /// по часам он не применяется.
  bool get packageApplies {
    final PackageEntity? p = selectedPackage;
    if (p == null || durationMinutes != p.minutes || hasHourOverrides) return false;
    int vr = 0;
    int ps = 0;
    for (final StationEntity s in stations) {
      if (!pickedIds.contains(s.id)) continue;
      if (s.type == StationType.ps5) {
        ps++;
      } else {
        vr++;
      }
    }
    return vr == p.headsets && ps == p.consoles;
  }

  /// Свободная станция для замены при конфликте.
  StationEntity? get conflictAlternative {
    for (final StationEntity s in freeHallStations) {
      if (!pickedIds.contains(s.id)) return s;
    }
    return null;
  }

  /// Готовы ли контактные данные.
  bool get isContactValid =>
      clientName.trim().length > 1 &&
      clientPhone.replaceAll(RegExp(r'[^0-9]'), '').length >= 10;

  /// Можно ли отправлять бронь: слот выбран, контакты валидны и в каждом
  /// часе сеанса выбрана хотя бы одна станция.
  bool get canSubmit {
    if (slot == null || !isContactValid) return false;
    for (int h = 0; h < hourCount; h++) {
      if (pickedAt(h).isEmpty) return false;
    }
    return true;
  }

  /// Копия с изменениями.
  BookingState copyWith({
    BookingStage? view,
    BookingStatus? status,
    bool? clubLocked,
    List<ClubEntity>? clubs,
    ClubEntity? club,
    List<StationEntity>? stations,
    List<PriceRateEntity>? prices,
    List<PackageEntity>? packages,
    String? selectedPackageId,
    List<HallOptionEntity>? hallOptions,
    HallOptionEntity? hall,
    DateTime? date,
    int? durationMinutes,
    List<TimeSlotEntity>? slots,
    List<BusyIntervalEntity>? busy,
    TimeSlotEntity? slot,
    Map<int, Set<String>>? pickedByHour,
    bool clearPicks = false,
    Set<String>? takenIds,
    bool? conflictShown,
    String? clientName,
    String? clientPhone,
    String? peopleInput,
    QuoteEntity? quote,
    AccountEntity? account,
    List<SavedBookingEntity>? savedBookings,
    bool? accountLoginOpen,
    String? accountLoginPhone,
    bool? accountListOpen,
    String? createdOrderId,
    String? errorMessage,
    bool clearSlot = false,
    bool clearAccount = false,
    bool clearHall = false,
    bool clearPackage = false,
    bool clearError = true,
  }) {
    return BookingState(
      view: view ?? this.view,
      status: status ?? this.status,
      clubLocked: clubLocked ?? this.clubLocked,
      clubs: clubs ?? this.clubs,
      club: club ?? this.club,
      stations: stations ?? this.stations,
      prices: prices ?? this.prices,
      packages: packages ?? this.packages,
      selectedPackageId:
          clearPackage ? null : (selectedPackageId ?? this.selectedPackageId),
      hallOptions: hallOptions ?? this.hallOptions,
      hall: clearHall ? null : (hall ?? this.hall),
      date: date ?? this.date,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      slots: slots ?? this.slots,
      busy: busy ?? this.busy,
      slot: clearSlot ? null : (slot ?? this.slot),
      pickedByHour: clearPicks
          ? const <int, Set<String>>{}
          : (pickedByHour ?? this.pickedByHour),
      takenIds: takenIds ?? this.takenIds,
      conflictShown: conflictShown ?? this.conflictShown,
      clientName: clientName ?? this.clientName,
      clientPhone: clientPhone ?? this.clientPhone,
      peopleInput: peopleInput ?? this.peopleInput,
      quote: quote ?? this.quote,
      account: clearAccount ? null : (account ?? this.account),
      savedBookings: savedBookings ?? this.savedBookings,
      accountLoginOpen: accountLoginOpen ?? this.accountLoginOpen,
      accountLoginPhone: accountLoginPhone ?? this.accountLoginPhone,
      accountListOpen: accountListOpen ?? this.accountListOpen,
      createdOrderId: createdOrderId ?? this.createdOrderId,
      errorMessage: clearError ? errorMessage : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => <Object?>[
        view,
        status,
        clubLocked,
        clubs,
        club,
        stations,
        prices,
        packages,
        selectedPackageId,
        hallOptions,
        hall,
        date,
        durationMinutes,
        slots,
        busy,
        slot,
        pickedByHour,
        takenIds,
        conflictShown,
        clientName,
        clientPhone,
        peopleInput,
        quote,
        account,
        savedBookings,
        accountLoginOpen,
        accountLoginPhone,
        accountListOpen,
        createdOrderId,
        errorMessage,
      ];
}
