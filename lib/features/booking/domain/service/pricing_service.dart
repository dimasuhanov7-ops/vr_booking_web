import '../entity/club_entity.dart';
import '../entity/price_rate_entity.dart';
import '../entity/quote_entity.dart';
import '../entity/station_entity.dart';
import 'club_clock.dart';

/// Считает стоимость брони по тарифам клуба.
class PricingService {
  /// Создаёт сервис.
  const PricingService();

  /// Цена одной станции за сеанс [minutes] минут в дату [startsAtUtc].
  num priceOf({
    required ClubEntity club,
    required StationEntity station,
    required DateTime startsAtUtc,
    required int minutes,
    required List<PriceRateEntity> rates,
  }) {
    final DayKind kind = DayKind.of(ClubClock(club).toWall(startsAtUtc));
    final PriceRateEntity? rate = rates
        .where((PriceRateEntity r) =>
            r.stationType == station.type && r.dayKind == kind)
        .cast<PriceRateEntity?>()
        .firstWhere((PriceRateEntity? r) => true, orElse: () => null);
    if (rate == null) return 0;
    return (rate.pricePerHour * minutes / 60).round();
  }

  /// Полный расчёт по выбранным станциям.
  QuoteEntity quote({
    required ClubEntity club,
    required List<StationEntity> stations,
    required DateTime startsAtUtc,
    required int minutes,
    required List<PriceRateEntity> rates,
    bool showRoomInLabel = false,
    num discountPercent = 0,
    String discountLabel = '',
  }) {
    final List<QuoteLineEntity> lines = stations.map((StationEntity s) {
      final String kind = s.type == StationType.ps5 ? 'PS5' : 'VR-шлем';
      final String label =
          showRoomInLabel ? '${s.roomName} · $kind ${s.label}' : '$kind ${s.label}';
      return QuoteLineEntity(
        stationId: s.id,
        label: label,
        price: priceOf(
          club: club,
          station: s,
          startsAtUtc: startsAtUtc,
          minutes: minutes,
          rates: rates,
        ),
      );
    }).toList(growable: false);

    final num gross = lines.fold<num>(0, (num a, QuoteLineEntity l) => a + l.price);
    return QuoteEntity(
      lines: lines,
      gross: gross,
      discountPercent: discountPercent,
      discountLabel: discountLabel,
    );
  }
}
