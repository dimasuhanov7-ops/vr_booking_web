import 'package:equatable/equatable.dart';

/// Зал клуба в админке.
class AdminHallEntity extends Equatable {
  /// Создаёт зал.
  const AdminHallEntity({
    required this.id,
    required this.name,
    required this.headsets,
    required this.consoles,
  });

  /// Идентификатор зала.
  final String id;

  /// Название зала.
  final String name;

  /// Число VR-шлемов.
  final int headsets;

  /// Число приставок PS5.
  final int consoles;

  /// Всего станций.
  int get capacity => headsets + consoles;

  @override
  List<Object?> get props => <Object?>[id, name, headsets, consoles];
}

/// Клуб в админке (со списком залов и рабочими часами).
class AdminClubEntity extends Equatable {
  /// Создаёт клуб.
  const AdminClubEntity({
    required this.id,
    required this.slug,
    required this.name,
    required this.hoursLabel,
    required this.openMinutes,
    required this.closeMinutes,
    required this.gapMinutes,
    required this.halls,
  });

  /// Идентификатор клуба.
  final String id;

  /// Код клуба (`effect_vr` / `v_ray`) — для выбора акцента.
  final String slug;

  /// Название клуба.
  final String name;

  /// Часы работы для подписи («11:00 – 22:30»).
  final String hoursLabel;

  /// Открытие, минут от полуночи.
  final int openMinutes;

  /// Закрытие, минут от полуночи.
  final int closeMinutes;

  /// Пауза между сеансами, минут.
  final int gapMinutes;

  /// Залы клуба.
  final List<AdminHallEntity> halls;

  @override
  List<Object?> get props =>
      <Object?>[id, slug, name, hoursLabel, openMinutes, closeMinutes, gapMinutes, halls];
}
