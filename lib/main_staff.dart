import 'app/embed/launch_params.dart';
import 'main.dart';

/// Точка входа отдельного Android-приложения для персонала «VR Админка».
///
/// Временное решение до переноса онлайн-броней в приложение-менеджер: тот же
/// код админки, что на сайте по `?admin=1`, но приложение сразу открывает вход
/// сотрудника. Своя иконка и applicationId — см. флейвор `staff` в
/// `android/app/build.gradle.kts`.
///
/// Сборка: `flutter build apk --release --flavor staff -t lib/main_staff.dart`.
Future<void> main() => runBookingApp(const LaunchParams(adminMode: true));
