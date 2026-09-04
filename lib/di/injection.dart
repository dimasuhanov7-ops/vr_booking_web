import 'package:supabase_flutter/supabase_flutter.dart';

import '../app/config/booking_config.dart';
import '../features/admin/data/repository/admin_repository_mock.dart';
import '../features/admin/domain/repository/i_admin_repository.dart';
import '../features/booking/data/repository/booking_repository.dart';
import '../features/booking/data/repository/booking_repository_mock.dart';
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

  /// Инициализирует Supabase. Вызывается один раз из `main`.
  Future<void> init() async {
    if (BookingConfig.useMock) return;
    await Supabase.initialize(
      url: BookingConfig.supabaseUrl,
      // Ключ анонимный/публикуемый — предназначен для клиентского бандла.
      // ignore: deprecated_member_use
      anonKey: BookingConfig.supabaseAnonKey,
    );
  }

  /// Репозиторий бронирования (mock или Supabase — по флагу сборки).
  IBookingRepository get bookingRepository => _bookingRepository ??=
      BookingConfig.useMock
          ? BookingRepositoryMock()
          : BookingRepository(Supabase.instance.client);

  /// Репозиторий админки (пока только in-memory — раздел на моках).
  IAdminRepository get adminRepository =>
      _adminRepository ??= const AdminRepositoryMock();
}
