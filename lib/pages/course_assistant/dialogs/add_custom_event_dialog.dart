import 'package:flutter/material.dart';

import '../../../models/course_assistant_models.dart';
import '../../../theme/app_theme.dart';
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

  showDialog(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: colorScheme.cardBackground,
            title: Text(
              "新增其他行程",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: colorScheme.primaryText,
              ),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    style: TextStyle(color: colorScheme.primaryText),
                    decoration: InputDecoration(
                      labelText: '標題 (如: 工讀、社團)',
                      labelStyle: TextStyle(color: colorScheme.subtitleText),
                      border: const OutlineInputBorder(),
                      filled: true,
                      fillColor: colorScheme.subtleBackground,
                    ),
                    onChanged: (val) => title = val,
                  ),
                  const SizedBox(height: 12),
                  // 位置的輸入框
                  TextField(
                    style: TextStyle(color: colorScheme.primaryText),
                    decoration: InputDecoration(
                      labelText: '位置',
                      labelStyle: TextStyle(color: colorScheme.subtitleText),
                      border: const OutlineInputBorder(),
                      filled: true,
                      fillColor: colorScheme.subtleBackground,
                    ),
                    onChanged: (val) => location = val,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    style: TextStyle(color: colorScheme.primaryText),
                    decoration: InputDecoration(
                      labelText: '詳細內容 (地點、備註)',
                      labelStyle: TextStyle(color: colorScheme.subtitleText),
                      border: const OutlineInputBorder(),
                      filled: true,
                      fillColor: colorScheme.subtleBackground,
                    ),
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
                  DropdownButton<int>(
                    isExpanded: true,
                    value: selectedDay,
                    dropdownColor: colorScheme.cardBackground,
                    style: TextStyle(color: colorScheme.primaryText),
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
                      if (val != null)
                        setDialogState(() => selectedDay = val);
                    },
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
                        backgroundColor: colorScheme.subtleBackground,
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
            ),
            actions: [
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
                        (a, b) => kPeriods
                            .indexOf(a)
                            .compareTo(kPeriods.indexOf(b)),
                      ),
                    location: location.trim(),
                  );

                  Navigator.pop(context);
                  await onSave(newEvent);
                },
                child: const Text("儲存"),
              ),
            ],
          );
        },
      );
    },
  );
}