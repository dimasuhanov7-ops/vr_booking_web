import 'package:flutter/material.dart';

import '../admin_theme.dart';

/// KPI-плитка вкладки «Записи».
class KpiTile extends StatelessWidget {
  /// Создаёт плитку.
  const KpiTile({
    required this.label,
    required this.value,
    required this.note,
    required this.valueColor,
    super.key,
  });

  /// Подпись сверху.
  final String label;

  /// Крупное значение.
  final String value;

  /// Пояснение снизу.
  final String note;

  /// Цвет значения (акцент-tint клуба).
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(15, 14, 15, 14),
      decoration: BoxDecoration(
        color: AdminColors.panel,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: AdminColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(label.toUpperCase(),
              style: const TextStyle(
                  fontSize: 11, letterSpacing: 1, color: AdminColors.textLabel)),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
                color: valueColor,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(note, style: const TextStyle(fontSize: 12, color: AdminColors.textFaint)),
        ],
      ),
    );
  }
}
