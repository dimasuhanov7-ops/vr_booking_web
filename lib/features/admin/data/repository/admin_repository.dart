import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../booking/data/dto/busy_interval_dto.dart';
import '../../../booking/data/dto/station_dto.dart';
import '../../../booking/domain/entity/busy_interval_entity.dart';
import '../../../booking/domain/entity/reservation_request_entity.dart';
import '../../../booking/domain/entity/station_entity.dart';
import '../../../booking/domain/service/club_clock.dart';
import '../../domain/entity/admin_booking_request_entity.dart';
import '../../domain/entity/admin_club_entity.dart';
import '../../domain/entity/admin_failure.dart';
import '../../domain/entity/availability_entity.dart';
import '../../domain/entity/booking_row_entity.dart';
import '../../domain/entity/hall_price_entity.dart';
import '../../domain/entity/package_entity.dart';
import '../../domain/repository/i_admin_repository.dart';
import '../../domain/service/admin_station_allocator.dart';
import '../dto/booking_row_dto.dart';

/// Реализация [IAdminRepository] поверх Supabase (PostgREST).
///
/// Пишет от лица авторизованного сотрудника — доступ проверяет RLS
/// (`booking_is_staff()`), см. миграцию `20260909120000_online_booking_staff_auth`.
///
/// Обновления и удаления возвращают затронутые строки и проверяют, что они
/// есть: RLS не выдаёт ошибку, а молча не меняет чужие строки, и без проверки
/// экран показывал бы сохранение, которого не было.
class AdminRepository implements IAdminRepository {
  /// Создаёт репозиторий.
  const AdminRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<bool> hasAccess() => _guard(() async {
        final dynamic ok = await _client.rpc<dynamic>('booking_is_staff');
        return ok == true;
      });

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
    final List<dynamic> prices = await _client
        .from('booking_prices')
        .select('club_id,station_type,day_kind,price_per_hour,min_qty');

    // club_id -> {field -> цена}
    final Map<String, Map<PriceField, int>> byClub = <String, Map<PriceField, int>>{};
    for (final dynamic c in clubs) {
      byClub[(c as Map<String, dynamic>)['id'] as String] = <PriceField, int>{};
    }
    // Ступени шлемов («от 6 штук дешевле») лежат в тех же строках с min_qty > 1:
    // club_id -> порог -> цены по типу дня.
    final Map<String, Map<int, ({int? weekday, int? weekend})>> tiers =
        <String, Map<int, ({int? weekday, int? weekend})>>{};
    for (final dynamic p in prices) {
      final Map<String, dynamic> m = p as Map<String, dynamic>;
      final String clubId = m['club_id'] as String;
      final String type = m['station_type'] as String;
      final bool weekend = m['day_kind'] as String == 'weekend';
      final int qty = (m['min_qty'] as num?)?.toInt() ?? 1;
      final int value = (m['price_per_hour'] as num).round();

      if (qty > 1) {
        // Ступени админка ведёт только для шлемов.
        if (type != 'vr_headset') continue;
        final Map<int, ({int? weekday, int? weekend})> club =
            tiers.putIfAbsent(clubId, () => <int, ({int? weekday, int? weekend})>{});
        final ({int? weekday, int? weekend}) cur =
            club[qty] ?? (weekday: null, weekend: null);
        club[qty] = weekend
            ? (weekday: cur.weekday, weekend: value)
            : (weekday: value, weekend: cur.weekend);
        continue;
      }

      final PriceField? f = _priceField(type, m['day_kind'] as String);
      if (f == null) continue;
      byClub.putIfAbsent(clubId, () => <PriceField, int>{})[f] = value;
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
        // Если у ступени задан только один тип дня, второй берём из базовой
        // цены — нулевой цены за шлем быть не должно.
        vrTiers: <VrTierEntity>[
          for (final MapEntry<int, ({int? weekday, int? weekend})> t
              in (tiers[m['club_id']] ?? <int, ({int? weekday, int? weekend})>{})
                  .entries)
            VrTierEntity(
              from: t.key,
              weekday: t.value.weekday ?? v[PriceField.vrWeekday] ?? 0,
              weekend: t.value.weekend ?? v[PriceField.vrWeekend] ?? 0,
            ),
        ]..sort((VrTierEntity a, VrTierEntity b) => a.from.compareTo(b.from)),
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
  Future<List<BookingRowEntity>> fetchRows() async {
    // Пояс берём у клуба, а не зашиваем в код: сид однажды уже поставил Москву
    // вместо Перми, и все брони в админке съехали бы на два часа.
    final List<dynamic> clubs =
        await _client.from('booking_clubs').select('id,timezone');
    final Map<String, Duration> tzByClub = <String, Duration>{
      for (final dynamic c in clubs)
        (c as Map<String, dynamic>)['id'] as String: ClubClock.offsetOf(
          c['timezone'] as String? ?? '',
        ),
    };

    final List<dynamic> orders = await _client
        .from('booking_orders')
        .select(
          'id,club_id,client_name,client_phone,status,source,created_at,comment,prepay,'
          'booking_packages(name),'
          'booking_order_items(starts_at,ends_at,booking_stations(type,room_id))',
        )
        .order('created_at', ascending: false)
        // TODO(booking): фильтровать по дате сеанса, а не брать хвост журнала —
        // при большом потоке броней дальние даты могут не попасть в срез.
        .limit(1000);

    final List<BookingRowEntity> out = <BookingRowEntity>[];
    for (final dynamic o in orders) {
      final Map<String, dynamic> order = o as Map<String, dynamic>;
      final Duration tz =
          tzByClub[order['club_id']] ?? DateTime.now().timeZoneOffset;
      final DateTime now = DateTime.now().toUtc().add(tz);
      // Бронь на несколько залов даёт запись на каждый зал.
      out.addAll(BookingRowDto.fromOrderJson(
        order,
        today: DateTime(now.year, now.month, now.day),
        tz: tz,
      ));
    }
    return out;
  }

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
  Future<String> createBooking(AdminBookingRequest request) => _guard(() async {
        final Map<String, dynamic> club = await _client
            .from('booking_clubs')
            .select('timezone')
            .eq('id', request.clubId)
            .single();
        final Duration tz =
            ClubClock.offsetOf(club['timezone'] as String? ?? '');

        final List<dynamic> stationRows = await _client
            .from('booking_stations')
            .select('*, booking_rooms!inner(name, club_id, sort_order)')
            .eq('booking_rooms.club_id', request.clubId)
            .eq('is_active', true)
            .order('sort_order', ascending: true);
        final List<StationEntity> stations = stationRows
            .map((dynamic e) =>
                StationDto.fromJson(e as Map<String, dynamic>).toEntity())
            .toList(growable: false);

        // Занятость — с сервера, а не из журнала админки: пока сотрудник
        // заполнял форму, клиент мог забронировать эти же места.
        final List<dynamic> busyRows = await _client.rpc<List<dynamic>>(
          'booking_busy_intervals',
          params: <String, dynamic>{
            'p_club_id': request.clubId,
            'p_day': _dateOnly(request.day),
          },
        );
        final List<BusyIntervalEntity> busy = busyRows
            .map((dynamic e) =>
                BusyIntervalDto.fromJson(e as Map<String, dynamic>).toEntity())
            .toList(growable: false);

        final DateTime startUtc = DateTime.utc(
          request.day.year,
          request.day.month,
          request.day.day,
        ).add(Duration(minutes: request.startMinutes)).subtract(tz);

        final List<ReservationSegmentEntity>? segments =
            const AdminStationAllocator().allocate(
          stations: stations,
          busy: busy,
          startUtc: startUtc,
          hours: request.hours,
        );
        if (segments == null) {
          throw const AdminFailure(
            'Столько свободных мест на это время уже нет — их только что '
            'заняли. Обновите данные и выберите заново.',
          );
        }
        if (segments.isEmpty) {
          throw const AdminFailure('Добавьте хотя бы один шлем или одну PS5.');
        }

        final String orderId;
        try {
          orderId = await _client.rpc<String>(
            'booking_create_order',
            params: <String, dynamic>{
              'p_club_id': request.clubId,
              'p_client_name': request.clientName.trim(),
              'p_client_phone': _phoneOrPlaceholder(request.phone),
              'p_segments': <Map<String, dynamic>>[
                for (final ReservationSegmentEntity s in segments)
                  <String, dynamic>{
                    'station_ids': s.stationIds,
                    'starts_at': s.startsAt.toUtc().toIso8601String(),
                    'ends_at': s.endsAt.toUtc().toIso8601String(),
                  },
              ],
              'p_comment': request.note.trim().isEmpty ? null : request.note.trim(),
              'p_source': 'staff',
            },
          );
        } on PostgrestException catch (e) {
          final AdminFailure? failure = _bookingFailure(e);
          if (failure != null) throw failure;
          rethrow;
        }

        if (request.prepay > 0) {
          await _client
              .from('booking_orders')
              .update(<String, dynamic>{'prepay': request.prepay})
              .eq('id', orderId);
        }
        return orderId;
      });

  @override
  Future<void> updateOrderDetails({
    required String orderId,
    required String clientName,
    required String phone,
    required String note,
    required int prepay,
  }) =>
      _guard(() async {
        final List<dynamic> rows = await _client
            .from('booking_orders')
            .update(<String, dynamic>{
              'client_name': clientName.trim(),
              'client_phone': _phoneOrPlaceholder(phone),
              'comment': note.trim().isEmpty ? null : note.trim(),
              'prepay': prepay,
            })
            .eq('id', orderId)
            .select('id');
        _ensureChanged(rows);
      });

  @override
  Future<void> saveClubPrice({
    required String clubId,
    required PriceField field,
    required int value,
  }) =>
      _guard(() async {
        final ({String type, String day}) k = _priceKey(field);
        final List<dynamic> rows = await _client
            .from('booking_prices')
            .update(<String, dynamic>{
              'price_per_hour': value,
              'updated_at': DateTime.now().toUtc().toIso8601String(),
            })
            .eq('club_id', clubId)
            .eq('station_type', k.type)
            .eq('day_kind', k.day)
            // Базовая цена — только строка первой ступени.
            .eq('min_qty', 1)
            .select('id');
        _ensureChanged(rows);
      });

  /// Таблицы, изменения которых видны на вкладках «Записи» и «Доступность».
  static const List<String> _watchedTables = <String>[
    'booking_orders',
    'booking_order_items',
    'booking_availability',
    'booking_clubs',
  ];

  @override
  Stream<void> watchChanges() {
    RealtimeChannel? channel;
    late final StreamController<void> out;
    out = StreamController<void>.broadcast(
      onListen: () {
        final RealtimeChannel c = _client.channel('admin-bookings');
        for (final String table in _watchedTables) {
          c.onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: table,
            callback: (_) {
              if (!out.isClosed) out.add(null);
            },
          );
        }
        channel = c..subscribe();
      },
      onCancel: () async {
        final RealtimeChannel? c = channel;
        channel = null;
        if (c != null) await _client.removeChannel(c);
      },
    );
    return out.stream;
  }

  @override
  Future<void> saveVrTiers({
    required String clubId,
    required List<VrTierEntity> tiers,
  }) =>
      _guard(() async {
        final String now = DateTime.now().toUtc().toIso8601String();
        // Сначала записываем новые ступени, потом убираем лишние: в обратном
        // порядке между запросами цена на миг стала бы без ступеней.
        if (tiers.isNotEmpty) {
          await _client.from('booking_prices').upsert(
            <Map<String, dynamic>>[
              for (final VrTierEntity t in tiers)
                for (final ({String day, int value}) r in <({String day, int value})>[
                  (day: 'weekday', value: t.weekday),
                  (day: 'weekend', value: t.weekend),
                ])
                  <String, dynamic>{
                    'club_id': clubId,
                    'station_type': 'vr_headset',
                    'day_kind': r.day,
                    'min_qty': t.from,
                    'price_per_hour': r.value,
                    'updated_at': now,
                  },
            ],
            onConflict: 'club_id,station_type,day_kind,min_qty',
          );
        }

        final Set<int> keep = <int>{for (final VrTierEntity t in tiers) t.from};
        final List<dynamic> existing = await _client
            .from('booking_prices')
            .select('id,min_qty')
            .eq('club_id', clubId)
            .eq('station_type', 'vr_headset')
            .gt('min_qty', 1);
        final List<String> stale = <String>[
          for (final dynamic r in existing)
            if (!keep.contains(((r as Map<String, dynamic>)['min_qty'] as num).toInt()))
              r['id'] as String,
        ];
        if (stale.isNotEmpty) {
          await _client.from('booking_prices').delete().inFilter('id', stale);
        }
      });

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
  Future<void> updatePackage(PackageEntity package) => _guard(() async {
        final List<dynamic> rows = await _client
            .from('booking_packages')
            .update(<String, dynamic>{
              'room_id': package.hallId.isEmpty ? null : package.hallId,
              'name': package.name,
              'headsets': package.headsets,
              'consoles': package.consoles,
              'minutes': package.minutes,
              'price': package.price,
              'is_active': package.isEnabled,
              'updated_at': DateTime.now().toUtc().toIso8601String(),
            })
            .eq('id', package.id)
            .select('id');
        _ensureChanged(rows);
      });

  @override
  Future<void> deletePackage(String packageId) => _guard(() async {
        final List<dynamic> rows = await _client
            .from('booking_packages')
            .delete()
            .eq('id', packageId)
            .select('id');
        _ensureChanged(rows);
      });

  @override
  Future<void> setOrderCancelled(String orderId, {required bool cancelled}) =>
      _guard(() async {
        final List<dynamic> rows = await _client
            .from('booking_orders')
            .update(<String, dynamic>{
              'status': cancelled ? 'cancelled' : 'confirmed',
            })
            .eq('id', orderId)
            .select('id');
        _ensureChanged(rows);
      });

  @override
  Future<void> setIntakeOpen(String clubId, {required bool open}) =>
      _guard(() async {
        final List<dynamic> rows = await _client
            .from('booking_clubs')
            .update(<String, dynamic>{'intake_open': open})
            .eq('id', clubId)
            .select('id');
        _ensureChanged(rows);
      });

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

  /// Гость у стойки может быть без телефона, а в БД поле обязательное
  /// (не короче 5 символов).
  static String _phoneOrPlaceholder(String phone) =>
      phone.trim().isEmpty ? 'не указан' : phone.trim();

  /// Изменение не затронуло ни одной строки — RLS отказал молча или записи
  /// уже нет. Показываем это, а не мнимый успех.
  static void _ensureChanged(List<dynamic> rows) {
    if (rows.isEmpty) {
      throw const AdminFailure(
        'Изменение не сохранилось: запись не найдена или нет прав. '
        'Обновите данные.',
      );
    }
  }

  /// Отказы `booking_create_order`, которые сотрудник может исправить сам.
  /// `null` — общий разбор в [_guard].
  static AdminFailure? _bookingFailure(PostgrestException e) {
    final String m = e.message;
    if (e.code == '23P01') {
      return const AdminFailure(
        'Эти места только что заняли. Обновите данные и выберите заново.',
      );
    }
    if (m.contains('SLOT_CLOSED')) {
      return const AdminFailure('Это время закрыто на вкладке «Доступность».');
    }
    if (m.contains('OUTSIDE_WORKING_HOURS')) {
      return const AdminFailure('Сеанс выходит за часы работы клуба.');
    }
    if (m.contains('STARTS_IN_PAST')) {
      return const AdminFailure('Это время уже прошло.');
    }
    if (m.contains('BAD_DURATION')) {
      return const AdminFailure('Такую длительность сеанса база не принимает.');
    }
    return null;
  }

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
      // Вернуть отменённую бронь нельзя, если её места уже заняли.
      if (e.code == '23P01') {
        throw const AdminFailure('Эти места уже заняты другой бронью.');
      }
      // Нарушено ограничение таблицы: одинаковое название пакета и т. п.
      if (e.code == '23505') {
        throw const AdminFailure('Такое название уже есть — выберите другое.');
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
