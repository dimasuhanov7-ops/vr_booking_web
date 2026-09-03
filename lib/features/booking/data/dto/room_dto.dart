import '../../domain/entity/room_entity.dart';

/// DTO строки таблицы `public.booking_rooms`.
class RoomDto {
  /// Создаёт DTO.
  const RoomDto({
    required this.id,
    required this.clubId,
    required this.name,
    required this.sortOrder,
  });

  /// Разбирает JSON от Supabase.
  factory RoomDto.fromJson(Map<String, dynamic> json) => RoomDto(
        id: json['id'] as String,
        clubId: json['club_id'] as String,
        name: json['name'] as String,
        sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
      );

  /// Идентификатор зала.
  final String id;

  /// Идентификатор клуба.
  final String clubId;

  /// Название зала.
  final String name;

  /// Порядок отображения.
  final int sortOrder;

  /// Преобразует DTO в доменную сущность.
  RoomEntity toEntity() => RoomEntity(
        id: id,
        clubId: clubId,
        name: name,
        sortOrder: sortOrder,
      );
}
