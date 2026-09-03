/// Глобальная конфигурация публичного виджета бронирования.
///
/// Значения Supabase берутся из `--dart-define` при сборке, с безопасными
/// дефолтами на проект «Vray/Effect info». Publishable-ключ анонимный и
/// предназначен для клиентской части, поэтому его наличие в бандле ожидаемо.
abstract final class BookingConfig {
  const BookingConfig._();

  /// URL проекта Supabase.
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://cpjmirlujtfuzvdnysyx.supabase.co',
  );

  /// Публикуемый (анонимный) ключ Supabase.
  ///
  /// Дефолт — legacy anon JWT проекта «Vray/Effect info». Для ротации ключа
  /// собирайте с `--dart-define=SUPABASE_ANON_KEY=sb_publishable_...`.
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImNwam1pcmx1anRmdXp2ZG55c3l4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODQ2NTI4ODksImV4cCI6MjEwMDIyODg4OX0.ZyXcHe-N4hULMC17ZKc7PmmYjym4YGXwsJuW8Txcen8',
  );

  /// Длительности сеансов, которые предлагаются клиенту, в минутах.
  static const List<int> sessionDurations = <int>[30, 60];

  /// На сколько дней вперёд открыта запись.
  static const int bookingHorizonDays = 30;

  /// Использовать in-memory данные вместо Supabase (демо UI).
  /// Сборка: `--dart-define=USE_MOCK=true`.
  static const bool useMock = bool.fromEnvironment('USE_MOCK');
}
