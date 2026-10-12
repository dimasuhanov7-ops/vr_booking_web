import 'package:flutter/widgets.dart';

import '../app/config/booking_config.dart';
import '../features/admin/domain/repository/i_admin_repository.dart';
import '../features/booking/data/account_store.dart';
import '../features/booking/data/repository/booking_repository_api.dart';
import '../features/booking/data/repository/booking_repository_mock.dart';
import '../features/booking/domain/repository/i_account_store.dart';
import '../features/booking/domain/repository/i_booking_repository.dart';
import 'supabase_module.dart' deferred as sb;

/// Простейший контейнер зависимостей уровня приложения.
///
/// Для одной фичи полноценный DI-фреймворк избыточен: держим синглтоны здесь.
/// Supabase SDK и админка — в отложенной библиотеке [sb]: публичный виджет в
/// api-режиме их не скачивает, и первая загрузка на сайте легче.
class Injection {
  Injection._();

  /// Единственный экземпляр контейнера.
  static final Injection instance = Injection._();

  IBookingRepository? _bookingRepository;
  IAdminRepository? _adminRepository;
  bool _moduleLoaded = false;

  /// Загружает отложенную часть и инициализирует Supabase SDK, когда он нужен:
  /// - открыта админка (`?admin=1`) — ей нужен Supabase Auth и запись в БД, либо
  /// - публичный виджет ходит в PostgREST/RPC напрямую (не mock, не api).
  Future<void> init({bool adminMode = false}) async {
    final bool needsModule =
        adminMode || (!BookingConfig.useMock && !BookingConfig.useApi);
    if (!needsModule) return;
    await sb.loadLibrary();
    _moduleLoaded = true;
    if (!BookingConfig.useMock) await sb.initSupabase();
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
    _requireModule();
    return sb.supabaseBookingRepository();
  }

  /// Репозиторий админки: реальный (Supabase) при входе сотрудника,
  /// in-memory — в демо-сборке. Только после `init(adminMode: true)`.
  IAdminRepository get adminRepository {
    _requireModule();
    return _adminRepository ??= sb.adminRepository();
  }

  /// Корневой экран админки. Только после `init(adminMode: true)`.
  Widget adminHome() {
    _requireModule();
    return sb.adminHome();
  }

  /// Локальное хранилище клиента (`localStorage`).
  IAccountStore get accountStore => _accountStore ??= const AccountStore();

  IAccountStore? _accountStore;

  void _requireModule() {
    if (!_moduleLoaded) {
      throw StateError('Injection.init(adminMode: true) не вызван: '
          'админка и Supabase загружаются отдельно.');
    }
  }
}
