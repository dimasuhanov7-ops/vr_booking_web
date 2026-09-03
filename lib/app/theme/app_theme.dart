import 'package:flutter/material.dart';

/// Палитра и типографика виджета бронирования (по макету Claude Design).
abstract final class BookingColors {
  const BookingColors._();

  /// Фон страницы.
  static const Color bg = Color(0xFF08090A);

  /// Фон «рамки» виджета.
  static const Color frame = Color(0xFF101015);

  /// Поверхность карточек / полей.
  static const Color surface = Color(0xFF15151A);

  /// Более тёмная поверхность (промо-инпут, план зала).
  static const Color surfaceDeep = Color(0xFF101015);

  /// Поверхность плитки станции.
  static const Color pod = Color(0xFF191920);

  /// Основной текст.
  static const Color text = Color(0xFFF2F2F5);

  /// Вторичный текст.
  static const Color textSoft = Color(0xFFC9C9D2);

  /// Приглушённый текст.
  static const Color textMuted = Color(0xFF8A8A96);

  /// Ещё тише.
  static const Color textDim = Color(0xFF6E6E7A);

  /// Оверлайны / подписи-капсы.
  static const Color textFaint = Color(0xFF5B5B66);

  /// Выключенный текст.
  static const Color textOff = Color(0xFF55555F);

  /// Границы (яркая / базовая / тихая).
  static const Color border = Color(0xFF2A2A33);
  static const Color borderSoft = Color(0xFF26262E);
  static const Color borderFaint = Color(0xFF222228);
  static const Color podBorder = Color(0xFF33333D);

  /// Акцент Effect VR (лайм).
  static const Color limeAccent = Color(0xFFA9F04A);
  static const Color limeTint = Color(0xFFDDFCAE);

  /// Акцент V-Ray (изумруд).
  static const Color emeraldAccent = Color(0xFF0FB981);
  static const Color emeraldTint = Color(0xFF8BEFCB);

  /// Предупреждение / конфликт.
  static const Color warn = Color(0xFFFFB020);
  static const Color warnBg = Color(0xFF241D10);
  static const Color warnBorder = Color(0xFF4A3A1F);
  static const Color warnTitle = Color(0xFFFFD48A);
  static const Color warnText = Color(0xFFCDBB99);

  /// Акцент клуба по его slug.
  static Color accentFor(String? slug) =>
      slug == 'v_ray' ? emeraldAccent : limeAccent;

  /// Светлый оттенок акцента клуба (для текста на акцентной подложке).
  static Color accentTintFor(String? slug) =>
      slug == 'v_ray' ? emeraldTint : limeTint;
}

/// Тема приложения.
abstract final class AppTheme {
  const AppTheme._();

  /// Тёмная тема виджета.
  static ThemeData get dark {
    final ThemeData base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: BookingColors.bg,
      textTheme: base.textTheme.apply(
        fontFamily: 'Archivo',
        bodyColor: BookingColors.text,
        displayColor: BookingColors.text,
      ),
      colorScheme: base.colorScheme.copyWith(
        primary: BookingColors.limeAccent,
        secondary: BookingColors.emeraldAccent,
        surface: BookingColors.surface,
        onSurface: BookingColors.text,
      ),
      splashFactory: InkSparkle.splashFactory,
    );
  }
}
