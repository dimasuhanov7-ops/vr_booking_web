import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vr_booking_web/features/booking/data/repository/booking_repository_mock.dart';
import 'package:vr_booking_web/features/booking/domain/state/booking_bloc.dart';

void main() {
  group('BookingBloc: запуск с ?club= / ?duration=', () {
    blocTest<BookingBloc, BookingState>(
      'lockedClubSlug -> клуб выбран сам, clubLocked, 3 шага',
      build: () => BookingBloc(
        repository: BookingRepositoryMock(),
        lockedClubSlug: 'effect_vr',
      ),
      act: (BookingBloc bloc) => bloc.add(const BookingStarted()),
      wait: const Duration(milliseconds: 1500),
      verify: (BookingBloc bloc) {
        expect(bloc.state.clubLocked, isTrue);
        expect(bloc.state.club?.slug, 'effect_vr');
        expect(bloc.state.stepCount, 3);
        // единственный зал Effect VR выбирается автоматически
        expect(bloc.state.hall, isNotNull);
      },
    );

    blocTest<BookingBloc, BookingState>(
      'неизвестный slug -> клуб не зафиксирован, 4 шага',
      build: () => BookingBloc(
        repository: BookingRepositoryMock(),
        lockedClubSlug: 'unknown',
      ),
      act: (BookingBloc bloc) => bloc.add(const BookingStarted()),
      wait: const Duration(milliseconds: 1500),
      verify: (BookingBloc bloc) {
        expect(bloc.state.clubLocked, isFalse);
        expect(bloc.state.club, isNull);
        expect(bloc.state.stepCount, 4);
      },
    );

    blocTest<BookingBloc, BookingState>(
      'initialDurationMinutes применяется при выборе клуба',
      build: () => BookingBloc(
        repository: BookingRepositoryMock(),
        lockedClubSlug: 'effect_vr',
        initialDurationMinutes: 240,
      ),
      act: (BookingBloc bloc) => bloc.add(const BookingStarted()),
      wait: const Duration(milliseconds: 1500),
      verify: (BookingBloc bloc) => expect(bloc.state.durationMinutes, 240),
    );
  });
}
