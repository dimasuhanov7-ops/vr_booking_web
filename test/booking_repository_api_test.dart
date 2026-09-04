import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:vr_booking_web/features/booking/data/repository/booking_repository_api.dart';
import 'package:vr_booking_web/features/booking/domain/entity/booking_failure.dart';
import 'package:vr_booking_web/features/booking/domain/entity/reservation_request_entity.dart';

ReservationRequestEntity _req() => ReservationRequestEntity(
      clubId: 'c1',
      stationIds: const <String>['s1', 's2'],
      startsAt: DateTime.utc(2026, 9, 10, 15),
      minutes: 90,
      clientName: 'Иван',
      clientPhone: '+7 900 000 00 00',
      source: 'site',
    );

BookingRepositoryApi _repo(MockClient client) =>
    BookingRepositoryApi(base: 'https://x.test/booking-intake', apiKey: 'k', client: client);

void main() {
  test('createReservation: 201 -> order_id', () async {
    final BookingRepositoryApi repo = _repo(MockClient((http.Request r) async {
      expect(r.url.path, endsWith('/reservations'));
      expect(r.headers['authorization'], 'Bearer k');
      final Map<String, dynamic> body = jsonDecode(r.body) as Map<String, dynamic>;
      expect(body['minutes'], 90);
      expect(body['station_ids'], <String>['s1', 's2']);
      return http.Response(jsonEncode(<String, String>{'order_id': 'ord-1'}), 201);
    }));
    expect(await repo.createReservation(_req()), 'ord-1');
  });

  test('createReservation: 409 SLOT_TAKEN -> SlotAlreadyTakenFailure', () async {
    final BookingRepositoryApi repo = _repo(MockClient((http.Request r) async =>
        http.Response(jsonEncode(<String, String>{'error': 'SLOT_TAKEN'}), 409)));
    expect(
      () => repo.createReservation(_req()),
      throwsA(isA<SlotAlreadyTakenFailure>()),
    );
  });

  test('createReservation: 422 DISCOUNT_MIN_STATIONS -> с числом', () async {
    final BookingRepositoryApi repo = _repo(MockClient((http.Request r) async =>
        http.Response(
            jsonEncode(<String, dynamic>{
              'error': 'DISCOUNT_MIN_STATIONS',
              'required_stations': 4,
            }),
            422)));
    await expectLater(
      repo.createReservation(_req()),
      throwsA(predicate<Object>(
          (Object e) => e is DiscountMinStationsFailure && e.requiredStations == 4)),
    );
  });

  test('resolveDiscount: null discount -> null', () async {
    final BookingRepositoryApi repo = _repo(MockClient((http.Request r) async =>
        http.Response(jsonEncode(<String, dynamic>{'discount': null}), 200)));
    expect(await repo.resolveDiscount(stationCount: 3), isNull);
  });
}
