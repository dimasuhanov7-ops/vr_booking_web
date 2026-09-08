/// Заглушка для платформ без JS (тесты на VM) — хранит значения в памяти процесса.
final Map<String, String> _mem = <String, String>{};

String? read(String key) => _mem[key];

void write(String key, String value) => _mem[key] = value;

void remove(String key) => _mem.remove(key);
