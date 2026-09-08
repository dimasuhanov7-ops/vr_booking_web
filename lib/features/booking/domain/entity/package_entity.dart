import 'package:equatable/equatable.dart';

/// Пакет: фиксированная цена за набор станций определённого состава на
/// фиксированную длительность в конкретном зале клуба.
class PackageEntity extends Equatable {
  /// Создаёт пакет.
  const PackageEntity({
    required this.id,
    required this.clubId,
    required this.roomId,
    required this.name,
    required this.headsets,
    required this.consoles,
    required this.minutes,
    required this.price,
    required this.note,
    this.sortOrder = 0,
  });

  /// Идентификатор пакета.
  final String id;

  /// Клуб.
  final String clubId;

  /// Зал, к которому привязан пакет (`null` — любой зал клуба).
  final String? roomId;

  /// Название («Компания», «Арена»).
  final String name;

  /// Сколько VR-шлемов входит.
  final int headsets;

  /// Сколько PS5 входит.
  final int consoles;

  /// Длительность сеанса, минут.
  final int minutes;

  /// Фиксированная цена, ₽.
  final num price;

  /// Пояснение состава («4 шлема и 2 PS5, 2 часа»).
  final String note;

  /// Порядок отображения.
  final int sortOrder;

  /// Всего станций в пакете.
  int get stationCount => headsets + consoles;

  @override
  List<Object?> get props => <Object?>[
        id,
        clubId,
        roomId,
        name,
        headsets,
        consoles,
        minutes,
        price,
        note,
        sortOrder,
      ];
}
