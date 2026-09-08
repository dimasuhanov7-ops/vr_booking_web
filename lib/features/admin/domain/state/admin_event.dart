part of 'admin_bloc.dart';

/// Базовое событие админки.
sealed class AdminEvent extends Equatable {
  const AdminEvent();

  @override
  List<Object?> get props => <Object?>[];
}

/// Первичная загрузка.
class AdminStarted extends AdminEvent {
  /// Создаёт событие.
  const AdminStarted();
}

/// Смена клуба.
class AdminClubChanged extends AdminEvent {
  /// Создаёт событие.
  const AdminClubChanged(this.clubId);

  /// Идентификатор клуба.
  final String clubId;

  @override
  List<Object?> get props => <Object?>[clubId];
}

/// Смена вкладки.
class AdminTabChanged extends AdminEvent {
  /// Создаёт событие.
  const AdminTabChanged(this.tab);

  /// Вкладка.
  final AdminTab tab;

  @override
  List<Object?> get props => <Object?>[tab];
}

/// Правка тарифа зала.
class AdminPriceChanged extends AdminEvent {
  /// Создаёт событие.
  const AdminPriceChanged({
    required this.hallId,
    required this.field,
    required this.value,
  });

  /// Зал.
  final String hallId;

  /// Поле тарифа.
  final PriceField field;

  /// Новое значение.
  final int value;

  @override
  List<Object?> get props => <Object?>[hallId, field, value];
}

/// Правка числового поля пакета.
class AdminPackageFieldChanged extends AdminEvent {
  /// Создаёт событие.
  const AdminPackageFieldChanged({
    required this.packageId,
    required this.field,
    required this.value,
  });

  /// Идентификатор пакета.
  final String packageId;

  /// Поле.
  final PackageField field;

  /// Новое значение.
  final int value;

  @override
  List<Object?> get props => <Object?>[packageId, field, value];
}

/// Включить/выключить пакет.
class AdminPackageToggled extends AdminEvent {
  /// Создаёт событие.
  const AdminPackageToggled(this.packageId);

  /// Идентификатор пакета.
  final String packageId;

  @override
  List<Object?> get props => <Object?>[packageId];
}

/// Удалить пакет.
class AdminPackageDeleted extends AdminEvent {
  /// Создаёт событие.
  const AdminPackageDeleted(this.packageId);

  /// Идентификатор пакета.
  final String packageId;

  @override
  List<Object?> get props => <Object?>[packageId];
}

/// Правка формы нового пакета.
class AdminNewPackageChanged extends AdminEvent {
  /// Создаёт событие.
  const AdminNewPackageChanged({
    this.name,
    this.hallId,
    this.headsets,
    this.consoles,
    this.minutes,
    this.price,
  });

  /// Название.
  final String? name;

  /// Зал.
  final String? hallId;

  /// VR-шлемов.
  final int? headsets;

  /// PS5.
  final int? consoles;

  /// Минут.
  final int? minutes;

  /// Цена.
  final int? price;

  @override
  List<Object?> get props => <Object?>[name, hallId, headsets, consoles, minutes, price];
}

/// Добавить новый пакет.
class AdminNewPackageSubmitted extends AdminEvent {
  /// Создаёт событие.
  const AdminNewPackageSubmitted();
}

/// Переключить приём заявок.
class AdminIntakeToggled extends AdminEvent {
  /// Создаёт событие.
  const AdminIntakeToggled();
}

/// Закрыть/открыть зал.
class AdminHallClosureToggled extends AdminEvent {
  /// Создаёт событие.
  const AdminHallClosureToggled(this.hallId);

  /// Зал.
  final String hallId;

  @override
  List<Object?> get props => <Object?>[hallId];
}

/// Смена дня в сетке закрытия слотов.
class AdminAvailDayChanged extends AdminEvent {
  /// Создаёт событие.
  const AdminAvailDayChanged(this.dayIndex);

  /// Индекс дня.
  final int dayIndex;

  @override
  List<Object?> get props => <Object?>[dayIndex];
}

/// Закрыть/открыть отдельный слот выбранного дня.
class AdminSlotClosureToggled extends AdminEvent {
  /// Создаёт событие.
  const AdminSlotClosureToggled(this.startMinutes);

  /// Старт слота, минут.
  final int startMinutes;

  @override
  List<Object?> get props => <Object?>[startMinutes];
}

/// Закрыть/открыть весь выбранный день.
class AdminDayClosureChanged extends AdminEvent {
  /// Создаёт событие.
  const AdminDayClosureChanged({required this.closeAll});

  /// `true` — закрыть все слоты дня, `false` — открыть.
  final bool closeAll;

  @override
  List<Object?> get props => <Object?>[closeAll];
}

/// Смена фильтра журнала.
class AdminFilterChanged extends AdminEvent {
  /// Создаёт событие.
  const AdminFilterChanged({this.day, this.hallId, this.type});

  /// Фильтр дня (`-1` — все).
  final int? day;

  /// Фильтр зала (`''` — все).
  final String? hallId;

  /// Фильтр типа.
  final AdminTypeFilter? type;

  @override
  List<Object?> get props => <Object?>[day, hallId, type];
}

/// Отменить/вернуть запись.
class AdminRowCancelToggled extends AdminEvent {
  /// Создаёт событие.
  const AdminRowCancelToggled(this.rowId);

  /// Идентификатор записи.
  final String rowId;

  @override
  List<Object?> get props => <Object?>[rowId];
}

/// Открыть карточку брони.
class AdminRowOpened extends AdminEvent {
  /// Создаёт событие.
  const AdminRowOpened(this.rowId);

  /// Идентификатор записи.
  final String rowId;

  @override
  List<Object?> get props => <Object?>[rowId];
}

/// Закрыть карточку брони.
class AdminRowClosed extends AdminEvent {
  /// Создаёт событие.
  const AdminRowClosed();
}

/// Правка поля открытой брони (оверлей, на сервер не уходит).
class AdminRowEdited extends AdminEvent {
  /// Создаёт событие.
  const AdminRowEdited({
    required this.rowId,
    this.clientName,
    this.phone,
    this.startMinutes,
    this.durationMinutes,
    this.headsets,
    this.consoles,
    this.prepay,
    this.note,
  });

  /// Идентификатор записи.
  final String rowId;

  /// Имя.
  final String? clientName;

  /// Телефон.
  final String? phone;

  /// Начало, минут.
  final int? startMinutes;

  /// Длительность, минут.
  final int? durationMinutes;

  /// VR-шлемов.
  final int? headsets;

  /// PS5.
  final int? consoles;

  /// Предоплата, ₽.
  final int? prepay;

  /// Комментарий.
  final String? note;

  @override
  List<Object?> get props => <Object?>[
        rowId,
        clientName,
        phone,
        startMinutes,
        durationMinutes,
        headsets,
        consoles,
        prepay,
        note,
      ];
}

/// Сбросить правки брони к исходным значениям.
class AdminRowEditReset extends AdminEvent {
  /// Создаёт событие.
  const AdminRowEditReset(this.rowId);

  /// Идентификатор записи.
  final String rowId;

  @override
  List<Object?> get props => <Object?>[rowId];
}

/// Открыть drawer «Новая запись».
class AdminNewBookingOpened extends AdminEvent {
  /// Создаёт событие.
  const AdminNewBookingOpened();
}

/// Закрыть drawer «Новая запись».
class AdminNewBookingClosed extends AdminEvent {
  /// Создаёт событие.
  const AdminNewBookingClosed();
}

/// Правка черновика новой брони.
class AdminNewBookingChanged extends AdminEvent {
  /// Создаёт событие.
  const AdminNewBookingChanged({
    this.hallId,
    this.dayIndex,
    this.startMinutes,
    this.durationMinutes,
    this.headsets,
    this.consoles,
    this.hour = 0,
    this.copyHourFromFirst,
    this.name,
    this.phone,
    this.prepay,
    this.note,
  });

  /// Зал.
  final String? hallId;

  /// День.
  final int? dayIndex;

  /// Начало, минут.
  final int? startMinutes;

  /// Длительность, минут.
  final int? durationMinutes;

  /// VR-шлемов (для часа [hour]).
  final int? headsets;

  /// PS5 (для часа [hour]).
  final int? consoles;

  /// Час брони, к которому относятся [headsets]/[consoles].
  final int hour;

  /// Скопировать состав 1-го часа в этот час.
  final int? copyHourFromFirst;

  /// Имя.
  final String? name;

  /// Телефон.
  final String? phone;

  /// Предоплата, ₽.
  final int? prepay;

  /// Комментарий.
  final String? note;

  @override
  List<Object?> get props => <Object?>[
        hallId,
        dayIndex,
        startMinutes,
        hour,
        copyHourFromFirst,
        durationMinutes,
        headsets,
        consoles,
        name,
        phone,
        prepay,
        note,
      ];
}

/// Сменить видимый месяц календаря в drawer «Новая запись».
class AdminNewBookingMonthChanged extends AdminEvent {
  /// Создаёт событие.
  const AdminNewBookingMonthChanged(this.month);

  /// Первое число видимого месяца.
  final DateTime month;

  @override
  List<Object?> get props => <Object?>[month];
}

/// Создать бронь из drawer «Новая запись».
class AdminNewBookingSubmitted extends AdminEvent {
  /// Создаёт событие.
  const AdminNewBookingSubmitted();
}
