import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';

/// Заглавная подпись-оверлайн над секцией.
///
/// [big] — крупный лейбл поля-карточки (дата, длительность, время начала):
/// 14px, белый, полужирный. Обычный — 11px, приглушённый оверлайн.
class SectionLabel extends StatelessWidget {
  /// Создаёт подпись.
  const SectionLabel(this.text, {this.padding, this.big = false, super.key});

  /// Текст (будет в верхнем регистре).
  final String text;

  /// Внешний отступ.
  final EdgeInsetsGeometry? padding;

  /// Крупный вариант.
  final bool big;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding ?? EdgeInsets.zero,
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: big ? 14 : 11,
          letterSpacing: big ? 0.9 : 1.4,
          fontWeight: big ? FontWeight.w700 : FontWeight.w600,
          color: big ? BookingColors.text : BookingColors.textFaint,
        ),
      ),
    );
  }
}

/// Карточка-поле: бордер `#2E2E38`, фон `#121217`, радиус 16 (дата, длительность).
///
/// Необязательный заголовок — крупный лейбл слева и подпись-подсказка справа.
class FieldCard extends StatelessWidget {
  /// Создаёт карточку-поле.
  const FieldCard({required this.child, this.label, this.trailing, super.key});

  /// Содержимое.
  final Widget child;

  /// Крупный лейбл (если нужен заголовок).
  final String? label;

  /// Подпись-подсказка справа от лейбла.
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: BookingColors.fieldSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2E2E38)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (label != null) ...<Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                Expanded(child: SectionLabel(label!, big: true)),
                if (trailing != null)
                  Text(trailing!,
                      style: const TextStyle(fontSize: 12, color: BookingColors.textDim)),
              ],
            ),
            const SizedBox(height: 10),
          ],
          child,
        ],
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
