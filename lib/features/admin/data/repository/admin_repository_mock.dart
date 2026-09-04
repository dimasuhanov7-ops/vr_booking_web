import '../../domain/entity/admin_club_entity.dart';
import '../../domain/entity/booking_row_entity.dart';
import '../../domain/entity/hall_price_entity.dart';
import '../../domain/entity/package_entity.dart';
import '../../domain/repository/i_admin_repository.dart';

/// In-memory данные админки. Повторяют прототип «Админка VR.dc.html»
/// (design/ADMIN_DESIGN_SPEC.md): единый датасет `LOG` вместо грубого `SEED`.
class AdminRepositoryMock implements IAdminRepository {
  /// Создаёт mock.
  const AdminRepositoryMock();

  @override
  Future<List<AdminClubEntity>> fetchClubs() => _delay(const <AdminClubEntity>[
        AdminClubEntity(
          id: 'effect',
          slug: 'effect_vr',
          name: 'Effect VR',
          hoursLabel: '11:00 – 22:30',
          openMinutes: 660,
          closeMinutes: 1350,
          gapMinutes: 10,
          halls: <AdminHallEntity>[
            AdminHallEntity(id: 'e-main', name: 'Зал', headsets: 4, consoles: 2),
          ],
        ),
        AdminClubEntity(
          id: 'vray',
          slug: 'v_ray',
          name: 'V-Ray',
          hoursLabel: '11:00 – 23:00',
          openMinutes: 660,
          closeMinutes: 1380,
          gapMinutes: 0,
          halls: <AdminHallEntity>[
            AdminHallEntity(id: 'v-big', name: 'Большой зал', headsets: 12, consoles: 0),
            AdminHallEntity(id: 'v-small', name: 'Малый зал', headsets: 4, consoles: 2),
          ],
        ),
      ]);

  @override
  Future<List<HallPriceEntity>> fetchPrices() => _delay(const <HallPriceEntity>[
        HallPriceEntity(
            hallId: 'e-main', vrWeekday: 1400, vrWeekend: 1700, ps5Weekday: 1000, ps5Weekend: 1200),
        HallPriceEntity(
            hallId: 'v-big', vrWeekday: 1400, vrWeekend: 1700, ps5Weekday: 1000, ps5Weekend: 1200),
        HallPriceEntity(
            hallId: 'v-small', vrWeekday: 1400, vrWeekend: 1700, ps5Weekday: 1000, ps5Weekend: 1200),
      ]);

  @override
  Future<List<PackageEntity>> fetchPackages() => _delay(const <PackageEntity>[
        PackageEntity(id: 'p1', clubId: 'effect', hallId: 'e-main', name: 'Вдвоём', headsets: 2, consoles: 0, minutes: 120, price: 5000, isEnabled: true),
        PackageEntity(id: 'p2', clubId: 'effect', hallId: 'e-main', name: 'Компания', headsets: 4, consoles: 0, minutes: 120, price: 10000, isEnabled: true),
        PackageEntity(id: 'p3', clubId: 'effect', hallId: 'e-main', name: 'Полный зал', headsets: 4, consoles: 2, minutes: 120, price: 14000, isEnabled: true),
        PackageEntity(id: 'p4', clubId: 'vray', hallId: 'v-big', name: 'Команда', headsets: 6, consoles: 0, minutes: 120, price: 14000, isEnabled: true),
        PackageEntity(id: 'p5', clubId: 'vray', hallId: 'v-big', name: 'Арена', headsets: 12, consoles: 0, minutes: 120, price: 26000, isEnabled: true),
        PackageEntity(id: 'p6', clubId: 'vray', hallId: 'v-small', name: 'Малый зал целиком', headsets: 4, consoles: 2, minutes: 120, price: 14000, isEnabled: true),
        PackageEntity(id: 'p7', clubId: 'vray', hallId: 'v-small', name: 'Шлемы и PS5', headsets: 2, consoles: 2, minutes: 60, price: 4300, isEnabled: true),
      ]);

  @override
  Future<List<BookingRowEntity>> fetchRows() => _delay(<BookingRowEntity>[
        _row('l1', 'vray', 'v-big', 0, 720, 120, 6, 0, 'Игорь', '+7 (912) 344-11-08', 'paid', 'виджет', pack: 'Команда'),
        _row('l2', 'vray', 'v-small', 0, 900, 120, 3, 1, 'Настя', '+7 (903) 771-20-64', 'confirmed', 'виджет'),
        _row('l3', 'vray', 'v-big', 0, 1140, 60, 12, 0, 'Дима', '+7 (999) 208-45-31', 'new', 'звонок'),
        _row('l4', 'vray', 'v-small', 1, 780, 60, 0, 2, 'Кирилл', '+7 (964) 112-90-77', 'confirmed', 'виджет'),
        _row('l5', 'vray', 'v-big', 1, 1020, 120, 12, 0, 'Марина', '+7 (908) 555-31-20', 'paid', 'виджет', pack: 'Арена'),
        _row('l6', 'vray', 'v-small', 2, 660, 60, 4, 2, 'Олег', '+7 (917) 604-18-52', 'new', 'звонок'),
        _row('l7', 'effect', 'e-main', 0, 780, 60, 4, 0, 'Лена', '+7 (905) 613-77-42', 'confirmed', 'виджет'),
        _row('l8', 'effect', 'e-main', 0, 1200, 120, 4, 2, 'Артём', '+7 (962) 480-15-93', 'paid', 'виджет', pack: 'Полный зал'),
        _row('l9', 'effect', 'e-main', 1, 900, 60, 0, 2, 'Соня', '+7 (951) 220-64-09', 'new', 'виджет'),
        _row('l10', 'effect', 'e-main', 2, 1080, 120, 2, 0, 'Паша', '+7 (926) 337-45-11', 'confirmed', 'звонок'),
      ]);

  static BookingRowEntity _row(
    String id,
    String club,
    String hall,
    int day,
    int start,
    int dur,
    int vr,
    int ps5,
    String name,
    String phone,
    String status,
    String src, {
    String? pack,
  }) =>
      BookingRowEntity(
        id: id,
        clubId: club,
        hallId: hall,
        dayIndex: day,
        startMinutes: start,
        durationMinutes: dur,
        headsets: vr,
        consoles: ps5,
        clientName: name,
        phone: phone,
        status: RecordStatus.fromRaw(status),
        source: RecordSource.fromRaw(src),
        packageName: pack,
      );

  Future<T> _delay<T>(T value) =>
      Future<T>.delayed(const Duration(milliseconds: 200), () => value);
}
