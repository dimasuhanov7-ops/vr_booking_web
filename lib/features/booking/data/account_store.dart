import 'dart:convert';

import '../../../app/embed/local_store.dart';
import '../domain/entity/account_entity.dart';
import '../domain/repository/i_account_store.dart';

/// Реализация [IAccountStore] поверх `localStorage` (см. [LocalStore]).
class AccountStore implements IAccountStore {
  /// Создаёт хранилище.
  const AccountStore();

  static const String _accountKey = 'vr-widget-me';
  static const String _bookingsKey = 'vr-widget-bookings';

  @override
  AccountEntity? readAccount() {
    final String? raw = LocalStore.read(_accountKey);
    if (raw == null) return null;
    try {
      final Object? j = jsonDecode(raw);
      if (j is! Map<String, dynamic>) return null;
      final String phone = j['phone'] as String? ?? '';
      if (phone.isEmpty) return null;
      return AccountEntity(phone: phone, name: j['name'] as String? ?? '');
    } catch (_) {
      return null;
    }
  }

  @override
  void writeAccount(AccountEntity account) => LocalStore.write(
        _accountKey,
        jsonEncode(<String, dynamic>{'phone': account.phone, 'name': account.name}),
      );

  @override
  void clearAccount() => LocalStore.remove(_accountKey);

  @override
  List<SavedBookingEntity> readBookings() {
    final String? raw = LocalStore.read(_bookingsKey);
    if (raw == null) return const <SavedBookingEntity>[];
    try {
      final Object? j = jsonDecode(raw);
      if (j is! List<dynamic>) return const <SavedBookingEntity>[];
      return j
          .whereType<Map<String, dynamic>>()
          .map(SavedBookingEntity.fromJson)
          .toList(growable: false);
    } catch (_) {
      return const <SavedBookingEntity>[];
    }
  }

  @override
  void addBooking(SavedBookingEntity booking) {
    final List<SavedBookingEntity> all = <SavedBookingEntity>[
      ...readBookings(),
      booking,
    ];
    LocalStore.write(
      _bookingsKey,
      jsonEncode(all.map((SavedBookingEntity b) => b.toJson()).toList()),
    );
  }
}
