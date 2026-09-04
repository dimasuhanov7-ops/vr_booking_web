import 'package:equatable/equatable.dart';

/// Редактируемое поле тарифа.
enum PriceField {
  /// VR-шлем, будни.
  vrWeekday,

  /// VR-шлем, выходные.
  vrWeekend,

  /// PS5, будни.
  ps5Weekday,

  /// PS5, выходные.
  ps5Weekend,
}

/// Тарифы одного зала: цена за час, VR/PS5 × будни/выходные.
class HallPriceEntity extends Equatable {
  /// Создаёт тарифы зала.
  const HallPriceEntity({
    required this.hallId,
    required this.vrWeekday,
    required this.vrWeekend,
    required this.ps5Weekday,
    required this.ps5Weekend,
  });

  /// Идентификатор зала.
  final String hallId;

  /// VR-шлем, будни, ₽/ч.
  final int vrWeekday;

  /// VR-шлем, выходные, ₽/ч.
  final int vrWeekend;

  /// PS5, будни, ₽/ч.
  final int ps5Weekday;

  /// PS5, выходные, ₽/ч.
  final int ps5Weekend;

  /// Ставка VR по типу дня.
  int vrRate({required bool weekend}) => weekend ? vrWeekend : vrWeekday;

  /// Ставка PS5 по типу дня.
  int ps5Rate({required bool weekend}) => weekend ? ps5Weekend : ps5Weekday;

  /// Значение конкретного поля.
  int value(PriceField field) => switch (field) {
        PriceField.vrWeekday => vrWeekday,
        PriceField.vrWeekend => vrWeekend,
        PriceField.ps5Weekday => ps5Weekday,
        PriceField.ps5Weekend => ps5Weekend,
      };

  /// Копия с изменённым полем.
  HallPriceEntity withField(PriceField field, int v) => HallPriceEntity(
        hallId: hallId,
        vrWeekday: field == PriceField.vrWeekday ? v : vrWeekday,
        vrWeekend: field == PriceField.vrWeekend ? v : vrWeekend,
        ps5Weekday: field == PriceField.ps5Weekday ? v : ps5Weekday,
        ps5Weekend: field == PriceField.ps5Weekend ? v : ps5Weekend,
      );

  @override
  List<Object?> get props =>
      <Object?>[hallId, vrWeekday, vrWeekend, ps5Weekday, ps5Weekend];
}
