import 'package:flutter/material.dart';
import '../../theme/layout_style_notifier.dart';

/// 顯示底部彈窗；當 liquid glass 模式時使用透明背景以利玻璃質感，
/// 否則退回標準 [showModalBottomSheet] 行為（呼叫端透過 colorScheme 設色）。
///
/// 回傳 [WidgetBuilder] 供呼叫端放入內容；底部彈窗的圓角與背景在玻璃模式下
/// 設為透明，讓呼叫端的內容（建議用 [GlassCard] 包裹）直接呈現玻璃效果。
Future<T?> showGlassModalBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = false,
  bool useRootNavigator = true,
  Color? barrierColor,
  bool enableDrag = true,
  bool dismissible = true,
  ShapeBorder? shape,
  Color? backgroundColor,
  BoxConstraints? constraints,
}) {
  final isLiquidGlass = LayoutStyleNotifier.instance.isLiquidGlass;

  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    useRootNavigator: useRootNavigator,
    backgroundColor:
        isLiquidGlass ? Colors.transparent : (backgroundColor),
    barrierColor: barrierColor,
    enableDrag: enableDrag,
    isDismissible: dismissible,
    shape: isLiquidGlass
        ? const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          )
        : shape,
    constraints: constraints,
    builder: builder,
  );
}