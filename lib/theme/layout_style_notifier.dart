import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 主選單樣式鍵值：'default' | 'compact' | 'grid' | 'bento' | 'aurora' | 'liquid_glass'
const String kMainMenuLayoutStyleKey = 'main_menu_layout_style';

/// 預設主選單樣式
const String kDefaultLayoutStyle = kLiquidGlassLayoutStyle;

/// liquid_glass 樣式值
const String kLiquidGlassLayoutStyle = 'liquid_glass';

/// 監聽 `main_menu_layout_style` 設定，讓子頁面能在樣式變更時即時重建。
///
/// 仿照 [ThemeNotifier] / [FontNotifier] 的單例 ValueNotifier 模式。
/// 設定頁透過 [set] 寫入並通知；各頁面以 ValueListenableBuilder 訂閱。
class LayoutStyleNotifier extends ValueNotifier<String> {
  LayoutStyleNotifier._() : super(kDefaultLayoutStyle);

  static final LayoutStyleNotifier instance = LayoutStyleNotifier._();

  /// 全域監聽器：用於通知外層 Layout 是否需要隱藏底部導覽列
  static final ValueNotifier<bool> hideNavBarNotifier = ValueNotifier<bool>(false);

  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      value = prefs.getString(kMainMenuLayoutStyleKey) ?? kDefaultLayoutStyle;
    } catch (e) {
      debugPrint('LayoutStyleNotifier: init error: $e');
    }
  }

  Future<void> set(String style) async {
    value = style;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(kMainMenuLayoutStyleKey, style);
    } catch (e) {
      debugPrint('LayoutStyleNotifier: set error: $e');
    }
  }

  /// 目前是否為 liquid glass 樣式
  bool get isLiquidGlass => value == kLiquidGlassLayoutStyle;
}
