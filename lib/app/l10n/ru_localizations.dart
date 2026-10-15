import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_custom.dart';
import 'package:intl/intl.dart' as intl;

import 'ru_date_data.dart';

/// Только русская локализация — вместо `GlobalMaterialLocalizations.delegate`
/// и `initializeDateFormatting()`.
///
/// Стандартные делегаты выбирают перевод через `switch` по всем ~80 языкам,
/// и компилятор не может выбросить ни один из них: в веб-бандл попадали
/// переводы кнопок и форматы дат на все языки. Здесь классы русского перевода
/// создаются напрямую, а остальные языки в сборку не попадают.
abstract final class RuLocalizations {
  const RuLocalizations._();

  /// Единственная поддерживаемая локаль.
  static const Locale locale = Locale('ru');

  /// Делегаты для `MaterialApp.localizationsDelegates`.
  static const List<LocalizationsDelegate<dynamic>> delegates =
      <LocalizationsDelegate<dynamic>>[
    _MaterialDelegate(),
    _CupertinoDelegate(),
    _WidgetsDelegate(),
  ];

  static bool _dateReady = false;

  /// Регистрирует русские форматы дат в intl. Вызывать до первого
  /// `DateFormat(..., 'ru')`; повторный вызов ничего не делает.
  static void initDateFormatting() {
    if (_dateReady) return;
    initializeDateFormattingCustom(
      locale: 'ru',
      symbols: ruDateSymbols,
      patterns: ruDatePatterns,
    );
    _dateReady = true;
  }
}

bool _isRu(Locale l) => l.languageCode == 'ru';

class _MaterialDelegate extends LocalizationsDelegate<MaterialLocalizations> {
  const _MaterialDelegate();

  @override
  bool isSupported(Locale locale) => _isRu(locale);

  @override
  Future<MaterialLocalizations> load(Locale locale) {
    RuLocalizations.initDateFormatting();
    return SynchronousFuture<MaterialLocalizations>(MaterialLocalizationRu(
      fullYearFormat: intl.DateFormat.y('ru'),
      compactDateFormat: intl.DateFormat.yMd('ru'),
      shortDateFormat: intl.DateFormat.yMMMd('ru'),
      mediumDateFormat: intl.DateFormat.MMMEd('ru'),
      longDateFormat: intl.DateFormat.yMMMMEEEEd('ru'),
      yearMonthFormat: intl.DateFormat.yMMMM('ru'),
      shortMonthDayFormat: intl.DateFormat.MMMd('ru'),
      decimalFormat: intl.NumberFormat.decimalPattern('ru'),
      twoDigitZeroPaddedFormat: intl.NumberFormat('00', 'ru'),
    ));
  }

  @override
  bool shouldReload(_MaterialDelegate old) => false;
}

class _CupertinoDelegate extends LocalizationsDelegate<CupertinoLocalizations> {
  const _CupertinoDelegate();

  @override
  bool isSupported(Locale locale) => _isRu(locale);

  @override
  Future<CupertinoLocalizations> load(Locale locale) {
    RuLocalizations.initDateFormatting();
    return SynchronousFuture<CupertinoLocalizations>(CupertinoLocalizationRu(
      fullYearFormat: intl.DateFormat.y('ru'),
      dayFormat: intl.DateFormat.d('ru'),
      weekdayFormat: intl.DateFormat.E('ru'),
      mediumDateFormat: intl.DateFormat.MMMEd('ru'),
      singleDigitHourFormat: intl.DateFormat('HH', 'ru'),
      singleDigitMinuteFormat: intl.DateFormat.m('ru'),
      doubleDigitMinuteFormat: intl.DateFormat('mm', 'ru'),
      singleDigitSecondFormat: intl.DateFormat.s('ru'),
      decimalFormat: intl.NumberFormat.decimalPattern('ru'),
    ));
  }

  @override
  bool shouldReload(_CupertinoDelegate old) => false;
}

class _WidgetsDelegate extends LocalizationsDelegate<WidgetsLocalizations> {
  const _WidgetsDelegate();

  @override
  bool isSupported(Locale locale) => _isRu(locale);

  @override
  Future<WidgetsLocalizations> load(Locale locale) =>
      SynchronousFuture<WidgetsLocalizations>(const WidgetsLocalizationRu());

  @override
  bool shouldReload(_WidgetsDelegate old) => false;
}
