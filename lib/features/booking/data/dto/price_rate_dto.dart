import '../../domain/entity/price_rate_entity.dart';
import '../../domain/entity/station_entity.dart';

/// DTO строки таблицы `public.booking_prices`.
class PriceRateDto {
  /// Создаёт DTO.
  const PriceRateDto({
    required this.stationType,
    required this.dayKind,
    required this.pricePerHour,
  });

  /// Разбирает JSON от Supabase.
  factory PriceRateDto.fromJson(Map<String, dynamic> json) => PriceRateDto(
        stationType: json['station_type'] as String,
        dayKind: json['day_kind'] as String,
        pricePerHour: json['price_per_hour'] as num,
      );

  /// Тип станции (`vr_headset` / `ps5`).
  final String stationType;

  /// Тип дня (`weekday` / `weekend`).
  final String dayKind;

  /// Цена за час.
  final num pricePerHour;

  /// В доменную сущность.
  PriceRateEntity toEntity() => PriceRateEntity(
        stationType: StationType.fromRaw(stationType),
        dayKind: DayKind.fromRaw(dayKind),
        pricePerHour: pricePerHour,
      );
}
