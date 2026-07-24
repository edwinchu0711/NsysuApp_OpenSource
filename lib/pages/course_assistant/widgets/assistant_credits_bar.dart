import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';
import '../../../theme/layout_style_notifier.dart';
import '../../../widgets/glass/glass_card.dart';

/// 學分資訊列（原 _buildCreditsBar）
class CreditsBar extends StatelessWidget {
  final int courseCount;
  final String totalCredits;
  final bool showManageButton;
  final VoidCallback onManage;

  const CreditsBar({
    super.key,
    required this.courseCount,
    required this.totalCredits,
    required this.showManageButton,
    required this.onManage,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isLiquidGlass = LayoutStyleNotifier.instance.isLiquidGlass;
    return Container(
      margin: isLiquidGlass ? const EdgeInsets.fromLTRB(12, 5, 12, 5) : null,
      padding: isLiquidGlass
          ? const EdgeInsets.symmetric(vertical: 4, horizontal: 14)
          : const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
      decoration: isLiquidGlass
          ? glassCardDecoration(context, borderRadius: 14)
          : BoxDecoration(
              color: colorScheme.isDark
                  ? const Color(0xFF1E2D4A)
                  : Colors.blue[50],
            ),
      width: double.infinity,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  size: 18,
                  color: colorScheme.isDark
                      ? const Color(0xFF6B9BF5)
                      : Colors.blue[800],
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    " $courseCount 門課程 / $totalCredits 學分",
                    style: TextStyle(
                      color: colorScheme.isDark
                          ? const Color(0xFF90CAF9)
                          : Colors.blue[900],
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          if (showManageButton)
            TextButton.icon(
              onPressed: onManage,
              icon: Icon(Icons.list_alt, size: isLiquidGlass ? 16 : 18),
              label: const Text("管理清單"),
              style: TextButton.styleFrom(
                foregroundColor: colorScheme.isDark
                    ? const Color(0xFF6B9BF5)
                    : Colors.blue[800],
                padding: isLiquidGlass
                    ? const EdgeInsets.symmetric(horizontal: 8, vertical: 0)
                    : null,
                visualDensity: isLiquidGlass ? VisualDensity.compact : null,
                tapTargetSize: isLiquidGlass
                    ? MaterialTapTargetSize.shrinkWrap
                    : null,
              ),
            ),
        ],
      ),
    );
  }
}