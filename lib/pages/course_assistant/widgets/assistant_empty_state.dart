import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';

/// 助手課表為空時的提示畫面（原 _buildEmptyState）
class AssistantEmptyState extends StatelessWidget {
  const AssistantEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.dashboard_customize,
            size: 80,
            color: colorScheme.isDark ? Colors.white30 : Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            "助手課表目前是空的",
            style: TextStyle(
              color: colorScheme.isDark ? colorScheme.subtitleText : Colors.grey,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "點擊右上角選單開始排課",
            style: TextStyle(
              color: colorScheme.isDark
                  ? colorScheme.subtitleText.withValues(alpha: 0.8)
                  : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
}