import 'package:equatable/equatable.dart';

/// Вид скидки промокода.
enum PromoKind {
  /// Процент от суммы.
  percent,

  /// Фиксированная сумма, ₽.
  fixed;

  /// Разбирает `booking_discounts.value` (numeric): число или строка.
  static int valueOf(Object? raw) => switch (raw) {
        final num n => n.round(),
        final String s => num.tryParse(s)?.round() ?? 0,
        _ => 0,
      };

  /// Разбирает `booking_discounts.kind`.
  static PromoKind fromRaw(String? raw) =>
      raw == 'fixed' ? PromoKind.fixed : PromoKind.percent;

  /// Значение для `booking_discounts.kind`.
  String get raw => name;
}

/// Промокод (`booking_discounts` с непустым `code`). Общий для всех клубов.
class PromoEntity extends Equatable {
  /// Создаёт промокод.
  const PromoEntity({
    required this.id,
    required this.code,
    required this.kind,
    required this.value,
    this.minStations = 1,
    this.isActive = true,
    this.validFrom,
    this.validUntil,
  });

  /// Идентификатор.
  final String id;

  /// Код, как его вводит клиент (хранится в верхнем регистре).
  final String code;

  /// Процент или сумма.
  final PromoKind kind;

  /// Процент (1–100) или сумма, ₽.
  final int value;

  /// Действует от стольких станций в брони.
  final int minStations;

  /// Включён ли.
  final bool isActive;

  /// Начало действия (задаётся в БД; `null` — без ограничения).
  final DateTime? validFrom;

  /// Конец действия (задаётся в БД; `null` — бессрочно).
  final DateTime? validUntil;

  /// Скидка с суммы [base]: процент округляется до рубля, фиксированная
  /// сумма не больше [base]. Так же считают виджет и таблица (booking-mirror).
  int amountOn(int base) {
    if (base <= 0 || value <= 0) return 0;
    return switch (kind) {
      PromoKind.percent => (base * value.clamp(0, 100) / 100).round(),
      PromoKind.fixed => value.clamp(0, base),
    };
  }

  /// «−10%» / «−500 ₽».
  String get effectLabel =>
      kind == PromoKind.percent ? '−$value%' : '−$value ₽';

  /// Срок действия уже закончился.
  bool isExpiredAt(DateTime now) =>
      validUntil != null && validUntil!.isBefore(now);

  /// Копия с изменениями.
  PromoEntity copyWith({bool? isActive}) => PromoEntity(
        id: id,
        code: code,
        kind: kind,
        value: value,
        minStations: minStations,
        isActive: isActive ?? this.isActive,
        validFrom: validFrom,
        validUntil: validUntil,
      );

  @override
  List<Object?> get props =>
      <Object?>[id, code, kind, value, minStations, isActive, validFrom, validUntil];
}
