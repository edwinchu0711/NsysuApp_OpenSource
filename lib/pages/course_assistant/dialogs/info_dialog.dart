import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';
import '../../../theme/layout_style_notifier.dart';

/// 選課助手功能說明對話框（原 _showInfoDialog）
void showInfoDialog(BuildContext context) {
  final colorScheme = Theme.of(context).colorScheme;
  final isDark = colorScheme.isDark;
  final isLiquidGlass = LayoutStyleNotifier.instance.isLiquidGlass;

  final bodyText = Text(
    "1. 提供自訂排課功能，模擬你的專屬課表。\n\n"
    "2. 方便在加簽時快速查看教室與上課時間等資訊。\n\n"
    "3. 支援新增「其他行程」(如工讀、社團)，協助管理個人時間。\n\n"
    "4. 支援從「選課小幫手」網站匯入課表。\n\n"
    "5. 排好的正規課程可直接匯出至「選課系統」進行快速選課。",
    style: TextStyle(height: 1.5, fontSize: 15, color: colorScheme.bodyText),
  );

  showDialog(
    context: context,
    barrierColor: Colors.black54,
    builder: (context) {
      if (isLiquidGlass) {
        final decoration = BoxDecoration(
          color: isDark
              ? const Color(0xFF1C2333).withValues(alpha: 0.92)
              : Colors.white.withValues(alpha: 0.94),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.18)
                : Colors.white.withValues(alpha: 0.70),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.15),
              blurRadius: 28,
              offset: const Offset(0, 8),
            ),
          ],
        );

        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 40,
          ),
          child: Container(
            decoration: decoration,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(19),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.lightbulb_outline,
                          color: Colors.orange,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          "選課助手功能說明",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: colorScheme.primaryText,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    bodyText,
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(
                          "我知道了",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.primary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }

      return AlertDialog(
        backgroundColor: colorScheme.cardBackground,
        title: Row(
          children: [
            const Icon(Icons.lightbulb_outline, color: Colors.orange),
            const SizedBox(width: 8),
            Text(
              "選課助手功能說明",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: colorScheme.primaryText,
              ),
            ),
          ],
        ),
        content: bodyText,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              "我知道了",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: colorScheme.primary,
              ),
            ),
          ),
        ],
      );
    },
  );
}
