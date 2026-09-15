import 'package:flutter_test/flutter_test.dart';

import 'package:vr_booking_web/features/booking/data/repository/booking_repository_mock.dart';
import 'package:vr_booking_web/features/booking/domain/state/booking_bloc.dart';

DateTime _weekdayAhead() {
  DateTime d = DateTime.now().add(const Duration(days: 6));
  while (d.weekday == DateTime.saturday || d.weekday == DateTime.sunday) {
    d = d.add(const Duration(days: 1));
  }
  return DateTime(d.year, d.month, d.day);
}

void main() {
  test('выбор группы: берутся только свободные, «снять» убирает группу', () async {
    final BookingBloc bloc = BookingBloc(
      repository: BookingRepositoryMock(),
      lockedClubSlug: 'effect_vr',
      initialDate: _weekdayAhead(),
    );
    bloc.add(const BookingStarted());
    await Future<void>.delayed(const Duration(milliseconds: 1800));

    // Effect VR: старты 11:00, 12:10, 13:20. В моке шлемы #1 и #3 заняты
    // 13:00–14:30, так что третий слот пересекается с их занятостью.
    expect(bloc.state.slots.length, greaterThan(2));
    bloc.add(BookingSlotSelected(bloc.state.slots[2]));
    await Future<void>.delayed(const Duration(milliseconds: 300));

    const Set<String> row = <String>{
      'e-main-vr1',
      'e-main-vr2',
      'e-main-vr3',
      'e-main-vr4',
    };
    bloc.add(const BookingStationsPicked(row));
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(bloc.state.pickedIds, <String>{'e-main-vr2', 'e-main-vr4'});

    bloc.add(const BookingStationsPicked(row, pick: false));
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(bloc.state.pickedIds, isEmpty);

    await bloc.close();
  });
}
