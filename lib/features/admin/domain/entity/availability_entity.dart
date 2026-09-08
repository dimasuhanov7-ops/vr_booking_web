import 'package:equatable/equatable.dart';

/// Одно закрытие из `booking_availability`.
///
/// Строка означает «здесь нельзя бронировать». Комбинации полей:
/// * [hallId] `null` — все залы клуба, иначе конкретный зал;
/// * [day] `null` — бессрочно (зал закрыт совсем), иначе конкретная дата;
/// * [fromMinutes] `null` — весь рабочий день, иначе окно.
class ClosureEntity extends Equatable {
  /// Создаёт закрытие.
  const ClosureEntity({
    required this.id,
    required this.clubId,
    this.hallId,
    this.day,
    this.fromMinutes,
    this.toMinutes,
  });

  /// Идентификатор строки (нужен для удаления).
  final String id;

  /// Клуб.
  final String clubId;

  /// Зал; `null` — весь клуб.
  final String? hallId;

  /// Дата; `null` — бессрочно.
  final DateTime? day;

  /// Начало окна, минут от полуночи; `null` — весь день.
  final int? fromMinutes;

  /// Конец окна, минут от полуночи.
  final int? toMinutes;

  /// Закрыт ли зал целиком и бессрочно (а не отдельное окно).
  bool get isWholeHall => hallId != null && day == null && fromMinutes == null;

  @override
  List<Object?> get props =>
      <Object?>[id, clubId, hallId, day, fromMinutes, toMinutes];
}

/// Состояние доступности на старте админки.
class AvailabilityEntity extends Equatable {
  /// Создаёт состояние.
  const AvailabilityEntity({
    this.pausedClubIds = const <String>{},
    this.closures = const <ClosureEntity>[],
  });

  /// Клубы, у которых приём онлайн-броней на паузе (`intake_open = false`).
  final Set<String> pausedClubIds;

  /// Закрытые залы и окна.
  final List<ClosureEntity> closures;

  @override
  List<Object?> get props => <Object?>[pausedClubIds, closures];
}
