import 'dart:convert';

import 'package:http/http.dart' as http;

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
import '../dto/station_dto.dart';

/// Реализация [IBookingRepository] поверх HTTP-контракта «приёма брони».
///
/// Виджет не знает, что стоит за [base] — Supabase Edge Function, API
/// приложения, n8n или бот. Контракт описан в `docs/INTEGRATION.md`.
class BookingRepositoryApi implements IBookingRepository {
  /// Создаёт репозиторий.
  BookingRepositoryApi({
    required String base,
    required this.apiKey,
    http.Client? client,
  })  : _base = base.endsWith('/') ? base.substring(0, base.length - 1) : base,
        _client = client ?? http.Client();

  final String _base;

  /// Ключ для заголовка `Authorization: Bearer …`.
  final String apiKey;

  final http.Client _client;

  Map<String, String> get _headers => <String, String>{
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      };

  @override
  Future<List<ClubEntity>> fetchClubs() => _guard(() async {
        final List<dynamic> rows = await _get('/clubs');
        return rows
            .map((dynamic e) =>
                ClubDto.fromJson(e as Map<String, dynamic>).toEntity())
            .toList(growable: false);
      });

  @override
  Future<List<RoomEntity>> fetchRooms(String clubId) => _guard(() async {
        // Залы восстанавливаются из станций — отдельный вызов не нужен.
        final List<StationEntity> stations = await fetchStations(clubId);
        final Map<String, RoomEntity> rooms = <String, RoomEntity>{};
        for (final StationEntity s in stations) {
          rooms.putIfAbsent(
            s.roomId,
            () => RoomEntity(
              id: s.roomId,
              clubId: clubId,
              name: s.roomName,
              sortOrder: rooms.length,
            ),
          );
        }
        return rooms.values.toList(growable: false);
      });

  @override
  Future<List<StationEntity>> fetchStations(String clubId) => _guard(() async {
        final List<dynamic> rows = await _get('/stations', <String, String>{
          'club_id': clubId,
        });
        return rows
            .map((dynamic e) =>
                StationDto.fromJson(e as Map<String, dynamic>).toEntity())
            .toList(growable: false);
      });

  @override
  Future<List<PriceRateEntity>> fetchPrices(String clubId) => _guard(() async {
        final List<dynamic> rows = await _get('/prices', <String, String>{
          'club_id': clubId,
        });
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
        final List<dynamic> rows = await _get('/availability', <String, String>{
          'club_id': clubId,
          'day': _dateOnly(day),
        });
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
        final Map<String, dynamic> body = await _post('/discount/validate', <String, dynamic>{
          'code': code,
          'station_count': stationCount,
        });
        final Object? discount = body['discount'];
        if (discount == null) return null;
        return DiscountDto.fromJson(discount as Map<String, dynamic>).toEntity();
      });

  @override
  Future<String> createReservation(ReservationRequestEntity request) =>
      _guard(() async {
        final Map<String, dynamic> body = await _post('/reservations', <String, dynamic>{
          'club_id': request.clubId,
          'station_ids': request.stationIds,
          'starts_at': request.startsAt.toUtc().toIso8601String(),
          'minutes': request.minutes,
          'client_name': request.clientName,
          'client_phone': request.clientPhone,
          'people_count': request.peopleCount,
          'discount_code': request.discountCode,
          'comment': request.comment,
          'source': request.source,
        });
        final Object? id = body['order_id'];
        if (id is! String) {
          throw const BookingUnexpectedFailure('Некорректный ответ сервера');
        }
        return id;
      });

  // ---------------------------------------------------------------------------

  Future<List<dynamic>> _get(String path, [Map<String, String>? query]) async {
    final Uri uri = Uri.parse('$_base$path').replace(queryParameters: query);
    final http.Response r = await _client.get(uri, headers: _headers);
    _throwIfError(r);
    return jsonDecode(r.body) as List<dynamic>;
  }

  Future<Map<String, dynamic>> _post(String path, Map<String, dynamic> body) async {
    final http.Response r = await _client.post(
      Uri.parse('$_base$path'),
      headers: _headers,
      body: jsonEncode(body),
    );
    _throwIfError(r);
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  void _throwIfError(http.Response r) {
    if (r.statusCode >= 200 && r.statusCode < 300) return;

    String code = '';
    int? requiredStations;
    try {
      final Object? decoded = jsonDecode(r.body);
      if (decoded is Map<String, dynamic>) {
        code = decoded['error']?.toString() ?? '';
        requiredStations = (decoded['required_stations'] as num?)?.toInt();
      }
    } catch (_) {
      // тело не JSON — оставляем code пустым
    }

    throw switch (code) {
      'SLOT_TAKEN' => const SlotAlreadyTakenFailure(),
      'DISCOUNT_NOT_FOUND' => const DiscountNotFoundFailure(),
      'DISCOUNT_MIN_STATIONS' =>
        DiscountMinStationsFailure(requiredStations ?? 1),
      'OUTSIDE_WORKING_HOURS' ||
      'STARTS_IN_PAST' ||
      'BAD_DURATION' =>
        const BookingWindowFailure(),
      _ => BookingUnexpectedFailure('HTTP ${r.statusCode}'),
    };
  }

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on BookingFailure {
      rethrow;
    } catch (e) {
      throw BookingUnexpectedFailure(e.toString());
    }
  }

  static String _dateOnly(DateTime day) =>
      '${day.year.toString().padLeft(4, '0')}-'
      '${day.month.toString().padLeft(2, '0')}-'
      '${day.day.toString().padLeft(2, '0')}';
}
