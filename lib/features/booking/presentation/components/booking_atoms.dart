import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';

/// Заглавная подпись-оверлайн над секцией.
class SectionLabel extends StatelessWidget {
  /// Создаёт подпись.
  const SectionLabel(this.text, {this.padding, super.key});

  /// Текст (будет в верхнем регистре).
  final String text;

  /// Внешний отступ.
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding ?? EdgeInsets.zero,
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          letterSpacing: 1.4,
          fontWeight: FontWeight.w600,
          color: BookingColors.textFaint,
        ),
      ),
    );
  }
}

/// Чип-кнопка выбора (длительность, зал, быстрый выбор).
class PillButton extends StatelessWidget {
  /// Создаёт чип.
  const PillButton({
    required this.label,
    required this.selected,
    required this.accent,
    required this.onTap,
    this.expand = false,
    this.dashed = false,
    this.dim = false,
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

  /// Растянуть по ширине (flex).
  final bool expand;

  /// Пунктирная рамка (для «Весь клуб»).
  final bool dashed;

  /// Приглушённый вид (кнопка «сбросить»).
  final bool dim;

  @override
  Widget build(BuildContext context) {
    final Color tint = accent == BookingColors.emeraldAccent
        ? BookingColors.emeraldTint
        : BookingColors.limeTint;
    final Color fg = selected
        ? tint
        : (dim ? BookingColors.textMuted : const Color(0xFF9A9AA6));

    Widget button = InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(11),
      child: DottedBorderBox(
        dashed: dashed && !selected,
        color: selected ? accent : BookingColors.border,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? accent.withValues(alpha: 0.18) : Colors.transparent,
            borderRadius: BorderRadius.circular(11),
            border: dashed && !selected
                ? null
                : Border.all(color: selected ? accent : BookingColors.border),
          ),
          child: Text(
            label,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: fg),
          ),
        ),
      ),
    );
    return expand ? Expanded(child: button) : button;
  }
}

/// Рамка, которая может быть пунктирной (для варианта «Весь клуб»).
class DottedBorderBox extends StatelessWidget {
  /// Создаёт рамку.
  const DottedBorderBox({
    required this.child,
    required this.dashed,
    required this.color,
    super.key,
  });

  /// Содержимое.
  final Widget child;

  /// Рисовать пунктиром.
  final bool dashed;

  /// Цвет рамки.
  final Color color;

  @override
  Widget build(BuildContext context) {
    if (!dashed) return child;
    return CustomPaint(
      painter: _DashedPainter(color),
      child: child,
    );
  }
}

class _DashedPainter extends CustomPainter {
  _DashedPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final RRect rect = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(11),
    );
    final Path path = Path()..addRRect(rect);
    final Paint paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (final metric in path.computeMetrics()) {
      double d = 0;
      while (d < metric.length) {
        canvas.drawPath(metric.extractPath(d, d + 4), paint);
        d += 8;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedPainter old) => old.color != color;
}
