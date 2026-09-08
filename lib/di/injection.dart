import 'package:supabase_flutter/supabase_flutter.dart';

import '../app/config/booking_config.dart';
import '../features/admin/data/repository/admin_repository_mock.dart';
import '../features/admin/domain/repository/i_admin_repository.dart';
import '../features/booking/data/account_store.dart';
import '../features/booking/data/repository/booking_repository.dart';
import '../features/booking/data/repository/booking_repository_api.dart';
import '../features/booking/data/repository/booking_repository_mock.dart';
import '../features/booking/domain/repository/i_account_store.dart';
import '../features/booking/domain/repository/i_booking_repository.dart';

/// Простейший контейнер зависимостей уровня приложения.
///
/// Для одной фичи полноценный DI-фреймворк избыточен: держим синглтоны здесь.
class Injection {
  Injection._();

  /// Единственный экземпляр контейнера.
  static final Injection instance = Injection._();

  IBookingRepository? _bookingRepository;
  IAdminRepository? _adminRepository;

  /// Инициализирует Supabase SDK, когда он нужен:
  /// - публичный виджет ходит в PostgREST/RPC напрямую (не mock, не api), либо
  /// - открыта админка (`?admin=1`) — ей нужен Supabase Auth и запись в БД.
  Future<void> init({bool adminMode = false}) async {
    if (BookingConfig.useMock) return;
    final bool needed = adminMode || !BookingConfig.useApi;
    if (!needed) return;
    await Supabase.initialize(
      url: BookingConfig.supabaseUrl,
      // Ключ анонимный/публикуемый — предназначен для клиентского бандла.
      // ignore: deprecated_member_use
      anonKey: BookingConfig.supabaseAnonKey,
    );
  }

  /// Репозиторий бронирования — выбор источника по конфигу сборки:
  /// mock (демо) / api (HTTP-контракт) / supabase (PostgREST напрямую).
  IBookingRepository get bookingRepository =>
      _bookingRepository ??= _buildBookingRepository();

  IBookingRepository _buildBookingRepository() {
    if (BookingConfig.useMock) return BookingRepositoryMock();
    if (BookingConfig.useApi) {
      return BookingRepositoryApi(
        base: BookingConfig.bookingApiBase,
        apiKey: BookingConfig.bookingApiKey,
      );
    }
    return BookingRepository(Supabase.instance.client);
  }

  /// Репозиторий админки (пока только in-memory — раздел на моках).
  IAdminRepository get adminRepository =>
      _adminRepository ??= const AdminRepositoryMock();

  /// Локальное хранилище клиента (`localStorage`).
  IAccountStore get accountStore => _accountStore ??= const AccountStore();

  IAccountStore? _accountStore;
}
