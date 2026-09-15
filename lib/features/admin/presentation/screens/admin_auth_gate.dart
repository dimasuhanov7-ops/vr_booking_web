import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../app/config/booking_config.dart';
import '../../../../app/embed/nav.dart';
import '../../../../di/injection.dart';
import '../../domain/state/admin_bloc.dart';
import '../admin_theme.dart';
import 'admin_login_screen.dart';
import 'admin_screen.dart';

/// Гейт доступа к админке.
///
/// В демо-сборке (`USE_MOCK`) авторизации нет — панель открывается сразу.
/// В остальных — вход сотрудника через Supabase Auth и проверка, что он в
/// списке персонала бронирования.
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
          // С авторизацией — выход из сессии сотрудника; в демо — просто уход
          // из админки к публичному виджету.
          onLogout: authEnabled
              ? () => Supabase.instance.client.auth.signOut()
              : Nav.toWidget,
        ),
      );

  @override
  Widget build(BuildContext context) {
    if (!authEnabled) return _panel();

    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (BuildContext context, _) {
        final Session? session = Supabase.instance.client.auth.currentSession;
        if (session == null) return const AdminLoginScreen();
        return _AccessCheck(
          key: ValueKey<String>(session.user.id),
          panel: _panel(),
        );
      },
    );
  }
}

/// Пускает в панель только персонал бронирования.
///
/// Войти в Supabase может любой сотрудник приложения-менеджера. Без этой
/// проверки он увидел бы панель с публичными ценами и пакетами, а его правки
/// выглядели бы сохранёнными — RLS молча отбрасывает чужие изменения.
class _AccessCheck extends StatefulWidget {
  const _AccessCheck({required this.panel, super.key});

  final Widget panel;

  @override
  State<_AccessCheck> createState() => _AccessCheckState();
}

class _AccessCheckState extends State<_AccessCheck> {
  late Future<bool> _check = Injection.instance.adminRepository.hasAccess();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _check,
      builder: (BuildContext context, AsyncSnapshot<bool> snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Scaffold(
            backgroundColor: AdminColors.bg,
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snap.hasError) {
          return _Notice(
            title: 'Не удалось проверить доступ',
            message: 'Проверьте интернет и попробуйте ещё раз.',
            actionLabel: 'Повторить',
            onAction: () => setState(() {
              _check = Injection.instance.adminRepository.hasAccess();
            }),
          );
        }
        if (snap.data != true) {
          return const _Notice(
            title: 'Нет доступа к броням',
            message: 'Эта учётная запись не добавлена в персонал бронирования. '
                'Попросите администратора выдать доступ и войдите снова.',
          );
        }
        return widget.panel;
      },
    );
  }
}

/// Экран-сообщение вместо панели: нет доступа или не удалось проверить.
class _Notice extends StatelessWidget {
  const _Notice({
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AdminColors.bg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AdminColors.panel,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AdminColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(title,
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    Text(message,
                        style: const TextStyle(
                            fontSize: 14, height: 1.45, color: AdminColors.textMuted)),
                    const SizedBox(height: 20),
                    if (actionLabel != null && onAction != null) ...<Widget>[
                      _button(actionLabel!, onAction!, primary: true),
                      const SizedBox(height: 10),
                    ],
                    _button('Выйти', () => Supabase.instance.client.auth.signOut()),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _button(String label, VoidCallback onTap, {bool primary = false}) =>
      InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: primary ? const Color(0xFFA9F04A) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: primary ? null : Border.all(color: AdminColors.borderInput),
          ),
          child: Text(label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: primary ? AdminColors.bg : AdminColors.textSoft,
              )),
        ),
      );
}
