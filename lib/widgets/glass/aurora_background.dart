import 'package:flutter/material.dart';
import 'dart:ui' as ui;

/// 流體極光背景：底層漸層 + 三個彩色光暈 + 全域高階模糊。
///
/// 從 [MainMenuLiquidGlassLayout._buildAuroraBackground] 與
/// [MainMenuPage._buildAuroraBackground] 兩處重複實作合併而來。
/// 依當前 [Theme] 亮度自動切換深淺配色。
class AuroraBackground extends StatelessWidget {
  /// 是否禁用最底層的 [ImageFiltered] 高階模糊（效能考量時可設為 true）。
  /// 模糊層是純裝飾，移除後漸層與光暈仍保留。
  final bool disableBlur;

  const AuroraBackground({super.key, this.disableBlur = true});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final colors = isDark
        ? [
            const Color(0xFF0C0E14),
            const Color(0xFF0F1A30),
            const Color(0xFF1B0F30),
            const Color(0xFF0C0E14),
          ]
        : [
            const Color(0xFFE8F0FE),
            const Color(0xFFF3E5F5),
            const Color(0xFFE0F7FA),
            const Color(0xFFE8F0FE),
          ];

    final Widget halos = Stack(
      children: [
        // 左上角青色光暈
        Positioned(
          top: -140,
          left: -140,
          child: Container(
            width: 450,
            height: 450,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  (isDark ? const Color(0xFF00E5FF) : const Color(0xFF80DEEA))
                      .withValues(alpha: isDark ? 0.35 : 0.38),
                  (isDark ? const Color(0xFF00E5FF) : const Color(0xFF80DEEA))
                      .withValues(alpha: 0.12),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.4, 1.0],
              ),
            ),
          ),
        ),
        // 右下角洋紅/紫色光暈
        Positioned(
          bottom: 80,
          right: -120,
          child: Container(
            width: 480,
            height: 480,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  (isDark ? const Color(0xFFD500F9) : const Color(0xFFF3E5F5))
                      .withValues(alpha: isDark ? 0.28 : 0.34),
                  (isDark ? const Color(0xFFD500F9) : const Color(0xFFF3E5F5))
                      .withValues(alpha: 0.10),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.4, 1.0],
              ),
            ),
          ),
        ),
        // 中右側天藍色光暈
        Positioned(
          top: 300,
          right: 20,
          child: Container(
            width: 320,
            height: 320,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  (isDark ? const Color(0xFF2979FF) : const Color(0xFFBBDEFB))
                      .withValues(alpha: isDark ? 0.26 : 0.30),
                  (isDark ? const Color(0xFF2979FF) : const Color(0xFFBBDEFB))
                      .withValues(alpha: 0.08),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.4, 1.0],
              ),
            ),
          ),
        ),
      ],
    );

    return Positioned.fill(
      child: RepaintBoundary(
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: colors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: disableBlur
              ? halos
              : ImageFiltered(
                  imageFilter: ui.ImageFilter.blur(sigmaX: 15.0, sigmaY: 15.0),
                  child: halos,
                ),
        ),
      ),
    );
  }
}
