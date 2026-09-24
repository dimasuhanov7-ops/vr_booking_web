/// Ошибка работы с бэкендом админки, уже переведённая на язык сотрудника.
///
/// Нужна, чтобы отличать «сессия истекла» и «нет прав» от обычного обрыва
/// связи: сотрудник должен понимать, надо ли ему войти заново.
class AdminFailure implements Exception {
  /// Создаёт ошибку.
  const AdminFailure(this.message, {this.needsReauth = false});

  /// Сессия истекла или прав нет — надо войти заново.
  const AdminFailure.auth()
      : message = 'Сессия истекла или доступ отозван. Войдите заново.',
        needsReauth = true;

  /// Вход выполнен, но аккаунта нет среди сотрудников (`booking_staff`).
  const AdminFailure.notStaff()
      : message = 'Этот аккаунт не подключён к админке. Попросите владельца '
            'добавить его в сотрудники или войдите под другим.',
        needsReauth = true;

  /// Сообщение для показа в шапке вкладки.
  final String message;

  /// Требуется повторный вход.
  final bool needsReauth;

  @override
  String toString() => 'AdminFailure($message)';
}
