import 'package:equatable/equatable.dart';

import 'package_entity.dart';

/// Совет перед подтверждением брони: пакет с большим составом стоит не дороже
/// того, что клиент выбрал сейчас («6 шлемов выйдет дешевле, чем 5»).
class PackageAdviceEntity extends Equatable {
  /// Создаёт совет.
  const PackageAdviceEntity({
    required this.package,
    required this.headsets,
    required this.consoles,
    required this.currentPrice,
  });

  /// Пакет, который выгоднее текущего выбора.
  final PackageEntity package;

  /// Сколько VR-шлемов выбрано сейчас.
  final int headsets;

  /// Сколько PS5 выбрано сейчас.
  final int consoles;

  /// Итог текущего выбора, ₽.
  final num currentPrice;

  /// Экономия при переходе на пакет, ₽ (0 — та же цена за больший состав).
  num get saving => currentPrice - package.price;

  @override
  List<Object?> get props => <Object?>[package, headsets, consoles, currentPrice];
}
