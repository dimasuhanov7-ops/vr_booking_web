import 'package:equatable/equatable.dart';

/// Сколько шлемов и PS5 занять в одном зале.
typedef HallUnits = ({int headsets, int consoles});

/// Бронь, которую сотрудник создаёт в админке.
///
/// Сотрудник думает количествами («4 шлема на арене и 2 PS5 в малом зале»),
/// а конкретные станции подбирает репозиторий по серверной занятости.
class AdminBookingRequest extends Equatable {
  /// Создаёт запрос.
  const AdminBookingRequest({
    required this.clubId,
    required this.day,
    required this.startMinutes,
    required this.hours,
    required this.clientName,
    this.phone = '',
    this.note = '',
    this.prepay = 0,
  });

  /// Клуб.
  final String clubId;

  /// Дата сеанса (день клуба, время не учитывается).
  final DateTime day;

  /// Начало сеанса, минут от полуночи по времени клуба.
  final int startMinutes;

  /// Состав по часам: `hours[h]` — зал → сколько занять в h-й час сеанса.
  /// Зал без станций в часе в карту не попадает.
  final List<Map<String, HallUnits>> hours;

  /// Имя гостя.
  final String clientName;

  /// Телефон (сотрудник может не знать его).
  final String phone;

  /// Комментарий сотрудника.
  final String note;

  /// Внесённая предоплата, ₽.
  final int prepay;

  /// Длительность сеанса, минут.
  int get durationMinutes => hours.length * 60;

  @override
  List<Object?> get props => <Object?>[
        clubId,
        day,
        startMinutes,
        hours,
        clientName,
        phone,
        note,
        prepay,
      ];
}
