import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/services.dart';
import 'core/theme.dart';

class MadrastyApp extends StatelessWidget {
  const MadrastyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'مدرستي',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      routerConfig: Services.router,
      locale: const Locale('ar', 'EG'), // يفعّل RTL تلقائيًا
      supportedLocales: const [Locale('ar', 'EG')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }
}
