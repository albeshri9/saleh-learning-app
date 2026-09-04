import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

import 'app/router.dart';
import 'core/design/app_theme.dart';
import 'core/design/app_viewport.dart';
import 'core/design/widgets/touch_feedback.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await InteractionEffects.load();
  await SystemChrome.setPreferredOrientations(const [
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  runApp(const ProviderScope(child: SalehApp()));
}

class SalehApp extends StatelessWidget {
  const SalehApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'تعلم مع صالح',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      builder: (context, child) => AppViewport(child: child!),
      routerConfig: appRouter,
      // عربية RTL من الجذر — كل الشاشات ترث الاتجاه واللغة تلقائيًا.
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }
}
