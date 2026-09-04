import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../di/injection.dart';
import '../features/admin/domain/state/admin_bloc.dart';
import '../features/admin/presentation/screens/admin_screen.dart';
import '../features/booking/domain/state/booking_bloc.dart';
import '../features/booking/presentation/screens/booking_screen.dart';
import 'theme/app_theme.dart';

/// Корневой виджет приложения. Публичный виджет бронирования и служебная
/// админка живут в одном бандле; раздел выбирается по query-параметру.
class BookingApp extends StatelessWidget {
  /// Создаёт приложение.
  const BookingApp({super.key});

  /// Query-параметры запуска (VK-детект, `?admin=1`).
  static Map<String, String> get _params =>
      kIsWeb ? Uri.base.queryParameters : const <String, String>{};

  /// Открыт ли раздел админки (`?admin=1`).
  static bool get _isAdmin => _params['admin'] == '1';

  /// Источник брони: `vk` во фрейме VK Mini App, иначе `site`.
  static String get _source =>
      _params.containsKey('vk_app_id') || _params['source'] == 'vk' ? 'vk' : 'site';

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: _isAdmin ? 'Админка · Бронирование VR' : 'Бронирование VR',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      locale: const Locale('ru'),
      supportedLocales: const <Locale>[Locale('ru'), Locale('en')],
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: _isAdmin
          ? BlocProvider<AdminBloc>(
              create: (_) => AdminBloc(
                repository: Injection.instance.adminRepository,
              )..add(const AdminStarted()),
              child: const AdminScreen(),
            )
          : BlocProvider<BookingBloc>(
              create: (_) => BookingBloc(
                repository: Injection.instance.bookingRepository,
                source: _source,
              )..add(const BookingStarted()),
              child: const BookingScreen(),
            ),
    );
  }
}
