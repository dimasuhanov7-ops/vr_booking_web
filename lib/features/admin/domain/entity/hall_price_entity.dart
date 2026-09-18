import 'package:equatable/equatable.dart';

/// Редактируемое поле базового тарифа.
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

/// Ступень цены шлемов: от [from] штук — другая цена за час.
///
/// Цена ступени применяется ко всем шлемам сеанса сразу (решение заказчика):
/// 8 шлемов при ступени «от 6» считаются по её цене все восемь.
class VrTierEntity extends Equatable {
  /// Создаёт ступень.
  const VrTierEntity({
    required this.from,
    required this.weekday,
    required this.weekend,
  });

  /// С какого числа шлемов действует цена.
  final int from;

  /// Цена за час в будни, ₽.
  final int weekday;

  /// Цена за час в выходные, ₽.
  final int weekend;

  /// Цена по типу дня.
  int rate({required bool weekend}) => weekend ? this.weekend : weekday;

  /// Копия с изменениями.
  VrTierEntity copyWith({int? from, int? weekday, int? weekend}) => VrTierEntity(
        from: from ?? this.from,
        weekday: weekday ?? this.weekday,
        weekend: weekend ?? this.weekend,
      );

  @override
  List<Object?> get props => <Object?>[from, weekday, weekend];
}

/// Тарифы одного зала: цена за час, VR/PS5 × будни/выходные.
///
/// У шлемов может быть несколько ступеней «от N штук дешевле» ([vrTiers]):
/// берётся самая высокая ступень, до которой дотягивает число шлемов.
class HallPriceEntity extends Equatable {
  /// Создаёт тарифы зала.
  const HallPriceEntity({
    required this.hallId,
    required this.vrWeekday,
    required this.vrWeekend,
    required this.ps5Weekday,
    required this.ps5Weekend,
    this.vrTiers = const <VrTierEntity>[],
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

  /// Ступени цены шлемов по возрастанию порога. Пусто — одна цена.
  final List<VrTierEntity> vrTiers;

  /// Есть ли ступени у шлемов.
  bool get hasVrTiers => vrTiers.isNotEmpty;

  /// Ставка VR по типу дня и количеству шлемов в сеансе.
  int vrRate({required bool weekend, int qty = 1}) {
    for (int i = vrTiers.length - 1; i >= 0; i--) {
      if (qty >= vrTiers[i].from) return vrTiers[i].rate(weekend: weekend);
    }
    return weekend ? vrWeekend : vrWeekday;
  }

  /// Ставка PS5 по типу дня.
  int ps5Rate({required bool weekend}) => weekend ? ps5Weekend : ps5Weekday;

  /// Значение поля базового тарифа.
  int value(PriceField field) => switch (field) {
        PriceField.vrWeekday => vrWeekday,
        PriceField.vrWeekend => vrWeekend,
        PriceField.ps5Weekday => ps5Weekday,
        PriceField.ps5Weekend => ps5Weekend,
      };

  /// Копия с изменённым полем базового тарифа.
  HallPriceEntity withField(PriceField field, int v) => HallPriceEntity(
        hallId: hallId,
        vrWeekday: field == PriceField.vrWeekday ? v : vrWeekday,
        vrWeekend: field == PriceField.vrWeekend ? v : vrWeekend,
        ps5Weekday: field == PriceField.ps5Weekday ? v : ps5Weekday,
        ps5Weekend: field == PriceField.ps5Weekend ? v : ps5Weekend,
        vrTiers: vrTiers,
      );

  /// Копия с другими ступенями — упорядоченными по порогу, без повторов и
  /// без порогов меньше 2 (от одного шлема — это базовая цена).
  HallPriceEntity withTiers(List<VrTierEntity> tiers) {
    final Map<int, VrTierEntity> byFrom = <int, VrTierEntity>{
      for (final VrTierEntity t in tiers)
        if (t.from >= 2) t.from: t,
    };
    final List<VrTierEntity> sorted = byFrom.values.toList()
      ..sort((VrTierEntity a, VrTierEntity b) => a.from.compareTo(b.from));
    return HallPriceEntity(
      hallId: hallId,
      vrWeekday: vrWeekday,
      vrWeekend: vrWeekend,
      ps5Weekday: ps5Weekday,
      ps5Weekend: ps5Weekend,
      vrTiers: List<VrTierEntity>.unmodifiable(sorted),
    );
  }

  @override
  List<Object?> get props => <Object?>[
        hallId,
        vrWeekday,
        vrWeekend,
        ps5Weekday,
        ps5Weekend,
        vrTiers,
      ];
}
