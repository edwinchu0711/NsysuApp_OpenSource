import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../theme/layout_style_notifier.dart';
import 'aurora_background.dart';

/// 可切換「液態玻璃」外觀的頁面 Scaffold。
///
/// drop-in 取代子頁面原本的 `Scaffold(...)`：
/// - 當 [LayoutStyleNotifier] 為 `liquid_glass` 時：在最底層放 [AuroraBackground]
///   （填滿整個螢幕，含 AppBar 區域），上層 Scaffold 背景透明、不延伸 body 到
///   AppBar 後方，並以 [Theme] 覆蓋 AppBarTheme 為透明。如此 body 仍從 AppBar 下方
///   開始排列（與原本版面一致），而透明 AppBar 與透明 body 都能透出極光，呈現玻璃質感。
/// - 否則：維持原行為 — `backgroundColor = colorScheme.pageBackground`、一般 AppBar。
///
/// 內部以 [ValueListenableBuilder] 訂閱 [LayoutStyleNotifier]，模式變更時自動重建。
class GlassPageScaffold extends StatelessWidget {
  final PreferredSizeWidget? appBar;
  final Widget body;
  final Widget? floatingActionButton;
  final FloatingActionButtonLocation? floatingActionButtonLocation;
  final Widget? drawer;
  final Widget? bottomNavigationBar;
  final Widget? bottomSheet;
  final bool? resizeToAvoidBottomInset;
  final Color? backgroundColor;

  const GlassPageScaffold({
    super.key,
    this.appBar,
    required this.body,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
    this.drawer,
    this.bottomNavigationBar,
    this.bottomSheet,
    this.resizeToAvoidBottomInset,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: LayoutStyleNotifier.instance,
      builder: (context, style, _) {
        final isLiquidGlass = style == kLiquidGlassLayoutStyle;

        if (!isLiquidGlass) {
          // 預設模式：沿用原本行為
          return Scaffold(
            backgroundColor:
                backgroundColor ?? Theme.of(context).colorScheme.pageBackground,
            appBar: appBar,
            body: body,
            floatingActionButton: floatingActionButton,
            floatingActionButtonLocation: floatingActionButtonLocation,
            drawer: drawer,
            bottomNavigationBar: bottomNavigationBar,
            bottomSheet: bottomSheet,
            resizeToAvoidBottomInset: resizeToAvoidBottomInset,
          );
        }

        // liquid glass 模式：覆蓋 AppBarTheme 為透明，讓極光透出
        final theme = Theme.of(context);
        final colorScheme = theme.colorScheme;
        final glassAppBarTheme = theme.appBarTheme.copyWith(
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          foregroundColor: colorScheme.primaryText,
          iconTheme: theme.appBarTheme.iconTheme?.copyWith(
            color: colorScheme.primaryText,
          ),
        );

        final themedAppBar = appBar == null
            ? null
            : _ThemedAppBar(
                themeData: theme.copyWith(appBarTheme: glassAppBarTheme),
                appBar: appBar!,
              );

        return Stack(
          children: [
            // 最底層極光背景：填滿整個螢幕（含 AppBar 區域），供透明 AppBar 與透明 body 透出
            const AuroraBackground(),
            // 上層透明 Scaffold：body 不延伸到 AppBar 後方，內容從 AppBar 下方開始排列
            Scaffold(
              backgroundColor: Colors.transparent,
              extendBodyBehindAppBar: false,
              appBar: themedAppBar,
              drawer: drawer,
              floatingActionButton: floatingActionButton,
              floatingActionButtonLocation: floatingActionButtonLocation,
              bottomNavigationBar: bottomNavigationBar,
              bottomSheet: bottomSheet,
              resizeToAvoidBottomInset: resizeToAvoidBottomInset,
              body: body,
            ),
          ],
        );
      },
    );
  }
}

/// 以指定 [ThemeData] 包裝一個 [AppBar]，並實作 [PreferredSizeWidget]
/// 以符合 [Scaffold.appBar] 的型別要求。preferredSize 委派給原始 appBar。
class _ThemedAppBar extends StatelessWidget implements PreferredSizeWidget {
  final ThemeData themeData;
  final PreferredSizeWidget appBar;

  const _ThemedAppBar({required this.themeData, required this.appBar});

  @override
  Size get preferredSize => appBar.preferredSize;

  @override
  Widget build(BuildContext context) {
    return Theme(data: themeData, child: appBar);
  }
}