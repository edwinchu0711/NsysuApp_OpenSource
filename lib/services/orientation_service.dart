import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OrientationService {
  static const String _kAllowLandscapeKey = 'allow_landscape_mode';

  /// 偵測目前裝置是否為平板 (以短邊 >= 600dp 為標準)
  static bool _detectIsTablet() {
    try {
      final view = ui.PlatformDispatcher.instance.views.first;
      final double devicePixelRatio = view.devicePixelRatio;
      final ui.Size physicalSize = view.physicalSize;

      if (devicePixelRatio == 0 ||
          physicalSize.width == 0 ||
          physicalSize.height == 0) {
        return false;
      }

      final double width = physicalSize.width / devicePixelRatio;
      final double height = physicalSize.height / devicePixelRatio;
      final double shortestSide = width < height ? width : height;

      return shortestSide >= 600;
    } catch (_) {
      return false; // 若發生異常，預設當作手機處理
    }
  }

  /// 取得動態預設值：平板為 true，手機為 false
  static bool _getDefaultValue() {
    return _detectIsTablet();
  }

  /// 初始化螢幕旋轉設定，讀取使用者設定並套用
  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.containsKey(_kAllowLandscapeKey)) {
      final bool allowLandscape =
          prefs.getBool(_kAllowLandscapeKey) ?? _getDefaultValue();
      await applyOrientation(allowLandscape);
    } else {
      // 第一次安裝且尚未有設定記錄：
      // 延遲到第一影格渲染後（此時視窗與尺寸皆已準備就緒），再進行平板/手機偵測並套用
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final bool allowLandscape = _detectIsTablet();
        await applyOrientation(allowLandscape);
      });
    }
  }

  /// 取得目前是否允許橫向旋轉
  static Future<bool> isLandscapeAllowed() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.containsKey(_kAllowLandscapeKey)) {
      return prefs.getBool(_kAllowLandscapeKey) ?? _getDefaultValue();
    } else {
      return _getDefaultValue();
    }
  }

  /// 設定是否允許橫向旋轉，並立即套用
  static Future<void> setLandscapeAllowed(bool allow) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kAllowLandscapeKey, allow);
    await applyOrientation(allow);
  }

  /// 實際套用螢幕旋轉限制到 SystemChrome
  static Future<void> applyOrientation(bool allowLandscape) async {
    if (allowLandscape) {
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } else {
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
    }
  }
}
