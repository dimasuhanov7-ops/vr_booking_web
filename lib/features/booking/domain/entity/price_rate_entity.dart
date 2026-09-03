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
class PriceRateEntity extends Equatable {
  /// Создаёт тариф.
  const PriceRateEntity({
    required this.stationType,
    required this.dayKind,
    required this.pricePerHour,
  });

  /// Тип станции.
  final StationType stationType;

  /// Тип дня.
  final DayKind dayKind;

  /// Цена за час, ₽.
  final num pricePerHour;

  @override
  List<Object?> get props => <Object?>[stationType, dayKind, pricePerHour];
}
