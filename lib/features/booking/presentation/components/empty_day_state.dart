import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';

/// Действие для состояния «на эту дату всё занято».
typedef EmptyDayAction = ({String label, bool primary, VoidCallback onTap});

/// Состояние «в зале на выбранную дату нет свободных станций».
class EmptyDayState extends StatelessWidget {
  /// Создаёт состояние.
  const EmptyDayState({
    required this.title,
    required this.actions,
    required this.accent,
    super.key,
  });

  /// Заголовок («На 8 сентября всё занято»).
  final String title;

  /// Три предложения-выхода.
  final List<EmptyDayAction> actions;

  /// Акцент клуба.
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 22, 18, 22),
      decoration: BoxDecoration(
        color: const Color(0xFF131318),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF34343E), style: BorderStyle.solid),
      ),
      child: Column(
        children: <Widget>[
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF34343E)),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[Color(0xFF1A1A20), Color(0xFF131318)],
                stops: <double>[0.5, 0.5],
                tileMode: TileMode.repeated,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          const Text(
            'В этом зале не осталось ни одной свободной станции. Ближайшие варианты:',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, height: 1.5, color: BookingColors.textMuted),
          ),
          const SizedBox(height: 16),
          for (final EmptyDayAction a in actions)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: SizedBox(
                width: double.infinity,
                child: InkWell(
                  onTap: a.onTap,
                  borderRadius: BorderRadius.circular(11),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: a.primary ? accent : Colors.transparent,
                      borderRadius: BorderRadius.circular(11),
                      border: Border.all(color: a.primary ? accent : BookingColors.border),
                    ),
                    child: Text(
                      a.label,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: a.primary ? BookingColors.bg : BookingColors.textSoft,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
