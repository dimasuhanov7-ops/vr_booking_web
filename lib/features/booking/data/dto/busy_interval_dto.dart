import '../../domain/entity/busy_interval_entity.dart';

/// DTO строки результата RPC `booking_busy_intervals`.
class BusyIntervalDto {
  /// Создаёт DTO.
  const BusyIntervalDto({
    required this.stationId,
    required this.roomId,
    required this.startsAt,
    required this.endsAt,
  });

  /// Разбирает JSON-строку результата RPC.
  factory BusyIntervalDto.fromJson(Map<String, dynamic> json) => BusyIntervalDto(
        stationId: json['station_id'] as String,
        roomId: json['room_id'] as String? ?? '',
        startsAt: DateTime.parse(json['starts_at'] as String).toUtc(),
        endsAt: DateTime.parse(json['ends_at'] as String).toUtc(),
      );

  /// Идентификатор занятой станции.
  final String stationId;

  /// Зал станции.
  final String roomId;

  /// Начало (UTC).
  final DateTime startsAt;

  /// Конец (UTC).
  final DateTime endsAt;

  /// В доменную сущность.
  BusyIntervalEntity toEntity() => BusyIntervalEntity(
        stationId: stationId,
        roomId: roomId,
        startsAt: startsAt,
        endsAt: endsAt,
      );
}
