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

  /// Поверхность карточки-поля (дата, длительность, заглушки) — `#121217`.
  static const Color fieldSurface = Color(0xFF121217);

  /// Поверхность плитки станции.
  static const Color pod = Color(0xFF191920);

  /// Основной текст.
  static const Color text = Color(0xFFF2F2F5);

  /// Вторичный текст.
  static const Color textSoft = Color(0xFFC9C9D2);

  // Ниже — четыре ступени «тихого» текста. Значения подобраны по контрасту
  // с тёмными подложками (frame #101015 и pod #191920), порог WCAG AA — 4.5:1
  // для обычного текста. До аудита textFaint давал 2.83, textOff — 2.58,
  // то есть подписи-капсы и статус «занято» формально не читались.

  /// Приглушённый текст. Контраст 5.6 на frame.
  static const Color textMuted = Color(0xFF8A8A96);

  /// Ещё тише. Контраст 5.1 на frame, 4.7 на плитке станции.
  static const Color textDim = Color(0xFF83838F);

  /// Оверлайны / подписи-капсы. Контраст 4.6 на frame.
  static const Color textFaint = Color(0xFF7D7D89);

  /// Выключенный текст — статус «занято» на плитке станции. 4.1 на frame:
  /// ниже AA, но это состояние «недоступно», а не основной контент; было 2.6.
  static const Color textOff = Color(0xFF74747F);

  /// Служебная подпись «Для сотрудников» — намеренно неприметная.
  /// Единственное осознанное исключение из порога контраста: элемент не для
  /// клиентов, и заказчик просил, чтобы он не бросался в глаза.
  static const Color textService = Color(0xFF4A4A54);

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
