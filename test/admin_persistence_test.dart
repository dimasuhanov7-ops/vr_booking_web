import 'package:flutter_test/flutter_test.dart';

import 'package:vr_booking_web/features/admin/data/repository/admin_repository_mock.dart';
import 'package:vr_booking_web/features/admin/domain/entity/admin_booking_request_entity.dart';
import 'package:vr_booking_web/features/admin/domain/entity/admin_club_entity.dart';
import 'package:vr_booking_web/features/admin/domain/entity/booking_row_entity.dart';
import 'package:vr_booking_web/features/admin/domain/entity/package_entity.dart';
import 'package:vr_booking_web/features/admin/domain/state/admin_bloc.dart';

/// Демо-данные, но с управляемыми ответами «сервера» и журналом вызовов.
class _Repo extends AdminRepositoryMock {
  _Repo({this.failLoad = false, this.deletes = true, this.movable = true});

  bool failLoad;
  final bool deletes;
  final bool movable;

  final List<AdminBookingRequest> bookingsCreated = <AdminBookingRequest>[];
  final List<(String, RecordStatus)> visits = <(String, RecordStatus)>[];
  final List<Map<String, Object?>> moves = <Map<String, Object?>>[];

  @override
  bool get canEditSchedule => movable;

  @override
  Future<List<AdminClubEntity>> fetchClubs() {
    if (failLoad) throw Exception('offline');
    return super.fetchClubs();
  }

  @override
  Future<bool> deletePackage(String packageId) async => deletes;

  @override
  Future<void> setOrderVisit(String orderId, {required RecordStatus status}) async {
    visits.add((orderId, status));
  }

  @override
  Future<String> createBooking(AdminBookingRequest request) async {
    bookingsCreated.add(request);
    return 'order-from-db';
  }

  @override
  Future<void> rescheduleOrder({
    required String orderId,
    required String clubId,
    required String hallId,
    required DateTime day,
    required int startMinutes,
    required List<int> headsetsByHour,
    required List<int> consolesByHour,
  }) async {
    moves.add(<String, Object?>{
      'id': orderId,
      'hall': hallId,
      'start': startMinutes,
      'vr': headsetsByHour,
      'ps': consolesByHour,
    });
  }
}

Future<AdminBloc> _start(_Repo repo, {AdminStatus until = AdminStatus.ready}) async {
  final AdminBloc bloc = AdminBloc(repository: repo, autoRefresh: null)
    ..add(const AdminStarted());
  await bloc.stream.firstWhere((AdminState s) => s.status == until);
  return bloc;
}

void main() {
  test('ошибка загрузки — не вечный спиннер, повтор после восстановления связи', () async {
    final _Repo repo = _Repo(failLoad: true);
    final AdminBloc bloc = await _start(repo, until: AdminStatus.failure);
    expect(bloc.state.saveError, isNotNull);

    repo.failLoad = false;
    bloc.add(const AdminStarted());
    await bloc.stream.firstWhere((AdminState s) => s.status == AdminStatus.ready);
    expect(bloc.state.clubs, isNotEmpty);
    await bloc.close();
  });

  test('пакет с бронями не удаляется, а выключается', () async {
    final AdminBloc bloc = await _start(_Repo(deletes: false));
    final PackageEntity pkg =
        bloc.state.packages.firstWhere((PackageEntity p) => p.isEnabled);

    bloc.add(AdminPackageDeleted(pkg.id));
    await bloc.stream.firstWhere((AdminState s) => s.saveNotice != null);

    final PackageEntity kept =
        bloc.state.packages.firstWhere((PackageEntity p) => p.id == pkg.id);
    expect(kept.isEnabled, isFalse);
    // Это не ошибка: пояснение идёт нейтральной плашкой, а не красной.
    expect(bloc.state.saveNotice, contains('выключен'));
    expect(bloc.state.saveError, isNull);
    await bloc.close();
  });

  test('признак переноса берётся из репозитория', () async {
    final AdminBloc movable = await _start(_Repo());
    final AdminBloc fixed = await _start(_Repo(movable: false));
    expect(movable.state.scheduleEditable, isTrue);
    expect(fixed.state.scheduleEditable, isFalse);
    await movable.close();
    await fixed.close();
  });

  test('новая запись уходит на сервер с составом по часам и предоплатой', () async {
    final _Repo repo = _Repo();
    final AdminBloc bloc = await _start(repo);

    bloc.add(const AdminNewBookingOpened());
    await bloc.stream.firstWhere((AdminState s) => s.newBooking != null);
    bloc
      ..add(const AdminNewBookingChanged(dayIndex: 3, startMinutes: 660, durationMinutes: 120))
      ..add(const AdminNewBookingChanged(headsets: 4))
      ..add(const AdminNewBookingChanged(hour: 1, headsets: 2))
      ..add(const AdminNewBookingChanged(name: 'Гость', phone: '+7 900 111', prepay: 2000))
      ..add(const AdminNewBookingSubmitted());
    await bloc.stream.firstWhere((AdminState s) => s.newBooking == null);

    final AdminBookingRequest req = repo.bookingsCreated.single;
    expect(req.startMinutes, 660);
    expect(req.prepay, 2000);
    expect(
      req.hours.map((Map<String, HallUnits> h) => h.values.single.headsets),
      <int>[4, 2],
    );
    final BookingRowEntity added = bloc.state.rowById('order-from-db')!;
    expect(added.source, RecordSource.admin);
    await bloc.close();
  });

  test('визит: «не пришёл» уходит на сервер, у отменённой брони не ставится', () async {
    final _Repo repo = _Repo();
    final AdminBloc bloc = await _start(repo);
    final BookingRowEntity live = bloc.state.rows
        .firstWhere((BookingRowEntity r) => !bloc.state.isCancelled(r.id));

    bloc.add(AdminVisitMarked(live.id, RecordStatus.noShow));
    await bloc.stream.firstWhere(
        (AdminState s) => s.rowById(live.id)!.status == RecordStatus.noShow);
    await Future<void>.delayed(Duration.zero);
    expect(repo.visits, <(String, RecordStatus)>[(live.orderId, RecordStatus.noShow)]);

    bloc.add(AdminRowCancelToggled(live.id));
    await bloc.stream.firstWhere((AdminState s) => s.isCancelled(live.id));
    bloc.add(AdminVisitMarked(live.id, RecordStatus.visited));
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(repo.visits, hasLength(1));
    await bloc.close();
  });

  test('перенос: новое время и состав уходят на сервер', () async {
    final _Repo repo = _Repo();
    final AdminBloc bloc = await _start(repo);
    final BookingRowEntity row = bloc.state.rows.firstWhere(
        (BookingRowEntity r) => !bloc.state.isCancelled(r.id) && !r.variesByHour);

    bloc.add(AdminRowRescheduled(
      rowId: row.id,
      dayIndex: row.dayIndex,
      startMinutes: row.startMinutes + 60,
      headsetsByHour: const <int>[1, 1],
      consolesByHour: const <int>[0, 0],
    ));
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(repo.moves.single['id'], row.orderId);
    expect(repo.moves.single['hall'], row.hallId);
    expect(repo.moves.single['start'], row.startMinutes + 60);
    expect(repo.moves.single['vr'], <int>[1, 1]);
    await bloc.close();
  });

  test('перенос брони в нескольких залах запрещён — места второго зала не теряются',
      () async {
    final _Repo repo = _Repo();
    final AdminBloc bloc = await _start(repo);

    bloc.add(const AdminClubChanged('vray'));
    bloc.add(const AdminNewBookingOpened());
    await bloc.stream.firstWhere((AdminState s) => s.newBooking != null);
    bloc
      ..add(const AdminNewBookingChanged(dayIndex: 3, startMinutes: 720))
      ..add(const AdminNewBookingChanged(hallId: 'v-big', headsets: 4))
      ..add(const AdminNewBookingChanged(hallId: 'v-small', headsets: 2))
      ..add(const AdminNewBookingChanged(name: 'Компания', phone: '+7 900 222'))
      ..add(const AdminNewBookingSubmitted());
    await bloc.stream.firstWhere((AdminState s) => s.newBooking == null);
    final BookingRowEntity part = bloc.state.rows
        .firstWhere((BookingRowEntity r) => r.orderId == 'order-from-db');

    bloc.add(AdminRowRescheduled(
      rowId: part.id,
      dayIndex: part.dayIndex,
      startMinutes: part.startMinutes + 60,
      headsetsByHour: const <int>[1],
      consolesByHour: const <int>[0],
    ));
    await bloc.stream.firstWhere((AdminState s) => s.saveError != null);

    expect(repo.moves, isEmpty);
    expect(bloc.state.saveError, contains('нескольких залах'));
    await bloc.close();
  });
}
