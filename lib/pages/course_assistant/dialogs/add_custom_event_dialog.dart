import 'package:flutter/material.dart';

import '../../../models/course_assistant_models.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/layout_style_notifier.dart';
import '../course_assistant_constants.dart';
import '../course_assistant_utils.dart';

/// 新增其他行程對話框（原 _showAddCustomEventDialog）
///
/// onSave 由主 State 實作：加入 _customEvents、寫入 prefs、_loadAllData、
/// 顯示「行程已加入！」snackbar。
void showAddCustomEventDialog(
  BuildContext context, {
  required Future<void> Function(CustomEvent event) onSave,
}) {
  String title = '';
  String details = '';
  String location = '';
  int selectedDay = 1; // 預設星期一
  Set<String> selectedPeriods = {};
  final colorScheme = Theme.of(context).colorScheme;
  final isLiquidGlass = LayoutStyleNotifier.instance.isLiquidGlass;
  final isDark = colorScheme.isDark;
  final Color fieldFill = isLiquidGlass
      ? (isDark
            ? Colors.white.withValues(alpha: 0.06)
            : Colors.white.withValues(alpha: 0.4))
      : colorScheme.subtleBackground;
  final Color fieldBorder = isLiquidGlass
      ? (isDark
            ? Colors.white.withValues(alpha: 0.35)
            : Colors.black.withValues(alpha: 0.08))
      : colorScheme.borderColor;
  InputDecoration fieldDecoration(String label) => InputDecoration(
    labelText: label,
    labelStyle: TextStyle(color: colorScheme.subtitleText),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: fieldBorder, width: 1.0),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: fieldBorder, width: 1.0),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
    ),
    filled: true,
    fillColor: fieldFill,
  );

  showDialog(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          final content = SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  style: TextStyle(color: colorScheme.primaryText),
                  decoration: fieldDecoration('標題 (如: 工讀、社團)'),
                  onChanged: (val) => title = val,
                ),
                const SizedBox(height: 12),
                // 位置的輸入框
                TextField(
                  style: TextStyle(color: colorScheme.primaryText),
                  decoration: fieldDecoration('位置'),
                  onChanged: (val) => location = val,
                ),
                const SizedBox(height: 12),
                TextField(
                  style: TextStyle(color: colorScheme.primaryText),
                  decoration: fieldDecoration('詳細內容 (地點、備註)'),
                  maxLines: 2,
                  onChanged: (val) => details = val,
                ),
                const SizedBox(height: 16),
                Text(
                  "選擇星期：",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.subtitleText,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: isLiquidGlass
                      ? BoxDecoration(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.08)
                              : Colors.white.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.12)
                                : Colors.black.withValues(alpha: 0.08),
                            width: 1.0,
                          ),
                        )
                      : null,
                  child: DropdownButton<int>(
                    isExpanded: true,
                    value: selectedDay,
                    dropdownColor: colorScheme.cardBackground,
                    style: TextStyle(color: colorScheme.primaryText),
                    underline: isLiquidGlass ? const SizedBox.shrink() : null,
                    items: List.generate(7, (index) {
                      return DropdownMenuItem(
                        value: index + 1,
                        child: Text(
                          "星期${kFullWeekDays[index]}",
                          style: TextStyle(color: colorScheme.primaryText),
                        ),
                      );
                    }),
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() => selectedDay = val);
                      }
                    },
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  "選擇節次 (可多選)：",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.subtitleText,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6.0,
                  runSpacing: 4.0,
                  children: kPeriods.map((p) {
                    final isSelected = selectedPeriods.contains(p);
                    return FilterChip(
                      label: Text(
                        p,
                        style: TextStyle(
                          color: isSelected
                              ? colorScheme.primary
                              : colorScheme.primaryText,
                        ),
                      ),
                      selected: isSelected,
                      selectedColor: colorScheme.primaryContainer,
                      backgroundColor: isLiquidGlass
                          ? (isDark
                                ? Colors.white.withValues(alpha: 0.06)
                                : Colors.white.withValues(alpha: 0.4))
                          : colorScheme.subtleBackground,
                      checkmarkColor: colorScheme.primary,
                      showCheckmark: false,
                      onSelected: (bool selected) {
                        setDialogState(() {
                          if (selected) {
                            selectedPeriods.add(p);
                          } else {
                            selectedPeriods.remove(p);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
              ],
            ),
          );
          final actions = [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                "取消",
                style: TextStyle(color: colorScheme.subtitleText),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: colorScheme.primary,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                if (title.trim().isEmpty || selectedPeriods.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text("請填寫標題並至少選擇一節課"),
                      duration: const Duration(milliseconds: 1500),
                    ),
                  );
                  return;
                }
                if (calculateTextLength(location.trim()) > 6.0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text("位置輸入過長，請縮減至6個中文字或12個英數字以內"),
                      duration: const Duration(milliseconds: 1500),
                    ),
                  );
                  return;
                }
                final newEvent = CustomEvent(
                  id: DateTime.now().millisecondsSinceEpoch
                      .toString(), // 產生唯一ID
                  title: title.trim(),
                  details: details.trim(),
                  day: selectedDay,
                  periods: selectedPeriods.toList()
                    ..sort(
                      (a, b) =>
                          kPeriods.indexOf(a).compareTo(kPeriods.indexOf(b)),
                    ),
                  location: location.trim(),
                );

                Navigator.pop(context);
                await onSave(newEvent);
              },
              child: const Text("儲存"),
            ),
          ];

          if (isLiquidGlass) {
            return Dialog(
              backgroundColor: Colors.transparent,
              elevation: 0,
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 40,
                vertical: 24,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 320),
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF1E222D).withValues(alpha: 0.90)
                        : Colors.white.withValues(alpha: 0.90),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.12)
                          : Colors.black.withValues(alpha: 0.08),
                      width: 1.0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(
                          alpha: isDark ? 0.3 : 0.08,
                        ),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          "新增其他行程",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: colorScheme.primaryText,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Flexible(child: content),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: actions,
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
            title: Text(
              "新增其他行程",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: colorScheme.primaryText,
              ),
            ),
            content: content,
            actions: actions,
          );
        },
      );
    },
  );
}
