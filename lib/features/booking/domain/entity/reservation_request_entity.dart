import 'package:equatable/equatable.dart';

/// Данные для создания групповой брони на несколько станций одним слотом.
class ReservationRequestEntity extends Equatable {
  /// Создаёт запрос на бронь.
  const ReservationRequestEntity({
    required this.clubId,
    required this.stationIds,
    required this.startsAt,
    required this.minutes,
    required this.clientName,
    required this.clientPhone,
    this.peopleCount,
    this.discountCode,
    this.comment,
    this.source = 'site',
  });

  /// Клуб брони.
  final String clubId;

  /// Станции (одна или несколько станций, в т.ч. из разных залов).
  final List<String> stationIds;

  /// Начало сеанса (UTC).
  final DateTime startsAt;

  /// Длительность сеанса, минут (60/90/120/180).
  final int minutes;

  /// Имя клиента.
  final String clientName;

  /// Телефон клиента.
  final String clientPhone;

  /// Сколько всего человек будет.
  final int? peopleCount;

  /// Промокод, если введён.
  final String? discountCode;

  /// Комментарий.
  final String? comment;

  /// Источник брони (`site` / `vk`).
  final String source;

  @override
  List<Object?> get props => <Object?>[
        clubId,
        stationIds,
        startsAt,
        minutes,
        clientName,
        clientPhone,
        peopleCount,
        discountCode,
        comment,
        source,
      ];
}
