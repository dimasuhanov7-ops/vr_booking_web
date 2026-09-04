import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/theme/app_theme.dart';
import '../admin_theme.dart';

/// Панель-карточка админки.
class AdminCard extends StatelessWidget {
  /// Создаёт карточку.
  const AdminCard({
    required this.child,
    this.padding = const EdgeInsets.all(18),
    super.key,
  });

  /// Содержимое.
  final Widget child;

  /// Внутренний отступ.
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: AdminColors.panel,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AdminColors.border),
      ),
      child: child,
    );
  }
}

/// Заголовок карточки: крупный текст + необязательная подпись.
class AdminCardTitle extends StatelessWidget {
  /// Создаёт заголовок.
  const AdminCardTitle(this.title, {this.subtitle, this.trailing, super.key});

  /// Заголовок.
  final String title;

  /// Подпись под заголовком.
  final String? subtitle;

  /// Виджет справа.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: Text(title,
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            ),
            ?trailing,
          ],
        ),
        if (subtitle != null) ...<Widget>[
          const SizedBox(height: 4),
          Text(subtitle!,
              style: const TextStyle(fontSize: 13, height: 1.4, color: AdminColors.textMuted)),
        ],
      ],
    );
  }
}

/// Заглавная подпись-оверлайн.
class AdminLabel extends StatelessWidget {
  /// Создаёт подпись.
  const AdminLabel(this.text, {this.color, super.key});

  /// Текст.
  final String text;

  /// Цвет (по умолчанию — тихий).
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        fontSize: 11,
        letterSpacing: 1,
        fontWeight: FontWeight.w600,
        color: color ?? AdminColors.textLabel,
      ),
    );
  }
}

/// Чип-кнопка выбора.
class AdminPill extends StatelessWidget {
  /// Создаёт чип.
  const AdminPill({
    required this.label,
    required this.selected,
    required this.accent,
    required this.onTap,
    this.compact = false,
    super.key,
  });

  /// Подпись.
  final String label;

  /// Выбран ли.
  final bool selected;

  /// Акцент клуба.
  final Color accent;

  /// Обработчик.
  final VoidCallback onTap;

  /// Уменьшенный вариант (фильтры).
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final Color tint = _tint(accent);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(9),
      child: Container(
        padding: compact
            ? const EdgeInsets.symmetric(horizontal: 12, vertical: 7)
            : const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? accent.withValues(alpha: 0.16) : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: selected ? accent : AdminColors.borderInput),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: compact ? 13 : 14,
            fontWeight: FontWeight.w600,
            color: selected ? tint : AdminColors.textMid,
          ),
        ),
      ),
    );
  }
}

/// Числовое поле с подписью сверху (right-aligned, tabular-nums).
class AdminNumberField extends StatefulWidget {
  /// Создаёт поле.
  const AdminNumberField({
    required this.label,
    required this.value,
    required this.onChanged,
    this.width = 96,
    super.key,
  });

  /// Подпись.
  final String label;

  /// Значение.
  final int value;

  /// Колбэк (гарантированно число, при пустом вводе — не вызывается).
  final ValueChanged<int> onChanged;

  /// Ширина поля.
  final double width;

  @override
  State<AdminNumberField> createState() => _AdminNumberFieldState();
}

class _AdminNumberFieldState extends State<AdminNumberField> {
  late final TextEditingController _c =
      TextEditingController(text: widget.value.toString());

  @override
  void didUpdateWidget(covariant AdminNumberField old) {
    super.didUpdateWidget(old);
    final String v = widget.value.toString();
    if (v != _c.text && !_c.selection.isValid) _c.text = v;
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(bottom: 5),
          child: Text(widget.label,
              style: const TextStyle(fontSize: 11, color: AdminColors.textLabel)),
        ),
        SizedBox(
          width: widget.width,
          child: TextField(
            controller: _c,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.right,
            inputFormatters: <TextInputFormatter>[
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(7),
            ],
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
              color: AdminColors.text,
            ),
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
              filled: true,
              fillColor: AdminColors.input,
              border: _border,
              enabledBorder: _border,
              focusedBorder: _border,
            ),
            onChanged: (String s) {
              final int? n = int.tryParse(s);
              if (n != null) widget.onChanged(n);
            },
          ),
        ),
      ],
    );
  }

  OutlineInputBorder get _border => OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AdminColors.borderInput),
      );
}

/// Тумблер «Приём заявок».
class AdminToggle extends StatelessWidget {
  /// Создаёт тумблер.
  const AdminToggle({
    required this.value,
    required this.accent,
    required this.onTap,
    super.key,
  });

  /// Включён ли.
  final bool value;

  /// Акцент клуба.
  final Color accent;

  /// Обработчик.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Container(
        width: 50,
        height: 29,
        padding: const EdgeInsets.all(2),
        alignment: value ? Alignment.centerRight : Alignment.centerLeft,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          color: value ? accent.withValues(alpha: 0.28) : const Color(0xFF15171B),
          border: Border.all(color: value ? accent : AdminColors.borderInput),
        ),
        child: Container(
          width: 23,
          height: 23,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: value ? accent : const Color(0xFF4E505A),
          ),
        ),
      ),
    );
  }
}

/// Мелкая обводка-кнопка (Закрыть зал, Отменить, Удалить…).
class AdminGhostButton extends StatelessWidget {
  /// Создаёт кнопку.
  const AdminGhostButton({
    required this.label,
    required this.onTap,
    this.tone = AdminButtonTone.neutral,
    this.filled = false,
    super.key,
  });

  /// Подпись.
  final String label;

  /// Обработчик.
  final VoidCallback onTap;

  /// Тон.
  final AdminButtonTone tone;

  /// Залитый вариант.
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final (Color fg, Color border, Color bg) = switch (tone) {
      AdminButtonTone.neutral => (
          AdminColors.textSoft,
          AdminColors.borderInput,
          Colors.transparent
        ),
      AdminButtonTone.danger => (
          AdminColors.danger,
          AdminColors.dangerBorder,
          filled ? AdminColors.dangerBg : Colors.transparent
        ),
      AdminButtonTone.warn => (
          AdminColors.warn,
          AdminColors.warnBorder,
          filled ? AdminColors.warnBg : Colors.transparent
        ),
    };
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: border),
        ),
        child: Text(label,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: fg)),
      ),
    );
  }
}

/// Тон кнопки [AdminGhostButton].
enum AdminButtonTone {
  /// Нейтральный.
  neutral,

  /// Опасный (красный).
  danger,

  /// Предупреждающий (жёлтый).
  warn,
}

Color _tint(Color accent) => accent == BookingColors.emeraldAccent
    ? BookingColors.emeraldTint
    : BookingColors.limeTint;
