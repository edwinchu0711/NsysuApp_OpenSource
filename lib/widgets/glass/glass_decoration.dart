import 'package:flutter/material.dart';

/// liquid glass 模式下，彈出選單容器的半透明玻璃外觀（搭配 BackdropFilter 模糊）。
/// 與 [GlassSingleSelectDropdown] 與 [GlassPopupMenu] 的選單視覺一致。
/// 供 `glass_dropdown.dart` 與 `glass_popup_menu.dart` 共用，避免重複定義。
BoxDecoration glassMenuDecoration(BuildContext context) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return BoxDecoration(
    color: isDark
        ? const Color(0xFF1E222D).withValues(alpha: 0.90)
        : Colors.white.withValues(alpha: 0.90),
    borderRadius: BorderRadius.circular(14),
    border: Border.all(
      color: isDark
          ? Colors.white.withValues(alpha: 0.12)
          : Colors.black.withValues(alpha: 0.08),
      width: 1.0,
    ),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
        blurRadius: 16,
        offset: const Offset(0, 6),
      ),
    ],
  );
}