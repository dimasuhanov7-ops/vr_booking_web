import 'package:equatable/equatable.dart';

import 'station_entity.dart';

/// Доступность станции в выбранном слоте для «плана зала».
class StationAvailabilityEntity extends Equatable {
  /// Создаёт ячейку доступности.
  const StationAvailabilityEntity({
    required this.station,
    required this.isFree,
    required this.isPicked,
    this.wasTaken = false,
  });

  /// Станция.
  final StationEntity station;

  /// Свободна ли в выбранном слоте.
  final bool isFree;

  /// Выбрана ли клиентом.
  final bool isPicked;

  /// Была выбрана, но занята при конфликте брони.
  final bool wasTaken;

  @override
  List<Object?> get props => <Object?>[station.id, isFree, isPicked, wasTaken];
}
