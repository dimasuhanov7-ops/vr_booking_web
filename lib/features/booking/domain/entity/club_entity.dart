import 'package:equatable/equatable.dart';

/// Клуб, доступный для онлайн-бронирования.
class ClubEntity extends Equatable {
  /// Создаёт сущность клуба.
  const ClubEntity({
    required this.id,
    required this.slug,
    required this.name,
    required this.timezone,
    required this.openTime,
    required this.closeTime,
    required this.slotGapMinutes,
    this.sortOrder = 0,
    this.intakeOpen = true,
  });

  /// Идентификатор клуба.
  final String id;

  /// Машиночитаемый код (`effect_vr`, `v_ray`).
  final String slug;

  /// Отображаемое название.
  final String name;

  /// Таймзона клуба (IANA, например `Asia/Yekaterinburg` — Пермь).
  final String timezone;

  /// Время открытия приёма броней (локальное время клуба).
  final Duration openTime;

  /// Время, до которого должна завершиться бронь (локальное время клуба).
  final Duration closeTime;

  /// Пауза между сеансами: шаг сетки слотов = длительность + пауза.
  final int slotGapMinutes;

  /// Порядок отображения в списке клубов.
  final int sortOrder;

  /// Принимает ли клуб онлайн-брони. `false` — пауза, включённая в админке:
  /// форму показываем, но предупреждаем сразу, а не в конце.
  final bool intakeOpen;

  @override
  List<Object?> get props => <Object?>[
        id,
        slug,
        name,
        timezone,
        openTime,
        closeTime,
        slotGapMinutes,
        sortOrder,
        intakeOpen,
      ];
}
