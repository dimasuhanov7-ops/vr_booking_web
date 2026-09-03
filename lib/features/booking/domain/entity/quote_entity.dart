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

  /// Подпись скидки.
  final String discountLabel;

  /// Есть ли скидка.
  bool get hasDiscount => discountPercent > 0;

  /// Сумма скидки, ₽ (округление до рубля).
  num get discountAmount => (gross * discountPercent / 100).round();

  /// Итог к оплате, ₽.
  num get net => gross - discountAmount;

  @override
  List<Object?> get props => <Object?>[lines, gross, discountPercent, discountLabel];
}
