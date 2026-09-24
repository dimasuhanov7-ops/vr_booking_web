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
  ///
  /// [qty] — сколько станций того же типа в брони в это время: по нему
  /// выбирается ступень тарифа, как в `booking_station_price` на сервере.
  num priceOf({
    required ClubEntity club,
    required StationEntity station,
    required DateTime startsAtUtc,
    required int minutes,
    required List<PriceRateEntity> rates,
    int qty = 1,
  }) {
    final DayKind kind = DayKind.of(ClubClock(club).toWall(startsAtUtc));
    final int q = qty < 1 ? 1 : qty;
    PriceRateEntity? rate;
    for (final PriceRateEntity r in rates) {
      if (r.stationType != station.type || r.dayKind != kind || r.minQty > q) {
        continue;
      }
      if (rate == null || r.minQty > rate.minQty) rate = r;
    }
    if (rate == null) return 0;
    return (rate.pricePerHour * minutes / 60).round();
  }

  /// Полный расчёт по выбранным станциям.
  ///
  /// [minutesOf] возвращает суммарное время станции за сеанс — так одна бронь
  /// может держать станцию не весь сеанс (12 шлемов в первый час, 6 во второй).
  ///
  /// [qtyByHourOf] — для каждого часа, в котором станция занята, число станций
  /// того же типа в этом часе. С ним цена считается почасово по ступеням
  /// тарифа; без него — по одной ступени на всё время станции.
  QuoteEntity quote({
    required ClubEntity club,
    required List<StationEntity> stations,
    required DateTime startsAtUtc,
    required int Function(StationEntity station) minutesOf,
    required List<PriceRateEntity> rates,
    List<int> Function(StationEntity station)? qtyByHourOf,
    bool showRoomInLabel = false,
    num discountPercent = 0,
    String discountLabel = '',
  }) {
    final List<QuoteLineEntity> lines = stations.map((StationEntity s) {
      final String kind = s.type == StationType.ps5 ? 'PS5' : 'VR-шлем';
      final int mins = minutesOf(s);
      final String hoursTag = mins > 0 && mins != 60 ? ' · ${mins ~/ 60} ч' : '';
      final String label = (showRoomInLabel
              ? '${s.roomName} · $kind ${s.label}'
              : '$kind ${s.label}') +
          hoursTag;
      final num price = qtyByHourOf == null
          ? priceOf(
              club: club,
              station: s,
              startsAtUtc: startsAtUtc,
              minutes: mins,
              rates: rates,
            )
          : qtyByHourOf(s).fold<num>(
              0,
              (num sum, int qty) =>
                  sum +
                  priceOf(
                    club: club,
                    station: s,
                    startsAtUtc: startsAtUtc,
                    minutes: 60,
                    rates: rates,
                    qty: qty,
                  ),
            );
      return QuoteLineEntity(stationId: s.id, label: label, price: price);
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
