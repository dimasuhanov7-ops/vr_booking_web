import 'package:flutter_test/flutter_test.dart';

import 'package:vr_booking_web/features/booking/data/repository/booking_repository_mock.dart';
import 'package:vr_booking_web/features/booking/domain/entity/account_entity.dart';
import 'package:vr_booking_web/features/booking/domain/repository/i_account_store.dart';
import 'package:vr_booking_web/features/booking/domain/state/booking_bloc.dart';
import 'package:vr_booking_web/features/booking/domain/entity/time_slot_entity.dart';

class _MemStore implements IAccountStore {
  AccountEntity? _account;
  final List<SavedBookingEntity> _bookings = <SavedBookingEntity>[];

  @override
  AccountEntity? readAccount() => _account;
  @override
  void writeAccount(AccountEntity a) => _account = a;
  @override
  void clearAccount() => _account = null;
  @override
  List<SavedBookingEntity> readBookings() => List<SavedBookingEntity>.of(_bookings);
  @override
  void addBooking(SavedBookingEntity b) => _bookings.add(b);
}

DateTime _weekdayAhead() {
  DateTime d = DateTime.now().add(const Duration(days: 6));
  while (d.weekday == DateTime.saturday || d.weekday == DateTime.sunday) {
    d = d.add(const Duration(days: 1));
  }
  return DateTime(d.year, d.month, d.day);
}

void main() {
  test('аккаунт: успешная бронь запоминает клиента; новый bloc подставляет контакты', () async {
    final _MemStore store = _MemStore();

    final BookingBloc a = BookingBloc(
      repository: BookingRepositoryMock(),
      accountStore: store,
      lockedClubSlug: 'effect_vr',
      initialDate: _weekdayAhead(),
    );
    a.add(const BookingStarted());
    await Future<void>.delayed(const Duration(milliseconds: 1800));
    expect(a.state.slots, isNotEmpty, reason: 'слоты загрузились');
    final TimeSlotEntity slot = a.state.slots.first;
    a.add(BookingSlotSelected(slot));
    await Future<void>.delayed(const Duration(milliseconds: 300));
    a.add(const BookingQuickPicked(2));
    await Future<void>.delayed(const Duration(milliseconds: 200));
    expect(a.state.pickedIds.length, 2, reason: 'быстрый выбор 2 станции');
    a.add(const BookingContactChanged(name: 'Аня', phone: '+7 (900) 111-22-33'));
    await Future<void>.delayed(const Duration(milliseconds: 200));
    expect(a.state.canSubmit, isTrue, reason: 'можно отправлять');
    a.add(const BookingSubmitted());
    await Future<void>.delayed(const Duration(milliseconds: 900));

    expect(a.state.view, BookingStage.done);
    expect(store.readAccount()?.phone, '+7 (900) 111-22-33');
    expect(store.readAccount()?.name, 'Аня');
    expect(store.readBookings().length, 1);
    expect(store.readBookings().first.name, 'Аня');
    await a.close();

    final BookingBloc b = BookingBloc(
      repository: BookingRepositoryMock(),
      accountStore: store,
      lockedClubSlug: 'effect_vr',
    );
    b.add(const BookingStarted());
    await Future<void>.delayed(const Duration(milliseconds: 900));
    expect(b.state.account?.name, 'Аня');
    expect(b.state.clientName, 'Аня');
    expect(b.state.clientPhone, '+7 (900) 111-22-33');
    expect(b.state.myBookings.length, 1);

    b.add(const BookingAccountLoggedOut());
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(b.state.account, isNull);
    expect(store.readAccount(), isNull);
    await b.close();
  });
}
