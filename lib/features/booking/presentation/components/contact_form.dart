import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/theme/app_theme.dart';
import '../booking_format.dart';

/// Поля контактов клиента (шаг 4).
class ContactForm extends StatelessWidget {
  /// Создаёт форму.
  const ContactForm({
    required this.name,
    required this.phone,
    required this.people,
    required this.pickedCount,
    required this.onNameChanged,
    required this.onPhoneChanged,
    required this.onPeopleChanged,
    super.key,
  });

  /// Имя.
  final String name;

  /// Телефон.
  final String phone;

  /// Число людей (строка).
  final String people;

  /// Сколько станций выбрано (для подсказки в placeholder).
  final int pickedCount;

  /// Колбэк имени.
  final ValueChanged<String> onNameChanged;

  /// Колбэк телефона.
  final ValueChanged<String> onPhoneChanged;

  /// Колбэк числа людей.
  final ValueChanged<String> onPeopleChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        _Field(
          label: 'Имя',
          hint: 'Как к вам обращаться',
          initial: name,
          onChanged: onNameChanged,
        ),
        const SizedBox(height: 10),
        _Field(
          label: 'Телефон',
          hint: '+7 (900) 000-00-00',
          initial: phone,
          keyboardType: TextInputType.phone,
          formatters: <TextInputFormatter>[_PhoneFormatter()],
          onChanged: onPhoneChanged,
        ),
        const SizedBox(height: 10),
        _Field(
          label: 'Сколько будет всего, с учётом игроков',
          hint: pickedCount > 0 ? '$pickedCount' : '',
          initial: people,
          keyboardType: TextInputType.number,
          formatters: <TextInputFormatter>[
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(3),
          ],
          onChanged: onPeopleChanged,
        ),
      ],
    );
  }
}

class _Field extends StatefulWidget {
  const _Field({
    required this.label,
    required this.hint,
    required this.initial,
    required this.onChanged,
    this.keyboardType,
    this.formatters,
  });

  final String label;
  final String hint;
  final String initial;
  final ValueChanged<String> onChanged;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? formatters;

  @override
  State<_Field> createState() => _FieldState();
}

class _FieldState extends State<_Field> {
  late final TextEditingController _c = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(widget.label,
              style: const TextStyle(fontSize: 12, color: BookingColors.textMuted)),
        ),
        TextField(
          controller: _c,
          keyboardType: widget.keyboardType,
          inputFormatters: widget.formatters,
          onChanged: widget.onChanged,
          style: const TextStyle(fontSize: 16, color: BookingColors.text),
          decoration: InputDecoration(
            isDense: true,
            hintText: widget.hint,
            hintStyle: const TextStyle(color: BookingColors.textFaint),
            filled: true,
            fillColor: BookingColors.surface,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            border: _border(BookingColors.border),
            enabledBorder: _border(BookingColors.border),
            focusedBorder: _border(BookingColors.textSoft),
          ),
        ),
      ],
    );
  }

  OutlineInputBorder _border(Color c) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: c),
      );
}

class _PhoneFormatter extends TextInputFormatter {
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
