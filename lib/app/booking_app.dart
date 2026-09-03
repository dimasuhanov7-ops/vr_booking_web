import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../di/injection.dart';
import '../features/booking/domain/state/booking_bloc.dart';
import '../features/booking/presentation/screens/booking_screen.dart';
import 'theme/app_theme.dart';

/// Корневой виджет публичного приложения бронирования.
class BookingApp extends StatelessWidget {
  /// Создаёт приложение.
  const BookingApp({super.key});

  /// Источник брони: `vk`, если запущено во фрейме VK Mini App, иначе `site`.
  static String get _source {
    if (kIsWeb) {
      final Uri uri = Uri.base;
      if (uri.queryParameters.containsKey('vk_app_id') ||
          uri.queryParameters['source'] == 'vk') {
        return 'vk';
      }
    }
    return 'site';
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Бронирование VR',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      locale: const Locale('ru'),
      supportedLocales: const <Locale>[Locale('ru'), Locale('en')],
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: BlocProvider<BookingBloc>(
        create: (_) => BookingBloc(
          repository: Injection.instance.bookingRepository,
          source: _source,
        )..add(const BookingStarted()),
        child: const BookingScreen(),
      ),
    );
  }
}
