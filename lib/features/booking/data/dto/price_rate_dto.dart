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
  });

  /// Разбирает JSON от Supabase.
  factory PriceRateDto.fromJson(Map<String, dynamic> json) => PriceRateDto(
        stationType: json['station_type'] as String,
        dayKind: json['day_kind'] as String,
        pricePerHour: json['price_per_hour'] as num,
        minQty: (json['min_qty'] as num?)?.toInt() ?? 1,
      );

  /// Тип станции (`vr_headset` / `ps5`).
  final String stationType;

  /// Тип дня (`weekday` / `weekend`).
  final String dayKind;

  /// Цена за час.
  final num pricePerHour;

  /// Ступень: с какого числа станций этого типа действует цена.
  final int minQty;

  /// В доменную сущность.
  PriceRateEntity toEntity() => PriceRateEntity(
        stationType: StationType.fromRaw(stationType),
        dayKind: DayKind.fromRaw(dayKind),
        pricePerHour: pricePerHour,
        minQty: minQty,
      );
}
