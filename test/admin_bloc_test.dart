import 'package:flutter_test/flutter_test.dart';

import 'package:vr_booking_web/features/admin/data/repository/admin_repository_mock.dart';
import 'package:vr_booking_web/features/admin/domain/entity/booking_row_entity.dart';
import 'package:vr_booking_web/features/admin/domain/entity/hall_price_entity.dart';
import 'package:vr_booking_web/features/admin/domain/entity/package_entity.dart';
import 'package:vr_booking_web/features/admin/domain/state/admin_bloc.dart';

/// Демо-репозиторий, который запоминает, что ушло «на сервер».
class _SpyRepository extends AdminRepositoryMock {
  _SpyRepository();

  final List<int> savedPrices = <int>[];
  final List<PackageEntity> savedPackages = <PackageEntity>[];
  final List<({String orderId, String name, int prepay})> savedOrders =
      <({String orderId, String name, int prepay})>[];

  @override
  Future<void> saveClubPrice({
    required String clubId,
    required PriceField field,
    required int value,
  }) async =>
      savedPrices.add(value);

  @override
  Future<void> updatePackage(PackageEntity package) async =>
      savedPackages.add(package);

  @override
  Future<void> updateOrderDetails({
    required String orderId,
    required String clientName,
    required String phone,
    required String note,
    required int prepay,
  }) async =>
      savedOrders.add((orderId: orderId, name: clientName, prepay: prepay));
}

const Duration _delay = Duration(milliseconds: 40);

Future<AdminBloc> _ready([AdminRepositoryMock? repo]) async {
  final AdminBloc bloc = AdminBloc(
    repository: repo ?? const AdminRepositoryMock(),
    autoRefresh: null,
    saveDelay: _delay,
  )..add(const AdminStarted());
  await bloc.stream.firstWhere((AdminState s) => s.status == AdminStatus.ready);
  return bloc;
}

Future<void> _afterSave() =>
    Future<void>.delayed(_delay * 4);

void main() {
  test('старт: клуб по умолчанию, вкладка «Записи», день = сегодня', () async {
    final AdminBloc bloc = await _ready();
    expect(bloc.state.tab, AdminTab.records);
    expect(AdminTab.values.first, AdminTab.records);
    expect(bloc.state.clubId, 'vray');
    expect(bloc.state.filterDay, 0); // после обновления страницы — сегодня
    expect(bloc.state.rows.length, greaterThan(10));
    expect(bloc.state.refreshedAt, isNotNull);
    await bloc.close();
  });

  test('новая бронь: открытие → правка → создание добавляет запись и открывает её',
      () async {
    final AdminBloc bloc = await _ready();

    bloc.add(const AdminNewBookingOpened());
    await bloc.stream.firstWhere((AdminState s) => s.newBooking != null);
    expect(bloc.state.newBooking!.units, isNotEmpty);

    bloc
      ..add(const AdminNewBookingChanged(dayIndex: 2, startMinutes: 660, durationMinutes: 120))
      ..add(const AdminNewBookingChanged(headsets: 3))
      ..add(const AdminNewBookingChanged(name: 'Тестовый гость', phone: '+7 900 111'));
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
    expect(added.headsets, 3);
    expect(added.orderId, added.id, reason: 'бронь в одном зале — одна строка');
    expect(bloc.state.openRowId, added.id);
    await bloc.close();
  });

  test('новая бронь сразу в двух залах: строка на зал, один заказ, правка и отмена целиком',
      () async {
    final _SpyRepository repo = _SpyRepository();
    final AdminBloc bloc = await _ready(repo);
    bloc.add(const AdminNewBookingOpened());
    await bloc.stream.firstWhere((AdminState s) => s.newBooking != null);

    bloc
      ..add(const AdminNewBookingChanged(dayIndex: 3, startMinutes: 720))
      ..add(const AdminNewBookingChanged(hallId: 'v-big', headsets: 4))
      ..add(const AdminNewBookingChanged(hallId: 'v-small', headsets: 2, consoles: 1))
      ..add(const AdminNewBookingChanged(name: 'Компания'));
    await bloc.stream.firstWhere((AdminState s) => s.newBooking?.name == 'Компания');
    expect(bloc.state.newBooking!.totalAt(0), 7);

    final int before = bloc.state.rows.length;
    bloc.add(const AdminNewBookingSubmitted());
    await bloc.stream.firstWhere((AdminState s) => s.newBooking == null);

    final List<BookingRowEntity> added = bloc.state.rows.sublist(before);
    expect(added, hasLength(2));
    expect(added.map((BookingRowEntity r) => r.hallId), <String>['v-big', 'v-small']);
    expect(added[0].headsets, 4);
    expect(added[1].headsets, 2);
    expect(added[1].consoles, 1);
    expect(added[0].orderId, added[1].orderId);
    expect(added[0].id, isNot(added[1].id));

    // Контакты и предоплата — у заказа: меняются в обеих строках, в базу — одним
    // запросом на заказ.
    bloc.add(AdminRowEdited(rowId: added[1].id, clientName: 'Компания Димы', prepay: 2000));
    await _afterSave();
    expect(bloc.state.rowById(added[0].id)!.clientName, 'Компания Димы');
    expect(bloc.state.rowById(added[0].id)!.prepay, 2000);
    expect(repo.savedOrders, hasLength(1));
    expect(repo.savedOrders.single.orderId, added[0].orderId);

    // Отмена одной строки снимает всю бронь — в базе это один заказ.
    bloc.add(AdminRowCancelToggled(added[1].id));
    await bloc.stream.firstWhere((AdminState s) => s.isCancelled(added[0].id));
    expect(bloc.state.isCancelled(added[1].id), isTrue);
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

  test('правка брони: слишком короткое имя не уходит в базу', () async {
    final _SpyRepository repo = _SpyRepository();
    final AdminBloc bloc = await _ready(repo);
    final String id = bloc.state.rows.first.id;

    bloc.add(AdminRowEdited(rowId: id, clientName: 'Я'));
    await _afterSave();
    expect(bloc.state.rowById(id)!.clientName, 'Я', reason: 'на экране видно');
    expect(repo.savedOrders, isEmpty, reason: 'но база такое не примет');
    await bloc.close();
  });

  test('цена: набор «1200» сохраняется один раз, а не на каждую цифру', () async {
    final _SpyRepository repo = _SpyRepository();
    final AdminBloc bloc = await _ready(repo);

    for (final int v in <int>[1, 12, 120, 1200]) {
      bloc.add(AdminPriceChanged(hallId: 'v-big', field: PriceField.vrWeekday, value: v));
    }
    await _afterSave();

    expect(repo.savedPrices, <int>[1200]);
    expect(bloc.state.priceOf('v-small').vrWeekday, 1200,
        reason: 'цена клубная — видна во всех залах');
    await bloc.close();
  });

  test('пакет: недопустимая длительность не отправляется', () async {
    final _SpyRepository repo = _SpyRepository();
    final AdminBloc bloc = await _ready(repo);
    final PackageEntity pack = bloc.state.clubPackages.first;

    bloc.add(AdminPackageFieldChanged(
        packageId: pack.id, field: PackageField.minutes, value: 90));
    await _afterSave();
    final PackageEntity edited =
        bloc.state.packages.firstWhere((PackageEntity p) => p.id == pack.id);
    expect(bloc.packageProblem(edited), isNotNull);
    expect(repo.savedPackages, isEmpty);

    bloc.add(AdminPackageFieldChanged(
        packageId: pack.id, field: PackageField.minutes, value: 180));
    await _afterSave();
    expect(repo.savedPackages.single.minutes, 180);
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
