import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';

/// 選課助手功能說明對話框（原 _showInfoDialog）
void showInfoDialog(BuildContext context) {
  final colorScheme = Theme.of(context).colorScheme;
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
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
      content: Text(
        "1. 提供自訂排課功能，模擬你的專屬課表。\n\n"
        "2. 方便在加簽時快速查看教室與上課時間等資訊。\n\n"
        "3. 支援新增「其他行程」(如工讀、社團)，協助管理個人時間。\n\n"
        "4. 支援從「選課小幫手」網站匯入課表。\n\n"
        "5. 排好的正規課程可直接匯出至「選課系統」進行快速選課。",
        style: TextStyle(
          height: 1.5,
          fontSize: 15,
          color: colorScheme.bodyText,
        ),
      ),
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
    ),
  );
}