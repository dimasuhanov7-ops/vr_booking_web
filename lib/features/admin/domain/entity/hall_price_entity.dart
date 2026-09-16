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

  /// VR-шлем от порога ступени, будни.
  vrTierWeekday,

  /// VR-шлем от порога ступени, выходные.
  vrTierWeekend,
}

/// Тарифы одного зала: цена за час, VR/PS5 × будни/выходные.
///
/// У шлемов может быть ступень «от [vrTierFrom] штук дешевле»: цена ступени
/// применяется ко всем шлемам сразу, а не только к тем, что сверх порога.
class HallPriceEntity extends Equatable {
  /// Создаёт тарифы зала.
  const HallPriceEntity({
    required this.hallId,
    required this.vrWeekday,
    required this.vrWeekend,
    required this.ps5Weekday,
    required this.ps5Weekend,
    this.vrTierFrom = 0,
    this.vrTierWeekday = 0,
    this.vrTierWeekend = 0,
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

  /// С какого числа шлемов действует вторая цена (0 — ступени нет).
  final int vrTierFrom;

  /// VR-шлем от порога, будни, ₽/ч.
  final int vrTierWeekday;

  /// VR-шлем от порога, выходные, ₽/ч.
  final int vrTierWeekend;

  /// Задана ли ступень для шлемов.
  bool get hasVrTier => vrTierFrom > 1;

  /// Ставка VR по типу дня и количеству шлемов в сеансе.
  int vrRate({required bool weekend, int qty = 1}) {
    if (hasVrTier && qty >= vrTierFrom) {
      return weekend ? vrTierWeekend : vrTierWeekday;
    }
    return weekend ? vrWeekend : vrWeekday;
  }

  /// Ставка PS5 по типу дня.
  int ps5Rate({required bool weekend}) => weekend ? ps5Weekend : ps5Weekday;

  /// Значение конкретного поля.
  int value(PriceField field) => switch (field) {
        PriceField.vrWeekday => vrWeekday,
        PriceField.vrWeekend => vrWeekend,
        PriceField.ps5Weekday => ps5Weekday,
        PriceField.ps5Weekend => ps5Weekend,
        PriceField.vrTierWeekday => vrTierWeekday,
        PriceField.vrTierWeekend => vrTierWeekend,
      };

  /// Копия с изменённым полем.
  HallPriceEntity withField(PriceField field, int v) => HallPriceEntity(
        hallId: hallId,
        vrWeekday: field == PriceField.vrWeekday ? v : vrWeekday,
        vrWeekend: field == PriceField.vrWeekend ? v : vrWeekend,
        ps5Weekday: field == PriceField.ps5Weekday ? v : ps5Weekday,
        ps5Weekend: field == PriceField.ps5Weekend ? v : ps5Weekend,
        vrTierFrom: vrTierFrom,
        vrTierWeekday: field == PriceField.vrTierWeekday ? v : vrTierWeekday,
        vrTierWeekend: field == PriceField.vrTierWeekend ? v : vrTierWeekend,
      );

  /// Копия с другой ступенью. [from] = 0 — ступень убрана.
  ///
  /// Цены ступени, если их ещё не задавали, берутся равными базовым: строка
  /// тарифа не должна уехать в базу с нулём.
  HallPriceEntity withTier(int from) => HallPriceEntity(
        hallId: hallId,
        vrWeekday: vrWeekday,
        vrWeekend: vrWeekend,
        ps5Weekday: ps5Weekday,
        ps5Weekend: ps5Weekend,
        vrTierFrom: from,
        vrTierWeekday:
            from == 0 ? 0 : (vrTierWeekday > 0 ? vrTierWeekday : vrWeekday),
        vrTierWeekend:
            from == 0 ? 0 : (vrTierWeekend > 0 ? vrTierWeekend : vrWeekend),
      );

  @override
  List<Object?> get props => <Object?>[
        hallId,
        vrWeekday,
        vrWeekend,
        ps5Weekday,
        ps5Weekend,
        vrTierFrom,
        vrTierWeekday,
        vrTierWeekend,
      ];
}
