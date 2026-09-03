import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';

/// Плашка «слот только что заняли» с вариантами действий.
class ConflictBanner extends StatelessWidget {
  /// Создаёт плашку.
  const ConflictBanner({
    required this.title,
    required this.text,
    required this.keepLabel,
    required this.onKeep,
    required this.onDismiss,
    super.key,
  });

  /// Заголовок.
  final String title;

  /// Текст.
  final String text;

  /// Подпись основной кнопки («Взять #5» / «Продолжить без неё» …).
  final String keepLabel;

  /// Основное действие.
  final VoidCallback onKeep;

  /// «Выбрать другое время».
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: BookingColors.warnBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: BookingColors.warnBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: BookingColors.warn,
              borderRadius: BorderRadius.circular(7),
            ),
            child: const Text('!',
                style: TextStyle(
                    color: BookingColors.warnBg,
                    fontWeight: FontWeight.w800,
                    fontSize: 14)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: BookingColors.warnTitle)),
                const SizedBox(height: 4),
                Text(text,
                    style: const TextStyle(
                        fontSize: 13, height: 1.5, color: BookingColors.warnText)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    _Btn(label: keepLabel, filled: true, onTap: onKeep),
                    _Btn(label: 'Выбрать другое время', filled: false, onTap: onDismiss),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Btn extends StatelessWidget {
  const _Btn({required this.label, required this.filled, required this.onTap});

  final String label;
  final bool filled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: filled ? BookingColors.warn : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: filled ? null : Border.all(color: BookingColors.warnBorder),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: filled ? FontWeight.w700 : FontWeight.w600,
            color: filled ? BookingColors.warnBg : BookingColors.warnText,
          ),
        ),
      ),
    );
  }
}
