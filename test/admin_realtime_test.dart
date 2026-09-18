import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:vr_booking_web/features/admin/data/repository/admin_repository_mock.dart';
import 'package:vr_booking_web/features/admin/domain/entity/availability_entity.dart';
import 'package:vr_booking_web/features/admin/domain/entity/booking_row_entity.dart';
import 'package:vr_booking_web/features/admin/domain/state/admin_bloc.dart';

/// Демо-репозиторий с управляемым потоком изменений и счётчиками чтений.
class _LiveRepository extends AdminRepositoryMock {
  _LiveRepository();

  final StreamController<void> changes = StreamController<void>.broadcast();
  int rowFetches = 0;
  int availabilityFetches = 0;

  @override
  Stream<void> watchChanges() => changes.stream;

  @override
  Future<List<BookingRowEntity>> fetchRows() {
    rowFetches++;
    return super.fetchRows();
  }

  @override
  Future<AvailabilityEntity> fetchAvailability() {
    availabilityFetches++;
    return super.fetchAvailability();
  }
}

Future<AdminBloc> _ready(_LiveRepository repo) async {
  final AdminBloc bloc = AdminBloc(repository: repo, autoRefresh: null)
    ..add(const AdminStarted());
  await bloc.stream.firstWhere((AdminState s) => s.status == AdminStatus.ready);
  return bloc;
}

/// Дождаться, пока склеенное обновление (700 мс) и само чтение закончатся.
Future<void> _settle() => Future<void>.delayed(const Duration(milliseconds: 1500));

void main() {
  test('изменение в базе — данные перечитываются сами, пачка событий — один раз', () async {
    final _LiveRepository repo = _LiveRepository();
    final AdminBloc bloc = await _ready(repo);
    expect(repo.rowFetches, 1, reason: 'первая загрузка');

    // Новая бронь с сайта: заказ и три его места — четыре события подряд.
    for (int i = 0; i < 4; i++) {
      repo.changes.add(null);
    }
    await _settle();

    expect(repo.rowFetches, 2, reason: 'события склеены в одно обновление');
    await bloc.close();
  });

  test('своё закрытие времени сразу перечитывает закрытия для «Записей»', () async {
    final _LiveRepository repo = _LiveRepository();
    final AdminBloc bloc = await _ready(repo);
    expect(repo.availabilityFetches, 1);

    bloc.add(AdminSlotClosureToggled(bloc.state.slotStarts.first));
    await _settle();

    expect(repo.availabilityFetches, 2);
    await bloc.close();
  });

  test('закрытый экран отписывается от изменений', () async {
    final _LiveRepository repo = _LiveRepository();
    final AdminBloc bloc = await _ready(repo);
    expect(repo.changes.hasListener, isTrue);

    await bloc.close();
    expect(repo.changes.hasListener, isFalse);
  });
}
