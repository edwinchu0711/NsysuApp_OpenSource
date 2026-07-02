/*

This file contains code derived from the NSYSU Open Development Community project.

Original Copyright (c) 2024 NSYSU Open Development Community

Licensed under the MIT License.

*/
import 'package:flutter/material.dart';
import 'pages/captcha_auto_login_page.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'theme/app_theme.dart';
import 'theme/theme_notifier.dart';
import 'theme/font_notifier.dart';
import 'services/storage_service.dart';
import 'services/orientation_service.dart';
import 'services/historical_score_service.dart';
import 'services/course_service.dart';

class BottomUpPageTransitionsBuilder extends PageTransitionsBuilder {
  const BottomUpPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    const begin = Offset(0.0, 1.0);
    const end = Offset.zero;
    const curve = Curves.ease;

    var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));

    return SlideTransition(position: animation.drive(tween), child: child);
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Future.wait([
    StorageService.instance.init(),
    ThemeNotifier.instance.init(),
    FontNotifier.instance.init(),
    OrientationService.init(),
  ]);

  // 顯式從快取載入資料 (StorageService 已就緒)
  await Future.wait([
    HistoricalScoreService.instance.loadFromCache(),
    CourseService.instance.loadFromCache(),
  ]);

  runApp(const NSYSUApp());
}

class NSYSUApp extends StatelessWidget {
  const NSYSUApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeNotifier.instance,
      builder: (context, themeMode, _) {
        return ValueListenableBuilder<String>(
          valueListenable: FontNotifier.instance,
          builder: (context, fontFamily, _) {
            return MaterialApp(
              debugShowCheckedModeBanner: false,
              home: CaptchaAutoLoginPage(),
              theme: AppTheme.buildTheme(AppTheme.lightColorScheme, fontFamily),
              darkTheme: AppTheme.buildTheme(
                AppTheme.darkColorScheme,
                fontFamily,
              ),
              themeMode: themeMode,
              localizationsDelegates: const [
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              supportedLocales: const [Locale('zh', 'TW'), Locale('en', 'US')],
            );
          },
        );
      },
    );
  }
}
