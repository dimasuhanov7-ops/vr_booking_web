import 'package:flutter_test/flutter_test.dart';

import 'package:vr_booking_web/features/admin/domain/entity/availability_entity.dart';
import 'package:vr_booking_web/features/admin/domain/state/admin_bloc.dart';

DateTime _day(int plusDays) {
  final DateTime n = DateTime.now();
  return DateTime(n.year, n.month, n.day).add(Duration(days: plusDays));
}

void main() {
  final AdminState state = AdminState(
    clubId: 'club-1',
    closures: <ClosureEntity>[
      // окно на завтра в большом зале
      ClosureEntity(
        id: 'c1',
        clubId: 'club-1',
        hallId: 'hall-big',
        day: _day(1),
        fromMinutes: 14 * 60,
        toMinutes: 18 * 60,
      ),
      // весь клуб на послезавтра целиком
      ClosureEntity(id: 'c2', clubId: 'club-1', day: _day(2)),
      // малый зал закрыт бессрочно
      const ClosureEntity(id: 'c3', clubId: 'club-1', hallId: 'hall-small'),
      // чужой клуб — не наше дело
      ClosureEntity(
        id: 'c4',
        clubId: 'club-2',
        hallId: 'hall-x',
        day: _day(1),
        fromMinutes: 11 * 60,
        toMinutes: 23 * 60,
      ),
    ],
  );

  test('на день попадают окна этого дня и бессрочно закрытые залы', () {
    expect(
      state.closuresOn(1).map((ClosureEntity c) => c.id),
      <String>['c3', 'c1'],
      reason: 'бессрочное закрытие идёт первым — у него нет времени начала',
    );
    // У обоих закрытий дня 2 нет времени начала — порядок остаётся исходным.
    expect(state.closuresOn(2).map((ClosureEntity c) => c.id), <String>['c2', 'c3']);
    expect(state.closuresOn(5).map((ClosureEntity c) => c.id), <String>['c3']);
  });

  test('час считается закрытым только при пересечении с окном', () {
    bool closed(int hour, {String hall = 'hall-big', int day = 1}) =>
        state.isClosedHour(hallId: hall, dayIndex: day, minutes: hour * 60);

    expect(closed(13), isFalse, reason: '13:00–14:00 кончается ровно на границе');
    expect(closed(14), isTrue);
    expect(closed(17), isTrue);
    expect(closed(18), isFalse, reason: '18:00 — уже после окна');
  });

  test('закрытие всего клуба и бессрочно закрытый зал', () {
    expect(state.isClosedHour(hallId: 'hall-big', dayIndex: 2, minutes: 12 * 60), isTrue);
    expect(state.isClosedHour(hallId: 'hall-small', dayIndex: 4, minutes: 12 * 60), isTrue);
    expect(state.isClosedHour(hallId: 'hall-big', dayIndex: 4, minutes: 12 * 60), isFalse);
  });

  test('закрытия чужого клуба не учитываются', () {
    const AdminState other = AdminState(clubId: 'club-9');
    expect(other.closuresOn(1), isEmpty);
    expect(state.closuresOn(1).any((ClosureEntity c) => c.clubId != 'club-1'), isFalse);
  });
}
