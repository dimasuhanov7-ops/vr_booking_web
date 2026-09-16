import '../entity/club_entity.dart';
import '../entity/price_rate_entity.dart';
import '../entity/quote_entity.dart';
import '../entity/station_entity.dart';
import 'club_clock.dart';

/// Считает стоимость брони по тарифам клуба.
///
/// Тариф может идти ступенями по количеству: «до 6 шлемов 800 ₽, от 7 — 700 ₽».
/// Ступень выбирается по числу станций этого типа в конкретном часе сеанса и
/// применяется ко всем станциям сразу — так же, как считает сервер
/// (`booking_station_price`), иначе итог в виджете разошёлся бы с чеком.
class PricingService {
  /// Создаёт сервис.
  const PricingService();

  /// Цена часа для [type] при [qty] станциях этого типа в этот же час.
  num ratePerHour({
    required List<PriceRateEntity> rates,
    required StationType type,
    required DayKind dayKind,
    int qty = 1,
  }) {
    final int n = qty < 1 ? 1 : qty;
    num rate = 0;
    int tier = 0;
    for (final PriceRateEntity r in rates) {
      if (r.stationType != type || r.dayKind != dayKind) continue;
      if (r.minQty > n || r.minQty < tier) continue;
      rate = r.pricePerHour;
      tier = r.minQty;
    }
    return rate;
  }

  /// Цена одной станции за сеанс [minutes] минут в дату [startsAtUtc],
  /// когда станций этого типа взято [qty].
  num priceOf({
    required ClubEntity club,
    required StationEntity station,
    required DateTime startsAtUtc,
    required int minutes,
    required List<PriceRateEntity> rates,
    int qty = 1,
  }) {
    final DayKind kind = DayKind.of(ClubClock(club).toWall(startsAtUtc));
    final num rate = ratePerHour(
      rates: rates,
      type: station.type,
      dayKind: kind,
      qty: qty,
    );
    return (rate * minutes / 60).round();
  }

  /// Полный расчёт по выбранным станциям.
  ///
  /// Сеанс разбит на часы: [isPickedAt] говорит, занята ли станция в этом часе
  /// (так одна бронь может держать 12 шлемов в первый час и 6 во второй), а
  /// цена каждого часа считается по составу именно этого часа.
  QuoteEntity quote({
    required ClubEntity club,
    required List<StationEntity> stations,
    required DateTime startsAtUtc,
    required int hourCount,
    required bool Function(StationEntity station, int hour) isPickedAt,
    required List<PriceRateEntity> rates,
    bool showRoomInLabel = false,
    num discountPercent = 0,
    String discountLabel = '',
  }) {
    final DayKind kind = DayKind.of(ClubClock(club).toWall(startsAtUtc));

    // Сколько станций каждого типа взято в каждом часе — это и есть ступень.
    final List<Map<StationType, int>> perHour = <Map<StationType, int>>[
      for (int h = 0; h < hourCount; h++)
        <StationType, int>{
          for (final StationEntity s in stations)
            if (isPickedAt(s, h)) s.type: 0,
        },
    ];
    for (int h = 0; h < hourCount; h++) {
      for (final StationEntity s in stations) {
        if (!isPickedAt(s, h)) continue;
        perHour[h].update(s.type, (int v) => v + 1, ifAbsent: () => 1);
      }
    }

    final List<QuoteLineEntity> lines = stations.map((StationEntity s) {
      final String kindLabel = s.type == StationType.ps5 ? 'PS5' : 'VR-шлем';
      num price = 0;
      int mins = 0;
      for (int h = 0; h < hourCount; h++) {
        if (!isPickedAt(s, h)) continue;
        mins += 60;
        price += ratePerHour(
          rates: rates,
          type: s.type,
          dayKind: kind,
          qty: perHour[h][s.type] ?? 1,
        );
      }
      final String hoursTag = mins > 0 && mins != 60 ? ' · ${mins ~/ 60} ч' : '';
      final String label = (showRoomInLabel
              ? '${s.roomName} · $kindLabel ${s.label}'
              : '$kindLabel ${s.label}') +
          hoursTag;
      return QuoteLineEntity(
        stationId: s.id,
        label: label,
        price: price.round(),
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
