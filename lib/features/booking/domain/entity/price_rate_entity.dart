import 'package:equatable/equatable.dart';

import 'station_entity.dart';

/// Тип дня для тарификации.
enum DayKind {
  /// Будний день (пн–пт).
  weekday,

  /// Выходной (сб, вс).
  weekend;

  /// Разбирает значение из БД.
  static DayKind fromRaw(String raw) =>
      raw == 'weekend' ? DayKind.weekend : DayKind.weekday;

  /// Определяет тип дня по дате.
  static DayKind of(DateTime date) =>
      (date.weekday == DateTime.saturday || date.weekday == DateTime.sunday)
          ? DayKind.weekend
          : DayKind.weekday;
}

/// Тариф: цена за час для типа станции в будни/выходные.
///
/// Цен на один тип станции может быть несколько — ступенями по количеству:
/// «до 6 шлемов 800 ₽, от 7 — 700 ₽». Ступень выбирается по числу станций
/// этого типа в сеансе и применяется ко всем сразу (см. [minQty]).
class PriceRateEntity extends Equatable {
  /// Создаёт тариф.
  const PriceRateEntity({
    required this.stationType,
    required this.dayKind,
    required this.pricePerHour,
    this.minQty = 1,
  });

  /// Тип станции.
  final StationType stationType;

  /// Тип дня.
  final DayKind dayKind;

  /// Цена за час, ₽.
  final num pricePerHour;

  /// С какого количества станций действует цена (базовая строка — 1).
  final int minQty;

  @override
  List<Object?> get props =>
      <Object?>[stationType, dayKind, pricePerHour, minQty];
}
