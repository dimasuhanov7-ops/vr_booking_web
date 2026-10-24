import '../../domain/entity/price_rate_entity.dart';
import '../../domain/entity/station_entity.dart';

/// DTO строки таблицы `public.booking_prices`.
class PriceRateDto {
  /// Создаёт DTO.
  const PriceRateDto({
    required this.stationType,
    required this.dayKind,
    required this.pricePerHour,
    this.minQty = 1,
    this.roomId,
  });

  /// Разбирает JSON от Supabase.
  factory PriceRateDto.fromJson(Map<String, dynamic> json) => PriceRateDto(
        stationType: json['station_type'] as String,
        dayKind: json['day_kind'] as String,
        pricePerHour: json['price_per_hour'] as num,
        // Столбца может не быть в старой схеме — тогда это базовая ступень.
        minQty: (json['min_qty'] as num?)?.toInt() ?? 1,
        // Строки booking_room_prices (цена зала) приходят с room_id.
        roomId: json['room_id'] as String?,
      );

  /// Тип станции (`vr_headset` / `ps5`).
  final String stationType;

  /// Тип дня (`weekday` / `weekend`).
  final String dayKind;

  /// Цена за час.
  final num pricePerHour;

  /// С какого количества станций действует цена.
  final int minQty;

  /// Зал, если это цена зала, а не тариф клуба.
  final String? roomId;

  /// В доменную сущность.
  PriceRateEntity toEntity() => PriceRateEntity(
        stationType: StationType.fromRaw(stationType),
        dayKind: DayKind.fromRaw(dayKind),
        pricePerHour: pricePerHour,
        minQty: minQty,
        roomId: roomId,
      );
}
