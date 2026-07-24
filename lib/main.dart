/*

This file contains code derived from the NSYSU Open Development Community project.

Original Copyright (c) 2024 NSYSU Open Development Community

Licensed under the MIT License.

*/
import 'package:flutter/material.dart';
import 'pages/login_page.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'theme/app_theme.dart';
import 'theme/theme_notifier.dart';
import 'theme/font_notifier.dart';
import 'theme/layout_style_notifier.dart';
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

/// 一次性遷移：舊版使用者已有 cached_courses 但沒有 has_initialized，
/// 視為已初始化過，避免升級後被要求重新選主題。
Future<void> migrateHasInitializedIfNeeded(SharedPreferences prefs) async {
  if (!prefs.containsKey('has_initialized') &&
      prefs.containsKey('cached_courses')) {
    await prefs.setBool('has_initialized', true);
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Future.wait([
    StorageService.instance.init(),
    ThemeNotifier.instance.init(),
    FontNotifier.instance.init(),
    OrientationService.init(),
    LiquidGlassWidgets.initialize(),
    LayoutStyleNotifier.instance.init(),
  ]);

  // 顯式從快取載入資料 (StorageService 已就緒)
  await Future.wait([
    HistoricalScoreService.instance.loadFromCache(),
    CourseService.instance.loadFromCache(),
  ]);

  // 一次性遷移：舊版使用者不打擾
  {
    final prefs = await SharedPreferences.getInstance();
    await migrateHasInitializedIfNeeded(prefs);
  }

  // adaptiveQuality: true 啟用 liquid_glass_widgets 內建的自動降級安全網
  // （GlassAdaptiveScope）：高階機維持 premium 玻璃著色器，低階機依實測 raster
  // 時間自動降到 standard / minimal，避免在舊裝置上持續卡頓。
  runApp(
    LiquidGlassWidgets.wrap(child: const NSYSUApp(), adaptiveQuality: true),
  );
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
              home: LoginPage(),
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
