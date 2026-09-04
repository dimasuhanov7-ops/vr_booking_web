import 'package:equatable/equatable.dart';

/// Редактируемое числовое поле пакета.
enum PackageField {
  /// Число VR-шлемов.
  headsets,

  /// Число PS5.
  consoles,

  /// Длительность, минут.
  minutes,

  /// Цена за пакет, ₽.
  price,
}

/// Пакет — фиксированная цена за компанию и время.
class PackageEntity extends Equatable {
  /// Создаёт пакет.
  const PackageEntity({
    required this.id,
    required this.clubId,
    required this.hallId,
    required this.name,
    required this.headsets,
    required this.consoles,
    required this.minutes,
    required this.price,
    required this.isEnabled,
  });

  /// Идентификатор пакета.
  final String id;

  /// Клуб.
  final String clubId;

  /// Зал.
  final String hallId;

  /// Название.
  final String name;

  /// VR-шлемов в пакете.
  final int headsets;

  /// PS5 в пакете.
  final int consoles;

  /// Длительность, минут.
  final int minutes;

  /// Цена за пакет, ₽.
  final int price;

  /// Активен ли пакет.
  final bool isEnabled;

  /// Значение конкретного поля.
  int value(PackageField field) => switch (field) {
        PackageField.headsets => headsets,
        PackageField.consoles => consoles,
        PackageField.minutes => minutes,
        PackageField.price => price,
      };

  /// Копия с изменённым числовым полем.
  PackageEntity withField(PackageField field, int v) => copyWith(
        headsets: field == PackageField.headsets ? v : null,
        consoles: field == PackageField.consoles ? v : null,
        minutes: field == PackageField.minutes ? v : null,
        price: field == PackageField.price ? v : null,
      );

  /// Копия с изменениями.
  PackageEntity copyWith({
    String? name,
    String? hallId,
    int? headsets,
    int? consoles,
    int? minutes,
    int? price,
    bool? isEnabled,
  }) =>
      PackageEntity(
        id: id,
        clubId: clubId,
        hallId: hallId ?? this.hallId,
        name: name ?? this.name,
        headsets: headsets ?? this.headsets,
        consoles: consoles ?? this.consoles,
        minutes: minutes ?? this.minutes,
        price: price ?? this.price,
        isEnabled: isEnabled ?? this.isEnabled,
      );

  @override
  List<Object?> get props => <Object?>[
        id,
        clubId,
        hallId,
        name,
        headsets,
        consoles,
        minutes,
        price,
        isEnabled,
      ];
}
