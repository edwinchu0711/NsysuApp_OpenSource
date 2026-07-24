import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';

/// 詳情對話框中使用的現代化資料列（原 _buildModernDetailRow）
class ModernDetailRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final Widget content;
  final bool isLoading;

  const ModernDetailRow({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.content,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = colorScheme.isDark;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: isDark ? 0.15 : 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.subtitleText,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                if (isLoading)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  content,
              ],
            ),
          ),
        ],
      ),
    );
  }
}