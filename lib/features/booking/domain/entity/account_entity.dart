import 'package:equatable/equatable.dart';

/// Запомненный на устройстве клиент (для автозаполнения контактов).
class AccountEntity extends Equatable {
  /// Создаёт запись клиента.
  const AccountEntity({required this.phone, required this.name});

  /// Телефон (в маске `+7 (900) 000-00-00`).
  final String phone;

  /// Имя.
  final String name;

  @override
  List<Object?> get props => <Object?>[phone, name];
}

/// Прошлая бронь клиента, сохранённая локально (только на этом устройстве).
class SavedBookingEntity extends Equatable {
  /// Создаёт запись брони.
  const SavedBookingEntity({
    required this.orderId,
    required this.phone,
    required this.name,
    required this.title,
    required this.meta,
    required this.total,
  });

  /// Разбирает из JSON localStorage.
  factory SavedBookingEntity.fromJson(Map<String, dynamic> j) => SavedBookingEntity(
        orderId: j['orderId'] as String? ?? '',
        phone: j['phone'] as String? ?? '',
        name: j['name'] as String? ?? '',
        title: j['title'] as String? ?? '',
        meta: j['meta'] as String? ?? '',
        total: j['total'] as String? ?? '',
      );

  /// Идентификатор брони.
  final String orderId;

  /// Телефон, на который сделана бронь.
  final String phone;

  /// Имя клиента.
  final String name;

  /// «Effect VR · Зал».
  final String title;

  /// «пн, 8 сент · 15:20–17:20 · 4 места».
  final String meta;

  /// Итог «10 000 ₽».
  final String total;

  /// В JSON для localStorage.
  Map<String, dynamic> toJson() => <String, dynamic>{
        'orderId': orderId,
        'phone': phone,
        'name': name,
        'title': title,
        'meta': meta,
        'total': total,
      };

  @override
  List<Object?> get props => <Object?>[orderId, phone, name, title, meta, total];
}
