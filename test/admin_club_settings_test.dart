import 'package:flutter_test/flutter_test.dart';

import 'package:vr_booking_web/features/admin/data/repository/admin_repository_mock.dart';
import 'package:vr_booking_web/features/admin/domain/entity/admin_club_entity.dart';
import 'package:vr_booking_web/features/admin/domain/state/admin_bloc.dart';

/// Демо-данные + что ушло в базу.
class _Repo extends AdminRepositoryMock {
  final List<AdminClubEntity> saved = <AdminClubEntity>[];

  @override
  Future<void> saveClubSettings(AdminClubEntity club) async => saved.add(club);
}

Future<AdminBloc> _start(_Repo repo) async {
  final AdminBloc bloc = AdminBloc(
    repository: repo,
    autoRefresh: null,
    saveDelay: const Duration(milliseconds: 10),
  )..add(const AdminStarted());
  await bloc.stream.firstWhere((AdminState s) => s.status == AdminStatus.ready);
  return bloc;
}

Future<void> _settle() => Future<void>.delayed(const Duration(milliseconds: 60));

void main() {
  test('длительности клиента: включить 6 ч, пакеты и запись сотрудника следуют', () async {
    final _Repo repo = _Repo();
    final AdminBloc bloc = await _start(repo);

    bloc.add(const AdminClubSettingsChanged(toggleDuration: 360));
    bloc.add(const AdminClubSettingsChanged(toggleDuration: 300));
    await _settle();

    expect(bloc.state.clientDurations, <int>[60, 120, 180, 240, 360]);
    // Сотрудник может записать и на 5 часов, хотя клиенту их больше не видно.
    expect(bloc.state.staffDurations, <int>[60, 120, 180, 240, 300, 360]);
    // Два изменения подряд — одно сохранение с итоговым набором.
    expect(repo.saved, hasLength(1));
    expect(repo.saved.single.durations, <int>[60, 120, 180, 240, 360]);
    await bloc.close();
  });

  test('последнюю длительность выключить нельзя', () async {
    final _Repo repo = _Repo();
    final AdminBloc bloc = await _start(repo);
    for (final int m in <int>[120, 180, 240, 300]) {
      bloc.add(AdminClubSettingsChanged(toggleDuration: m));
    }
    await _settle();
    bloc.add(const AdminClubSettingsChanged(toggleDuration: 60));
    await _settle();

    expect(bloc.state.clientDurations, <int>[60]);
    expect(bloc.state.saveError, contains('хотя бы одну'));
    await bloc.close();
  });

  test('ссылка на политику: недописанная не сохраняется, полная — сохраняется',
      () async {
    final _Repo repo = _Repo();
    final AdminBloc bloc = await _start(repo);

    bloc.add(const AdminClubSettingsChanged(privacyUrl: 'https://'));
    await _settle();
    bloc.add(const AdminClubSettingsChanged(privacyUrl: 'effectvr.ru/privacy'));
    await _settle();
    expect(repo.saved, isEmpty);

    bloc.add(const AdminClubSettingsChanged(
      privacyUrl: 'https://effectvr.ru/privacy',
      leadMinutes: 15,
      horizonDays: 60,
    ));
    await _settle();
    final AdminClubEntity last = repo.saved.single;
    expect(last.privacyUrl, 'https://effectvr.ru/privacy');
    expect(last.leadMinutes, 15);
    expect(last.horizonDays, 60);
    await bloc.close();
  });

  test('проверка ссылки', () {
    expect(AdminClubEntity.isValidPrivacyUrl(''), isTrue);
    expect(AdminClubEntity.isValidPrivacyUrl('https://vrayarena.ru/privacy'), isTrue);
    expect(AdminClubEntity.isValidPrivacyUrl('vrayarena.ru/privacy'), isFalse);
    expect(AdminClubEntity.isValidPrivacyUrl('javascript:alert(1)'), isFalse);
    expect(AdminClubEntity.isValidPrivacyUrl('https://a b.ru'), isFalse);
  });
}
