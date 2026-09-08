import '../../domain/entity/package_entity.dart';

/// DTO строки таблицы `public.booking_packages`.
class PackageDto {
  /// Создаёт DTO.
  const PackageDto({
    required this.id,
    required this.clubId,
    required this.roomId,
    required this.name,
    required this.headsets,
    required this.consoles,
    required this.minutes,
    required this.price,
    required this.note,
    required this.sortOrder,
  });

  /// Разбирает JSON от Supabase / Edge Function.
  factory PackageDto.fromJson(Map<String, dynamic> json) => PackageDto(
        id: json['id'] as String,
        clubId: json['club_id'] as String,
        roomId: json['room_id'] as String?,
        name: json['name'] as String,
        headsets: (json['headsets'] as num?)?.toInt() ?? 0,
        consoles: (json['consoles'] as num?)?.toInt() ?? 0,
        minutes: (json['minutes'] as num).toInt(),
        price: json['price'] as num,
        note: json['note'] as String? ?? '',
        sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
      );

  /// Идентификатор.
  final String id;

  /// Клуб.
  final String clubId;

  /// Зал.
  final String? roomId;

  /// Название.
  final String name;

  /// VR-шлемов.
  final int headsets;

  /// PS5.
  final int consoles;

  /// Длительность, минут.
  final int minutes;

  /// Цена, ₽.
  final num price;

  /// Пояснение.
  final String note;

  /// Порядок.
  final int sortOrder;

  /// В доменную сущность.
  PackageEntity toEntity() => PackageEntity(
        id: id,
        clubId: clubId,
        roomId: roomId,
        name: name,
        headsets: headsets,
        consoles: consoles,
        minutes: minutes,
        price: price,
        note: note,
        sortOrder: sortOrder,
      );
}
