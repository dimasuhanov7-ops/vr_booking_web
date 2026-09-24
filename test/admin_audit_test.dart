import 'package:flutter_test/flutter_test.dart';

import 'package:vr_booking_web/features/admin/data/repository/admin_repository_mock.dart';
import 'package:vr_booking_web/features/admin/domain/entity/audit_entry_entity.dart';
import 'package:vr_booking_web/features/admin/domain/service/audit_describer.dart';
import 'package:vr_booking_web/features/admin/domain/state/admin_bloc.dart';

const AuditDescriber _d = AuditDescriber(
  clubNames: <String, String>{'vray': 'V-Ray'},
  hallNames: <String, String>{'v-small': 'Малый зал'},
);

AuditEntryEntity _e(
  String entity,
  String action, {
  Map<String, dynamic>? before,
  Map<String, dynamic>? after,
  String? actorId,
  String? actorName,
}) =>
    AuditEntryEntity(
      id: 1,
      at: DateTime.utc(2026, 9, 24, 10),
      entity: entity,
      action: action,
      actorId: actorId,
      actorName: actorName,
      before: before,
      after: after,
    );

void main() {
  test('цена: было → стало, со ступенью', () {
    final AuditLine l = _d.describe(_e('booking_prices', 'update',
        before: <String, dynamic>{
          'club_id': 'vray', 'station_type': 'vr_headset', 'day_kind': 'weekday',
          'price_per_hour': '800', 'min_qty': 6,
        },
        after: <String, dynamic>{
          'club_id': 'vray', 'station_type': 'vr_headset', 'day_kind': 'weekday',
          'price_per_hour': '700', 'min_qty': 6,
        }));
    expect(l.title, 'Цена · V-Ray');
    expect(l.details, 'VR будни, от 6 шлемов: 800 → 700 ₽/ч');
  });

  test('пакет: перечисляет только изменённое', () {
    final AuditLine l = _d.describe(_e('booking_packages', 'update',
        before: <String, dynamic>{
          'club_id': 'vray', 'name': 'Команда', 'price': 14000, 'headsets': 6,
          'consoles': 0, 'minutes': 120, 'is_active': true,
        },
        after: <String, dynamic>{
          'club_id': 'vray', 'name': 'Команда', 'price': 12000, 'headsets': 6,
          'consoles': 0, 'minutes': 120, 'is_active': false,
        }));
    expect(l.title, 'Пакет «Команда» · V-Ray');
    expect(l.details, 'цена: 14000 → 12000 ₽; выключен');
  });

  test('доступность: зал закрыт и окно открыто', () {
    expect(
      _d.describe(_e('booking_availability', 'insert', after: <String, dynamic>{
        'club_id': 'vray', 'room_id': 'v-small', 'day': null, 'from_minutes': null,
      })).details,
      'зал «Малый зал»',
    );
    final AuditLine open = _d.describe(_e('booking_availability', 'delete',
        before: <String, dynamic>{
          'club_id': 'vray', 'room_id': null, 'day': '2026-09-25',
          'from_minutes': 900, 'to_minutes': 960,
        }));
    expect(open.title, 'Открыто для записи · V-Ray');
    expect(open.details, '25.09, 15:00–16:00');
  });

  test('клуб: пауза приёма; бронь: смена статуса', () {
    expect(
      _d.describe(_e('booking_clubs', 'update',
          before: <String, dynamic>{'id': 'vray', 'name': 'V-Ray', 'intake_open': true},
          after: <String, dynamic>{'id': 'vray', 'name': 'V-Ray', 'intake_open': false})).details,
      'онлайн-запись на паузе',
    );
    expect(
      _d.describe(_e('booking_orders', 'update',
          before: <String, dynamic>{'club_id': 'vray', 'client_name': 'Юля', 'status': 'confirmed'},
          after: <String, dynamic>{'club_id': 'vray', 'client_name': 'Юля', 'status': 'no_show'})).details,
      'статус: подтверждена → не пришёл',
    );
  });

  test('перенос брони: было → стало', () {
    final AuditLine l = _d.describe(_e('booking_reschedule', 'update',
        before: <String, dynamic>{
          'club_id': 'vray', 'client_name': 'Игорь', 'day': '2026-09-25',
          'from': '12:00', 'to': '14:00', 'vr': 6, 'ps': 0,
        },
        after: <String, dynamic>{
          'club_id': 'vray', 'client_name': 'Игорь', 'day': '2026-09-25',
          'from': '13:00', 'to': '15:00', 'vr': 4, 'ps': 1,
        }));
    expect(l.title, 'Бронь перенесена · Игорь · V-Ray');
    expect(l.details, '25.09 12:00–14:00, 6 VR → 25.09 13:00–15:00, 4 VR + 1 PS5');
  });

  test('автор: имя, короткий id или клиент', () {
    expect(AuditDescriber.actorOf(_e('x', 'update', actorId: 'u1', actorName: 'Анна')), 'Анна');
    expect(
      AuditDescriber.actorOf(_e('x', 'update', actorId: '0123456789abcdef')),
      'сотрудник 01234567',
    );
    expect(AuditDescriber.actorOf(_e('x', 'update')), 'клиент или система');
  });

  test('клуб записи: у booking_clubs это её id', () {
    expect(_e('booking_clubs', 'update', after: <String, dynamic>{'id': 'vray'}).clubId, 'vray');
    expect(_e('booking_prices', 'update', after: <String, dynamic>{'club_id': 'effect'}).clubId,
        'effect');
  });

  test('открытие вкладки «Журнал» загружает записи', () async {
    final AdminBloc bloc = AdminBloc(repository: const AdminRepositoryMock())
      ..add(const AdminStarted());
    await bloc.stream.firstWhere((AdminState s) => s.status == AdminStatus.ready);

    bloc.add(const AdminTabChanged(AdminTab.log));
    await bloc.stream.firstWhere((AdminState s) => s.auditEntries.isNotEmpty);

    expect(bloc.state.auditLoading, isFalse);
    expect(bloc.state.clubAuditEntries, isNotEmpty);
    await bloc.close();
  });
}
