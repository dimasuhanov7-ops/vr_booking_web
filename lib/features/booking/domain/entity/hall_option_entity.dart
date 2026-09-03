import 'package:equatable/equatable.dart';

/// Вариант выбора «зала» на шаге 2.
///
/// Обычно совпадает с реальным залом ([roomIds] из одного элемента). Для V-Ray
/// добавляется комбинированный вариант «Весь клуб» ([isCombo] == true), который
/// охватывает станции сразу нескольких залов в одной брони.
class HallOptionEntity extends Equatable {
  /// Создаёт вариант зала.
  const HallOptionEntity({
    required this.id,
    required this.name,
    required this.roomIds,
    required this.headsets,
    required this.consoles,
    this.isCombo = false,
  });

  /// Идентификатор варианта (id зала или `combo:<clubId>`).
  final String id;

  /// Название («Большой зал», «Весь клуб»).
  final String name;

  /// Залы, входящие в вариант.
  final List<String> roomIds;

  /// Число VR-шлемов в варианте.
  final int headsets;

  /// Число приставок PS5 в варианте.
  final int consoles;

  /// Это объединённый вариант «весь клуб».
  final bool isCombo;

  /// Суммарное число станций.
  int get capacity => headsets + consoles;

  /// Подпись состава («12 шлемов», «4 шлема + 2 PS5», «оба зала · 18 мест»).
  String get kitLabel {
    if (isCombo) return 'оба зала · $capacity мест';
    final String vr = '$headsets ${_plural(headsets, 'шлем', 'шлема', 'шлемов')}';
    return consoles > 0 ? '$vr + $consoles PS5' : vr;
  }

  static String _plural(int n, String one, String few, String many) {
    final int m10 = n % 10;
    final int m100 = n % 100;
    if (m10 == 1 && m100 != 11) return one;
    if (m10 >= 2 && m10 <= 4 && (m100 < 12 || m100 > 14)) return few;
    return many;
  }

  @override
  List<Object?> get props => <Object?>[id, name, roomIds, headsets, consoles, isCombo];
}
