import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../admin_theme.dart';

/// Акцент экрана входа — лайм Effect VR.
const Color _accent = Color(0xFFA9F04A);

/// Экран входа сотрудника в админку (Supabase Auth, email + пароль).
class AdminLoginScreen extends StatefulWidget {
  /// Создаёт экран входа.
  const AdminLoginScreen({super.key});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final String email = _email.text.trim();
    final String password = _password.text;
    if (email.isEmpty || password.isEmpty) {
      setState(() => _error = 'Введите email и пароль');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await Supabase.instance.client.auth
          .signInWithPassword(email: email, password: password);
      // Успех — AdminAuthGate перерисуется по auth-стриму.
    } on AuthException catch (e) {
      setState(() => _error = _humanize(e.message));
    } catch (_) {
      setState(() => _error = 'Не удалось войти. Попробуйте ещё раз.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _humanize(String raw) {
    final String m = raw.toLowerCase();
    if (m.contains('invalid login') || m.contains('credentials')) {
      return 'Неверный email или пароль';
    }
    if (m.contains('email not confirmed')) {
      return 'Email не подтверждён';
    }
    return raw;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AdminColors.bg,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(-0.6, -1.7),
            radius: 1.3,
            colors: <Color>[Color(0xFF062018), AdminColors.bg],
            stops: <double>[0.0, 0.68],
          ),
        ),
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
                    const Text('АДМИНКА',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.9,
                          color: _accent,
                        )),
                    const SizedBox(height: 6),
                    const Text('Вход для сотрудников',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    const Text('Бронирование Effect VR / V-Ray',
                        style: TextStyle(fontSize: 13, color: AdminColors.textFaint)),
                    const SizedBox(height: 22),
                    _field(
                      controller: _email,
                      hint: 'email',
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const <String>[AutofillHints.username],
                    ),
                    const SizedBox(height: 10),
                    _field(
                      controller: _password,
                      hint: 'пароль',
                      obscure: true,
                      autofillHints: const <String>[AutofillHints.password],
                      onSubmitted: (_) => _submit(),
                    ),
                    if (_error != null) ...<Widget>[
                      const SizedBox(height: 12),
                      Text(_error!,
                          style: const TextStyle(fontSize: 13, color: Color(0xFFE0575B))),
                    ],
                    const SizedBox(height: 18),
                    InkWell(
                      onTap: _busy ? null : _submit,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: _busy ? AdminColors.borderInput : _accent,
                        ),
                        child: _busy
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: AdminColors.textMuted),
                              )
                            : const Text('Войти',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: AdminColors.bg,
                                )),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Аккаунты создаёт администратор в Supabase. '
                      'Забыли пароль — обратитесь к нему.',
                      style: TextStyle(fontSize: 12, height: 1.4, color: AdminColors.textFaint),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String hint,
    bool obscure = false,
    TextInputType? keyboardType,
    List<String>? autofillHints,
    ValueChanged<String>? onSubmitted,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      autofillHints: autofillHints,
      onSubmitted: onSubmitted,
      style: const TextStyle(fontSize: 16, color: AdminColors.text),
      decoration: InputDecoration(
        isDense: true,
        hintText: hint,
        hintStyle: const TextStyle(color: AdminColors.textFaint),
        filled: true,
        fillColor: AdminColors.tile,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        border: _border(AdminColors.borderInput),
        enabledBorder: _border(AdminColors.borderInput),
        focusedBorder: _border(_accent),
      ),
    );
  }

  OutlineInputBorder _border(Color c) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: c),
      );
}
