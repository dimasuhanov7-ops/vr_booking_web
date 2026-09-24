import 'package:equatable/equatable.dart';

/// Запись журнала действий (`booking_audit_log`): кто, когда и что поменял.
class AuditEntryEntity extends Equatable {
  /// Создаёт запись.
  const AuditEntryEntity({
    required this.id,
    required this.at,
    required this.entity,
    required this.action,
    this.actorId,
    this.actorName,
    this.before,
    this.after,
  });

  /// Идентификатор записи журнала.
  final int id;

  /// Когда (UTC).
  final DateTime at;

  /// Таблица: `booking_prices`, `booking_packages`, `booking_availability`,
  /// `booking_clubs`, `booking_orders`.
  final String entity;

  /// `insert` / `update` / `delete`.
  final String action;

  /// Кто сделал (`auth.users.id`); `null` — клиент или системный вызов.
  final String? actorId;

  /// Имя сотрудника из `booking_staff`, если известно.
  final String? actorName;

  /// Строка до изменения.
  final Map<String, dynamic>? before;

  /// Строка после изменения.
  final Map<String, dynamic>? after;

  /// Клуб, к которому относится изменение, если он есть в строке
  /// (у самой `booking_clubs` это её `id`).
  String? get clubId {
    final String key = entity == 'booking_clubs' ? 'id' : 'club_id';
    return (after?[key] ?? before?[key]) as String?;
  }

  @override
  List<Object?> get props =>
      <Object?>[id, at, entity, action, actorId, actorName, before, after];
}
