import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/font_service.dart';

const String _kFontFamilyKey = 'app_font_family'; // 'system' | 'NotoSansTC'

class FontNotifier extends ValueNotifier<String> {
  FontNotifier._() : super('system');

  static final FontNotifier instance = FontNotifier._();

  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_kFontFamilyKey) ?? 'system';
      if (saved == 'NotoSansTC') {
        value = 'NotoSansTC';
        // 異步預載，不阻礙 App 啟動
        FontService.instance.preloadFont().catchError((e) {
          debugPrint('FontNotifier: init preloading error: $e');
        });
        return;
<<<<<<< HEAD
      } else {
        // 若啟動時設定為預設字體，異步嘗試清理殘留的字體快取（此時新進程啟動，舊鎖定已被釋放）
        FontService.instance.deleteFontCache().catchError((e) {
          debugPrint('FontNotifier: init deleting font cache error: $e');
        });
=======
>>>>>>> cb0e69536426ceb2a943a1d70f3df893136211d7
      }
    } catch (e) {
      debugPrint('FontNotifier: Initialize error: $e');
    }
    value = 'system';
  }

  Future<void> setFontFamily(String fontFamily) async {
    final prefs = await SharedPreferences.getInstance();
    if (fontFamily == 'NotoSansTC') {
      try {
        await FontService.instance.preloadFont();
        value = 'NotoSansTC';
        await prefs.setString(_kFontFamilyKey, 'NotoSansTC');
      } catch (e) {
        debugPrint('FontNotifier: Set Noto Sans failed: $e');
        rethrow;
      }
    } else {
      value = 'system';
      await prefs.setString(_kFontFamilyKey, 'system');
      await FontService.instance.deleteFontCache();
    }
  }

  bool get isNotoSans => value == 'NotoSansTC';
}
