import 'package:equatable/equatable.dart';

/// Строка расчёта: станция и её стоимость за сеанс.
class QuoteLineEntity extends Equatable {
  /// Создаёт строку расчёта.
  const QuoteLineEntity({
    required this.stationId,
    required this.label,
    required this.price,
  });

  /// Идентификатор станции.
  final String stationId;

  /// Подпись («Большой зал · VR-шлем 7»).
  final String label;

  /// Стоимость станции за сеанс, ₽.
  final num price;

  @override
  List<Object?> get props => <Object?>[stationId, label, price];
}

/// Итоговый расчёт брони.
class QuoteEntity extends Equatable {
  /// Создаёт расчёт.
  const QuoteEntity({
    required this.lines,
    required this.gross,
    this.discountPercent = 0,
    this.discountLabel = '',
    this.netOverride,
    this.promoPercent = 0,
    this.promoFixed = 0,
    this.promoLabel = '',
  });

  /// Пустой расчёт.
  static const QuoteEntity empty =
      QuoteEntity(lines: <QuoteLineEntity>[], gross: 0);

  /// Позиции.
  final List<QuoteLineEntity> lines;

  /// Стоимость без скидки, ₽.
  final num gross;

  /// Процент скидки.
  final num discountPercent;

  /// Подпись скидки / пакета.
  final String discountLabel;

  /// Фиксированный итог (цена пакета) вместо `gross − скидка`.
  final num? netOverride;

  /// Промокод: процент от суммы после пакета.
  final num promoPercent;

  /// Промокод: фиксированная сумма, ₽ (не больше суммы после пакета).
  final num promoFixed;

  /// Подпись промокода, например «Промокод VRPARTY».
  final String promoLabel;

  /// Есть ли скидка (пакет дешевле почасовой, процент или промокод).
  bool get hasDiscount =>
      discountPercent > 0 || (netOverride != null && netOverride! < gross) || hasPromo;

  /// Выгода пакета или процентной скидки, ₽ (без промокода).
  num get discountAmount => netOverride != null
      ? (gross - netOverride!).clamp(0, gross)
      : (gross * discountPercent / 100).round();

  /// Сумма до промокода: цена пакета или почасовая за вычетом процента.
  num get _beforePromo => netOverride ?? (gross - discountAmount);

  /// Скидка по промокоду, ₽. Те же правила — в админке и `booking-mirror`.
  num get promoAmount {
    final num base = _beforePromo;
    if (base <= 0) return 0;
    if (promoPercent > 0) return (base * promoPercent / 100).round();
    return promoFixed.clamp(0, base);
  }

  /// Применён ли промокод.
  bool get hasPromo => promoAmount > 0;

  /// Итог к оплате, ₽.
  num get net => _beforePromo - promoAmount;

  /// Копия с промокодом (или без него).
  QuoteEntity withPromo({num percent = 0, num fixed = 0, String label = ''}) =>
      QuoteEntity(
        lines: lines,
        gross: gross,
        discountPercent: discountPercent,
        discountLabel: discountLabel,
        netOverride: netOverride,
        promoPercent: percent,
        promoFixed: fixed,
        promoLabel: label,
      );

  @override
  List<Object?> get props => <Object?>[
        lines,
        gross,
        discountPercent,
        discountLabel,
        netOverride,
        promoPercent,
        promoFixed,
        promoLabel,
      ];
}
