import 'package:flutter_test/flutter_test.dart';

import 'package:vr_booking_web/features/admin/data/repository/admin_repository_mock.dart';
import 'package:vr_booking_web/features/admin/domain/entity/booking_row_entity.dart';
import 'package:vr_booking_web/features/admin/domain/state/admin_bloc.dart';

const BookingRowEntity _row = BookingRowEntity(
  id: 'r1',
  clubId: 'vray',
  hallId: 'v-big',
  dayIndex: 0,
  startMinutes: 720,
  durationMinutes: 120,
  headsets: 6,
  consoles: 0,
  clientName: 'Игорь Петров',
  phone: '+7 (912) 344-11-08',
  status: RecordStatus.confirmed,
  source: RecordSource.widget,
);

Future<AdminBloc> _ready() async {
  final AdminBloc bloc = AdminBloc(repository: const AdminRepositoryMock())
    ..add(const AdminStarted());
  await bloc.stream.firstWhere((AdminState s) => s.status == AdminStatus.ready);
  return bloc;
}

void main() {
  test('поиск: имя, цифры телефона, 8 вместо +7', () {
    expect(AdminState.matchesSearch(_row, 'игорь'), isTrue);
    expect(AdminState.matchesSearch(_row, 'Петров'), isTrue);
    expect(AdminState.matchesSearch(_row, '912 344'), isTrue);
    expect(AdminState.matchesSearch(_row, '11-08'), isTrue);
    expect(AdminState.matchesSearch(_row, '8 912 344 11 08'), isTrue);
    expect(AdminState.matchesSearch(_row, '+7912'), isTrue);
    // Двух цифр мало — иначе совпадёт почти всё.
    expect(AdminState.matchesSearch(_row, '12'), isFalse);
    expect(AdminState.matchesSearch(_row, 'Анна'), isFalse);
    expect(AdminState.matchesSearch(_row, '   '), isFalse);
  });

  test('результат поиска из другого клуба открывает карточку в его клубе', () async {
    final AdminBloc bloc = await _ready();
    final BookingRowEntity target =
        bloc.state.rows.firstWhere((BookingRowEntity r) => r.clubId == 'vray');

    bloc
      ..add(const AdminClubChanged('effect'))
      ..add(AdminSearchChanged(target.clientName));
    await bloc.stream.firstWhere((AdminState s) => s.searchResults.isNotEmpty);
    expect(bloc.state.searchResults.map((BookingRowEntity r) => r.id), contains(target.id));

    bloc.add(AdminSearchResultOpened(target.id));
    await bloc.stream.firstWhere((AdminState s) => s.openRowId == target.id);

    expect(bloc.state.clubId, 'vray');
    expect(bloc.state.searchQuery, isEmpty);
    await bloc.close();
  });
}
