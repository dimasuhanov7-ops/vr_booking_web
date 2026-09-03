import '../../domain/entity/station_entity.dart';

/// DTO строки таблицы `public.booking_stations`
/// (с присоединённым названием зала).
class StationDto {
  /// Создаёт DTO.
  const StationDto({
    required this.id,
    required this.roomId,
    required this.roomName,
    required this.type,
    required this.label,
    required this.rowIndex,
    required this.positionInRow,
    required this.sortOrder,
    required this.isActive,
  });

  /// Разбирает JSON от Supabase.
  ///
  /// Название зала берётся из вложенного `booking_rooms` (при join через select)
  /// или из плоского поля `room_name`.
  factory StationDto.fromJson(Map<String, dynamic> json) {
    final Object? room = json['booking_rooms'] ?? json['room'];
    final String roomName = room is Map<String, dynamic>
        ? (room['name'] as String? ?? '')
        : (json['room_name'] as String? ?? '');
    return StationDto(
      id: json['id'] as String,
      roomId: json['room_id'] as String,
      roomName: roomName,
      type: json['type'] as String,
      label: json['label'] as String,
      rowIndex: (json['row_index'] as num?)?.toInt() ?? 0,
      positionInRow: (json['position_in_row'] as num?)?.toInt() ?? 0,
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  /// Идентификатор станции.
  final String id;

  /// Идентификатор зала.
  final String roomId;

  /// Название зала.
  final String roomName;

  /// Тип (`vr_headset` / `ps5`).
  final String type;

  /// Номер/название.
  final String label;

  /// Индекс ряда.
  final int rowIndex;

  /// Позиция в ряду.
  final int positionInRow;

  /// Порядок отображения.
  final int sortOrder;

  /// Активна ли.
  final bool isActive;

  /// В доменную сущность.
  StationEntity toEntity() => StationEntity(
        id: id,
        roomId: roomId,
        roomName: roomName,
        type: StationType.fromRaw(type),
        label: label,
        rowIndex: rowIndex,
        positionInRow: positionInRow,
        sortOrder: sortOrder,
        isActive: isActive,
      );
}
