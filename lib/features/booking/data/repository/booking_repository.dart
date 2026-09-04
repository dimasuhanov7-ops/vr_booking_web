import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entity/booking_failure.dart';
import '../../domain/entity/busy_interval_entity.dart';
import '../../domain/entity/club_entity.dart';
import '../../domain/entity/discount_entity.dart';
import '../../domain/entity/price_rate_entity.dart';
import '../../domain/entity/reservation_request_entity.dart';
import '../../domain/entity/room_entity.dart';
import '../../domain/entity/station_entity.dart';
import '../../domain/repository/i_booking_repository.dart';
import '../dto/busy_interval_dto.dart';
import '../dto/club_dto.dart';
import '../dto/discount_dto.dart';
import '../dto/price_rate_dto.dart';
import '../dto/room_dto.dart';
import '../dto/station_dto.dart';

/// Реализация [IBookingRepository] поверх Supabase (PostgREST + RPC).
class BookingRepository implements IBookingRepository {
  /// Создаёт репозиторий.
  const BookingRepository(this._client);

  final SupabaseClient _client;

  /// SQLSTATE нарушения exclusion-констрейнта (двойная бронь).
  static const String _exclusionViolation = '23P01';

  @override
  Future<List<ClubEntity>> fetchClubs() => _guard(() async {
        final List<dynamic> rows = await _client
            .from('booking_clubs')
            .select()
            .order('sort_order', ascending: true)
            .order('name', ascending: true);
        return rows
            .map((dynamic e) =>
                ClubDto.fromJson(e as Map<String, dynamic>).toEntity())
            .toList(growable: false);
      });

  @override
  Future<List<RoomEntity>> fetchRooms(String clubId) => _guard(() async {
        final List<dynamic> rows = await _client
            .from('booking_rooms')
            .select()
            .eq('club_id', clubId)
            .order('sort_order', ascending: true);
        return rows
            .map((dynamic e) =>
                RoomDto.fromJson(e as Map<String, dynamic>).toEntity())
            .toList(growable: false);
      });

  @override
  Future<List<StationEntity>> fetchStations(String clubId) => _guard(() async {
        final List<dynamic> rows = await _client
            .from('booking_stations')
            .select('*, booking_rooms!inner(name, club_id, sort_order)')
            .eq('booking_rooms.club_id', clubId)
            .order('sort_order', ascending: true);
        return rows
            .map((dynamic e) =>
                StationDto.fromJson(e as Map<String, dynamic>).toEntity())
            .toList(growable: false);
      });

  @override
  Future<List<PriceRateEntity>> fetchPrices(String clubId) => _guard(() async {
        final List<dynamic> rows = await _client
            .from('booking_prices')
            .select()
            .eq('club_id', clubId);
        return rows
            .map((dynamic e) =>
                PriceRateDto.fromJson(e as Map<String, dynamic>).toEntity())
            .toList(growable: false);
      });

  @override
  Future<List<BusyIntervalEntity>> fetchBusyIntervals({
    required String clubId,
    required DateTime day,
  }) =>
      _guard(() async {
        final List<dynamic> rows = await _client.rpc<List<dynamic>>(
          'booking_busy_intervals',
          params: <String, dynamic>{
            'p_club_id': clubId,
            'p_day': _dateOnly(day),
          },
        );
        return rows
            .map((dynamic e) =>
                BusyIntervalDto.fromJson(e as Map<String, dynamic>).toEntity())
            .toList(growable: false);
      });

  @override
  Future<DiscountEntity?> resolveDiscount({
    String? code,
    required int stationCount,
  }) =>
      _guard(() async {
        final List<dynamic> rows = await _client.rpc<List<dynamic>>(
          'booking_validate_discount',
          params: <String, dynamic>{
            'p_code': code,
            'p_station_count': stationCount,
          },
        );
        if (rows.isEmpty) return null;
        return DiscountDto.fromJson(rows.first as Map<String, dynamic>).toEntity();
      });

  @override
  Future<String> createReservation(ReservationRequestEntity request) =>
      _guard(() async {
        final String orderId = await _client.rpc<String>(
          'booking_create_order',
          params: <String, dynamic>{
            'p_club_id': request.clubId,
            'p_client_name': request.clientName,
            'p_client_phone': request.clientPhone,
            'p_station_ids': request.stationIds,
            'p_starts_at': request.startsAt.toUtc().toIso8601String(),
            'p_minutes': request.minutes,
            'p_people_count': request.peopleCount,
            'p_discount_code': request.discountCode,
            'p_comment': request.comment,
            'p_source': request.source,
          },
        );
        return orderId;
      });

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on PostgrestException catch (e) {
      throw _mapPostgrestError(e);
    } on BookingFailure {
      rethrow;
    } catch (e) {
      throw BookingUnexpectedFailure(e.toString());
    }
  }

  BookingFailure _mapPostgrestError(PostgrestException e) {
    if (e.code == _exclusionViolation) return const SlotAlreadyTakenFailure();
    final String m = e.message;
    if (m.contains('DISCOUNT_NOT_FOUND')) return const DiscountNotFoundFailure();
    if (m.contains('DISCOUNT_MIN_STATIONS')) {
      final int req =
          int.tryParse(m.replaceAll(RegExp(r'[^0-9]'), '')) ?? 1;
      return DiscountMinStationsFailure(req);
    }
    if (m.contains('OUTSIDE_WORKING_HOURS') ||
        m.contains('STARTS_IN_PAST') ||
        m.contains('BAD_DURATION')) {
      return const BookingWindowFailure();
    }
    return BookingUnexpectedFailure(m);
  }

  static String _dateOnly(DateTime day) =>
      '${day.year.toString().padLeft(4, '0')}-'
      '${day.month.toString().padLeft(2, '0')}-'
      '${day.day.toString().padLeft(2, '0')}';
}
