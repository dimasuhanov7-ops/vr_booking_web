import 'package:equatable/equatable.dart';

/// Один непрерывный отрезок брони: набор станций на конкретное окно времени.
/// Разбивка на отрезки позволяет держать разное число станций в разные часы.
class ReservationSegmentEntity extends Equatable {
  /// Создаёт отрезок.
  const ReservationSegmentEntity({
    required this.stationIds,
    required this.startsAt,
    required this.endsAt,
  });

  /// Станции этого отрезка.
  final List<String> stationIds;

  /// Начало отрезка (UTC).
  final DateTime startsAt;

  /// Конец отрезка (UTC).
  final DateTime endsAt;

  @override
  List<Object?> get props => <Object?>[stationIds, startsAt, endsAt];
}

/// Данные для создания групповой брони (один или несколько отрезков).
class ReservationRequestEntity extends Equatable {
  /// Создаёт запрос на бронь.
  const ReservationRequestEntity({
    required this.clubId,
    required this.segments,
    required this.startsAt,
    required this.minutes,
    required this.clientName,
    required this.clientPhone,
    this.peopleCount,
    this.discountCode,
    this.comment,
    this.source = 'site',
    this.packageId,
  });

  /// Клуб брони.
  final String clubId;

  /// Отрезки брони. При «одинаковом составе на весь сеанс» — один отрезок.
  final List<ReservationSegmentEntity> segments;

  /// Начало всего сеанса (UTC).
  final DateTime startsAt;

  /// Полная длительность сеанса, минут (для карточки/журнала).
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

  /// Источник брони (`site` / `vk` / `admin`).
  final String source;

  /// Выбранный пакет, если применён.
  final String? packageId;

  /// Все станции брони (объединение отрезков) — для репозиториев, которым
  /// достаточно плоского списка.
  List<String> get allStationIds => <String>{
        for (final ReservationSegmentEntity s in segments) ...s.stationIds,
      }.toList(growable: false);

  @override
  List<Object?> get props => <Object?>[
        clubId,
        segments,
        startsAt,
        minutes,
        clientName,
        clientPhone,
        peopleCount,
        discountCode,
        comment,
        source,
        packageId,
      ];
}
