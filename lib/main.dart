import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app/booking_app.dart';
import 'di/injection.dart';

/// Точка входа публичного виджета онлайн-бронирования VR-клубов.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ru');
  await Injection.instance.init();
  runApp(const BookingApp());
}
