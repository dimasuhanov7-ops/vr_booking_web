import 'package:equatable/equatable.dart';

/// Агрегаты по отфильтрованным записям (6 KPI-плиток).
class RecordsSummaryEntity extends Equatable {
  /// Создаёт сводку.
  const RecordsSummaryEntity({
    required this.records,
    required this.cancelled,
    required this.headsets,
    required this.consoles,
    required this.sessionHours,
    required this.stationHours,
    required this.total,
  });

  /// Пустая сводка.
  static const RecordsSummaryEntity empty = RecordsSummaryEntity(
    records: 0,
    cancelled: 0,
    headsets: 0,
    consoles: 0,
    sessionHours: 0,
    stationHours: 0,
    total: 0,
  );

  /// Активных записей по фильтру.
  final int records;

  /// Сколько из отфильтрованных отменено.
  final int cancelled;

  /// Суммарно VR-шлемов.
  final int headsets;

  /// Суммарно PS5.
  final int consoles;

  /// Суммарная длительность сеансов, часов.
  final double sessionHours;

  /// Станций × длительность, часов.
  final double stationHours;

  /// Сумма по текущему тарифу, ₽.
  final int total;

  @override
  List<Object?> get props => <Object?>[
        records,
        cancelled,
        headsets,
        consoles,
        sessionHours,
        stationHours,
        total,
      ];
}
