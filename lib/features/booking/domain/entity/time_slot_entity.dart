import 'package:equatable/equatable.dart';

/// Слот сетки бронирования: старт сеанса заданной длительности.
class TimeSlotEntity extends Equatable {
  /// Создаёт слот.
  const TimeSlotEntity({
    required this.startsAt,
    required this.endsAt,
  });

  /// Начало сеанса (абсолютный момент, UTC).
  final DateTime startsAt;

  /// Конец сеанса (UTC).
  final DateTime endsAt;

  /// Длительность слота.
  Duration get duration => endsAt.difference(startsAt);

  @override
  List<Object?> get props => <Object?>[startsAt, endsAt];
}
