import 'package:flutter_test/flutter_test.dart';

import 'package:vr_booking_web/app/embed/launch_params.dart';
import 'package:vr_booking_web/features/booking/data/dto/club_dto.dart';
import 'package:vr_booking_web/features/booking/data/repository/booking_repository_mock.dart';
import 'package:vr_booking_web/features/booking/domain/entity/club_entity.dart';
import 'package:vr_booking_web/features/booking/domain/entity/reservation_request_entity.dart';
import 'package:vr_booking_web/features/booking/domain/state/booking_bloc.dart';
import 'package:vr_booking_web/features/booking/presentation/booking_calendar.dart';

/// Демо-данные + что ушло на сервер и что «сервер» насчитал.
class _Repo extends BookingRepositoryMock {
  _Repo({this.total});

  final num? total;
  ReservationRequestEntity? sent;

  @override
  Future<String> createReservation(ReservationRequestEntity request) {
    sent = request;
    return super.createReservation(request);
  }

  @override
  Future<num?> fetchOrderTotal({
    required String orderId,
    required String clientPhone,
  }) async =>
      total;
}

DateTime _dayAhead() {
  final DateTime d = DateTime.now().add(const Duration(days: 9));
  return DateTime(d.year, d.month, d.day);
}

/// Effect VR, первый слот дня; по умолчанию сеанс на 2 часа.
Future<BookingBloc> _ready(_Repo repo, {int minutes = 120}) async {
  final BookingBloc bloc = BookingBloc(
    repository: repo,
    lockedClubSlug: 'effect_vr',
    initialDate: _dayAhead(),
    initialDurationMinutes: minutes,
    utm: const <String, String>{'utm_source': 'yandex', 'utm_medium': 'cpc'},
  )..add(const BookingStarted());
  await bloc.stream.firstWhere((BookingState s) => s.slots.isNotEmpty);
  bloc.add(BookingSlotSelected(bloc.state.slots.first));
  await bloc.stream.firstWhere((BookingState s) => s.slot != null);
  return bloc;
}

void main() {
  group('настройки клуба из базы', () {
    test('длительности, окно записи и политика читаются из строки клуба', () {
      final ClubEntity c = ClubDto.fromJson(<String, dynamic>{
        'id': 'c',
        'slug': 'v_ray',
        'name': 'V-Ray',
        'lead_minutes': 15,
        'horizon_days': 60,
        'durations': <int>[180, 60, 90, 60],
        'privacy_url': 'https://vrayarena.ru/privacy',
      }).toEntity();
      expect(c.leadMinutes, 15);
      expect(c.horizonDays, 60);
      // 90 — не кратно часу, повтор убран, по возрастанию.
      expect(c.durations, <int>[60, 180]);
      expect(c.privacyUrl, 'https://vrayarena.ru/privacy');
      expect(c.nearestDuration(120), 60);
      expect(c.nearestDuration(240), 180);
    });

    test('без новых колонок — прежние значения', () {
      final ClubEntity c = ClubDto.fromJson(<String, dynamic>{
        'id': 'c',
        'slug': 'v_ray',
        'name': 'V-Ray',
        'privacy_url': 'javascript:alert(1)',
      }).toEntity();
      expect(c.leadMinutes, 30);
      expect(c.horizonDays, 30);
      expect(c.durations, ClubEntity.defaultDurations);
      expect(c.privacyUrl, isNull);
    });
  });

  test('UTM: только известные ключи, не длиннее 100 символов', () {
    final Map<String, String> utm = LaunchParams.utmFrom(<String, String>{
      'utm_source': ' yandex ',
      'utm_campaign': 'x' * 150,
      'utm_term': '',
      'gclid': 'abc',
    });
    expect(utm.keys, <String>['utm_source', 'utm_campaign']);
    expect(utm['utm_source'], 'yandex');
    expect(utm['utm_campaign']!.length, 100);
  });

  test('сеанс на 2 часа выбирается одним планом, по часам — по переключателю',
      () async {
    final BookingBloc bloc = await _ready(_Repo());
    expect(bloc.state.multiHour, isTrue);
    expect(bloc.state.showHourPlan, isFalse);

    bloc.add(const BookingQuickPicked(3));
    await bloc.stream.firstWhere((BookingState s) => s.pickedIds.length == 3);
    expect(bloc.state.pickedAt(1), bloc.state.pickedAt(0));

    bloc.add(const BookingPerHourToggled());
    await bloc.stream.firstWhere((BookingState s) => s.showHourPlan);
    bloc.add(const BookingQuickPicked(1, hour: 1));
    await bloc.stream.firstWhere((BookingState s) => s.pickedCountAt(1) == 1);
    expect(bloc.state.hasHourOverrides, isTrue);

    // Выключили — снова один состав на весь сеанс, как в первом часе.
    bloc.add(const BookingPerHourToggled());
    await bloc.stream.firstWhere((BookingState s) => !s.showHourPlan);
    expect(bloc.state.pickedCountAt(1), 3);
    await bloc.close();
  });

  test('в бронь уходят пожелания и UTM, в чеке — сумма сервера', () async {
    final _Repo repo = _Repo(total: 1234);
    final BookingBloc bloc = await _ready(repo, minutes: 60);
    bloc
      ..add(const BookingQuickPicked(1))
      ..add(const BookingContactChanged(
        name: 'Гость',
        phone: '+7 900 111-22-33',
        comment: '  день рождения, 10 лет  ',
      ))
      ..add(const BookingSubmitted());
    await bloc.stream.firstWhere((BookingState s) => s.createdOrderId != null);

    expect(repo.sent!.comment, 'день рождения, 10 лет');
    expect(repo.sent!.utm, <String, String>{'utm_source': 'yandex', 'utm_medium': 'cpc'});
    expect(bloc.state.confirmedNet, 1234);
    await bloc.close();
  });

  test('календарь: время в UTC, текст экранирован, напоминание за 2 часа', () {
    final BookingCalendarEvent e = BookingCalendarEvent(
      uid: 'ord-1',
      title: 'VR · V-Ray',
      details: 'Бронь VR-1A2B3C; 2 места, оплата на месте',
      location: 'V-Ray',
      startsAtUtc: DateTime.utc(2026, 10, 14, 7),
      endsAtUtc: DateTime.utc(2026, 10, 14, 9),
    );
    expect(e.ics, contains('DTSTART:20261014T070000Z'));
    expect(e.ics, contains(r'DESCRIPTION:Бронь VR-1A2B3C\; 2 места\, оплата на месте'));
    expect(e.ics, contains('TRIGGER:-PT2H'));
    expect(e.googleUrl, contains('dates=20261014T070000Z%2F20261014T090000Z'));
  });

  test('имя из профиля ВК подставляется в форму', () async {
    final BookingBloc bloc = BookingBloc(
      repository: _Repo(),
      lockedClubSlug: 'effect_vr',
      initialName: '  Анна ',
    );
    expect(bloc.state.clientName, 'Анна');
    await bloc.close();
  });
}
