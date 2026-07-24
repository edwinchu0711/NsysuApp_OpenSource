import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../theme/layout_style_notifier.dart';

/// 玻璃卡片：可作為 drop-in 取代子頁面中 `Container(decoration: BoxDecoration(...))`
/// 形式的卡片。
///
/// - 當 [LayoutStyleNotifier] 為 `liquid_glass` 時：半透明白底 + 細邊框 + 柔陰影
///   （玻璃質感），呼應主選單的 [MainMenuLiquidGlassLayout] 風格。
/// - 否則：固態 `colorScheme.cardBackground` + 淺邊框 + 極輕陰影，視覺貼近
///   原本各頁面的純色卡片，避免在非玻璃模式下出現突兀的半透明。
///
/// 純 [Container] 實作，不使用 shader，適合大量出現在捲動列表中
/// （效能遠低於 [AdaptiveGlass]）。內部以 [ValueListenableBuilder] 訂閱模式，
/// 切換時自動重建。
class GlassCard extends StatelessWidget {
  final Widget child;
  final double borderRadius;

  const GlassCard({super.key, required this.child, this.borderRadius = 20.0});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = colorScheme.isDark;
    final isLiquidGlass = LayoutStyleNotifier.instance.isLiquidGlass;

    final Color bgColor;
    final Border border;
    final List<BoxShadow> shadows;

    if (isLiquidGlass) {
      bgColor = isDark
          ? Colors.white.withValues(alpha: 0.04)
          : Colors.white.withValues(alpha: 0.45);
      border = Border.all(
        color: isDark
            ? Colors.white.withValues(alpha: 0.08)
            : Colors.white.withValues(alpha: 0.35),
        width: 1.0,
      );
      shadows = [
        BoxShadow(
          color: isDark
              ? Colors.black.withValues(alpha: 0.15)
              : Colors.black.withValues(alpha: 0.04),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ];
    } else {
      bgColor = colorScheme.cardBackground;
      border = Border.all(color: colorScheme.borderColor, width: 0.5);
      shadows = const [
        BoxShadow(
          color: Color(0x0A000000),
          blurRadius: 4,
          offset: Offset(0, 2),
        ),
      ];
    }

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        border: border,
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: shadows,
      ),
      child: child,
    );
  }
}

/// 玻璃模式專用的卡片 [BoxDecoration] 產生器。
///
/// 僅在 `liquid_glass` 模式下回傳「半透明白底 + 細邊框 + 柔陰影」的玻璃樣式；
/// 否則回傳 `null`，由呼叫端保留原本的 decoration（確保非玻璃模式外觀不變）。
///
/// [isSelected] / [selectedColor] 用於帶有選取狀態的卡片（如成績課程卡片），
/// 選取時改用 [selectedColor] 作為邊框與光暈色，呼應原選取視覺。
BoxDecoration? glassCardDecoration(
  BuildContext context, {
  double borderRadius = 16,
  bool isSelected = false,
  Color? selectedColor,
}) {
  final isLiquidGlass = LayoutStyleNotifier.instance.isLiquidGlass;
  if (!isLiquidGlass) return null;

  final isDark = Theme.of(context).brightness == Brightness.dark;
  final accent = selectedColor ?? Theme.of(context).colorScheme.primary;

  return BoxDecoration(
    color: isDark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.white.withValues(alpha: 0.45),
    borderRadius: BorderRadius.circular(borderRadius),
    border: Border.all(
      color: isSelected
          ? accent
          : (isDark
              ? Colors.white.withValues(alpha: 0.12)
              : Colors.white.withValues(alpha: 0.35)),
      width: isSelected ? 2.0 : 1.0,
    ),
    boxShadow: [
      BoxShadow(
        color: isSelected
            ? accent.withValues(alpha: 0.4)
            : Colors.black.withValues(alpha: isDark ? 0.18 : 0.05),
        blurRadius: isSelected ? 12 : 8,
        spreadRadius: isSelected ? 2 : 0,
        offset: isSelected ? Offset.zero : const Offset(0, 2),
      ),
    ],
  );
}