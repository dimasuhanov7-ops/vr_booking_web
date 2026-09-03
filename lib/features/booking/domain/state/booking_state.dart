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
    this.clubs = const <ClubEntity>[],
    this.club,
    this.stations = const <StationEntity>[],
    this.prices = const <PriceRateEntity>[],
    this.hallOptions = const <HallOptionEntity>[],
    this.hall,
    this.date,
    this.durationMinutes = 60,
    this.slots = const <TimeSlotEntity>[],
    this.busy = const <BusyIntervalEntity>[],
    this.slot,
    this.pickedIds = const <String>{},
    this.takenIds = const <String>{},
    this.conflictShown = false,
    this.clientName = '',
    this.clientPhone = '',
    this.peopleInput = '',
    this.quote = QuoteEntity.empty,
    this.createdOrderId,
    this.errorMessage,
  });

  /// Форма / успех.
  final BookingStage view;

  /// Статус.
  final BookingStatus status;

  /// Клубы.
  final List<ClubEntity> clubs;

  /// Выбранный клуб.
  final ClubEntity? club;

  /// Все станции клуба.
  final List<StationEntity> stations;

  /// Тарифы клуба.
  final List<PriceRateEntity> prices;

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

  /// Выбранные станции.
  final Set<String> pickedIds;

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

  /// Идентификатор созданной брони.
  final String? createdOrderId;

  /// Текст ошибки.
  final String? errorMessage;

  /// Шаг мастера (1..4) — для заголовка.
  int get stepNo {
    if (club == null) return 1;
    if (slot == null) return 2;
    if (pickedIds.isEmpty) return 3;
    return 4;
  }

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

  /// Свободна ли станция в выбранном слоте.
  bool isFree(String stationId) {
    final TimeSlotEntity? s = slot;
    if (s == null) return false;
    return !busy.any((BusyIntervalEntity b) =>
        b.stationId == stationId && b.overlaps(s.startsAt, s.endsAt));
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

  /// Можно ли отправлять бронь.
  bool get canSubmit => slot != null && pickedIds.isNotEmpty && isContactValid;

  /// Копия с изменениями.
  BookingState copyWith({
    BookingStage? view,
    BookingStatus? status,
    List<ClubEntity>? clubs,
    ClubEntity? club,
    List<StationEntity>? stations,
    List<PriceRateEntity>? prices,
    List<HallOptionEntity>? hallOptions,
    HallOptionEntity? hall,
    DateTime? date,
    int? durationMinutes,
    List<TimeSlotEntity>? slots,
    List<BusyIntervalEntity>? busy,
    TimeSlotEntity? slot,
    Set<String>? pickedIds,
    Set<String>? takenIds,
    bool? conflictShown,
    String? clientName,
    String? clientPhone,
    String? peopleInput,
    QuoteEntity? quote,
    String? createdOrderId,
    String? errorMessage,
    bool clearSlot = false,
    bool clearError = true,
  }) {
    return BookingState(
      view: view ?? this.view,
      status: status ?? this.status,
      clubs: clubs ?? this.clubs,
      club: club ?? this.club,
      stations: stations ?? this.stations,
      prices: prices ?? this.prices,
      hallOptions: hallOptions ?? this.hallOptions,
      hall: hall ?? this.hall,
      date: date ?? this.date,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      slots: slots ?? this.slots,
      busy: busy ?? this.busy,
      slot: clearSlot ? null : (slot ?? this.slot),
      pickedIds: pickedIds ?? this.pickedIds,
      takenIds: takenIds ?? this.takenIds,
      conflictShown: conflictShown ?? this.conflictShown,
      clientName: clientName ?? this.clientName,
      clientPhone: clientPhone ?? this.clientPhone,
      peopleInput: peopleInput ?? this.peopleInput,
      quote: quote ?? this.quote,
      createdOrderId: createdOrderId ?? this.createdOrderId,
      errorMessage: clearError ? errorMessage : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => <Object?>[
        view,
        status,
        clubs,
        club,
        stations,
        prices,
        hallOptions,
        hall,
        date,
        durationMinutes,
        slots,
        busy,
        slot,
        pickedIds,
        takenIds,
        conflictShown,
        clientName,
        clientPhone,
        peopleInput,
        quote,
        createdOrderId,
        errorMessage,
      ];
}
