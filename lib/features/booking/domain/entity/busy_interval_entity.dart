import 'package:equatable/equatable.dart';

/// Занятый интервал конкретной станции (без персональных данных клиента).
class BusyIntervalEntity extends Equatable {
  /// Создаёт занятый интервал.
  const BusyIntervalEntity({
    required this.stationId,
    required this.roomId,
    required this.startsAt,
    required this.endsAt,
  });

  /// Идентификатор занятой станции.
  final String stationId;

  /// Зал станции.
  final String roomId;

  /// Начало занятого интервала (UTC).
  final DateTime startsAt;

  /// Конец занятого интервала (UTC).
  final DateTime endsAt;

  /// Пересекается ли интервал с полуинтервалом `[from, to)`.
  bool overlaps(DateTime from, DateTime to) =>
      startsAt.isBefore(to) && endsAt.isAfter(from);

  @override
  List<Object?> get props => <Object?>[stationId, roomId, startsAt, endsAt];
}
