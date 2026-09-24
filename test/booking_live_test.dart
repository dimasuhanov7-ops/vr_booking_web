import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vr_booking_web/features/booking/data/repository/booking_repository_mock.dart';
import 'package:vr_booking_web/features/booking/domain/entity/busy_interval_entity.dart';
import 'package:vr_booking_web/features/booking/domain/state/booking_bloc.dart';

/// Демо-данные, в которые «другой клиент» может занять станцию.
class _Repo extends BookingRepositoryMock {
  String? takenStation;
  String takenRoom = '';

  @override
  Future<List<BusyIntervalEntity>> fetchBusyIntervals({
    required String clubId,
    required DateTime day,
  }) async {
    final List<BusyIntervalEntity> base =
        await super.fetchBusyIntervals(clubId: clubId, day: day);
    final String? id = takenStation;
    if (id == null) return base;
    return <BusyIntervalEntity>[
      ...base,
      BusyIntervalEntity(
        stationId: id,
        roomId: takenRoom,
        startsAt: DateTime.utc(2000),
        endsAt: DateTime.utc(2100),
      ),
    ];
  }
}

DateTime _dayAhead() {
  final DateTime d = DateTime.now().add(const Duration(days: 5));
  return DateTime(d.year, d.month, d.day);
}

void main() {
  final _Repo repo = _Repo();
  late String stolen;

  blocTest<BookingBloc, BookingState>(
    'фоновое обновление: станцию заняли, пока клиент выбирал — убираем до отправки',
    build: () => BookingBloc(
      repository: repo,
      lockedClubSlug: 'effect_vr',
      initialDate: _dayAhead(),
    ),
    act: (BookingBloc bloc) async {
      bloc.add(const BookingStarted());
      await Future<void>.delayed(const Duration(milliseconds: 1500));
      bloc.add(BookingSlotSelected(bloc.state.slots.last));
      await Future<void>.delayed(const Duration(milliseconds: 700));
      bloc.add(const BookingQuickPicked(2));
      await Future<void>.delayed(const Duration(milliseconds: 100));

      stolen = bloc.state.pickedIds.first;
      repo
        ..takenStation = stolen
        ..takenRoom = bloc.state.hall?.roomIds.first ?? '';
      bloc.add(const BookingLiveTick());
      await Future<void>.delayed(const Duration(milliseconds: 700));
    },
    wait: const Duration(milliseconds: 200),
    verify: (BookingBloc bloc) {
      expect(bloc.state.pickedIds, isNot(contains(stolen)));
      expect(bloc.state.pickedIds, hasLength(1));
      expect(bloc.state.takenIds, contains(stolen));
      expect(bloc.state.conflictShown, isTrue);
    },
  );
}
