import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../app/config/booking_config.dart';
import '../features/admin/data/repository/admin_repository.dart';
import '../features/admin/data/repository/admin_repository_mock.dart';
import '../features/admin/domain/repository/i_admin_repository.dart';
import '../features/admin/presentation/screens/admin_auth_gate.dart';
import '../features/booking/data/repository/booking_repository.dart';
import '../features/booking/domain/repository/i_booking_repository.dart';

/// Всё, что тянет Supabase SDK и экраны админки.
///
/// Подключается в [Injection] через `deferred as`: в вебе это отдельный файл,
/// который браузер скачивает, только когда он нужен, — при входе сотрудника
/// (`?admin=1`) или в сборке, где виджет ходит в Supabase напрямую. Клиент
/// сайта в боевой сборке (api-режим) его не загружает вовсе.

/// Инициализирует Supabase SDK.
Future<void> initSupabase() => Supabase.initialize(
      url: BookingConfig.supabaseUrl,
      // Ключ анонимный/публикуемый — предназначен для клиентского бандла.
      // ignore: deprecated_member_use
      anonKey: BookingConfig.supabaseAnonKey,
    );

/// Репозиторий бронирования поверх PostgREST/RPC.
IBookingRepository supabaseBookingRepository() =>
    BookingRepository(Supabase.instance.client);

/// Репозиторий админки: реальный или демо.
IAdminRepository adminRepository() => BookingConfig.useMock
    ? const AdminRepositoryMock()
    : AdminRepository(Supabase.instance.client);

/// Корневой экран админки (вход сотрудника → панель).
Widget adminHome() => const AdminAuthGate();
