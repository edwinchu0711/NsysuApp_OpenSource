import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';
import '../menu_item_model.dart';

class MainMenuGridLayout extends StatelessWidget {
  final List<MainMenuItem> menuItems;
  final double horizontalPadding;
  final bool isTablet;
  final bool isWideScreen;

  const MainMenuGridLayout({
    Key? key,
    required this.menuItems,
    required this.horizontalPadding,
    required this.isTablet,
    required this.isWideScreen,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: EdgeInsets.symmetric(
        horizontal: horizontalPadding,
        vertical: 16.0,
      ),
      sliver: SliverGrid(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: isWideScreen ? 4 : (isTablet ? 3 : 2),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: isWideScreen ? 1.25 : (isTablet ? 1.2 : 1.15),
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final item = menuItems[index];
            return _buildGridMenuButton(context, item);
          },
          childCount: menuItems.length,
        ),
      ),
    );
  }

  // 格狀按鈕組件 (一排兩個正方形框框格式)
  Widget _buildGridMenuButton(BuildContext context, MainMenuItem item) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.cardBackground,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colorScheme.borderColor, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: item.onTap,
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // 圖標背景圓形框
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: item.color.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(item.icon, size: 28, color: item.color),
                ),
                const SizedBox(height: 12),
                // 標題
                Text(
                  item.label,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primaryText,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
