import 'package:equatable/equatable.dart';

/// Статус записи.
enum RecordStatus {
  /// Новая (заявка не обработана).
  newRequest,

  /// Подтверждена.
  confirmed,

  /// Оплачена.
  paid;

  /// Разбирает значение из мок-данных.
  static RecordStatus fromRaw(String raw) => switch (raw) {
        'new' => RecordStatus.newRequest,
        'confirmed' => RecordStatus.confirmed,
        'paid' => RecordStatus.paid,
        _ => RecordStatus.newRequest,
      };

  /// Подпись.
  String get label => switch (this) {
        RecordStatus.newRequest => 'новая',
        RecordStatus.confirmed => 'подтверждена',
        RecordStatus.paid => 'оплачена',
      };
}

/// Откуда пришла запись.
enum RecordSource {
  /// Заявка через виджет.
  widget,

  /// Внесена персоналом (звонок).
  call;

  /// Разбирает значение из мок-данных.
  static RecordSource fromRaw(String raw) =>
      raw == 'звонок' ? RecordSource.call : RecordSource.widget;

  /// Подпись.
  String get label => this == RecordSource.call ? 'звонок' : 'виджет';
}

/// Единая запись брони — источник и для «Броней» (сегодняшний срез), и для
/// «Записей» (полный список + агрегаты).
class BookingRowEntity extends Equatable {
  /// Создаёт запись.
  const BookingRowEntity({
    required this.id,
    required this.clubId,
    required this.hallId,
    required this.dayIndex,
    required this.startMinutes,
    required this.durationMinutes,
    required this.headsets,
    required this.consoles,
    required this.clientName,
    required this.phone,
    required this.status,
    required this.source,
    this.packageName,
  });

  /// Идентификатор.
  final String id;

  /// Клуб.
  final String clubId;

  /// Зал.
  final String hallId;

  /// Смещение дня от сегодняшнего (0 — сегодня).
  final int dayIndex;

  /// Начало, минут от полуночи.
  final int startMinutes;

  /// Длительность, минут.
  final int durationMinutes;

  /// VR-шлемов в брони.
  final int headsets;

  /// PS5 в брони.
  final int consoles;

  /// Имя клиента.
  final String clientName;

  /// Телефон.
  final String phone;

  /// Статус.
  final RecordStatus status;

  /// Источник.
  final RecordSource source;

  /// Название пакета, если бронь по пакету.
  final String? packageName;

  /// Конец, минут от полуночи.
  int get endMinutes => startMinutes + durationMinutes;

  /// Всего станций.
  int get stationCount => headsets + consoles;

  /// Длительность в часах.
  double get hours => durationMinutes / 60;

  @override
  List<Object?> get props => <Object?>[
        id,
        clubId,
        hallId,
        dayIndex,
        startMinutes,
        durationMinutes,
        headsets,
        consoles,
        clientName,
        phone,
        status,
        source,
        packageName,
      ];
}
