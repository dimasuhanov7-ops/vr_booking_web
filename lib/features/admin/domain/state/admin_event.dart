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
  const AdminFilterChanged({this.day, this.hallId, this.type, this.status});

  /// Фильтр дня (`-1` — все).
  final int? day;

  /// Фильтр зала (`''` — все).
  final String? hallId;

  /// Фильтр типа.
  final AdminTypeFilter? type;

  /// Фильтр статуса.
  final AdminStatusFilter? status;

  @override
  List<Object?> get props => <Object?>[day, hallId, type, status];
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
