import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../booking/domain/service/club_clock.dart';
import '../../domain/entity/admin_club_entity.dart';
import '../../domain/entity/audit_entry_entity.dart';
import '../../domain/entity/admin_failure.dart';
import '../../domain/entity/availability_entity.dart';
import '../../domain/entity/booking_row_entity.dart';
import '../../domain/entity/hall_price_entity.dart';
import '../../domain/entity/package_entity.dart';
import '../../domain/entity/promo_entity.dart';
import '../../domain/repository/i_admin_repository.dart';
import '../dto/booking_row_dto.dart';

/// Реализация [IAdminRepository] поверх Supabase (PostgREST).
///
/// Пишет от лица авторизованного сотрудника — доступ проверяет RLS
/// (`booking_is_staff()`), см. миграцию `20260908191216_online_booking_staff_auth`.
class AdminRepository implements IAdminRepository {
  /// Создаёт репозиторий.
  const AdminRepository(this._client);

  final SupabaseClient _client;

  /// Таймзона, если у клуба она почему-то не пришла: клубы в Перми.
  static const String _defaultTimezone = 'Asia/Yekaterinburg';

  // -- доступ ---------------------------------------------------------------

  @override
  Future<bool> isStaff() =>
      _guard(() async => await _client.rpc<bool>('booking_is_staff') == true);

  /// Время и состав меняет RPC `booking_reschedule_order` (миграция
  /// `online_booking_reschedule`); напрямую позиции сотруднику только читаются.
  @override
  bool get canEditSchedule => true;

  /// Таблицы, изменения которых панель ловит через Realtime. Их публикацию
  /// включает миграция `online_booking_admin_realtime`; события приходят с
  /// учётом RLS, то есть только сотрудникам.
  static const List<String> _watchedTables = <String>[
    'booking_orders',
    'booking_order_items',
    'booking_availability',
    'booking_clubs',
  ];

  /// Websocket Realtime может молча отвалиться (сон ноутбука, смена сети) —
  /// раз в минуту перечитываем брони на всякий случай.
  @override
  Duration? get refreshInterval => const Duration(minutes: 1);

  @override
  Stream<void> changes() {
    late final RealtimeChannel channel;
    final StreamController<void> out = StreamController<void>(
      onCancel: () => unawaited(_client.removeChannel(channel)),
    );
    channel = _client.channel('admin-bookings');
    for (final String table in _watchedTables) {
      channel.onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: table,
        callback: (_) {
          if (!out.isClosed) out.add(null);
        },
      );
    }
    channel.subscribe();
    return out.stream;
  }

  // -- чтение ---------------------------------------------------------------

  @override
  Future<List<AdminClubEntity>> fetchClubs() async {
    final List<dynamic> clubs = await _client
        .from('booking_clubs')
        .select('id,slug,name,open_time,close_time,slot_gap_minutes')
        .eq('is_active', true)
        .order('sort_order', ascending: true);
    final List<dynamic> rooms = await _client
        .from('booking_rooms')
        .select('id,club_id,name,sort_order')
        .order('sort_order', ascending: true);
    final List<dynamic> stations = await _client
        .from('booking_stations')
        .select('room_id,type')
        .eq('is_active', true);

    final Map<String, int> vr = <String, int>{};
    final Map<String, int> ps = <String, int>{};
    for (final dynamic s in stations) {
      final Map<String, dynamic> m = s as Map<String, dynamic>;
      final String room = m['room_id'] as String;
      if (m['type'] == 'ps5') {
        ps[room] = (ps[room] ?? 0) + 1;
      } else {
        vr[room] = (vr[room] ?? 0) + 1;
      }
    }

    final Map<String, List<AdminHallEntity>> byClub = <String, List<AdminHallEntity>>{};
    for (final dynamic r in rooms) {
      final Map<String, dynamic> m = r as Map<String, dynamic>;
      final String id = m['id'] as String;
      byClub.putIfAbsent(m['club_id'] as String, () => <AdminHallEntity>[]).add(
            AdminHallEntity(
              id: id,
              name: m['name'] as String,
              headsets: vr[id] ?? 0,
              consoles: ps[id] ?? 0,
            ),
          );
    }

    return clubs.map((dynamic c) {
      final Map<String, dynamic> m = c as Map<String, dynamic>;
      final int open = _minutes(m['open_time'] as String?);
      final int close = _minutes(m['close_time'] as String?);
      return AdminClubEntity(
        id: m['id'] as String,
        slug: m['slug'] as String,
        name: m['name'] as String,
        hoursLabel: '${_hhmm(open)} – ${_hhmm(close)}',
        openMinutes: open,
        closeMinutes: close,
        gapMinutes: (m['slot_gap_minutes'] as num?)?.toInt() ?? 0,
        halls: byClub[m['id']] ?? const <AdminHallEntity>[],
      );
    }).toList(growable: false);
  }

  @override
  Future<List<HallPriceEntity>> fetchPrices() async {
    final List<dynamic> clubs = await _client
        .from('booking_clubs')
        .select('id')
        .eq('is_active', true);
    final List<dynamic> rooms =
        await _client.from('booking_rooms').select('id,club_id');
    // Админка правит базовую ступень тарифа (min_qty = 1); ступени «от N
    // станций» задаются отдельно и здесь не затираются.
    final List<dynamic> prices = await _client
        .from('booking_prices')
        .select('club_id,station_type,day_kind,price_per_hour')
        .eq('min_qty', 1);

    // club_id -> {field -> цена}
    final Map<String, Map<PriceField, int>> byClub = <String, Map<PriceField, int>>{};
    for (final dynamic c in clubs) {
      byClub[(c as Map<String, dynamic>)['id'] as String] = <PriceField, int>{};
    }
    for (final dynamic p in prices) {
      final Map<String, dynamic> m = p as Map<String, dynamic>;
      final PriceField? f = _priceField(
        m['station_type'] as String,
        m['day_kind'] as String,
      );
      if (f == null) continue;
      byClub.putIfAbsent(m['club_id'] as String, () => <PriceField, int>{})[f] =
          (m['price_per_hour'] as num).round();
    }

    final List<HallPriceEntity> out = <HallPriceEntity>[];
    for (final dynamic r in rooms) {
      final Map<String, dynamic> m = r as Map<String, dynamic>;
      final Map<PriceField, int> v = byClub[m['club_id']] ?? <PriceField, int>{};
      out.add(HallPriceEntity(
        hallId: m['id'] as String,
        vrWeekday: v[PriceField.vrWeekday] ?? 0,
        vrWeekend: v[PriceField.vrWeekend] ?? 0,
        ps5Weekday: v[PriceField.ps5Weekday] ?? 0,
        ps5Weekend: v[PriceField.ps5Weekend] ?? 0,
      ));
    }
    return out;
  }

  @override
  Future<List<PackageEntity>> fetchPackages() async {
    final List<dynamic> rows = await _client
        .from('booking_packages')
        .select('id,club_id,room_id,name,headsets,consoles,minutes,price,is_active')
        .order('sort_order', ascending: true);
    return rows.map((dynamic p) {
      final Map<String, dynamic> m = p as Map<String, dynamic>;
      return PackageEntity(
        id: m['id'] as String,
        clubId: m['club_id'] as String,
        hallId: m['room_id'] as String? ?? '',
        name: m['name'] as String,
        headsets: (m['headsets'] as num?)?.toInt() ?? 0,
        consoles: (m['consoles'] as num?)?.toInt() ?? 0,
        minutes: (m['minutes'] as num).toInt(),
        price: (m['price'] as num).round(),
        isEnabled: m['is_active'] as bool? ?? true,
      );
    }).toList(growable: false);
  }

  @override
  Future<List<PromoEntity>> fetchPromos() => _guard(() async {
        final List<dynamic> rows = await _client
            .from('booking_discounts')
            .select('id,code,kind,value,min_stations,active,valid_from,valid_until')
            .not('code', 'is', null)
            .order('code', ascending: true);
        return rows.map((dynamic r) {
          final Map<String, dynamic> m = r as Map<String, dynamic>;
          DateTime? at(String k) =>
              m[k] == null ? null : DateTime.parse(m[k] as String).toUtc();
          return PromoEntity(
            id: m['id'] as String,
            code: m['code'] as String,
            kind: PromoKind.fromRaw(m['kind'] as String?),
            value: PromoKind.valueOf(m['value']),
            minStations: (m['min_stations'] as num?)?.toInt() ?? 1,
            isActive: m['active'] as bool? ?? true,
            validFrom: at('valid_from'),
            validUntil: at('valid_until'),
          );
        }).toList(growable: false);
      });

  @override
  Future<List<BookingRowEntity>> fetchRows() async {
    // Время брони показываем в таймзоне её клуба (booking_clubs.timezone),
    // а не в зашитом смещении: иначе при смене таймзоны клуба всё «съезжает».
    final List<dynamic> clubs =
        await _client.from('booking_clubs').select('id,timezone');
    final Map<String, Duration> tzByClub = <String, Duration>{
      for (final dynamic c in clubs)
        (c as Map<String, dynamic>)['id'] as String: ClubClock.offsetOf(
            c['timezone'] as String? ?? _defaultTimezone),
    };
    final DateTime nowUtc = DateTime.now().toUtc();

    final List<dynamic> orders = await _client
        .from('booking_orders')
        .select(
          'id,club_id,client_name,client_phone,status,source,created_at,'
          'prepay,comment,discount_id,'
          'booking_packages(name),'
          'booking_discounts(code,title,kind,value),'
          'booking_order_items(starts_at,ends_at,booking_stations(type,room_id))',
        )
        .order('created_at', ascending: false)
        // TODO(booking): фильтровать по дате сеанса, а не брать хвост журнала —
        // при большом потоке броней дальние даты могут не попасть в срез.
        .limit(1000);

    final List<BookingRowEntity> out = <BookingRowEntity>[];
    for (final dynamic o in orders) {
      final Map<String, dynamic> m = o as Map<String, dynamic>;
      final Duration tz = tzByClub[m['club_id']] ??
          ClubClock.offsetOf(_defaultTimezone);
      final DateTime now = nowUtc.add(tz);
      final BookingRowEntity? row = BookingRowDto.fromOrderJson(
        m,
        today: DateTime(now.year, now.month, now.day),
        tz: tz,
      );
      if (row != null) out.add(row);
    }
    return out;
  }

  @override
  Future<List<AuditEntryEntity>> fetchAuditLog({int limit = 200}) =>
      _guard(() async {
        final List<dynamic> rows = await _client
            .from('booking_audit_log')
            .select('id,actor_id,entity,action,before,after,created_at')
            .order('created_at', ascending: false)
            .limit(limit);
        // Имена сотрудников. Пока не применена миграция
        // online_booking_staff_read_all, RLS отдаёт только свою строку —
        // остальные покажутся коротким id.
        final List<dynamic> staff =
            await _client.from('booking_staff').select('user_id,name');
        final Map<String, String> names = <String, String>{
          for (final dynamic s in staff)
            if (((s as Map<String, dynamic>)['name'] as String?)?.trim().isNotEmpty ??
                false)
              s['user_id'] as String: (s['name'] as String).trim(),
        };
        return rows.map((dynamic r) {
          final Map<String, dynamic> m = r as Map<String, dynamic>;
          final String? actor = m['actor_id'] as String?;
          return AuditEntryEntity(
            id: (m['id'] as num).toInt(),
            at: DateTime.parse(m['created_at'] as String).toUtc(),
            entity: m['entity'] as String,
            action: m['action'] as String,
            actorId: actor,
            actorName: actor == null ? null : names[actor],
            before: m['before'] as Map<String, dynamic>?,
            after: m['after'] as Map<String, dynamic>?,
          );
        }).toList(growable: false);
      });

  @override
  Future<AvailabilityEntity> fetchAvailability() async {
    final List<dynamic> clubs = await _client
        .from('booking_clubs')
        .select('id,intake_open')
        .eq('is_active', true);
    final List<dynamic> rows = await _client
        .from('booking_availability')
        .select('id,club_id,room_id,day,from_minutes,to_minutes');

    return AvailabilityEntity(
      pausedClubIds: <String>{
        for (final dynamic c in clubs)
          if ((c as Map<String, dynamic>)['intake_open'] == false)
            c['id'] as String,
      },
      closures: rows.map((dynamic r) {
        final Map<String, dynamic> m = r as Map<String, dynamic>;
        final String? day = m['day'] as String?;
        return ClosureEntity(
          id: m['id'] as String,
          clubId: m['club_id'] as String,
          hallId: m['room_id'] as String?,
          day: day == null ? null : DateTime.parse(day),
          fromMinutes: (m['from_minutes'] as num?)?.toInt(),
          toMinutes: (m['to_minutes'] as num?)?.toInt(),
        );
      }).toList(growable: false),
    );
  }

  // -- запись -------------------------------------------------------------

  @override
  Future<void> saveClubPrice({
    required String clubId,
    required PriceField field,
    required int value,
  }) async {
    final ({String type, String day}) k = _priceKey(field);
    await _guard(() => _client
        .from('booking_prices')
        .update(<String, dynamic>{
          'price_per_hour': value,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('club_id', clubId)
        .eq('station_type', k.type)
        .eq('day_kind', k.day)
        .eq('min_qty', 1));
  }

  @override
  Future<String> createPackage(PackageEntity draft) async {
    final Map<String, dynamic> row = await _guard(() => _client
        .from('booking_packages')
        .insert(<String, dynamic>{
          'club_id': draft.clubId,
          'room_id': draft.hallId.isEmpty ? null : draft.hallId,
          'name': draft.name,
          'headsets': draft.headsets,
          'consoles': draft.consoles,
          'minutes': draft.minutes,
          'price': draft.price,
          'is_active': draft.isEnabled,
        })
        .select('id')
        .single());
    return row['id'] as String;
  }

  @override
  Future<void> updatePackage(PackageEntity package) async {
    await _guard(() => _client.from('booking_packages').update(<String, dynamic>{
      'room_id': package.hallId.isEmpty ? null : package.hallId,
      'name': package.name,
      'headsets': package.headsets,
      'consoles': package.consoles,
      'minutes': package.minutes,
      'price': package.price,
      'is_active': package.isEnabled,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', package.id));
  }

  @override
  Future<bool> deletePackage(String packageId) => _guard(() async {
        try {
          await _client.from('booking_packages').delete().eq('id', packageId);
          return true;
        } on PostgrestException catch (e) {
          // 23503 — на пакет ссылаются брони (booking_orders.package_id):
          // удалить нельзя, выключаем, чтобы он пропал из виджета.
          if (e.code != '23503') rethrow;
          await _client.from('booking_packages').update(<String, dynamic>{
            'is_active': false,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          }).eq('id', packageId);
          return false;
        }
      });

  /// Промокоды без политики сотрудника (миграция не применена): вставку RLS
  /// отклоняет, а правка и удаление молча не находят строк.
  static const AdminFailure _promosOff = AdminFailure(
    'Промокоды ещё не включены на сервере — нужна миграция '
    'online_booking_discounts_admin.',
  );

  @override
  Future<String> createPromo(PromoEntity draft) => _guard(() async {
        try {
          final Map<String, dynamic> row = await _client
              .from('booking_discounts')
              .insert(<String, dynamic>{
                'code': draft.code.trim().toUpperCase(),
                'kind': draft.kind.raw,
                'value': draft.value,
                'min_stations': draft.minStations,
                'active': draft.isActive,
              })
              .select('id')
              .single();
          return row['id'] as String;
        } on PostgrestException catch (e) {
          if (e.code == '23505') {
            throw AdminFailure('Промокод ${draft.code.trim().toUpperCase()} уже есть.');
          }
          if (e.code == '42501' || e.message.toLowerCase().contains('row-level security')) {
            throw _promosOff;
          }
          rethrow;
        }
      });

  @override
  Future<void> setPromoActive(String promoId, {required bool active}) =>
      _guard(() async {
        final List<dynamic> updated = await _client
            .from('booking_discounts')
            .update(<String, dynamic>{'active': active})
            .eq('id', promoId)
            .select('id');
        if (updated.isEmpty) throw _promosOff;
      });

  @override
  Future<bool> deletePromo(String promoId) => _guard(() async {
        try {
          final List<dynamic> deleted = await _client
              .from('booking_discounts')
              .delete()
              .eq('id', promoId)
              .select('id');
          if (deleted.isEmpty) throw _promosOff;
          return true;
        } on PostgrestException catch (e) {
          // 23503 — промокод уже в бронях (booking_orders.discount_id):
          // удалить нельзя, выключаем — клиенты его больше не применят.
          if (e.code != '23503') rethrow;
          await setPromoActive(promoId, active: false);
          return false;
        }
      });

  @override
  Future<void> setOrderCancelled(String orderId, {required bool cancelled}) async {
    await _guard(() => _client.from('booking_orders').update(<String, dynamic>{
          'status': cancelled ? 'cancelled' : 'confirmed',
        }).eq('id', orderId));
  }

  @override
  Future<void> setOrderVisit(String orderId, {required RecordStatus status}) async {
    final String raw = switch (status) {
      RecordStatus.visited => 'completed',
      RecordStatus.noShow => 'no_show',
      _ => 'confirmed',
    };
    await _guard(() => _client
        .from('booking_orders')
        .update(<String, dynamic>{'status': raw}).eq('id', orderId));
  }

  @override
  Future<void> updateOrderDetails({
    required String orderId,
    required String clientName,
    required String phone,
    required int prepay,
    required String note,
  }) async {
    final List<dynamic> updated = await _guard(() => _client
        .from('booking_orders')
        .update(<String, dynamic>{
          'client_name': clientName,
          'client_phone': phone,
          'prepay': prepay,
          'comment': note.isEmpty ? null : note,
        })
        .eq('id', orderId)
        .select('id'));
    // RLS не даёт ошибку, а просто не обновляет строку — проверяем явно.
    if (updated.isEmpty) throw const AdminFailure.auth();
  }

  @override
  Future<String> createBooking({
    required String clubId,
    required String hallId,
    required DateTime day,
    required int startMinutes,
    required List<int> headsetsByHour,
    required List<int> consolesByHour,
    required String clientName,
    required String phone,
    required String note,
  }) =>
      _guard(() async {
        final List<Map<String, dynamic>> segments = await _planSegments(
          clubId: clubId,
          hallId: hallId,
          day: day,
          startMinutes: startMinutes,
          headsetsByHour: headsetsByHour,
          consolesByHour: consolesByHour,
        );
        try {
          // От сотрудника RPC не применяет лимиты и паузу приёма, source=staff.
          return await _client.rpc<String>(
            'booking_create_order',
            params: <String, dynamic>{
              'p_club_id': clubId,
              'p_client_name': clientName,
              'p_client_phone': phone,
              'p_segments': segments,
              'p_comment': note.isEmpty ? null : note,
              'p_source': 'staff',
            },
          );
        } on PostgrestException catch (e) {
          throw _bookingError(e) ?? e;
        }
      });

  @override
  Future<void> rescheduleOrder({
    required String orderId,
    required String clubId,
    required String hallId,
    required DateTime day,
    required int startMinutes,
    required List<int> headsetsByHour,
    required List<int> consolesByHour,
  }) =>
      _guard(() async {
        // Станции самой брони: их не считаем занятыми и берём в первую очередь —
        // при переносе гость по возможности остаётся на тех же местах.
        final List<dynamic> own = await _client
            .from('booking_order_items')
            .select('station_id')
            .eq('order_id', orderId);
        final List<String> prefer = <String>{
          for (final dynamic r in own) (r as Map<String, dynamic>)['station_id'] as String,
        }.toList();
        final List<Map<String, dynamic>> segments = await _planSegments(
          clubId: clubId,
          hallId: hallId,
          day: day,
          startMinutes: startMinutes,
          headsetsByHour: headsetsByHour,
          consolesByHour: consolesByHour,
          excludeOrderId: orderId,
          prefer: prefer,
        );
        try {
          await _client.rpc<void>(
            'booking_reschedule_order',
            params: <String, dynamic>{'p_order_id': orderId, 'p_segments': segments},
          );
        } on PostgrestException catch (e) {
          // PGRST202 — функции на сервере нет: миграция ещё не применена.
          if (e.code == 'PGRST202') {
            throw const AdminFailure('Перенос брони ещё не включён на сервере: '
                'нужна миграция online_booking_reschedule.');
          }
          throw _bookingError(e) ?? e;
        }
      });

  /// Отрезки брони для RPC: на каждый час подбирает свободные станции зала
  /// нужного типа и склеивает подряд идущие часы с одинаковым составом.
  ///
  /// [excludeOrderId] — позиции этой брони не считаются занятыми (перенос);
  /// [prefer] — станции, которые берутся первыми.
  Future<List<Map<String, dynamic>>> _planSegments({
    required String clubId,
    required String hallId,
    required DateTime day,
    required int startMinutes,
    required List<int> headsetsByHour,
    required List<int> consolesByHour,
    String? excludeOrderId,
    List<String> prefer = const <String>[],
  }) async {
    final Map<String, dynamic> club = await _client
        .from('booking_clubs')
        .select('timezone')
        .eq('id', clubId)
        .single();
    final Duration tz =
        ClubClock.offsetOf(club['timezone'] as String? ?? _defaultTimezone);
    final int hours = headsetsByHour.length;
    final DateTime from = DateTime.utc(day.year, day.month, day.day)
        .add(Duration(minutes: startMinutes))
        .subtract(tz);
    final DateTime to = from.add(Duration(hours: hours));

    final List<dynamic> stationRows = await _client
        .from('booking_stations')
        .select('id,type')
        .eq('room_id', hallId)
        .eq('is_active', true)
        .order('sort_order', ascending: true);
    final List<({String id, bool ps5})> stations = <({String id, bool ps5})>[
      for (final dynamic s in stationRows)
        (
          id: (s as Map<String, dynamic>)['id'] as String,
          ps5: s['type'] == 'ps5',
        ),
    ];

    List<dynamic> busyRows = const <dynamic>[];
    if (stations.isNotEmpty) {
      PostgrestFilterBuilder<List<Map<String, dynamic>>> q = _client
          .from('booking_order_items')
          .select('station_id,starts_at,ends_at')
          .inFilter('station_id',
              stations.map((({String id, bool ps5}) s) => s.id).toList())
          .eq('is_active', true)
          .lt('starts_at', to.toIso8601String())
          .gt('ends_at', from.toIso8601String());
      if (excludeOrderId != null) q = q.neq('order_id', excludeOrderId);
      busyRows = await q;
    }
    final List<({String id, DateTime start, DateTime end})> busy =
        <({String id, DateTime start, DateTime end})>[
      for (final dynamic b in busyRows)
        (
          id: (b as Map<String, dynamic>)['station_id'] as String,
          start: DateTime.parse(b['starts_at'] as String),
          end: DateTime.parse(b['ends_at'] as String),
        ),
    ];

    // Подбираем станции по часам. Сначала те же, что в прошлом часе (или
    // [prefer] для первого): гостю не нужно пересаживаться, отрезков меньше.
    final List<List<String>> perHour = <List<String>>[];
    List<String> prev = prefer;
    for (int h = 0; h < hours; h++) {
      final DateTime a = from.add(Duration(hours: h));
      final DateTime b = a.add(const Duration(hours: 1));
      List<String> pick({required bool ps5, required int need}) {
        final List<String> free = <String>[
          for (final ({String id, bool ps5}) s in stations)
            if (s.ps5 == ps5 &&
                !busy.any((({String id, DateTime start, DateTime end}) x) =>
                    x.id == s.id && x.start.isBefore(b) && x.end.isAfter(a)))
              s.id,
        ];
        if (free.length < need) {
          throw AdminFailure('${h + 1}-й час: свободно только '
              '${free.length} ${ps5 ? 'PS5' : 'шлемов'}.');
        }
        return <String>[
          ...free.where(prev.contains),
          ...free.where((String id) => !prev.contains(id)),
        ].take(need).toList();
      }

      final List<String> ids = <String>[
        ...pick(ps5: false, need: headsetsByHour[h]),
        ...pick(ps5: true, need: consolesByHour[h]),
      ];
      perHour.add(ids);
      prev = ids.isEmpty ? prev : ids;
    }

    // Подряд идущие часы с одинаковым составом — один отрезок (p_segments).
    final List<Map<String, dynamic>> segments = <Map<String, dynamic>>[];
    int runStart = 0;
    for (int h = 1; h <= hours; h++) {
      if (h < hours && _sameIds(perHour[h - 1], perHour[h])) continue;
      if (perHour[runStart].isNotEmpty) {
        segments.add(<String, dynamic>{
          'station_ids': perHour[runStart],
          'starts_at': from.add(Duration(hours: runStart)).toIso8601String(),
          'ends_at': from.add(Duration(hours: h)).toIso8601String(),
        });
      }
      runStart = h;
    }
    if (segments.isEmpty) {
      throw const AdminFailure('Добавьте хотя бы один шлем или одну PS5.');
    }
    return segments;
  }

  /// Понятный сотруднику текст для отказа `booking_create_order`, либо `null`.
  static AdminFailure? _bookingError(PostgrestException e) {
    if (e.code == '23P01') {
      return const AdminFailure(
          'Эти станции только что заняли. Обновите страницу и выберите снова.');
    }
    final String m = e.message;
    if (m.contains('SLOT_CLOSED')) {
      return const AdminFailure('Это время закрыто на вкладке «Доступность».');
    }
    if (m.contains('STARTS_IN_PAST')) {
      return const AdminFailure('Это время уже прошло.');
    }
    if (m.contains('OUTSIDE_WORKING_HOURS')) {
      return const AdminFailure('Сеанс выходит за часы работы клуба.');
    }
    if (m.contains('BAD_DURATION')) {
      return const AdminFailure('Такой сеанс сервер не принимает: не длиннее 5 часов.');
    }
    if (m.contains('ORDER_CANCELLED')) {
      return const AdminFailure('Отменённую бронь перенести нельзя — сначала верните её.');
    }
    if (m.contains('ORDER_NOT_FOUND')) {
      return const AdminFailure('Бронь не найдена — возможно, её удалили.');
    }
    return null;
  }

  static bool _sameIds(List<String> a, List<String> b) =>
      a.length == b.length && a.every(b.contains);

  @override
  Future<void> setIntakeOpen(String clubId, {required bool open}) async {
    await _guard(() => _client
        .from('booking_clubs')
        .update(<String, dynamic>{'intake_open': open}).eq('id', clubId));
  }

  @override
  Future<void> setHallClosed({
    required String clubId,
    required String hallId,
    required bool closed,
  }) async {
    if (closed) {
      // Зал закрыт бессрочно: day и окно не задаём.
      await _guard(() => _client.from('booking_availability').insert(
            <String, dynamic>{'club_id': clubId, 'room_id': hallId},
          ));
      return;
    }
    await _guard(() => _client
        .from('booking_availability')
        .delete()
        .eq('club_id', clubId)
        .eq('room_id', hallId)
        .isFilter('day', null)
        .isFilter('from_minutes', null));
  }

  @override
  Future<void> setSlotClosed({
    required String clubId,
    required DateTime day,
    required int startMinutes,
    required bool closed,
  }) async {
    final String date = _dateOnly(day);
    if (closed) {
      await _guard(() => _client.from('booking_availability').insert(
            <String, dynamic>{
              'club_id': clubId,
              'day': date,
              'from_minutes': startMinutes,
              'to_minutes': startMinutes + 60,
            },
          ));
      return;
    }
    await _guard(() => _client
        .from('booking_availability')
        .delete()
        .eq('club_id', clubId)
        .eq('day', date)
        .eq('from_minutes', startMinutes));
  }

  static String _dateOnly(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  /// Переводит ошибку PostgREST в [AdminFailure] с понятным сотруднику текстом.
  ///
  /// Главное — отличить «сессия истекла / прав нет» от обрыва связи: в первом
  /// случае помогает только повторный вход, и сотрудник должен это понимать.
  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on PostgrestException catch (e) {
      final String m = e.message.toLowerCase();
      // 42501 — insufficient_privilege (в т.ч. отказ RLS);
      // PGRST301 / JWT expired — протухший или отозванный токен.
      if (e.code == '42501' ||
          e.code == 'PGRST301' ||
          m.contains('jwt') ||
          m.contains('row-level security')) {
        throw const AdminFailure.auth();
      }
      throw AdminFailure('Сервер отклонил изменение: ${e.message}');
    } on AdminFailure {
      rethrow;
    } catch (_) {
      throw const AdminFailure('Нет связи с сервером. Попробуйте ещё раз.');
    }
  }

  // -- утилиты -----------------------------------------------------------

  static int _minutes(String? time) {
    if (time == null || time.isEmpty) return 0;
    final List<String> p = time.split(':');
    final int h = int.tryParse(p[0]) ?? 0;
    final int m = p.length > 1 ? (int.tryParse(p[1]) ?? 0) : 0;
    return h * 60 + m;
  }

  static String _hhmm(int minutes) =>
      '${(minutes ~/ 60).toString().padLeft(2, '0')}:'
      '${(minutes % 60).toString().padLeft(2, '0')}';

  static PriceField? _priceField(String type, String day) {
    final bool ps = type == 'ps5';
    final bool weekend = day == 'weekend';
    if (ps) return weekend ? PriceField.ps5Weekend : PriceField.ps5Weekday;
    return weekend ? PriceField.vrWeekend : PriceField.vrWeekday;
  }

  static ({String type, String day}) _priceKey(PriceField field) => switch (field) {
        PriceField.vrWeekday => (type: 'vr_headset', day: 'weekday'),
        PriceField.vrWeekend => (type: 'vr_headset', day: 'weekend'),
        PriceField.ps5Weekday => (type: 'ps5', day: 'weekday'),
        PriceField.ps5Weekend => (type: 'ps5', day: 'weekend'),
      };

}
