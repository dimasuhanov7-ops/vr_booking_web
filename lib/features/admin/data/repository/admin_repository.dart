import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entity/admin_club_entity.dart';
import '../../domain/entity/booking_row_entity.dart';
import '../../domain/entity/hall_price_entity.dart';
import '../../domain/entity/package_entity.dart';
import '../../domain/repository/i_admin_repository.dart';

/// Реализация [IAdminRepository] поверх Supabase (PostgREST).
///
/// Пишет от лица авторизованного сотрудника — доступ проверяет RLS
/// (`booking_is_staff()`), см. миграцию `20260909120000_online_booking_staff_auth`.
class AdminRepository implements IAdminRepository {
  /// Создаёт репозиторий.
  const AdminRepository(this._client);

  final SupabaseClient _client;

  /// Смещение Москвы (клубы работают в фиксированной TZ без перехода на лето).
  static const Duration _tz = Duration(hours: 3);

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
        .select('club_id,station_type,day_kind,price_per_hour');

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
  Future<List<BookingRowEntity>> fetchRows() async {
    final DateTime now = DateTime.now().toUtc().add(_tz);
    final DateTime today = DateTime(now.year, now.month, now.day);

    final List<dynamic> orders = await _client
        .from('booking_orders')
        .select(
          'id,club_id,client_name,client_phone,status,created_at,'
          'booking_packages(name),'
          'booking_order_items(starts_at,ends_at,booking_stations(type,room_id))',
        )
        .order('created_at', ascending: false)
        .limit(300);

    final List<BookingRowEntity> out = <BookingRowEntity>[];
    for (final dynamic o in orders) {
      final Map<String, dynamic> m = o as Map<String, dynamic>;
      final List<dynamic> items =
          (m['booking_order_items'] as List<dynamic>? ?? const <dynamic>[]);
      if (items.isEmpty) continue;

      final DateTime start = DateTime.parse(
              (items.first as Map<String, dynamic>)['starts_at'] as String)
          .toUtc()
          .add(_tz);
      final DateTime end = DateTime.parse(
              (items.first as Map<String, dynamic>)['ends_at'] as String)
          .toUtc()
          .add(_tz);
      final DateTime day = DateTime(start.year, start.month, start.day);

      int vr = 0;
      int ps = 0;
      String hallId = '';
      for (final dynamic it in items) {
        final Map<String, dynamic>? st =
            (it as Map<String, dynamic>)['booking_stations'] as Map<String, dynamic>?;
        if (st == null) continue;
        hallId = hallId.isEmpty ? (st['room_id'] as String? ?? '') : hallId;
        if (st['type'] == 'ps5') {
          ps++;
        } else {
          vr++;
        }
      }

      final Map<String, dynamic>? pkg =
          m['booking_packages'] as Map<String, dynamic>?;

      out.add(BookingRowEntity(
        id: m['id'] as String,
        clubId: m['club_id'] as String,
        hallId: hallId,
        dayIndex: day.difference(today).inDays,
        startMinutes: start.hour * 60 + start.minute,
        durationMinutes: end.difference(start).inMinutes,
        headsets: vr,
        consoles: ps,
        clientName: m['client_name'] as String? ?? '',
        phone: m['client_phone'] as String? ?? '',
        status: _recordStatus(m['status'] as String? ?? 'confirmed'),
        source: RecordSource.widget,
        packageName: pkg?['name'] as String?,
        isCancelled: m['status'] == 'cancelled',
      ));
    }
    return out;
  }

  // -- запись -------------------------------------------------------------

  @override
  Future<void> saveClubPrice({
    required String clubId,
    required PriceField field,
    required int value,
  }) async {
    final ({String type, String day}) k = _priceKey(field);
    await _client
        .from('booking_prices')
        .update(<String, dynamic>{
          'price_per_hour': value,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('club_id', clubId)
        .eq('station_type', k.type)
        .eq('day_kind', k.day);
  }

  @override
  Future<String> createPackage(PackageEntity draft) async {
    final Map<String, dynamic> row = await _client
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
        .single();
    return row['id'] as String;
  }

  @override
  Future<void> updatePackage(PackageEntity package) async {
    await _client.from('booking_packages').update(<String, dynamic>{
      'room_id': package.hallId.isEmpty ? null : package.hallId,
      'name': package.name,
      'headsets': package.headsets,
      'consoles': package.consoles,
      'minutes': package.minutes,
      'price': package.price,
      'is_active': package.isEnabled,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', package.id);
  }

  @override
  Future<void> deletePackage(String packageId) async {
    await _client.from('booking_packages').delete().eq('id', packageId);
  }

  @override
  Future<void> setOrderCancelled(String orderId, {required bool cancelled}) async {
    await _client.from('booking_orders').update(<String, dynamic>{
      'status': cancelled ? 'cancelled' : 'confirmed',
    }).eq('id', orderId);
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

  static RecordStatus _recordStatus(String raw) => switch (raw) {
        'completed' => RecordStatus.paid,
        'confirmed' => RecordStatus.confirmed,
        'cancelled' => RecordStatus.confirmed, // помечается через cancelledRowIds
        _ => RecordStatus.newRequest,
      };
}
