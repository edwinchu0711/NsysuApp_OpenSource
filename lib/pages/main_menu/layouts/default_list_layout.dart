import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';
import '../menu_item_model.dart';

class MainMenuDefaultListLayout extends StatelessWidget {
  final List<MainMenuItem> menuItems;
  final double horizontalPadding;
  final bool isTablet;
  final bool isWideScreen;
  final String layoutStyle;

  const MainMenuDefaultListLayout({
    Key? key,
    required this.menuItems,
    required this.horizontalPadding,
    required this.isTablet,
    required this.isWideScreen,
    required this.layoutStyle,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (isTablet) {
      return SliverPadding(
        padding: EdgeInsets.symmetric(
          horizontal: horizontalPadding,
          vertical: 10,
        ),
        sliver: SliverToBoxAdapter(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isWideScreen) ...[
                // 3 欄式儀表板 (寬螢幕/橫向平板)
                Expanded(
                  child: _buildSectionColumn(
                    context,
                    "成績與進度",
                    Icons.analytics_rounded,
                    menuItems,
                    isFirst: true,
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: _buildSectionColumn(
                    context,
                    "課表與選課",
                    Icons.menu_book_rounded,
                    menuItems,
                    isFirst: true,
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: _buildSectionColumn(
                    context,
                    "學習與校園",
                    Icons.campaign_rounded,
                    menuItems,
                    isFirst: true,
                  ),
                ),
              ] else ...[
                // 2 欄式儀表板 (直向平板)
                Expanded(
                  child: _buildSectionColumn(
                    context,
                    "成績與進度",
                    Icons.analytics_rounded,
                    menuItems,
                    isFirst: true,
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionColumn(
                        context,
                        "課表與選課",
                        Icons.menu_book_rounded,
                        menuItems,
                        isFirst: true,
                      ),
                      const SizedBox(height: 10),
                      _buildSectionColumn(
                        context,
                        "學習與校園",
                        Icons.campaign_rounded,
                        menuItems,
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    // 手機排版
    return SliverPadding(
      padding: EdgeInsets.symmetric(
        horizontal: horizontalPadding,
        vertical: 10,
      ),
      sliver: SliverList(
        delegate: SliverChildListDelegate([
          _buildSectionHeader(
            context,
            "成績與進度",
            Icons.analytics_rounded,
            isFirst: true,
          ),
          ...menuItems
              .where((item) => item.section == "成績與進度")
              .map(
                (item) => _buildBarMenuButton(
                  context,
                  icon: item.icon,
                  label: item.label,
                  subtitle: item.subtitle,
                  color: item.color,
                  onTap: item.onTap,
                ),
              ),
          _buildSectionHeader(
            context,
            "課表與選課",
            Icons.menu_book_rounded,
          ),
          ...menuItems
              .where((item) => item.section == "課表與選課")
              .map(
                (item) => _buildBarMenuButton(
                  context,
                  icon: item.icon,
                  label: item.label,
                  subtitle: item.subtitle,
                  color: item.color,
                  onTap: item.onTap,
                ),
              ),
          _buildSectionHeader(
            context,
            "學習與校園",
            Icons.campaign_rounded,
          ),
          ...menuItems
              .where((item) => item.section == "學習與校園")
              .map(
                (item) => _buildBarMenuButton(
                  context,
                  icon: item.icon,
                  label: item.label,
                  subtitle: item.subtitle,
                  color: item.color,
                  onTap: item.onTap,
                ),
              ),
        ]),
      ),
    );
  }

  // 複合分類整欄組件（平板/寬螢幕排版用）
  Widget _buildSectionColumn(
    BuildContext context,
    String sectionName,
    IconData icon,
    List<MainMenuItem> menuItems, {
    bool isFirst = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(context, sectionName, icon, isFirst: isFirst),
        ...menuItems
            .where((item) => item.section == sectionName)
            .map(
              (item) => _buildBarMenuButton(
                context,
                icon: item.icon,
                label: item.label,
                subtitle: item.subtitle,
                color: item.color,
                onTap: item.onTap,
              ),
            ),
      ],
    );
  }

  // 條狀選單分類標題組件
  Widget _buildSectionHeader(
    BuildContext context,
    String title,
    IconData icon, {
    bool isFirst = false,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.only(
        top: isFirst ? 10.0 : 24.0,
        bottom: 12.0,
        left: 4.0,
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: colorScheme.accentBlue),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: colorScheme.accentBlue,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  // 條狀按鈕組件
  Widget _buildBarMenuButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final isCompact = layoutStyle == 'compact';

    return Container(
      margin: EdgeInsets.symmetric(vertical: isCompact ? 4.0 : 6.0),
      decoration: BoxDecoration(
        color: colorScheme.cardBackground,
        borderRadius: BorderRadius.circular(16),
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
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: isCompact ? 8.0 : 14.0,
            ),
            child: Row(
              children: [
                // 圖標背景圓角框
                Container(
                  padding: EdgeInsets.all(isCompact ? 8 : 12),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, size: isCompact ? 22 : 26, color: color),
                ),
                const SizedBox(width: 16),
                // 標題與說明文字
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: isCompact ? 15 : 16,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.primaryText,
                        ),
                      ),
                      if (!isCompact) ...[
                        const SizedBox(height: 3),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.subtitleText,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                // 箭頭
                Icon(
                  Icons.chevron_right_rounded,
                  color: colorScheme.subtitleText.withValues(alpha: 0.7),
                  size: isCompact ? 20 : 24,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
