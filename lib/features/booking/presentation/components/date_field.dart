import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../booking_format.dart';
import 'calendar_sheet.dart';

/// Кнопка выбора даты, открывающая календарь (шаг 2).
class DateField extends StatelessWidget {
  /// Создаёт поле даты.
  const DateField({
    required this.date,
    required this.accent,
    required this.daysAhead,
    required this.onSelected,
    super.key,
  });

  /// Выбранная дата.
  final DateTime date;

  /// Акцент клуба.
  final Color accent;

  /// На сколько дней вперёд открыта запись.
  final int daysAhead;

  /// Колбэк выбора даты.
  final ValueChanged<DateTime> onSelected;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        final DateTime? picked = await showModalBottomSheet<DateTime>(
          context: context,
          backgroundColor: BookingColors.frame,
          isScrollControlled: true,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
          ),
          builder: (_) => CalendarSheet(
            initial: date,
            accent: accent,
            daysAhead: daysAhead,
          ),
        );
        if (picked != null) onSelected(picked);
      },
      borderRadius: BorderRadius.circular(13),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
        decoration: BoxDecoration(
          color: BookingColors.surface,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: BookingColors.border),
        ),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Text(
                _cap(BookingFormat.dayLong(date)),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
            const Text('изменить',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: BookingColors.textMuted)),
          ],
        ),
      ),
    );
  }

  static String _cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}
