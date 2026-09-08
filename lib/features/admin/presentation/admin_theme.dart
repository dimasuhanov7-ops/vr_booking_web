import 'package:flutter/material.dart';

import '../../../app/theme/app_theme.dart';

/// Токены админки поверх общих [BookingColors] (панели темнее, чем в виджете).
abstract final class AdminColors {
  const AdminColors._();

  /// Фон страницы.
  static const Color bg = BookingColors.bg;

  /// Панель / карточка.
  static const Color panel = Color(0xFF101216);

  /// Поверхность строки/плитки.
  static const Color tile = Color(0xFF0C0E11);

  /// Инпут.
  static const Color input = Color(0xFF0A0C0E);

  /// Отключённый пакет.
  static const Color tileMuted = Color(0xFF0A0B0D);

  /// Граница панели.
  static const Color border = Color(0xFF212227);

  /// Граница инпута / чипа.
  static const Color borderInput = Color(0xFF2A2C33);

  /// Разделитель шапки.
  static const Color divider = Color(0xFF1E1F24);

  /// Разделитель строк списка.
  static const Color rowDivider = Color(0xFF1A1B20);

  /// Текст.
  static const Color text = BookingColors.text;
  static const Color textSoft = Color(0xFFC9C9D2);
  static const Color textMid = Color(0xFF9A9AA6);
  static const Color textMuted = Color(0xFF8A8A96);
  static const Color textDim = Color(0xFF7C7C88);
  static const Color textFaint = Color(0xFF6E6E7A);
  static const Color textLabel = Color(0xFF5B5B66);

  /// Закрыто / пауза (жёлтый).
  static const Color warn = Color(0xFFFFC98A);
  static const Color warnBg = Color(0xFF1E1610);
  static const Color warnBgDeep = Color(0xFF16110C);
  static const Color warnBorder = Color(0xFF3A2A1C);

  /// Отмена / опасно (красный).
  static const Color danger = Color(0xFFFF9BA6);
  static const Color dangerBg = Color(0xFF1B1114);
  static const Color dangerBorder = Color(0xFF3A2226);

  /// Акцент клуба.
  static Color accentFor(String slug) => BookingColors.accentFor(slug);

  /// Светлый оттенок акцента клуба.
  static Color tintFor(String slug) => BookingColors.accentTintFor(slug);

  /// Цвета статуса записи: (текст, фон, рамка).
  static (Color, Color, Color) status(String key) => switch (key) {
        'confirmed' => (const Color(0xFF8BEFCB), const Color(0xFF0C1A16), const Color(0xFF1E3A31)),
        'paid' => (const Color(0xFFA9F04A), const Color(0xFF141A0C), const Color(0xFF2C3A1C)),
        _ => (warn, warnBg, warnBorder),
      };

  /// Палитра сетки занятости — 6 оттенков по кругу (фон, рамка, текст).
  static const List<(Color, Color, Color)> _hues = <(Color, Color, Color)>[
    (Color(0x6BA9F04A), Color(0xBFA9F04A), Color(0xFFEAFFC8)),
    (Color(0x6B7FA6FF), Color(0xBF7FA6FF), Color(0xFFDCE8FF)),
    (Color(0x6BFFA85C), Color(0xBFFFA85C), Color(0xFFFFE7D2)),
    (Color(0x6BD685FF), Color(0xBFD685FF), Color(0xFFF4E1FF)),
    (Color(0x6B5EE1CC), Color(0xBF5EE1CC), Color(0xFFD6FFF7)),
    (Color(0x6BFF8AA8), Color(0xC7FF8AA8), Color(0xFFFFE0E7)),
  ];

  /// Оттенок брони в сетке занятости по её порядковому номеру за день.
  static ({Color bg, Color border, Color text}) hue(int index) {
    final (Color, Color, Color) h = _hues[index % _hues.length];
    return (bg: h.$1, border: h.$2, text: h.$3);
  }
}
