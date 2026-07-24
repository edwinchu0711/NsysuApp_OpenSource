import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import '../../../theme/app_theme.dart';
import '../menu_item_model.dart';

class MainMenuBentoLayout extends StatelessWidget {
  final List<MainMenuItem> menuItems;
  final double horizontalPadding;
  final bool isTablet;
  final bool isWideScreen;
  final bool isAurora;

  const MainMenuBentoLayout({
    Key? key,
    required this.menuItems,
    required this.horizontalPadding,
    required this.isTablet,
    required this.isWideScreen,
    required this.isAurora,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // A helper to safely find an item by label
    MainMenuItem? getItem(String label) {
      try {
        return menuItems.firstWhere((item) => item.label == label);
      } catch (_) {
        return null;
      }
    }

    final scoreQuery = getItem("學期成績查詢");
    final openScore = getItem("開放成績查詢");
    final scoreTracking = getItem("分數試算");
    final schedule = getItem("課表查詢");
    final assistant = getItem("選課助手");
    final selection = getItem("選課系統");
    final elearn = getItem("網路大學");
    final progress = getItem("學程進度");
    final graduation = getItem("畢業檢核");
    final bus = getItem("校園公車");
    final calendar = getItem("行事曆");

    if (isTablet || isWideScreen) {
      // 3欄式 Bento 佈局 (平板與寬螢幕)
      return SliverPadding(
        padding: EdgeInsets.symmetric(
          horizontal: horizontalPadding,
          vertical: 16.0,
        ),
        sliver: SliverToBoxAdapter(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 第一欄
              Expanded(
                child: Column(
                  children: [
                    if (scoreQuery != null)
                      _BentoTile(
                        item: scoreQuery,
                        isTall: true,
                        height: 228,
                        isGlassmorphic: isAurora,
                      ),
                    const SizedBox(height: 12),
                    if (openScore != null)
                      _BentoTile(
                        item: openScore,
                        height: 120,
                        isGlassmorphic: isAurora,
                      ),
                    const SizedBox(height: 12),
                    if (graduation != null)
                      _BentoTile(
                        item: graduation,
                        height: 120,
                        isGlassmorphic: isAurora,
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 16),

              // 第二欄
              Expanded(
                child: Column(
                  children: [
                    if (schedule != null)
                      _BentoTile(
                        item: schedule,
                        isTall: true,
                        height: 228,
                        isGlassmorphic: isAurora,
                      ),
                    const SizedBox(height: 12),
                    if (assistant != null)
                      _BentoTile(
                        item: assistant,
                        height: 120,
                        isGlassmorphic: isAurora,
                      ),
                    const SizedBox(height: 12),
                    if (selection != null)
                      _BentoTile(
                        item: selection,
                        height: 120,
                        isGlassmorphic: isAurora,
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 16),

              // 第三欄
              Expanded(
                child: Column(
                  children: [
                    if (elearn != null)
                      _BentoTile(
                        item: elearn,
                        isTall: true,
                        height: 228,
                        isGlassmorphic: isAurora,
                      ),
                    const SizedBox(height: 12),
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (progress != null)
                            Expanded(
                              child: _BentoTile(
                                item: progress,
                                height: 120,
                                isGlassmorphic: isAurora,
                              ),
                            ),
                          const SizedBox(width: 12),
                          if (scoreTracking != null)
                            Expanded(
                              child: _BentoTile(
                                item: scoreTracking,
                                height: 120,
                                isGlassmorphic: isAurora,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (bus != null)
                            Expanded(
                              child: _BentoTile(
                                item: bus,
                                height: 120,
                                isGlassmorphic: isAurora,
                              ),
                            ),
                          const SizedBox(width: 12),
                          if (calendar != null)
                            Expanded(
                              child: _BentoTile(
                                item: calendar,
                                height: 120,
                                isGlassmorphic: isAurora,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    // 雙欄非對稱 Bento 佈局 (手機端)
    return SliverPadding(
      padding: EdgeInsets.symmetric(
        horizontal: horizontalPadding,
        vertical: 12.0,
      ),
      sliver: SliverList(
        delegate: SliverChildListDelegate([
          // 區塊一：成績焦點 (不對稱設計)
          SizedBox(
            height: 252,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (scoreQuery != null)
                  Expanded(
                    child: _BentoTile(
                      item: scoreQuery,
                      isTall: true,
                      height: 252,
                      isGlassmorphic: isAurora,
                    ),
                  ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    children: [
                      if (openScore != null)
                        _BentoTile(
                          item: openScore,
                          height: 120,
                          isGlassmorphic: isAurora,
                        ),
                      const SizedBox(height: 12),
                      if (scoreTracking != null)
                        _BentoTile(
                          item: scoreTracking,
                          height: 120,
                          isGlassmorphic: isAurora,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // 區塊二：今日課表 (單張大寬卡)
          if (schedule != null)
            _BentoTile(
              item: schedule,
              isWide: true,
              height: 100,
              isGlassmorphic: isAurora,
            ),
          const SizedBox(height: 12),

          // 區塊三：選課核心 (雙欄並排)
          Row(
            children: [
              if (assistant != null)
                Expanded(
                  child: _BentoTile(
                    item: assistant,
                    height: 120,
                    isGlassmorphic: isAurora,
                  ),
                ),
              const SizedBox(width: 12),
              if (selection != null)
                Expanded(
                  child: _BentoTile(
                    item: selection,
                    height: 120,
                    isGlassmorphic: isAurora,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // 區塊四：網路大學 (單張大寬卡)
          if (elearn != null)
            _BentoTile(
              item: elearn,
              isWide: true,
              height: 100,
              isGlassmorphic: isAurora,
            ),
          const SizedBox(height: 12),

          // 區塊五：學歷與畢業追蹤 (雙欄並排)
          Row(
            children: [
              if (progress != null)
                Expanded(
                  child: _BentoTile(
                    item: progress,
                    height: 120,
                    isGlassmorphic: isAurora,
                  ),
                ),
              const SizedBox(width: 12),
              if (graduation != null)
                Expanded(
                  child: _BentoTile(
                    item: graduation,
                    height: 120,
                    isGlassmorphic: isAurora,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // 區塊六：生活與校園便利 (雙欄並排)
          Row(
            children: [
              if (bus != null)
                Expanded(
                  child: _BentoTile(
                    item: bus,
                    height: 120,
                    isGlassmorphic: isAurora,
                  ),
                ),
              const SizedBox(width: 12),
              if (calendar != null)
                Expanded(
                  child: _BentoTile(
                    item: calendar,
                    height: 120,
                    isGlassmorphic: isAurora,
                  ),
                ),
            ],
          ),
        ]),
      ),
    );
  }
}

// Bento Box 專用微光漸層卡片組件 (Bento Tile)
// ─────────────────────────────────────────────
class _BentoTile extends StatefulWidget {
  final MainMenuItem item;
  final bool isWide;
  final bool isTall;
  final double? height;
  final bool isGlassmorphic;

  const _BentoTile({
    Key? key,
    required this.item,
    this.isWide = false,
    this.isTall = false,
    this.height,
    required this.isGlassmorphic,
  }) : super(key: key);

  @override
  State<_BentoTile> createState() => _BentoTileState();
}

class _BentoTileState extends State<_BentoTile>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _isGlowing = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.96,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final item = widget.item;
    final isGlassmorphic = widget.isGlassmorphic;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTapDown: (_) {
          setState(() {
            _isGlowing = true;
          });
          _controller.forward();
        },
        onTapUp: (_) {
          _controller.reverse();

          if (mounted) {
            setState(() {
              _isGlowing = false;
            });
          }

          if (item.pageBuilder != null && mounted) {
            final RenderBox renderBox = context.findRenderObject() as RenderBox;
            final Offset position = renderBox.localToGlobal(Offset.zero);
            final Size size = renderBox.size;
            final rect = Rect.fromLTWH(
              position.dx,
              position.dy,
              size.width,
              size.height,
            );

            Navigator.push(
              context,
              BentoPageRoute(
                builder: item.pageBuilder!,
                startRect: rect,
                startBorderRadius: 22.0,
                accentColor: item.color,
              ),
            );
          } else {
            item.onTap();
          }
        },
        onTapCancel: () {
          setState(() {
            _isGlowing = false;
          });
          _controller.reverse();
        },
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: Container(
            height: widget.height,
            decoration: BoxDecoration(
              color: isGlassmorphic
                  ? colorScheme.cardBackground.withValues(alpha: 
                      colorScheme.brightness == Brightness.dark ? 0.30 : 0.50,
                    )
                  : colorScheme.cardBackground,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: isGlassmorphic
                    ? item.color.withValues(alpha: 
                        colorScheme.brightness == Brightness.dark ? 0.4 : 0.3,
                      )
                    : item.color.withValues(alpha: 
                        colorScheme.brightness == Brightness.dark ? 0.25 : 0.18,
                      ),
                width: isGlassmorphic ? 1.5 : 1.2,
              ),
              gradient: isGlassmorphic
                  ? LinearGradient(
                      colors: colorScheme.brightness == Brightness.dark
                          ? [
                              item.color.withValues(alpha: 0.18),
                              item.color.withValues(alpha: 0.04),
                            ]
                          : [
                              item.color.withValues(alpha: 0.24),
                              item.color.withValues(alpha: 0.08),
                            ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : LinearGradient(
                      colors: colorScheme.brightness == Brightness.dark
                          ? [
                              item.color.withValues(alpha: 0.08),
                              item.color.withValues(alpha: 0.01),
                            ]
                          : [
                              item.color.withValues(alpha: 0.12),
                              item.color.withValues(alpha: 0.02),
                            ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
              boxShadow: [
                BoxShadow(
                  color: _isGlowing
                      ? item.color.withValues(alpha: 
                          colorScheme.brightness == Brightness.dark
                              ? 0.85
                              : 0.70,
                        )
                      : (isGlassmorphic
                            ? item.color.withValues(alpha: 
                                colorScheme.brightness == Brightness.dark
                                    ? 0.15
                                    : 0.1,
                              )
                            : item.color.withValues(alpha: 0.06)),
                  spreadRadius: _isGlowing ? 6 : (isGlassmorphic ? 2 : 1),
                  blurRadius: _isGlowing ? 26 : (isGlassmorphic ? 16 : 10),
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: Stack(
                children: [
                  Positioned(
                    right: -20,
                    top: widget.isWide ? 10 : -20,
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: item.color.withValues(alpha: 0.05),
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.all(
                      widget.isWide ? 16.0 : (widget.isTall ? 14.0 : 12.0),
                    ),
                    child: widget.isWide
                        ? Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: item.color.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Icon(
                                  item.icon,
                                  size: 28,
                                  color: item.color,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      item.label,
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: colorScheme.primaryText,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      item.subtitle,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: colorScheme.subtitleText,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.chevron_right_rounded,
                                color: item.color.withValues(alpha: 0.5),
                              ),
                            ],
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Container(
                                    padding: EdgeInsets.all(
                                      widget.isTall ? 10 : 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: item.color.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Icon(
                                      item.icon,
                                      size: 22,
                                      color: item.color,
                                    ),
                                  ),
                                  Icon(
                                    Icons.arrow_outward_rounded,
                                    size: 16,
                                    color: item.color.withValues(alpha: 0.5),
                                  ),
                                ],
                              ),
                              SizedBox(height: widget.isTall ? 12 : 6),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.label,
                                    style: TextStyle(
                                      fontSize: widget.isTall ? 14 : 13,
                                      fontWeight: FontWeight.bold,
                                      color: colorScheme.primaryText,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    item.subtitle,
                                    style: TextStyle(
                                      fontSize: widget.isTall ? 10.5 : 9.5,
                                      color: colorScheme.subtitleText,
                                    ),
                                    maxLines: widget.isTall ? 2 : 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ],
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Bento 專用絲滑原地放大與內容淡入轉場路由 (BentoPageRoute)
// ─────────────────────────────────────────────
class BentoPageRoute<T> extends PageRouteBuilder<T> {
  final WidgetBuilder builder;
  final Rect startRect;
  final double startBorderRadius;
  final Color accentColor;

  BentoPageRoute({
    required this.builder,
    required this.startRect,
    required this.startBorderRadius,
    required this.accentColor,
  }) : super(
         pageBuilder: (context, animation, secondaryAnimation) =>
             builder(context),
         transitionDuration: const Duration(milliseconds: 400),
         reverseTransitionDuration: const Duration(milliseconds: 350),
         transitionsBuilder: (context, animation, secondaryAnimation, child) {
           final curvedAnimation = CurvedAnimation(
             parent: animation,
             curve: Curves.easeInOutCubic,
           );

           final mediaQuery = MediaQuery.of(context);
           final screenWidth = mediaQuery.size.width;
           final screenHeight = mediaQuery.size.height;
           final theme = Theme.of(context);
           final startBgColor = accentColor.withValues(alpha: 0.12);
           final endBgColor = theme.scaffoldBackgroundColor;

           return Stack(
             children: [
               AnimatedBuilder(
                 animation: curvedAnimation,
                 builder: (context, _) {
                   final progress = curvedAnimation.value;

                   final currentRect = Rect.lerp(
                     startRect,
                     Rect.fromLTWH(0, 0, screenWidth, screenHeight),
                     progress,
                   )!;

                   final currentRadius = ui.lerpDouble(
                     startBorderRadius,
                     0.0,
                     progress,
                   )!;

                   final currentBgColor = Color.lerp(
                     startBgColor,
                     endBgColor,
                     progress,
                   )!;

                   final contentOpacity = Interval(
                     0.4,
                     1.0,
                     curve: Curves.easeOut,
                   ).transform(progress);

                   return Positioned.fromRect(
                     rect: currentRect,
                     child: Container(
                       decoration: BoxDecoration(
                         color: currentBgColor,
                         borderRadius: BorderRadius.circular(currentRadius),
                         boxShadow: [
                           BoxShadow(
                             color: accentColor.withValues(alpha: 
                               ui.lerpDouble(0.15, 0.0, progress)!,
                             ),
                             spreadRadius: ui.lerpDouble(2.0, 0.0, progress)!,
                             blurRadius: ui.lerpDouble(16.0, 0.0, progress)!,
                           ),
                         ],
                       ),
                       child: ClipRRect(
                         borderRadius: BorderRadius.circular(currentRadius),
                         child: Opacity(
                           opacity: contentOpacity,
                           child: progress > 0.35
                               ? child
                               : const SizedBox.shrink(),
                         ),
                       ),
                     ),
                   );
                 },
               ),
             ],
           );
         },
       );
}
