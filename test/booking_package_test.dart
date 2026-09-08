import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vr_booking_web/features/booking/data/repository/booking_repository_mock.dart';
import 'package:vr_booking_web/features/booking/domain/entity/package_entity.dart';
import 'package:vr_booking_web/features/booking/domain/entity/time_slot_entity.dart';
import 'package:vr_booking_web/features/booking/domain/state/booking_bloc.dart';

DateTime _weekdayAhead() {
  DateTime d = DateTime.now().add(const Duration(days: 6));
  while (d.weekday == DateTime.saturday || d.weekday == DateTime.sunday) {
    d = d.add(const Duration(days: 1));
  }
  return DateTime(d.year, d.month, d.day);
}

void main() {
  blocTest<BookingBloc, BookingState>(
    'пакет: выбор ставит длительность, состав и фиксирует цену',
    build: () => BookingBloc(
      repository: BookingRepositoryMock(),
      lockedClubSlug: 'effect_vr',
      initialDate: _weekdayAhead(),
    ),
    act: (BookingBloc bloc) async {
      bloc.add(const BookingStarted());
      await Future<void>.delayed(const Duration(milliseconds: 1500));
      // слот 11:00 (валиден и для 60, и для 120 мин)
      final TimeSlotEntity first = bloc.state.slots.first;
      bloc.add(BookingSlotSelected(first));
      await Future<void>.delayed(const Duration(milliseconds: 700));
      final PackageEntity company =
          bloc.state.hallPackages.firstWhere((PackageEntity p) => p.name == 'Компания');
      bloc.add(BookingPackageSelected(company));
      await Future<void>.delayed(const Duration(milliseconds: 900));
    },
    wait: const Duration(milliseconds: 200),
    verify: (BookingBloc bloc) {
      expect(bloc.state.packages.length, 3, reason: 'у Effect VR 3 пакета');
      expect(bloc.state.selectedPackage?.name, 'Компания');
      expect(bloc.state.durationMinutes, 120);
      expect(bloc.state.pickedIds.length, 4);
      expect(bloc.state.packageApplies, isTrue);
      // Итог фиксируется ценой пакета вместо почасового расчёта.
      expect(bloc.state.quote.net, 10000);
    },
  );
}
