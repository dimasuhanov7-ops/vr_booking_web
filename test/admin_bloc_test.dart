import 'package:flutter_test/flutter_test.dart';

import 'package:vr_booking_web/features/admin/data/repository/admin_repository_mock.dart';
import 'package:vr_booking_web/features/admin/domain/entity/booking_row_entity.dart';
import 'package:vr_booking_web/features/admin/domain/state/admin_bloc.dart';

Future<AdminBloc> _ready() async {
  final AdminBloc bloc = AdminBloc(repository: const AdminRepositoryMock())
    ..add(const AdminStarted());
  await bloc.stream.firstWhere((AdminState s) => s.status == AdminStatus.ready);
  return bloc;
}

void main() {
  test('старт: клуб по умолчанию, вкладка «Цены», день = сегодня', () async {
    final AdminBloc bloc = await _ready();
    expect(bloc.state.tab, AdminTab.prices);
    expect(bloc.state.clubId, 'vray');
    expect(bloc.state.filterDay, 0); // после обновления страницы — сегодня
    expect(bloc.state.rows.length, greaterThan(10));
    expect(AdminTab.values.contains(AdminTab.records), isTrue);
    await bloc.close();
  });

  test('новая бронь: открытие → правка → создание добавляет запись и открывает её',
      () async {
    final AdminBloc bloc = await _ready();

    bloc.add(const AdminNewBookingOpened());
    await bloc.stream.firstWhere((AdminState s) => s.newBooking != null);
    expect(bloc.state.newBookingHall, isNotNull);

    bloc
      ..add(const AdminNewBookingChanged(dayIndex: 2, startMinutes: 660, durationMinutes: 120))
      ..add(const AdminNewBookingChanged(headsets: 3))
      ..add(const AdminNewBookingChanged(name: 'Тестовый гость', phone: '+7 900'));
    await bloc.stream.firstWhere((AdminState s) => s.newBooking?.name == 'Тестовый гость');

    final int before = bloc.state.rows.length;
    bloc.add(const AdminNewBookingSubmitted());
    await bloc.stream.firstWhere((AdminState s) => s.newBooking == null);

    expect(bloc.state.rows.length, before + 1);
    expect(bloc.state.tab, AdminTab.records);
    expect(bloc.state.filterDay, 2);
    final BookingRowEntity added = bloc.state.rows.last;
    expect(added.clientName, 'Тестовый гость');
    expect(added.source, RecordSource.admin);
    expect(bloc.state.openRowId, added.id);
    await bloc.close();
  });

  test('новая бронь: без имени — сообщение об ошибке, запись не создаётся', () async {
    final AdminBloc bloc = await _ready();
    bloc.add(const AdminNewBookingOpened());
    await bloc.stream.firstWhere((AdminState s) => s.newBooking != null);

    final int before = bloc.state.rows.length;
    bloc.add(const AdminNewBookingSubmitted());
    await bloc.stream.firstWhere((AdminState s) => s.newBooking?.message.isNotEmpty ?? false);

    expect(bloc.state.rows.length, before);
    expect(bloc.state.newBooking, isNotNull);
    await bloc.close();
  });

  test('правка брони: оверлей применяется и сбрасывается', () async {
    final AdminBloc bloc = await _ready();
    final String id = bloc.state.rows.first.id;

    bloc.add(AdminRowOpened(id));
    await bloc.stream.firstWhere((AdminState s) => s.openRowId == id);

    bloc.add(AdminRowEdited(rowId: id, clientName: 'Переименовано'));
    await bloc.stream.firstWhere((AdminState s) => s.isEdited(id));
    expect(bloc.state.rowById(id)!.clientName, 'Переименовано');

    bloc.add(AdminRowEditReset(id));
    await bloc.stream.firstWhere((AdminState s) => !s.isEdited(id));
    expect(bloc.state.rowById(id)!.clientName, isNot('Переименовано'));
    await bloc.close();
  });

  test('свободная ёмкость учитывает пересекающиеся брони', () async {
    final AdminBloc bloc = await _ready();
    // V-Ray, «Большой зал» (12 шлемов). LOG: l1 12:00–14:00, 6 шлемов.
    final FreeUnits at12 = bloc.state.freeUnits(
      hallId: 'v-big',
      dayIndex: 0,
      startMinutes: 720,
      durationMinutes: 60,
    );
    expect(at12.headsets, 12 - 6);

    final FreeUnits at9 = bloc.state.freeUnits(
      hallId: 'v-big',
      dayIndex: 0,
      startMinutes: 540,
      durationMinutes: 60,
    );
    expect(at9.headsets, 12);
    await bloc.close();
  });
}
