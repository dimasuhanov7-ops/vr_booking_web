import '../entity/package_advice_entity.dart';
import '../entity/package_entity.dart';

/// Сравнивает выбор клиента с пакетами клуба, чтобы клиент не переплачивал.
///
/// Пакет — фиксированная цена за состав на фиксированную длительность, поэтому
/// сравниваются только пакеты той же длительности, что и сеанс.
class PackageAdvisorService {
  /// Создаёт сервис.
  const PackageAdvisorService();

  /// Пакет, по которому считать цену ровно выбранного состава, или `null` —
  /// считать по часам.
  ///
  /// Выбранный клиентом пакет [selected] применяется, если состав совпал.
  /// Иначе берётся самый дешёвый пакет с тем же составом, но только если он
  /// дешевле почасовой суммы [gross]: клиент набрал «6 шлемов» руками и не
  /// заметил карточку пакета — цена всё равно должна быть пакетной.
  PackageEntity? priceFor({
    required List<PackageEntity> packages,
    required PackageEntity? selected,
    required int headsets,
    required int consoles,
    required int minutes,
    required num gross,
  }) {
    bool same(PackageEntity p) =>
        p.minutes == minutes && p.headsets == headsets && p.consoles == consoles;

    if (selected != null && same(selected)) return selected;
    PackageEntity? best;
    for (final PackageEntity p in packages) {
      if (!same(p) || p.price <= 0 || p.price >= gross) continue;
      if (best == null || p.price < best.price) best = p;
    }
    return best;
  }

  /// Пакет с большим составом, который стоит не дороже текущего итога
  /// [currentPrice], или `null`, если такого нет.
  ///
  /// [packages] — только те, что можно взять на выбранное время. Из нескольких
  /// подходящих — с наибольшей экономией, при равной — с меньшим составом.
  PackageAdviceEntity? upgrade({
    required List<PackageEntity> packages,
    required int headsets,
    required int consoles,
    required int minutes,
    required num currentPrice,
  }) {
    final int picked = headsets + consoles;
    if (picked == 0 || currentPrice <= 0) return null;

    PackageAdviceEntity? best;
    for (final PackageEntity p in packages) {
      final bool bigger = p.headsets >= headsets &&
          p.consoles >= consoles &&
          p.stationCount > picked;
      if (!bigger || p.minutes != minutes || p.price <= 0 || p.price > currentPrice) {
        continue;
      }
      final PackageAdviceEntity next = PackageAdviceEntity(
        package: p,
        headsets: headsets,
        consoles: consoles,
        currentPrice: currentPrice,
      );
      final PackageAdviceEntity? cur = best;
      if (cur == null ||
          next.saving > cur.saving ||
          (next.saving == cur.saving &&
              p.stationCount < cur.package.stationCount)) {
        best = next;
      }
    }
    return best;
  }
}
