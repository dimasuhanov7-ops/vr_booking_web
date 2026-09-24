import 'package:flutter_test/flutter_test.dart';

import 'package:vr_booking_web/features/admin/data/dto/booking_row_dto.dart';
import 'package:vr_booking_web/features/admin/data/repository/admin_repository_mock.dart';
import 'package:vr_booking_web/features/admin/domain/entity/admin_failure.dart';
import 'package:vr_booking_web/features/admin/domain/entity/audit_entry_entity.dart';
import 'package:vr_booking_web/features/admin/domain/entity/booking_row_entity.dart';
import 'package:vr_booking_web/features/admin/domain/entity/hall_price_entity.dart';
import 'package:vr_booking_web/features/admin/domain/entity/package_entity.dart';
import 'package:vr_booking_web/features/admin/domain/entity/promo_entity.dart';
import 'package:vr_booking_web/features/admin/domain/service/admin_pricing_service.dart';
import 'package:vr_booking_web/features/admin/domain/service/audit_describer.dart';
import 'package:vr_booking_web/features/admin/domain/state/admin_bloc.dart';

const AdminPricingService _svc = AdminPricingService();

/// Одинаковая ставка в будни и выходные — итог не зависит от дня запуска.
const HallPriceEntity _flat = HallPriceEntity(
  hallId: 'v-big',
  vrWeekday: 1000,
  vrWeekend: 1000,
  ps5Weekday: 1000,
  ps5Weekend: 1000,
);

const PackageEntity _team = PackageEntity(
  id: 'p4',
  clubId: 'vray',
  hallId: 'v-big',
  name: 'Команда',
  headsets: 6,
  consoles: 0,
  minutes: 120,
  price: 14000,
  isEnabled: true,
);

const PromoEntity _ten =
    PromoEntity(id: 'd1', code: 'VRPARTY', kind: PromoKind.percent, value: 10);
const PromoEntity _minus500 =
    PromoEntity(id: 'd2', code: 'MINUS500', kind: PromoKind.fixed, value: 500);

BookingRowEntity _row({String? pack, int vr = 6, PromoEntity? promo}) =>
    BookingRowEntity(
      id: 'r1',
      clubId: 'vray',
      hallId: 'v-big',
      dayIndex: 0,
      startMinutes: 720,
      durationMinutes: 120,
      headsets: vr,
      consoles: 0,
      clientName: 'Тест',
      phone: '+7',
      status: RecordStatus.confirmed,
      source: RecordSource.widget,
      packageName: pack,
      promo: promo,
    );

/// Демо-данные + управляемые ответы «сервера» по промокодам.
class _Repo extends AdminRepositoryMock {
  _Repo({this.deletes = true, this.failWrites = false});

  final bool deletes;
  final bool failWrites;
  final List<PromoEntity> created = <PromoEntity>[];
  final List<(String, bool)> toggled = <(String, bool)>[];

  @override
  Future<String> createPromo(PromoEntity draft) async {
    if (failWrites) throw const AdminFailure('Промокоды ещё не включены на сервере.');
    created.add(draft);
    return 'srv-${created.length}';
  }

  @override
  Future<void> setPromoActive(String promoId, {required bool active}) async {
    if (failWrites) throw const AdminFailure('Промокоды ещё не включены на сервере.');
    toggled.add((promoId, active));
  }

  @override
  Future<bool> deletePromo(String promoId) async => deletes;
}

Future<AdminBloc> _ready(_Repo repo) async {
  final AdminBloc bloc = AdminBloc(repository: repo)..add(const AdminStarted());
  await bloc.stream.firstWhere((AdminState s) => s.status == AdminStatus.ready);
  return bloc;
}

Future<void> _settle() => Future<void>.delayed(const Duration(milliseconds: 30));

void main() {
  group('скидка промокода', () {
    test('процент округляется до рубля, фиксированная не больше суммы', () {
      expect(_ten.amountOn(6400), 640);
      expect(_ten.amountOn(1005), 101);
      expect(_minus500.amountOn(6400), 500);
      expect(_minus500.amountOn(300), 300);
      expect(_ten.amountOn(0), 0);
      expect(_ten.effectLabel, '−10%');
      expect(_minus500.effectLabel, '−500 ₽');
    });

    test('по часам: промокод вычитается из почасовой суммы', () {
      // 6 шлемов × 2 ч × 1000 ₽ = 12 000.
      expect(_svc.baseCost(row: _row(promo: _ten), price: _flat, packages: const <PackageEntity>[]),
          12000);
      expect(_svc.rowCost(row: _row(promo: _ten), price: _flat, packages: const <PackageEntity>[]),
          10800);
      expect(
          _svc.rowCost(row: _row(promo: _minus500), price: _flat, packages: const <PackageEntity>[]),
          11500);
    });

    test('по пакету: промокод считается от цены пакета', () {
      final BookingRowEntity row = _row(pack: 'Команда', promo: _ten);
      expect(_svc.baseCost(row: row, price: _flat, packages: const <PackageEntity>[_team]), 14000);
      expect(_svc.promoDiscount(row: row, base: 14000), 1400);
      expect(_svc.rowCost(row: row, price: _flat, packages: const <PackageEntity>[_team]), 12600);
    });

    test('без промокода сумма прежняя', () {
      expect(_svc.rowCost(row: _row(), price: _flat, packages: const <PackageEntity>[]), 12000);
    });
  });

  test('DTO: скидка брони из вложенного booking_discounts', () {
    final Map<String, dynamic> order = <String, dynamic>{
      'id': 'o1',
      'club_id': 'c1',
      'client_name': 'Тест',
      'client_phone': '+7 900',
      'status': 'confirmed',
      'source': 'site',
      'discount_id': 'd1',
      'booking_discounts': <String, dynamic>{
        'code': 'VRPARTY', 'title': null, 'kind': 'percent', 'value': '10',
      },
      'booking_order_items': <Map<String, dynamic>>[
        <String, dynamic>{
          'starts_at': '2026-09-10T07:00:00Z',
          'ends_at': '2026-09-10T08:00:00Z',
          'booking_stations': <String, dynamic>{'type': 'vr_headset', 'room_id': 'r'},
        },
      ],
    };
    // Бронь в одном зале — одна запись (в нескольких залах их было бы несколько).
    final BookingRowEntity row = BookingRowDto.fromOrderJson(order,
            today: DateTime(2026, 9, 10), tz: const Duration(hours: 5))
        .single;
    expect(row.promo, isNotNull);
    expect(row.promo!.code, 'VRPARTY');
    expect(row.promo!.kind, PromoKind.percent);
    expect(row.promo!.value, 10);

    // Сотруднику таблица скидок ещё закрыта — PostgREST отдаёт null.
    order['booking_discounts'] = null;
    expect(
      BookingRowDto.fromOrderJson(order,
              today: DateTime(2026, 9, 10), tz: const Duration(hours: 5))
          .single
          .promo,
      isNull,
    );
  });

  group('админка: промокоды', () {
    test('при старте промокоды загружаются', () async {
      final AdminBloc bloc = await _ready(_Repo());
      expect(bloc.state.promos.map((PromoEntity p) => p.code),
          containsAll(<String>['VRPARTY', 'MINUS500']));
      await bloc.close();
    });

    test('новый код: проверки формы, затем сохраняется заглавными', () async {
      final _Repo repo = _Repo();
      final AdminBloc bloc = await _ready(repo);

      bloc
        ..add(const AdminNewPromoChanged(code: 'vrparty'))
        ..add(const AdminNewPromoSubmitted());
      await _settle();
      expect(bloc.state.newPromo.message, contains('уже есть'));
      expect(repo.created, isEmpty);

      bloc
        ..add(const AdminNewPromoChanged(code: 'с пробелом'))
        ..add(const AdminNewPromoSubmitted());
      await _settle();
      expect(bloc.state.newPromo.isError, isTrue);

      bloc
        ..add(const AdminNewPromoChanged(code: 'birthday', value: 150))
        ..add(const AdminNewPromoSubmitted());
      await _settle();
      expect(bloc.state.newPromo.message, contains('от 1 до 100'));

      bloc
        ..add(const AdminNewPromoChanged(value: 20, minStations: 3))
        ..add(const AdminNewPromoSubmitted());
      await _settle();
      expect(repo.created.single.code, 'BIRTHDAY');
      expect(repo.created.single.value, 20);
      expect(repo.created.single.minStations, 3);
      final PromoEntity added =
          bloc.state.promos.firstWhere((PromoEntity p) => p.code == 'BIRTHDAY');
      expect(added.id, 'srv-1');
      expect(bloc.state.newPromo.code, isEmpty, reason: 'форма очищается');
      expect(bloc.state.newPromo.isError, isFalse);
      await bloc.close();
    });

    test('сервер отклонил создание — понятное сообщение, списка не трогаем', () async {
      final AdminBloc bloc = await _ready(_Repo(failWrites: true));
      final int before = bloc.state.promos.length;
      bloc
        ..add(const AdminNewPromoChanged(code: 'NEWCODE'))
        ..add(const AdminNewPromoSubmitted());
      await _settle();
      expect(bloc.state.promos.length, before);
      expect(bloc.state.newPromo.message, contains('не включены'));
      expect(bloc.state.newPromo.submitting, isFalse);
      await bloc.close();
    });

    test('выключение: уходит на сервер; при ошибке возвращается как было', () async {
      final _Repo repo = _Repo();
      final AdminBloc bloc = await _ready(repo);
      bloc.add(const AdminPromoToggled('d1'));
      await _settle();
      expect(repo.toggled.single, ('d1', false));
      expect(bloc.state.promos.firstWhere((PromoEntity p) => p.id == 'd1').isActive, isFalse);
      await bloc.close();

      final AdminBloc failing = await _ready(_Repo(failWrites: true));
      failing.add(const AdminPromoToggled('d1'));
      await _settle();
      expect(failing.state.promos.firstWhere((PromoEntity p) => p.id == 'd1').isActive, isTrue);
      expect(failing.state.saveError, isNotNull);
      await failing.close();
    });

    test('код с бронями не удаляется, а выключается — с пояснением', () async {
      final AdminBloc bloc = await _ready(_Repo(deletes: false));
      bloc.add(const AdminPromoDeleted('d1'));
      await _settle();
      final PromoEntity kept = bloc.state.promos.firstWhere((PromoEntity p) => p.id == 'd1');
      expect(kept.isActive, isFalse);
      expect(bloc.state.saveNotice, contains('выключен'));
      await bloc.close();

      final AdminBloc clean = await _ready(_Repo());
      clean.add(const AdminPromoDeleted('d1'));
      await _settle();
      expect(clean.state.promos.any((PromoEntity p) => p.id == 'd1'), isFalse);
      await clean.close();
    });
  });

  group('журнал: промокоды', () {
    const AuditDescriber d = AuditDescriber();
    AuditEntryEntity e(String action, {Map<String, dynamic>? before, Map<String, dynamic>? after}) =>
        AuditEntryEntity(
          id: 1,
          at: DateTime.utc(2026, 9, 24),
          entity: 'booking_discounts',
          action: action,
          before: before,
          after: after,
        );

    test('новый, изменённый и удалённый код', () {
      final AuditLine created = d.describe(e('insert', after: <String, dynamic>{
        'code': 'VRPARTY', 'kind': 'percent', 'value': 10, 'min_stations': 2, 'active': true,
      }));
      expect(created.title, 'Новый промокод VRPARTY');
      expect(created.details, '−10%, от 2 мест');

      final AuditLine changed = d.describe(e('update',
          before: <String, dynamic>{
            'code': 'VRPARTY', 'kind': 'percent', 'value': 10, 'min_stations': 2, 'active': true,
          },
          after: <String, dynamic>{
            'code': 'VRPARTY', 'kind': 'fixed', 'value': 500, 'min_stations': 2, 'active': false,
          }));
      expect(changed.title, 'Промокод VRPARTY');
      expect(changed.details, 'скидка: −10% → −500 ₽; выключен');

      expect(
        d.describe(e('delete', before: <String, dynamic>{'code': 'OLD'})).title,
        'Промокод OLD удалён',
      );
    });

    test('у промокода нет клуба — запись видна в журнале любого клуба', () {
      expect(e('insert', after: <String, dynamic>{'code': 'X'}).clubId, isNull);
    });
  });
}
