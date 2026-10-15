import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

import 'package:vr_booking_web/app/l10n/ru_localizations.dart';

void main() {
  test('русские даты без initializeDateFormatting на все языки', () {
    RuLocalizations.initDateFormatting();
    final DateTime d = DateTime(2026, 10, 14);
    expect(DateFormat('EEEE, d MMMM', 'ru').format(d), 'среда, 14 октября');
    expect(DateFormat('EEE, d MMM', 'ru').format(d), 'ср, 14 окт.');
    expect(DateFormat('LLLL yyyy', 'ru').format(d), 'октябрь 2026');
  });

  testWidgets('кнопки системных меню — по-русски', (WidgetTester tester) async {
    late MaterialLocalizations m;
    await tester.pumpWidget(MaterialApp(
      locale: RuLocalizations.locale,
      supportedLocales: const <Locale>[RuLocalizations.locale],
      localizationsDelegates: RuLocalizations.delegates,
      home: Builder(builder: (BuildContext c) {
        m = MaterialLocalizations.of(c);
        return const SizedBox();
      }),
    ));
    expect(m.copyButtonLabel, 'Копировать');
    expect(m.pasteButtonLabel, 'Вставить');
    expect(m.formatMediumDate(DateTime(2026, 10, 14)), contains('окт'));
  });
}
