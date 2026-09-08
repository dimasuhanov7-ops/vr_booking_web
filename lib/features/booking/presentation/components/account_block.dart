import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/theme/app_theme.dart';
import '../../domain/entity/account_entity.dart';
import '../booking_format.dart';

/// Блок «аккаунт по телефону» вверху формы: запоминает клиента на устройстве
/// (`localStorage`) и показывает его брони с этого браузера.
class AccountBlock extends StatelessWidget {
  /// Создаёт блок.
  const AccountBlock({
    required this.account,
    required this.myBookings,
    required this.loginOpen,
    required this.loginPhone,
    required this.listOpen,
    required this.accent,
    required this.onPrimary,
    required this.onLogout,
    required this.onLoginPhoneChanged,
    required this.onLoginSubmit,
    super.key,
  });

  /// Запомненный клиент или `null`.
  final AccountEntity? account;

  /// Брони клиента (этого устройства).
  final List<SavedBookingEntity> myBookings;

  /// Открыта панель ввода телефона.
  final bool loginOpen;

  /// Значение поля телефона.
  final String loginPhone;

  /// Открыт список броней.
  final bool listOpen;

  /// Акцент клуба.
  final Color accent;

  /// «Мои брони» / «Войти по номеру».
  final VoidCallback onPrimary;

  /// «Выйти».
  final VoidCallback onLogout;

  /// Ввод телефона.
  final ValueChanged<String> onLoginPhoneChanged;

  /// Подтверждение входа.
  final VoidCallback onLoginSubmit;

  bool get _loggedIn => account != null;

  @override
  Widget build(BuildContext context) {
    final int n = myBookings.length;
    final String title = _loggedIn
        ? (account!.name.isNotEmpty ? '${account!.name} · ${account!.phone}' : account!.phone)
        : 'Вход по номеру телефона';
    final String sub = _loggedIn
        ? (n > 0
            ? '$n ${BookingFormat.plural(n, 'бронь', 'брони', 'броней')} на этом номере · контакты заполнены'
            : 'Броней пока нет · контакты заполнены')
        : 'Мы запомним вас и покажем ваши брони при следующем визите.';
    final String primaryLabel = _loggedIn
        ? (listOpen ? 'Скрыть брони' : 'Мои брони')
        : 'Войти по номеру';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: BookingColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: BookingColors.borderSoft),
          ),
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 10,
            children: <Widget>[
              ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 180),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(title,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 3),
                    Text(sub,
                        style: const TextStyle(fontSize: 12, color: BookingColors.textMuted)),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  _ghostButton(primaryLabel, onPrimary),
                  if (_loggedIn) ...<Widget>[
                    const SizedBox(width: 8),
                    _ghostButton('Выйти', onLogout, muted: true),
                  ],
                ],
              ),
            ],
          ),
        ),
        if (!_loggedIn && loginOpen) ...<Widget>[
          const SizedBox(height: 12),
          _LoginPanel(
            phone: loginPhone,
            accent: accent,
            onPhoneChanged: onLoginPhoneChanged,
            onSubmit: onLoginSubmit,
          ),
        ],
        if (_loggedIn && listOpen) ...<Widget>[
          const SizedBox(height: 12),
          _bookingList(),
        ],
      ],
    );
  }

  Widget _ghostButton(String label, VoidCallback onTap, {bool muted = false}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: BookingColors.border),
        ),
        child: Text(label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: muted ? BookingColors.textMuted : BookingColors.textSoft,
            )),
      ),
    );
  }

  Widget _bookingList() {
    if (myBookings.isEmpty) {
      return const Text('Пока нет ни одной брони на этом номере.',
          style: TextStyle(fontSize: 13, color: BookingColors.textMuted));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        for (final SavedBookingEntity b in myBookings.reversed)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: BookingColors.surface,
                borderRadius: BorderRadius.circular(13),
                border: Border.all(color: BookingColors.borderSoft),
              ),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(b.title,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 3),
                        Text(b.meta,
                            style: const TextStyle(fontSize: 12, color: BookingColors.textMuted)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(b.total,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
                      )),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _LoginPanel extends StatefulWidget {
  const _LoginPanel({
    required this.phone,
    required this.accent,
    required this.onPhoneChanged,
    required this.onSubmit,
  });

  final String phone;
  final Color accent;
  final ValueChanged<String> onPhoneChanged;
  final VoidCallback onSubmit;

  @override
  State<_LoginPanel> createState() => _LoginPanelState();
}

class _LoginPanelState extends State<_LoginPanel> {
  late final TextEditingController _c = TextEditingController(text: widget.phone);

  @override
  void didUpdateWidget(_LoginPanel old) {
    super.didUpdateWidget(old);
    // Бэклог очистил поле (после успешного входа) — синхронизируем контроллер.
    if (widget.phone.isEmpty && _c.text.isNotEmpty) _c.clear();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  bool get _valid => _c.text.replaceAll(RegExp(r'[^0-9]'), '').length == 11;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: BookingColors.fieldSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: BookingColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text('Введите телефон — покажем ваши брони и заполним контакты за вас.',
              style: TextStyle(fontSize: 13, color: BookingColors.textMuted)),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              Expanded(
                child: TextField(
                  controller: _c,
                  keyboardType: TextInputType.phone,
                  inputFormatters: <TextInputFormatter>[_MaskPhone()],
                  onChanged: (String v) => setState(() => widget.onPhoneChanged(v)),
                  style: const TextStyle(fontSize: 16, color: BookingColors.text),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: '+7 (900) 000-00-00',
                    hintStyle: const TextStyle(color: BookingColors.textFaint),
                    filled: true,
                    fillColor: BookingColors.surface,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                    border: _border(BookingColors.border),
                    enabledBorder: _border(BookingColors.border),
                    focusedBorder: _border(widget.accent),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: _valid ? widget.onSubmit : null,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: _valid ? widget.accent : BookingColors.border,
                  ),
                  child: Text('Войти',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: _valid ? BookingColors.bg : BookingColors.textDim,
                      )),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  OutlineInputBorder _border(Color c) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: c),
      );
}

class _MaskPhone extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) return newValue;
    final String masked = BookingFormat.phoneMask(newValue.text);
    return TextEditingValue(
      text: masked,
      selection: TextSelection.collapsed(offset: masked.length),
    );
  }
}
