import 'package:flutter_test/flutter_test.dart';

import 'package:vr_booking_web/features/admin/data/repository/admin_repository_mock.dart';
import 'package:vr_booking_web/features/admin/domain/entity/hall_price_entity.dart';
import 'package:vr_booking_web/features/admin/domain/state/admin_bloc.dart';

/// Демо-данные + журнал сохранений цен.
class _Repo extends AdminRepositoryMock {
  final List<String> log = <String>[];

  @override
  Future<void> saveClubPrice({
    required String clubId,
    required PriceField field,
    required int value,
  }) async =>
      log.add('club:$clubId:${field.name}=$value');

  @override
  Future<void> saveHallPrice({
    required String hallId,
    required PriceField field,
    required int value,
  }) async =>
      log.add('hall:$hallId:${field.name}=$value');

  @override
  Future<void> setHallPricesCustom({
    required String hallId,
    required bool custom,
    required HallPriceEntity price,
    required bool consoles,
  }) async =>
      log.add('custom:$hallId:$custom:ps=$consoles:vr=${price.vrWeekday}');
}

Future<AdminBloc> _vray(_Repo repo) async {
  final AdminBloc bloc = AdminBloc(
    repository: repo,
    autoRefresh: null,
    saveDelay: const Duration(milliseconds: 10),
  )..add(const AdminStarted());
  await bloc.stream.firstWhere((AdminState s) => s.status == AdminStatus.ready);
  // Клуб по умолчанию — V-Ray (Большой и Малый залы).
  expect(bloc.state.clubId, 'vray');
  return bloc;
}

Future<void> _settle() => Future<void>.delayed(const Duration(milliseconds: 60));

void main() {
  test('своя цена малого зала: включение копирует цены клуба, правки идут в зал',
      () async {
    final _Repo repo = _Repo();
    final AdminBloc bloc = await _vray(repo);
    final int clubVr = bloc.state.priceOf('v-big').vrWeekday;

    bloc.add(const AdminHallPricesCustomToggled('v-small'));
    await _settle();
    expect(bloc.state.priceOf('v-small').custom, isTrue);
    expect(bloc.state.priceOf('v-small').vrWeekday, clubVr);
    expect(repo.log.last, 'custom:v-small:true:ps=true:vr=$clubVr');

    bloc.add(const AdminPriceChanged(
        hallId: 'v-small', field: PriceField.vrWeekday, value: 500));
    bloc.add(const AdminPriceChanged(
        hallId: 'v-small', field: PriceField.ps5Weekday, value: 250));
    await _settle();

    expect(bloc.state.priceOf('v-small').vrWeekday, 500);
    expect(bloc.state.priceOf('v-small').ps5Weekday, 250);
    // Большой зал и клубный тариф не тронуты.
    expect(bloc.state.priceOf('v-big').vrWeekday, clubVr);
    expect(repo.log, contains('hall:v-small:vrWeekday=500'));
    expect(repo.log, contains('hall:v-small:ps5Weekday=250'));
    expect(repo.log.where((String l) => l.startsWith('club:')), isEmpty);
    await bloc.close();
  });

  test('клубный тариф и ступени не меняют зал со своей ценой', () async {
    final _Repo repo = _Repo();
    final AdminBloc bloc = await _vray(repo);
    bloc.add(const AdminHallPricesCustomToggled('v-small'));
    bloc.add(const AdminPriceChanged(
        hallId: 'v-small', field: PriceField.vrWeekday, value: 500));
    await _settle();

    bloc.add(const AdminPriceChanged(
        hallId: 'v-big', field: PriceField.vrWeekday, value: 900));
    bloc.add(const AdminVrTiersChanged(<VrTierEntity>[
      VrTierEntity(from: 6, weekday: 700, weekend: 1100),
    ]));
    await _settle();

    expect(bloc.state.priceOf('v-big').vrWeekday, 900);
    expect(bloc.state.priceOf('v-big').vrTiers, hasLength(1));
    expect(bloc.state.priceOf('v-small').vrWeekday, 500);
    expect(bloc.state.priceOf('v-small').vrTiers, isEmpty);
    expect(repo.log, contains('club:vray:vrWeekday=900'));
    await bloc.close();
  });

  test('выключение возвращает зал к тарифу клуба', () async {
    final _Repo repo = _Repo();
    final AdminBloc bloc = await _vray(repo);
    bloc.add(const AdminHallPricesCustomToggled('v-small'));
    bloc.add(const AdminPriceChanged(
        hallId: 'v-small', field: PriceField.vrWeekday, value: 500));
    await _settle();

    bloc.add(const AdminHallPricesCustomToggled('v-small'));
    await _settle();
    expect(bloc.state.priceOf('v-small').custom, isFalse);
    expect(bloc.state.priceOf('v-small').vrWeekday,
        bloc.state.priceOf('v-big').vrWeekday);
    expect(repo.log.last, startsWith('custom:v-small:false'));
    await bloc.close();
  });
}
