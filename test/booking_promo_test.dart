import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vr_booking_web/features/booking/data/repository/booking_repository_mock.dart';
import 'package:vr_booking_web/features/booking/domain/entity/quote_entity.dart';
import 'package:vr_booking_web/features/booking/domain/entity/reservation_request_entity.dart';
import 'package:vr_booking_web/features/booking/domain/state/booking_bloc.dart';

/// Демо-данные + запоминаем, что ушло на сервер.
class _Repo extends BookingRepositoryMock {
  ReservationRequestEntity? sent;

  @override
  Future<String> createReservation(ReservationRequestEntity request) {
    sent = request;
    return super.createReservation(request);
  }
}

DateTime _dayAhead() {
  final DateTime d = DateTime.now().add(const Duration(days: 9));
  return DateTime(d.year, d.month, d.day);
}

void main() {
  group('итог с промокодом', () {
    const QuoteEntity hourly = QuoteEntity(lines: <QuoteLineEntity>[], gross: 6400);

    test('процент и фиксированная сумма от почасовой', () {
      expect(hourly.withPromo(percent: 10).net, 5760);
      expect(hourly.withPromo(fixed: 500).net, 5900);
      expect(hourly.withPromo(fixed: 500).promoAmount, 500);
      expect(hourly.net, 6400);
      expect(hourly.hasDiscount, isFalse);
    });

    test('после пакета: промокод считается от цены пакета', () {
      const QuoteEntity pkg = QuoteEntity(
          lines: <QuoteLineEntity>[], gross: 6400, netOverride: 10000, discountLabel: 'Пакет');
      final QuoteEntity q = pkg.withPromo(percent: 10);
      expect(q.promoAmount, 1000);
      expect(q.net, 9000);
      // Пакет дороже почасовой — выгоды пакета нет, но промокод есть.
      expect(q.discountAmount, 0);
      expect(q.hasDiscount, isTrue);
    });

    test('фиксированная скидка не уводит итог в минус', () {
      const QuoteEntity small = QuoteEntity(lines: <QuoteLineEntity>[], gross: 300);
      expect(small.withPromo(fixed: 500).net, 0);
    });
  });

  final _Repo repo = _Repo();
  late int grossWithTwo;

  blocTest<BookingBloc, BookingState>(
    'промокод: порог станций, скидка в итоге и код в брони',
    build: () => BookingBloc(
      repository: repo,
      lockedClubSlug: 'effect_vr',
      initialDate: _dayAhead(),
    ),
    act: (BookingBloc bloc) async {
      bloc.add(const BookingStarted());
      await Future<void>.delayed(const Duration(milliseconds: 1500));
      bloc.add(BookingSlotSelected(bloc.state.slots.first));
      await Future<void>.delayed(const Duration(milliseconds: 700));

      // Одна станция: VRPARTY действует от двух — код принят, но не применён.
      bloc
        ..add(const BookingQuickPicked(1))
        ..add(const BookingPromoInputChanged('vrparty'))
        ..add(const BookingPromoSubmitted());
      await Future<void>.delayed(const Duration(milliseconds: 400));
      expect(bloc.state.promo?.code, 'VRPARTY');
      expect(bloc.state.promoApplies, isFalse);
      expect(bloc.state.quote.net, bloc.state.quote.gross);

      bloc.add(const BookingQuickPicked(2));
      await Future<void>.delayed(const Duration(milliseconds: 100));
      grossWithTwo = bloc.state.quote.gross.toInt();

      bloc.add(const BookingContactChanged(name: 'Тест', phone: '+7 900 000-00-00'));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      bloc.add(const BookingSubmitted());
      await Future<void>.delayed(const Duration(milliseconds: 800));
    },
    wait: const Duration(milliseconds: 200),
    verify: (BookingBloc bloc) {
      expect(bloc.state.view, BookingStage.done);
      expect(bloc.state.quote.net, grossWithTwo - (grossWithTwo * 10 / 100).round());
      expect(repo.sent?.discountCode, 'VRPARTY');
    },
  );

  blocTest<BookingBloc, BookingState>(
    'промокод: неизвестный код — понятная ошибка, скидки нет',
    build: () => BookingBloc(repository: BookingRepositoryMock()),
    act: (BookingBloc bloc) async {
      bloc
        ..add(const BookingPromoInputChanged('NOPE'))
        ..add(const BookingPromoSubmitted());
      await Future<void>.delayed(const Duration(milliseconds: 400));
    },
    verify: (BookingBloc bloc) {
      expect(bloc.state.promo, isNull);
      expect(bloc.state.promoError, contains('не найден'));
    },
  );
}
