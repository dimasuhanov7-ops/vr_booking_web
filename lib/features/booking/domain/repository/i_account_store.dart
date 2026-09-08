import '../entity/account_entity.dart';

/// Локальное (на устройстве) хранилище клиента и его броней.
///
/// Синхронное — за ним `localStorage`. Данные не уходят на сервер и видны
/// только в этом браузере.
abstract interface class IAccountStore {
  /// Запомненный клиент или `null`.
  AccountEntity? readAccount();

  /// Запомнить клиента.
  void writeAccount(AccountEntity account);

  /// Забыть клиента (кнопка «Выйти»).
  void clearAccount();

  /// Все локально сохранённые брони.
  List<SavedBookingEntity> readBookings();

  /// Добавить бронь в локальный список.
  void addBooking(SavedBookingEntity booking);
}
