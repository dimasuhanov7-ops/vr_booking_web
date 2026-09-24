import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:vr_booking_web/features/admin/data/repository/admin_repository_mock.dart';
import 'package:vr_booking_web/features/admin/domain/entity/booking_row_entity.dart';
import 'package:vr_booking_web/features/admin/domain/state/admin_bloc.dart';

/// Демо-данные + управляемый поток «на сервере что-то поменялось».
class _LiveRepo extends AdminRepositoryMock {
  _LiveRepo();

  final StreamController<void> events = StreamController<void>.broadcast();
  final List<BookingRowEntity> extra = <BookingRowEntity>[];

  @override
  Stream<void> changes() => events.stream;

  @override
  Future<List<BookingRowEntity>> fetchRows() async =>
      <BookingRowEntity>[...await super.fetchRows(), ...extra];
}

const BookingRowEntity _fromWidget = BookingRowEntity(
  id: 'online-1',
  clubId: 'vray',
  hallId: 'v-big',
  dayIndex: 0,
  startMinutes: 1080,
  durationMinutes: 60,
  headsets: 2,
  consoles: 0,
  clientName: 'Новая онлайн-бронь',
  phone: '+7 900 000-00-00',
  status: RecordStatus.confirmed,
  source: RecordSource.widget,
);

void main() {
  test('событие Realtime подтягивает новую бронь и не теряет правки', () async {
    final _LiveRepo repo = _LiveRepo();
    final AdminBloc bloc = AdminBloc(repository: repo)..add(const AdminStarted());
    await bloc.stream.firstWhere((AdminState s) => s.status == AdminStatus.ready);

    // Сотрудник правит другую бронь и ещё не сохранил.
    final String editedId = bloc.state.rows.first.id;
    bloc.add(AdminRowEdited(rowId: editedId, clientName: 'Правка в процессе'));
    await bloc.stream.firstWhere((AdminState s) => s.isEdited(editedId));

    // С виджета пришла бронь; несколько событий подряд — одно перечитывание.
    repo.extra.add(_fromWidget);
    repo.events
      ..add(null)
      ..add(null)
      ..add(null);
    await bloc.stream.firstWhere((AdminState s) => s.rowById('online-1') != null);

    expect(bloc.state.rowById(editedId)!.clientName, 'Правка в процессе');
    await bloc.close();
    await repo.events.close();
  });
}
