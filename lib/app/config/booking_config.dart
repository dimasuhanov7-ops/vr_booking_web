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

  /// Длительности сеанса, минут — единый список для виджета и админки.
  /// Зашит и в БД: `booking_create_order` (BAD_DURATION) и RLS-политика
  /// вставки `booking_order_items`. Менять только вместе с миграцией.
  static const List<int> sessionDurations = <int>[60, 120, 180, 240, 300];

  /// На сколько дней вперёд открыта запись клиенту.
  static const int bookingHorizonDays = 30;

  /// Горизонт для персонала: клуб принимает брони по телефону дальше, чем
  /// открыта публичная запись, поэтому календарь админки длиннее — намеренно.
  static const int staffHorizonDays = 120;

  /// Использовать in-memory данные вместо реального бэкенда (демо UI).
  /// Сборка: `--dart-define=USE_MOCK=true`.
  static const bool useMock = bool.fromEnvironment('USE_MOCK');

  /// Адрес политики конфиденциальности на сайте клуба.
  ///
  /// Пока пуст — под формой показывается только текст об обработке данных,
  /// без ссылки. Задать при сборке:
  /// `--dart-define=PRIVACY_URL=https://effectvr.ru/privacy`.
  /// Черновик самого документа — `docs/PRIVACY.md`.
  static const String privacyUrl = String.fromEnvironment('PRIVACY_URL');

  /// Слово-пропуск на скрытой кнопке «в админку» на публичном виджете.
  /// Это лишь заслон от случайных нажатий — в боевой сборке админку всё равно
  /// защищает Supabase Auth. Меняется сборкой:
  /// `--dart-define=ADMIN_GATE=...`.
  static const String adminGate = String.fromEnvironment(
    'ADMIN_GATE',
    defaultValue: 'vr2026',
  );

  /// Куда виджет отправляет бронь и откуда читает справочник:
  /// `supabase` — напрямую в PostgREST/RPC; `api` — только на [bookingApiBase].
  /// См. `docs/INTEGRATION.md`.
  static const String bookingBackend = String.fromEnvironment(
    'BOOKING_BACKEND',
    defaultValue: 'supabase',
  );

  /// Виджет ходит только на HTTP-контракт «приёма брони».
  static bool get useApi => !useMock && bookingBackend == 'api';

  /// База URL точки интеграции (Edge Function / API приложения / вебхук).
  static const String bookingApiBase = String.fromEnvironment(
    'BOOKING_API_BASE',
    defaultValue:
        'https://cpjmirlujtfuzvdnysyx.functions.supabase.co/booking-intake',
  );

  /// Ключ для заголовка `Authorization: Bearer …` на точке интеграции.
  /// По умолчанию — тот же анонимный ключ Supabase.
  static const String bookingApiKey = String.fromEnvironment(
    'BOOKING_API_KEY',
    defaultValue: supabaseAnonKey,
  );
}
