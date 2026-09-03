import 'package:equatable/equatable.dart';

/// Способ начисления скидки.
enum DiscountKind {
  /// Процент от суммы.
  percent,

  /// Фиксированная сумма.
  fixed;

  /// Разбирает значение из БД.
  static DiscountKind fromRaw(String raw) => switch (raw) {
        'percent' => DiscountKind.percent,
        'fixed' => DiscountKind.fixed,
        _ => throw ArgumentError('Неизвестный тип скидки: $raw'),
      };
}

/// Применённая к брони скидка: промокод или автоматическая по числу станций.
class DiscountEntity extends Equatable {
  /// Создаёт сущность скидки.
  const DiscountEntity({
    required this.id,
    required this.kind,
    required this.value,
    required this.minStations,
    this.code,
    this.title,
  });

  /// Идентификатор скидки.
  final String id;

  /// Промокод. `null` — автоматическая скидка по числу станций.
  final String? code;

  /// Название для отображения.
  final String? title;

  /// Способ начисления.
  final DiscountKind kind;

  /// Величина: проценты или абсолютная сумма (в зависимости от [kind]).
  final num value;

  /// Минимальное число станций для применения.
  final int minStations;

  /// Является ли скидка автоматической (без промокода).
  bool get isAutomatic => code == null;

  /// Подпись эффекта скидки, например «−10%» или «−500 ₽».
  String get effectLabel => switch (kind) {
        DiscountKind.percent => '−${_trim(value)}%',
        DiscountKind.fixed => '−${_trim(value)} ₽',
      };

  static String _trim(num v) => v == v.roundToDouble() ? v.toInt().toString() : v.toString();

  @override
  List<Object?> get props => <Object?>[id, code, title, kind, value, minStations];
}
