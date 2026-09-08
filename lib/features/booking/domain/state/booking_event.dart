part of 'booking_bloc.dart';

/// Базовое событие виджета бронирования.
sealed class BookingEvent extends Equatable {
  const BookingEvent();

  @override
  List<Object?> get props => <Object?>[];
}

/// Первичная загрузка (список клубов).
class BookingStarted extends BookingEvent {
  /// Создаёт событие старта.
  const BookingStarted();
}

/// Выбран клуб.
class BookingClubSelected extends BookingEvent {
  /// Создаёт событие.
  const BookingClubSelected(this.club);

  /// Клуб.
  final ClubEntity club;

  @override
  List<Object?> get props => <Object?>[club];
}

/// Выбран зал (или вариант «Весь клуб»).
class BookingHallSelected extends BookingEvent {
  /// Создаёт событие.
  const BookingHallSelected(this.hall);

  /// Вариант зала.
  final HallOptionEntity hall;

  @override
  List<Object?> get props => <Object?>[hall];
}

/// Выбрана дата.
class BookingDateSelected extends BookingEvent {
  /// Создаёт событие.
  const BookingDateSelected(this.date);

  /// Дата (календарный день).
  final DateTime date;

  @override
  List<Object?> get props => <Object?>[date];
}

/// Выбрана длительность сеанса (минут).
class BookingDurationSelected extends BookingEvent {
  /// Создаёт событие.
  const BookingDurationSelected(this.minutes);

  /// Длительность, минут.
  final int minutes;

  @override
  List<Object?> get props => <Object?>[minutes];
}

/// Выбран слот времени.
class BookingSlotSelected extends BookingEvent {
  /// Создаёт событие.
  const BookingSlotSelected(this.slot);

  /// Слот.
  final TimeSlotEntity slot;

  @override
  List<Object?> get props => <Object?>[slot];
}

/// Станция добавлена/убрана из выбора в конкретном часе сеанса.
class BookingStationToggled extends BookingEvent {
  /// Создаёт событие.
  const BookingStationToggled(this.stationId, {this.hour = 0});

  /// Идентификатор станции.
  final String stationId;

  /// Час сеанса (0-й, 1-й, …).
  final int hour;

  @override
  List<Object?> get props => <Object?>[stationId, hour];
}

/// Выбран/снят пакет. `null` — снять.
class BookingPackageSelected extends BookingEvent {
  /// Создаёт событие.
  const BookingPackageSelected(this.package);

  /// Пакет или `null` для снятия.
  final PackageEntity? package;

  @override
  List<Object?> get props => <Object?>[package];
}

/// Быстрый выбор: взять сразу [count] свободных станций (`-1` — все).
class BookingQuickPicked extends BookingEvent {
  /// Создаёт событие.
  const BookingQuickPicked(this.count, {this.hour = 0});

  /// Сколько станций взять (`-1` — все свободные).
  final int count;

  /// Час сеанса.
  final int hour;

  @override
  List<Object?> get props => <Object?>[count, hour];
}

/// Сбросить выбор станций. [hour] `null` — во всём сеансе, иначе — в этом часе.
class BookingSelectionCleared extends BookingEvent {
  /// Создаёт событие.
  const BookingSelectionCleared({this.hour});

  /// Час сеанса (`null` — весь сеанс).
  final int? hour;

  @override
  List<Object?> get props => <Object?>[hour];
}

/// Скопировать состав часа [from] в час [to] («как в 1-м часе»).
class BookingHourCopied extends BookingEvent {
  /// Создаёт событие.
  const BookingHourCopied({required this.from, required this.to});

  /// Источник.
  final int from;

  /// Куда.
  final int to;

  @override
  List<Object?> get props => <Object?>[from, to];
}

/// Изменены контактные данные.
class BookingContactChanged extends BookingEvent {
  /// Создаёт событие.
  const BookingContactChanged({this.name, this.phone, this.people});

  /// Имя.
  final String? name;

  /// Телефон.
  final String? phone;

  /// Число людей.
  final String? people;

  @override
  List<Object?> get props => <Object?>[name, phone, people];
}

/// Обновить доступность (после конфликта / вручную).
class BookingAvailabilityRefreshed extends BookingEvent {
  /// Создаёт событие.
  const BookingAvailabilityRefreshed();
}

/// Подтверждение брони.
class BookingSubmitted extends BookingEvent {
  /// Создаёт событие.
  const BookingSubmitted();
}

/// Действие по плашке конфликта (взять замену / продолжить без станции).
class BookingConflictResolved extends BookingEvent {
  /// Создаёт событие.
  const BookingConflictResolved();
}

/// Закрыть конфликт и выбрать другое время.
class BookingConflictDismissed extends BookingEvent {
  /// Создаёт событие.
  const BookingConflictDismissed();
}

/// Начать новую бронь.
class BookingResetRequested extends BookingEvent {
  /// Создаёт событие.
  const BookingResetRequested();
}

/// Открыть/закрыть панель входа по телефону.
class BookingAccountLoginToggled extends BookingEvent {
  /// Создаёт событие.
  const BookingAccountLoginToggled();
}

/// Ввод телефона в панели входа.
class BookingAccountLoginPhoneChanged extends BookingEvent {
  /// Создаёт событие.
  const BookingAccountLoginPhoneChanged(this.phone);

  /// Введённый телефон.
  final String phone;

  @override
  List<Object?> get props => <Object?>[phone];
}

/// Подтвердить вход по телефону.
class BookingAccountLoginSubmitted extends BookingEvent {
  /// Создаёт событие.
  const BookingAccountLoginSubmitted();
}

/// Выйти (забыть клиента).
class BookingAccountLoggedOut extends BookingEvent {
  /// Создаёт событие.
  const BookingAccountLoggedOut();
}

/// Открыть/закрыть список «мои брони».
class BookingAccountListToggled extends BookingEvent {
  /// Создаёт событие.
  const BookingAccountListToggled();
}
