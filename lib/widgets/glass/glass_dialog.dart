import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../theme/layout_style_notifier.dart';

/// 顯示對話框；當 liquid glass 模式時改用 [GlassCard] 外觀，否則退回標準 [AlertDialog]。
///
/// drop-in 取代 `showDialog(builder: (ctx) => AlertDialog(...))`。
/// 參數與 [AlertDialog] 對齊，無論是否為玻璃模式都能正常顯示。
Future<T?> showGlassDialog<T>({
  required BuildContext context,
  Widget? title,
  Widget? content,
  List<Widget>? actions,
  bool barrierDismissible = true,
  Color? barrierColor,
  bool useRootNavigator = true,
  double? maxWidth,
}) {
  final isLiquidGlass = LayoutStyleNotifier.instance.isLiquidGlass;

  if (!isLiquidGlass) {
    return showDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      barrierColor: barrierColor,
      useRootNavigator: useRootNavigator,
      builder: (ctx) =>
          AlertDialog(title: title, content: content, actions: actions),
    );
  }

  // 玻璃模式：高不透明度玻璃（90% 不透明度）
  return showDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierColor: barrierColor ?? Colors.black54,
    useRootNavigator: useRootNavigator,
    builder: (ctx) {
      final colorScheme = Theme.of(ctx).colorScheme;
      final isDark = colorScheme.isDark;
      return Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth ?? 320),
          child: Container(
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF1E222D).withValues(alpha: 0.90)
                  : Colors.white.withValues(alpha: 0.97),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.12)
                    : Colors.black.withValues(alpha: 0.08),
                width: 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (title != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: DefaultTextStyle.merge(
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.primaryText,
                        ),
                        child: title,
                      ),
                    ),
                  if (content != null)
                    Flexible(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: DefaultTextStyle.merge(
                          style: TextStyle(
                            fontSize: 14,
                            color: colorScheme.subtitleText,
                          ),
                          child: content,
                        ),
                      ),
                    ),
                  if (actions != null)
                    Align(
                      alignment: Alignment.centerRight,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: actions,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}
