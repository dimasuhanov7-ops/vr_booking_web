import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app/booking_app.dart';
import 'app/embed/launch_params.dart';
import 'di/injection.dart';

/// Точка входа публичного виджета онлайн-бронирования VR-клубов.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ru');
  final LaunchParams params = LaunchParams.fromUri();
  await Injection.instance.init(adminMode: params.adminMode);
  runApp(BookingApp(params: params));
}
