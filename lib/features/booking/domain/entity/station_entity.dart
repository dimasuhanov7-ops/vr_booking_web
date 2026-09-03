import 'package:equatable/equatable.dart';

/// Тип станции, которую бронирует клиент.
enum StationType {
  /// VR-шлем.
  vrHeadset,

  /// Игровая приставка PS5.
  ps5;

  /// Разбирает значение из БД (`vr_headset` / `ps5`).
  static StationType fromRaw(String raw) => switch (raw) {
        'vr_headset' => StationType.vrHeadset,
        'ps5' => StationType.ps5,
        _ => throw ArgumentError('Неизвестный тип станции: $raw'),
      };

  /// Значение для БД.
  String get raw => switch (this) {
        StationType.vrHeadset => 'vr_headset',
        StationType.ps5 => 'ps5',
      };
}

/// Конкретный шлем или приставка, бронируемый по номеру.
class StationEntity extends Equatable {
  /// Создаёт сущность станции.
  const StationEntity({
    required this.id,
    required this.roomId,
    required this.roomName,
    required this.type,
    required this.label,
    required this.rowIndex,
    required this.positionInRow,
    required this.sortOrder,
    required this.isActive,
  });

  /// Идентификатор станции.
  final String id;

  /// Идентификатор зала.
  final String roomId;

  /// Название зала (для брони на «весь клуб» — из какого зала станция).
  final String roomName;

  /// Тип станции.
  final StationType type;

  /// Номер/название (`#7`, `PS5-1`).
  final String label;

  /// Индекс ряда в «плане зала».
  final int rowIndex;

  /// Позиция станции внутри ряда.
  final int positionInRow;

  /// Порядок отображения.
  final int sortOrder;

  /// Активна ли станция.
  final bool isActive;

  @override
  List<Object?> get props =>
      <Object?>[id, roomId, type, label, rowIndex, positionInRow, sortOrder, isActive];
}
