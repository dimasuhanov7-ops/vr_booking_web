import '../entity/audit_entry_entity.dart';

/// Понятная сотруднику строка журнала: что поменялось и подробности.
typedef AuditLine = ({String title, String? details});

/// Переводит сырые строки `booking_audit_log` (before/after целиком) в фразы
/// вроде «Цена · V-Ray · VR будни: 800 → 900 ₽/ч».
class AuditDescriber {
  /// Создаёт сервис. [clubNames] и [hallNames] — названия по id.
  const AuditDescriber({
    this.clubNames = const <String, String>{},
    this.hallNames = const <String, String>{},
  });

  /// Названия клубов по id.
  final Map<String, String> clubNames;

  /// Названия залов по id.
  final Map<String, String> hallNames;

  /// Кто сделал: имя сотрудника, «клиент или система» либо короткий id.
  static String actorOf(AuditEntryEntity e) {
    final String? name = e.actorName?.trim();
    if (name != null && name.isNotEmpty) return name;
    final String? id = e.actorId;
    if (id == null) return 'клиент или система';
    return 'сотрудник ${id.length > 8 ? id.substring(0, 8) : id}';
  }

  /// Описание записи.
  AuditLine describe(AuditEntryEntity e) {
    final Map<String, dynamic> row = e.after ?? e.before ?? const <String, dynamic>{};
    return switch (e.entity) {
      'booking_prices' => _price(e, row),
      'booking_packages' => _package(e, row),
      'booking_availability' => _availability(e, row),
      'booking_clubs' => _club(e, row),
      'booking_orders' => _order(e, row),
      'booking_reschedule' => _reschedule(e, row),
      _ => (title: '${e.entity} · ${e.action}', details: null),
    };
  }

  AuditLine _price(AuditEntryEntity e, Map<String, dynamic> row) {
    final String type = row['station_type'] == 'ps5' ? 'PS5' : 'VR';
    final String day = row['day_kind'] == 'weekend' ? 'выходные' : 'будни';
    final int qty = (row['min_qty'] as num?)?.toInt() ?? 1;
    final String what = '$type $day${qty > 1 ? ', от $qty станций' : ''}';
    final String club = _clubName(row['club_id']);
    final String? was = _num(e.before?['price_per_hour']);
    final String? now = _num(e.after?['price_per_hour']);
    return switch (e.action) {
      'insert' => (title: 'Цена добавлена · $club', details: '$what: $now ₽/ч'),
      'delete' => (title: 'Цена удалена · $club', details: '$what: было $was ₽/ч'),
      _ => (title: 'Цена · $club', details: '$what: $was → $now ₽/ч'),
    };
  }

  AuditLine _package(AuditEntryEntity e, Map<String, dynamic> row) {
    final String name = '«${row['name'] ?? 'пакет'}»';
    final String club = _clubName(row['club_id']);
    if (e.action == 'insert') {
      return (
        title: 'Новый пакет $name · $club',
        details: '${_kit(row)}, ${_num(row['price'])} ₽',
      );
    }
    if (e.action == 'delete') return (title: 'Пакет $name удалён · $club', details: null);

    final List<String> changes = <String>[];
    final Map<String, dynamic> b = e.before ?? const <String, dynamic>{};
    final Map<String, dynamic> a = e.after ?? const <String, dynamic>{};
    if (b['name'] != a['name']) changes.add('название: «${b['name']}» → «${a['name']}»');
    if (b['price'] != a['price']) {
      changes.add('цена: ${_num(b['price'])} → ${_num(a['price'])} ₽');
    }
    if (b['headsets'] != a['headsets'] ||
        b['consoles'] != a['consoles'] ||
        b['minutes'] != a['minutes']) {
      changes.add('состав: ${_kit(b)} → ${_kit(a)}');
    }
    if (b['room_id'] != a['room_id']) {
      changes.add('зал: ${_hallName(b['room_id'])} → ${_hallName(a['room_id'])}');
    }
    if (b['is_active'] != a['is_active']) {
      changes.add(a['is_active'] == true ? 'включён' : 'выключен');
    }
    return (
      title: 'Пакет $name · $club',
      details: changes.isEmpty ? null : changes.join('; '),
    );
  }

  AuditLine _availability(AuditEntryEntity e, Map<String, dynamic> row) {
    final bool open = e.action == 'delete';
    final String club = _clubName(row['club_id']);
    final String? room = row['room_id'] as String?;
    final String? day = row['day'] as String?;
    final int? from = (row['from_minutes'] as num?)?.toInt();
    final int? to = (row['to_minutes'] as num?)?.toInt();

    final String what;
    if (day == null && from == null) {
      what = room == null ? 'весь клуб' : 'зал «${_hallName(room)}»';
    } else {
      final String date = day == null ? 'ежедневно' : _date(day);
      final String window = from == null ? 'весь день' : '${_hhmm(from)}–${_hhmm(to ?? 1440)}';
      what = '$date, $window${room == null ? '' : ' · ${_hallName(room)}'}';
    }
    return (title: '${open ? 'Открыто' : 'Закрыто'} для записи · $club', details: what);
  }

  AuditLine _club(AuditEntryEntity e, Map<String, dynamic> row) {
    final String club = (row['name'] as String?) ?? _clubName(row['id']);
    final Map<String, dynamic> b = e.before ?? const <String, dynamic>{};
    final Map<String, dynamic> a = e.after ?? const <String, dynamic>{};
    final List<String> changes = <String>[];
    if (b['intake_open'] != a['intake_open']) {
      changes.add(a['intake_open'] == false
          ? 'онлайн-запись на паузе'
          : 'онлайн-запись снова открыта');
    }
    if (b['open_time'] != a['open_time'] || b['close_time'] != a['close_time']) {
      changes.add('часы: ${_time(b['open_time'])}–${_time(b['close_time'])} → '
          '${_time(a['open_time'])}–${_time(a['close_time'])}');
    }
    if (b['timezone'] != a['timezone']) {
      changes.add('часовой пояс: ${b['timezone']} → ${a['timezone']}');
    }
    return (
      title: 'Клуб $club',
      details: changes.isEmpty ? 'настройки клуба' : changes.join('; '),
    );
  }

  AuditLine _order(AuditEntryEntity e, Map<String, dynamic> row) {
    final String who = (row['client_name'] as String?) ?? 'бронь';
    final String? was = e.before?['status'] as String?;
    final String? now = e.after?['status'] as String?;
    return (
      title: 'Бронь · $who · ${_clubName(row['club_id'])}',
      details: 'статус: ${_status(was)} → ${_status(now)}',
    );
  }

  /// Перенос брони (`booking_reschedule_order`): прежнее и новое расписание.
  AuditLine _reschedule(AuditEntryEntity e, Map<String, dynamic> row) {
    String span(Map<String, dynamic>? r) {
      if (r == null) return '—';
      final int vr = (r['vr'] as num?)?.toInt() ?? 0;
      final int ps = (r['ps'] as num?)?.toInt() ?? 0;
      final String kit = <String>[if (vr > 0) '$vr VR', if (ps > 0) '$ps PS5'].join(' + ');
      final String day = r['day'] == null ? '' : '${_date(r['day'] as String)} ';
      return '$day${r['from']}–${r['to']}, $kit';
    }

    return (
      title: 'Бронь перенесена · ${row['client_name'] ?? 'бронь'} · ${_clubName(row['club_id'])}',
      details: '${span(e.before)} → ${span(e.after)}',
    );
  }

  // -- мелочи -----------------------------------------------------------------

  String _clubName(Object? id) => clubNames[id] ?? 'клуб';

  String _hallName(Object? id) => id == null ? 'все залы' : (hallNames[id] ?? 'зал');

  static String _kit(Map<String, dynamic> r) {
    final int vr = (r['headsets'] as num?)?.toInt() ?? 0;
    final int ps = (r['consoles'] as num?)?.toInt() ?? 0;
    final int min = (r['minutes'] as num?)?.toInt() ?? 0;
    final String parts = <String>[
      if (vr > 0) '$vr VR',
      if (ps > 0) '$ps PS5',
    ].join(' + ');
    return '$parts, ${min ~/ 60} ч';
  }

  static String? _num(Object? v) {
    if (v == null) return null;
    final num? n = v is num ? v : num.tryParse('$v');
    if (n == null) return '$v';
    return n == n.roundToDouble() ? n.round().toString() : n.toString();
  }

  static String _hhmm(int minutes) =>
      '${(minutes ~/ 60).toString().padLeft(2, '0')}:'
      '${(minutes % 60).toString().padLeft(2, '0')}';

  static String _time(Object? v) {
    final String s = '${v ?? ''}';
    return s.length >= 5 ? s.substring(0, 5) : s;
  }

  static String _date(String iso) {
    final DateTime? d = DateTime.tryParse(iso);
    if (d == null) return iso;
    return '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}';
  }

  static String _status(String? raw) => switch (raw) {
        'confirmed' => 'подтверждена',
        'cancelled' => 'отменена',
        'completed' => 'пришёл',
        'no_show' => 'не пришёл',
        null => '—',
        _ => raw,
      };
}
