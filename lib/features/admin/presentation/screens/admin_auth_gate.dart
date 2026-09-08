import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../app/config/booking_config.dart';
import '../../../../di/injection.dart';
import '../../domain/state/admin_bloc.dart';
import 'admin_login_screen.dart';
import 'admin_screen.dart';

/// Гейт доступа к админке.
///
/// В демо-сборке (`USE_MOCK`) авторизации нет — панель открывается сразу.
/// В остальных — требуется вход сотрудника через Supabase Auth.
class AdminAuthGate extends StatelessWidget {
  /// Создаёт гейт.
  const AdminAuthGate({super.key});

  /// Нужна ли авторизация (везде, кроме демо-сборки).
  static bool get authEnabled => !BookingConfig.useMock;

  Widget _panel() => BlocProvider<AdminBloc>(
        create: (_) => AdminBloc(
          repository: Injection.instance.adminRepository,
        )..add(const AdminStarted()),
        child: AdminScreen(
          onLogout: authEnabled
              ? () => Supabase.instance.client.auth.signOut()
              : null,
        ),
      );

  @override
  Widget build(BuildContext context) {
    if (!authEnabled) return _panel();

    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (BuildContext context, _) {
        final Session? session = Supabase.instance.client.auth.currentSession;
        return session == null ? const AdminLoginScreen() : _panel();
      },
    );
  }
}
