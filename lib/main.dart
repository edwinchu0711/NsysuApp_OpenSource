/*

This file contains code derived from the NSYSU Open Development Community project.

Original Copyright (c) 2024 NSYSU Open Development Community

Licensed under the MIT License.

*/
import 'package:flutter/material.dart';
import 'pages/captcha_auto_login_page.dart';
import 'package:flutter/services.dart'; 
import 'services/cache_manager.dart';
import 'package:flutter_localizations/flutter_localizations.dart'; // 記得保留這個

// 自定義動畫 Builder (保持原樣)
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

    return SlideTransition(
      position: animation.drive(tween),
      child: child,
    );
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 這裡是你原本註解掉的快取清理，我保持原樣
  // try {
  //   await AppCacheManager.checkAndCleanCache();
  //   print("快取檢查完成");
  // } catch (e) {
  //   print("清理快取時發生錯誤: $e");
  // }



  // 設定限制方向
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]).then((_) {
    
    runApp(MaterialApp(
      debugShowCheckedModeBanner: false,
      home: CaptchaAutoLoginPage(),
      
      // ★★★ 新增：設定語言環境 (這會讓日曆顯示中文) ★★★
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('zh', 'TW'), // 繁體中文
        Locale('en', 'US'), // 英文
      ],
      // ★★★ 結束 ★★★

      theme: ThemeData(
        primarySwatch: Colors.blue,
        pageTransitionsTheme: PageTransitionsTheme(
          builders: {
            TargetPlatform.android: CupertinoPageTransitionsBuilder(),
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          },
        ),
      ),
    ));
  });
}