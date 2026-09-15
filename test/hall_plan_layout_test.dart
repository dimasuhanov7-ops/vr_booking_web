import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vr_booking_web/app/theme/app_theme.dart';
import 'package:vr_booking_web/features/booking/domain/entity/station_entity.dart';
import 'package:vr_booking_web/features/booking/presentation/components/hall_plan.dart';

/// Ширина области плана на телефоне шириной 411 dp (Nothing Phone 1): внутри
/// контейнера плана остаётся 310.
const double _phoneWidth = 340;

List<StationEntity> _room({required int headsets, required int perRow}) =>
    <StationEntity>[
      for (int i = 0; i < headsets; i++)
        StationEntity(
          id: 'vr${i + 1}',
          roomId: 'big',
          roomName: 'Большой зал',
          type: StationType.vrHeadset,
          label: '#${i + 1}',
          rowIndex: i ~/ perRow,
          positionInRow: i % perRow,
          sortOrder: i,
          isActive: true,
        ),
    ];

Future<void> _pump(
  WidgetTester tester, {
  required List<StationEntity> stations,
  required double width,
  Set<String> picked = const <String>{},
  void Function(Set<String> ids, {required bool pick})? onPickGroup,
}) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: width,
            child: SingleChildScrollView(
              child: HallPlan(
                stations: stations,
                isFree: (_) => true,
                pickedIds: picked,
                takenIds: const <String>{},
                isCombo: false,
                accent: BookingColors.emeraldAccent,
                freeCount: stations.length,
                onToggle: (_) {},
                onQuickPick: (_) {},
                onClear: () {},
                onPickGroup:
                    onPickGroup ?? (Set<String> ids, {required bool pick}) {},
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

double _y(WidgetTester tester, String label) =>
    tester.getCenter(find.text(label)).dy;

void main() {
  group('hallRowFit', () {
    test('половина арены на телефоне — блок 3×2 во всю ширину', () {
      final ({int cols, double pod}) f = hallRowFit(6, 310);
      expect(f.cols, 3);
      expect(f.pod, 98);
    });

    test('на планшете половина встаёт в ряд целиком, не шире макета', () {
      final ({int cols, double pod}) f = hallRowFit(6, 560);
      expect(f.cols, 6);
      expect(f.pod, 74);
    });

    test('ряд из 4 на телефоне остаётся целым', () {
      expect(hallRowFit(4, 310).cols, 4);
    });

    test('на очень узком экране 4 делятся на 2+2, а не 3+1', () {
      expect(hallRowFit(4, 240).cols, 2);
    });
  });

  group('HallPlan', () {
    testWidgets('телефон: половина арены 3×2, подпись «половина»', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        stations: _room(headsets: 12, perRow: 6),
        width: _phoneWidth,
      );

      expect(find.text('ПОЛОВИНА 1 · 6 ШЛЕМОВ'), findsOneWidget);
      expect(find.text('ПОЛОВИНА 2 · 6 ШЛЕМОВ'), findsOneWidget);
      expect(_y(tester, '#1'), _y(tester, '#3'));
      expect(_y(tester, '#4'), greaterThan(_y(tester, '#3')));
      expect(_y(tester, '#4'), _y(tester, '#6'));
      expect(_y(tester, '#7'), greaterThan(_y(tester, '#6')));
    });

    testWidgets('ряд из 4 не переносится (обводка фокуса не ест ширину)', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        stations: _room(headsets: 4, perRow: 4),
        width: _phoneWidth,
      );

      expect(_y(tester, '#1'), _y(tester, '#4'));
      expect(find.text('взять половину'), findsNothing);
    });

    testWidgets('«взять половину» отдаёт свободные станции своей половины', (
      WidgetTester tester,
    ) async {
      Set<String>? got;
      bool? gotPick;
      await _pump(
        tester,
        stations: _room(headsets: 12, perRow: 6),
        width: _phoneWidth,
        onPickGroup: (Set<String> ids, {required bool pick}) {
          got = ids;
          gotPick = pick;
        },
      );

      await tester.tap(find.text('взять половину').first);
      expect(got, <String>{'vr1', 'vr2', 'vr3', 'vr4', 'vr5', 'vr6'});
      expect(gotPick, isTrue);
    });

    testWidgets('выбранная целиком половина предлагает «снять»', (
      WidgetTester tester,
    ) async {
      bool? gotPick;
      await _pump(
        tester,
        stations: _room(headsets: 12, perRow: 6),
        width: _phoneWidth,
        picked: <String>{'vr7', 'vr8', 'vr9', 'vr10', 'vr11', 'vr12'},
        onPickGroup: (Set<String> ids, {required bool pick}) => gotPick = pick,
      );

      expect(find.text('снять'), findsOneWidget);
      await tester.tap(find.text('снять'));
      expect(gotPick, isFalse);
    });
  });
}
