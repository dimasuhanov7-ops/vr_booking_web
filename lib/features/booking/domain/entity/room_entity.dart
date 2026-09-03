import 'package:equatable/equatable.dart';

/// Зал клуба.
class RoomEntity extends Equatable {
  /// Создаёт сущность зала.
  const RoomEntity({
    required this.id,
    required this.clubId,
    required this.name,
    required this.sortOrder,
  });

  /// Идентификатор зала.
  final String id;

  /// Идентификатор клуба.
  final String clubId;

  /// Название зала.
  final String name;

  /// Порядок отображения.
  final int sortOrder;

  @override
  List<Object?> get props => <Object?>[id, clubId, name, sortOrder];
}
