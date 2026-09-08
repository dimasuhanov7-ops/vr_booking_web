import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app/booking_app.dart';
import 'app/embed/launch_params.dart';
import 'di/injection.dart';

/// Точка входа публичного виджета онлайн-бронирования VR-клубов.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Дерево доступности во Flutter Web по умолчанию выключено и включается
  // только когда посетитель сам нажмёт скрытую кнопку «Enable accessibility».
  // Для формы бронирования это значит, что со скринридером ей пользоваться
  // нельзя, — поэтому включаем сразу.
  SemanticsBinding.instance.ensureSemantics();
  _styleSystemBars();
  _installErrorScreen();
  await initializeDateFormatting('ru');
  final LaunchParams params = LaunchParams.fromUri();
  await Injection.instance.init(adminMode: params.adminMode);
  runApp(BookingApp(params: params));
}

/// Системные панели под тёмный интерфейс.
///
/// На Android по умолчанию статус-бар получает иконки под светлую тему —
/// на нашем почти чёрном фоне они не видны. В вебе вызов безвреден и не
/// делает ничего.
void _styleSystemBars() {
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
    systemNavigationBarColor: Color(0xFF08090A),
    systemNavigationBarIconBrightness: Brightness.light,
  ));
}

/// Заменяет серый экран Flutter на понятное сообщение с телефоном клуба.
///
/// Виджет живёт в чужом iframe: клиент, увидев «краш», просто уйдёт — поэтому
/// даже на необработанной ошибке нужно оставить способ забронировать.
void _installErrorScreen() {
  ErrorWidget.builder = (FlutterErrorDetails details) => Directionality(
        textDirection: TextDirection.ltr,
        child: Container(
          color: const Color(0xFF08090A),
          alignment: Alignment.center,
          padding: const EdgeInsets.all(24),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                'Не получилось показать форму',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFF2F2F5),
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Обновите страницу. Если не поможет — позвоните в клуб, '
                'мы забронируем вручную.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.5,
                  color: Color(0xFF8A8A96),
                ),
              ),
            ],
          ),
        ),
      );
}
