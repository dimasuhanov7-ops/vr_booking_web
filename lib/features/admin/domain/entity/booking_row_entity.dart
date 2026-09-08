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
  call,

  /// Создана сотрудником прямо в админке.
  admin;

  /// Разбирает значение из мок-данных.
  static RecordSource fromRaw(String raw) => switch (raw) {
        'звонок' => RecordSource.call,
        'админка' => RecordSource.admin,
        _ => RecordSource.widget,
      };

  /// Подпись.
  String get label => switch (this) {
        RecordSource.call => 'звонок',
        RecordSource.admin => 'админка',
        RecordSource.widget => 'виджет',
      };
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
    this.isCancelled = false,
    this.prepay = 0,
    this.note = '',
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

  /// Бронь уже отменена (пришла со статусом `cancelled`).
  final bool isCancelled;

  /// Внесённая предоплата, ₽.
  final int prepay;

  /// Комментарий сотрудника.
  final String note;

  /// Конец, минут от полуночи.
  int get endMinutes => startMinutes + durationMinutes;

  /// Всего станций.
  int get stationCount => headsets + consoles;

  /// Длительность в часах.
  double get hours => durationMinutes / 60;

  /// Копия с изменениями (используется при правке брони в админке).
  BookingRowEntity copyWith({
    String? clientName,
    String? phone,
    int? startMinutes,
    int? durationMinutes,
    int? headsets,
    int? consoles,
    int? prepay,
    String? note,
  }) =>
      BookingRowEntity(
        id: id,
        clubId: clubId,
        hallId: hallId,
        dayIndex: dayIndex,
        startMinutes: startMinutes ?? this.startMinutes,
        durationMinutes: durationMinutes ?? this.durationMinutes,
        headsets: headsets ?? this.headsets,
        consoles: consoles ?? this.consoles,
        clientName: clientName ?? this.clientName,
        phone: phone ?? this.phone,
        status: status,
        source: source,
        packageName: packageName,
        isCancelled: isCancelled,
        prepay: prepay ?? this.prepay,
        note: note ?? this.note,
      );

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
        isCancelled,
        prepay,
        note,
      ];
}
