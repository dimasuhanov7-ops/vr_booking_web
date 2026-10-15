import 'package:flutter_test/flutter_test.dart';

import 'package:vr_booking_web/features/booking/data/repository/booking_repository_mock.dart';
import 'package:vr_booking_web/features/booking/domain/entity/busy_interval_entity.dart';
import 'package:vr_booking_web/features/booking/domain/entity/package_entity.dart';
import 'package:vr_booking_web/features/booking/domain/entity/price_rate_entity.dart';
import 'package:vr_booking_web/features/booking/domain/entity/station_entity.dart';
import 'package:vr_booking_web/features/booking/domain/state/booking_bloc.dart';

/// Демо-данные, но каждый запрос «идёт до Стокгольма» [lag] и считается.
class _SlowRepo extends BookingRepositoryMock {
  static const Duration lag = Duration(milliseconds: 300);
  int busyCalls = 0;

  @override
  Future<List<StationEntity>> fetchStations(String clubId) async {
    await Future<void>.delayed(lag);
    return super.fetchStations(clubId);
  }

  @override
  Future<List<PriceRateEntity>> fetchPrices(String clubId) async {
    await Future<void>.delayed(lag);
    return super.fetchPrices(clubId);
  }

  @override
  Future<List<PackageEntity>> fetchPackages(String clubId) async {
    await Future<void>.delayed(lag);
    return super.fetchPackages(clubId);
  }

  @override
  Future<List<BusyIntervalEntity>> fetchBusyIntervals({
    required String clubId,
    required DateTime day,
  }) async {
    busyCalls++;
    await Future<void>.delayed(lag);
    return super.fetchBusyIntervals(clubId: clubId, day: day);
  }
}

void main() {
  test('справочник и занятость грузятся параллельно, занятость — один раз',
      () async {
    final _SlowRepo repo = _SlowRepo();
    final Stopwatch sw = Stopwatch()..start();
    final DateTime d = DateTime.now().add(const Duration(days: 3));
    final BookingBloc bloc = BookingBloc(
      repository: repo,
      lockedClubSlug: 'effect_vr',
      initialDate: DateTime(d.year, d.month, d.day),
    )..add(const BookingStarted());
    await bloc.stream.firstWhere((BookingState s) => s.slots.isNotEmpty);
    sw.stop();

    // Последовательно было бы 4 × 300 мс плюс задержки самого мока.
    // Параллельно — один «круг» до сервера на справочник и занятость.
    expect(sw.elapsed, lessThan(_SlowRepo.lag * 3));
    expect(repo.busyCalls, 1);
    await bloc.close();
  });
}
