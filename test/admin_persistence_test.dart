import 'package:flutter_test/flutter_test.dart';

import 'package:vr_booking_web/features/admin/data/repository/admin_repository_mock.dart';
import 'package:vr_booking_web/features/admin/domain/entity/admin_club_entity.dart';
import 'package:vr_booking_web/features/admin/domain/entity/booking_row_entity.dart';
import 'package:vr_booking_web/features/admin/domain/entity/package_entity.dart';
import 'package:vr_booking_web/features/admin/domain/state/admin_bloc.dart';

/// Демо-данные, но с управляемыми ответами «сервера» и журналом вызовов.
class _Repo extends AdminRepositoryMock {
  _Repo({
    this.staff = true,
    this.failLoad = false,
    this.deletes = true,
  });

  final bool staff;
  bool failLoad;
  final bool deletes;

  final List<Map<String, Object?>> detailsSaved = <Map<String, Object?>>[];
  final List<Map<String, Object?>> bookingsCreated = <Map<String, Object?>>[];
  final List<(String, RecordStatus)> visits = <(String, RecordStatus)>[];

  @override
  Future<void> setOrderVisit(String orderId, {required RecordStatus status}) async {
    visits.add((orderId, status));
  }

  @override
  Future<bool> isStaff() async => staff;

  /// Как боевой репозиторий: позиции брони сотруднику только читаются.
  @override
  bool get canEditSchedule => false;

  @override
  Future<List<AdminClubEntity>> fetchClubs() {
    if (failLoad) throw Exception('offline');
    return super.fetchClubs();
  }

  @override
  Future<bool> deletePackage(String packageId) async => deletes;

  @override
  Future<void> updateOrderDetails({
    required String orderId,
    required String clientName,
    required String phone,
    required int prepay,
    required String note,
  }) async {
    detailsSaved.add(<String, Object?>{
      'id': orderId,
      'name': clientName,
      'phone': phone,
      'prepay': prepay,
      'note': note,
    });
  }

  @override
  Future<String> createBooking({
    required String clubId,
    required String hallId,
    required DateTime day,
    required int startMinutes,
    required List<int> headsetsByHour,
    required List<int> consolesByHour,
    required String clientName,
    required String phone,
    required String note,
  }) async {
    bookingsCreated.add(<String, Object?>{
      'club': clubId,
      'hall': hallId,
      'start': startMinutes,
      'vr': headsetsByHour,
      'ps': consolesByHour,
      'name': clientName,
    });
    return 'order-from-db';
  }
}

Future<AdminBloc> _start(_Repo repo, {AdminStatus until = AdminStatus.ready}) async {
  final AdminBloc bloc = AdminBloc(repository: repo)..add(const AdminStarted());
  await bloc.stream.firstWhere((AdminState s) => s.status == until);
  return bloc;
}

void main() {
  test('не сотрудник — экран ошибки с выходом, без «Повторить»', () async {
    final AdminBloc bloc = await _start(_Repo(staff: false), until: AdminStatus.error);
    expect(bloc.state.loadError, contains('не подключён к админке'));
    expect(bloc.state.loadNeedsReauth, isTrue);
    await bloc.close();
  });

  test('ошибка загрузки — не вечный спиннер, повтор после восстановления связи', () async {
    final _Repo repo = _Repo(failLoad: true);
    final AdminBloc bloc = await _start(repo, until: AdminStatus.error);
    expect(bloc.state.loadNeedsReauth, isFalse);

    repo.failLoad = false;
    bloc.add(const AdminStarted());
    await bloc.stream.firstWhere((AdminState s) => s.status == AdminStatus.ready);
    expect(bloc.state.clubs, isNotEmpty);
    await bloc.close();
  });

  test('пакет с бронями не удаляется, а выключается', () async {
    final AdminBloc bloc = await _start(_Repo(deletes: false));
    final PackageEntity pkg = bloc.state.packages.firstWhere((PackageEntity p) => p.isEnabled);

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

  test('карточка брони: «Сохранить» пишет контакты и предоплату на сервер', () async {
    final _Repo repo = _Repo();
    final AdminBloc bloc = await _start(repo);
    final BookingRowEntity row = bloc.state.rows.first;

    bloc
      ..add(AdminRowEdited(rowId: row.id, clientName: 'Новое Имя', prepay: 1500))
      ..add(AdminRowSaved(row.id));
    await bloc.stream.firstWhere(
        (AdminState s) => !s.isEdited(row.id) && repo.detailsSaved.isNotEmpty);

    expect(repo.detailsSaved.single['id'], row.id);
    expect(repo.detailsSaved.single['name'], 'Новое Имя');
    expect(repo.detailsSaved.single['prepay'], 1500);
    expect(bloc.state.rowById(row.id)!.clientName, 'Новое Имя');
    await bloc.close();
  });

  test('боевая сборка: время и состав брони не правятся', () async {
    final AdminBloc bloc = await _start(_Repo());
    expect(bloc.state.scheduleEditable, isFalse);
    final BookingRowEntity row = bloc.state.rows.first;

    bloc.add(AdminRowEdited(
      rowId: row.id,
      clientName: 'Имя',
      startMinutes: row.startMinutes + 60,
      headsets: row.headsets + 1,
    ));
    await bloc.stream.firstWhere((AdminState s) => s.isEdited(row.id));

    final BookingRowEntity edited = bloc.state.rowById(row.id)!;
    expect(edited.clientName, 'Имя');
    expect(edited.startMinutes, row.startMinutes);
    expect(edited.headsets, row.headsets);
    await bloc.close();
  });

  test('новая запись уходит на сервер с составом по часам и получает id из БД', () async {
    final _Repo repo = _Repo();
    final AdminBloc bloc = await _start(repo);

    bloc.add(const AdminNewBookingOpened());
    await bloc.stream.firstWhere((AdminState s) => s.newBooking != null);
    bloc
      ..add(const AdminNewBookingChanged(dayIndex: 3, startMinutes: 660, durationMinutes: 120))
      ..add(const AdminNewBookingChanged(headsets: 4))
      ..add(const AdminNewBookingChanged(hour: 1, headsets: 2))
      ..add(const AdminNewBookingChanged(name: 'Гость', prepay: 2000))
      ..add(const AdminNewBookingSubmitted());
    await bloc.stream.firstWhere((AdminState s) => s.openRowId == 'order-from-db');

    expect(repo.bookingsCreated.single['vr'], <int>[4, 2]);
    expect(repo.bookingsCreated.single['start'], 660);
    final BookingRowEntity added = bloc.state.rowById('order-from-db')!;
    expect(added.source, RecordSource.admin);

    // Предоплата — отдельной записью после создания брони (state при успехе
    // не меняется, поэтому просто даём обработчику доработать).
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(repo.detailsSaved.single['id'], 'order-from-db');
    expect(repo.detailsSaved.single['prepay'], 2000);
    await bloc.close();
  });

  test('визит: «не пришёл» уходит на сервер, у отменённой брони не ставится', () async {
    final _Repo repo = _Repo();
    final AdminBloc bloc = await _start(repo);
    final List<BookingRowEntity> rows = bloc.state.rows;
    final BookingRowEntity live =
        rows.firstWhere((BookingRowEntity r) => !bloc.state.isCancelled(r.id));

    bloc.add(AdminVisitMarked(live.id, RecordStatus.noShow));
    await bloc.stream.firstWhere(
        (AdminState s) => s.rowById(live.id)!.status == RecordStatus.noShow);
    await Future<void>.delayed(Duration.zero);
    expect(repo.visits, <(String, RecordStatus)>[(live.id, RecordStatus.noShow)]);

    bloc.add(AdminRowCancelToggled(live.id));
    await bloc.stream.firstWhere((AdminState s) => s.isCancelled(live.id));
    bloc.add(AdminVisitMarked(live.id, RecordStatus.visited));
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(repo.visits, hasLength(1));
    await bloc.close();
  });
}
