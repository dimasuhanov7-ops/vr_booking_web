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

/// Станция добавлена/убрана из выбора.
class BookingStationToggled extends BookingEvent {
  /// Создаёт событие.
  const BookingStationToggled(this.stationId);

  /// Идентификатор станции.
  final String stationId;

  @override
  List<Object?> get props => <Object?>[stationId];
}

/// Быстрый выбор: взять сразу [count] свободных станций (`-1` — все).
class BookingQuickPicked extends BookingEvent {
  /// Создаёт событие.
  const BookingQuickPicked(this.count);

  /// Сколько станций взять (`-1` — все свободные).
  final int count;

  @override
  List<Object?> get props => <Object?>[count];
}

/// Сбросить выбор станций.
class BookingSelectionCleared extends BookingEvent {
  /// Создаёт событие.
  const BookingSelectionCleared();
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
