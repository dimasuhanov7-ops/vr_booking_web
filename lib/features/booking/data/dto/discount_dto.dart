import '../../domain/entity/discount_entity.dart';

/// DTO результата RPC `booking_validate_discount`.
class DiscountDto {
  /// Создаёт DTO.
  const DiscountDto({
    required this.id,
    required this.kind,
    required this.value,
    required this.minStations,
    this.code,
    this.title,
  });

  /// Разбирает JSON-строку результата RPC.
  factory DiscountDto.fromJson(Map<String, dynamic> json) => DiscountDto(
        id: json['id'] as String,
        code: json['code'] as String?,
        title: json['title'] as String?,
        kind: json['kind'] as String,
        value: json['value'] as num,
        minStations: (json['min_stations'] as num).toInt(),
      );

  /// Идентификатор скидки.
  final String id;

  /// Промокод (или `null` для автоскидки).
  final String? code;

  /// Название.
  final String? title;

  /// Тип начисления (`percent` / `fixed`).
  final String kind;

  /// Величина скидки.
  final num value;

  /// Минимальное число станций.
  final int minStations;

  /// Преобразует DTO в доменную сущность.
  DiscountEntity toEntity() => DiscountEntity(
        id: id,
        code: code,
        title: title,
        kind: DiscountKind.fromRaw(kind),
        value: value,
        minStations: minStations,
      );
}
