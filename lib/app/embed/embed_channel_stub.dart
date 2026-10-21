/// Заглушка для платформ без JS (тесты на VM). Ничего не делает.
void send(String type, Map<String, Object?> data) {}

bool get isVk => false;

Future<String?> vkUserName(Duration timeout) => Future<String?>.value();
