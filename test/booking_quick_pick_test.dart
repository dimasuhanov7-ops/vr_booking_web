import 'package:flutter_test/flutter_test.dart';

import 'package:vr_booking_web/features/booking/data/repository/booking_repository_mock.dart';
import 'package:vr_booking_web/features/booking/domain/entity/hall_option_entity.dart';
import 'package:vr_booking_web/features/booking/domain/state/booking_bloc.dart';

DateTime _weekdayAhead() {
  DateTime d = DateTime.now().add(const Duration(days: 6));
  while (d.weekday == DateTime.saturday || d.weekday == DateTime.sunday) {
    d = d.add(const Duration(days: 1));
  }
  return DateTime(d.year, d.month, d.day);
}

void main() {
  test('«Весь клуб», взять 4 — все с арены, а не 2+2 по залам', () async {
    final BookingBloc bloc = BookingBloc(
      repository: BookingRepositoryMock(),
      lockedClubSlug: 'v_ray',
      initialDate: _weekdayAhead(),
    );
    bloc.add(const BookingStarted());
    await Future<void>.delayed(const Duration(milliseconds: 1500));

    final HallOptionEntity combo = bloc.state.hallOptions
        .firstWhere((HallOptionEntity h) => h.isCombo);
    bloc.add(BookingHallSelected(combo));
    await Future<void>.delayed(const Duration(milliseconds: 700));
    expect(bloc.state.slots, isNotEmpty, reason: 'слоты загрузились');

    // Первый слот (11:00) в моке свободен целиком.
    bloc.add(BookingSlotSelected(bloc.state.slots.first));
    await Future<void>.delayed(const Duration(milliseconds: 200));
    bloc.add(const BookingQuickPicked(4));
    await Future<void>.delayed(const Duration(milliseconds: 100));

    expect(bloc.state.pickedIds, <String>{
      'v-big-vr1',
      'v-big-vr2',
      'v-big-vr3',
      'v-big-vr4',
    });
    await bloc.close();
  });
}
