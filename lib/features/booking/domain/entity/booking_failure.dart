/// Типизированные ошибки доменного слоя бронирования.
sealed class BookingFailure implements Exception {
  /// Базовый конструктор с человекочитаемым сообщением.
  const BookingFailure(this.message);

  /// Сообщение для показа пользователю.
  final String message;

  @override
  String toString() => 'BookingFailure($message)';
}

/// Выбранный слот заняли между загрузкой сетки и подтверждением брони.
/// Соответствует ошибке Postgres `23P01` (exclusion violation).
class SlotAlreadyTakenFailure extends BookingFailure {
  /// Создаёт ошибку занятого слота.
  const SlotAlreadyTakenFailure()
      : super('Этот слот только что заняли. Обновите доступность и попробуйте снова.');
}

/// Промокод не найден или не действует.
class DiscountNotFoundFailure extends BookingFailure {
  /// Создаёт ошибку неизвестного промокода.
  const DiscountNotFoundFailure() : super('Промокод не найден или больше не действует.');
}

/// Промокоду не хватает выбранных станций.
class DiscountMinStationsFailure extends BookingFailure {
  /// Создаёт ошибку с требуемым числом станций.
  const DiscountMinStationsFailure(this.requiredStations)
      : super('Промокод действует от $requiredStations станций.');

  /// Минимально необходимое число станций.
  final int requiredStations;
}

/// Бронь вне рабочих часов клуба или в прошлом.
class BookingWindowFailure extends BookingFailure {
  /// Создаёт ошибку недопустимого времени брони.
  const BookingWindowFailure()
      : super('Выбранное время недоступно для брони. Проверьте дату и рабочие часы клуба.');
}

/// С этого номера бронируют слишком часто (антиспам на стороне БД).
class BookingRateLimitedFailure extends BookingFailure {
  /// Создаёт ошибку превышения частоты.
  const BookingRateLimitedFailure()
      : super('С этого номера только что бронировали. '
            'Подождите немного или позвоните в клуб.');
}

/// На номере уже слишком много будущих броней.
class BookingTooManyActiveFailure extends BookingFailure {
  /// Создаёт ошибку превышения числа активных броней.
  const BookingTooManyActiveFailure()
      : super('На этом номере уже несколько будущих броней. '
            'Отмените лишние или позвоните в клуб.');
}

/// Телефон не похож на настоящий.
class BookingBadPhoneFailure extends BookingFailure {
  /// Создаёт ошибку некорректного телефона.
  const BookingBadPhoneFailure()
      : super('Проверьте номер телефона — он введён не полностью.');
}

/// Клуб временно не принимает онлайн-брони (пауза из админки).
class BookingIntakeClosedFailure extends BookingFailure {
  /// Создаёт ошибку паузы приёма.
  const BookingIntakeClosedFailure()
      : super('Клуб сейчас не принимает онлайн-брони. '
            'Позвоните нам — забронируем вручную.');
}

/// Выбранное время закрыто администратором (зал на обслуживании, событие).
class BookingSlotClosedFailure extends BookingFailure {
  /// Создаёт ошибку закрытого окна.
  const BookingSlotClosedFailure()
      : super('Это время закрыто для записи. Выберите другое.');
}

/// Прочая непредвиденная ошибка сети/сервера.
class BookingUnexpectedFailure extends BookingFailure {
  /// Создаёт непредвиденную ошибку.
  const BookingUnexpectedFailure([String? details])
      : super(details ?? 'Не удалось выполнить операцию. Попробуйте позже.');
}
