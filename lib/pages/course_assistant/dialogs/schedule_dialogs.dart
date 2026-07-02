import 'package:flutter/material.dart';

import '../../../models/course_assistant_models.dart';
import '../../../theme/app_theme.dart';

/// 新增課表對話框（原 _showAddScheduleDialog）
///
/// onCreate 由主 State 實作：產生 newId、寫入 _schedules、依 cloneCurrent
/// 複製課程/行程、切換至新課表、顯示 snackbar。
void showAddScheduleDialog(
  BuildContext context, {
  required Future<void> Function(String name, bool cloneCurrent) onCreate,
}) {
  final colorScheme = Theme.of(context).colorScheme;
  String newName = "";
  bool cloneCurrent = false;

  showDialog(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: colorScheme.cardBackground,
            title: Text(
              "新增課表",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: colorScheme.primaryText,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  style: TextStyle(color: colorScheme.primaryText),
                  decoration: InputDecoration(
                    labelText: '課表名稱',
                    labelStyle: TextStyle(color: colorScheme.subtitleText),
                    border: const OutlineInputBorder(),
                    filled: true,
                    fillColor: colorScheme.subtleBackground,
                  ),
                  onChanged: (val) => newName = val,
                ),
                const SizedBox(height: 16),
                CheckboxListTile(
                  title: Text(
                    "複製當前課表內容",
                    style: TextStyle(color: colorScheme.primaryText),
                  ),
                  subtitle: Text(
                    "包含所有正規課程與自訂行程",
                    style: TextStyle(
                      color: colorScheme.subtitleText,
                      fontSize: 12,
                    ),
                  ),
                  value: cloneCurrent,
                  activeColor: colorScheme.primary,
                  checkColor: Colors.white,
                  contentPadding: EdgeInsets.zero,
                  onChanged: (val) {
                    if (val != null) {
                      setDialogState(() {
                        cloneCurrent = val;
                      });
                    }
                  },
                ),
              ],
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
                  if (newName.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text("請輸入課表名稱"),
                        duration: const Duration(milliseconds: 1500),
                      ),
                    );
                    return;
                  }
                  Navigator.pop(context);
                  await onCreate(newName.trim(), cloneCurrent);
                },
                child: const Text("新增"),
              ),
            ],
          );
        },
      );
    },
  );
}

/// 課表操作選單 bottom sheet（原 _showScheduleActionMenu）
void showScheduleActionMenu(
  BuildContext context,
  AssistantSchedule schedule,
  int scheduleCount, {
  required VoidCallback onRename,
  required VoidCallback onClone,
  required VoidCallback onDelete,
}) {
  final colorScheme = Theme.of(context).colorScheme;
  showModalBottomSheet(
    context: context,
    backgroundColor: colorScheme.cardBackground,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (context) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                "管理課表：${schedule.name}",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.primaryText,
                ),
              ),
            ),
            Divider(height: 1, color: colorScheme.borderColor),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text("重新命名"),
              onTap: () {
                Navigator.pop(context);
                onRename();
              },
            ),
            ListTile(
              leading: const Icon(Icons.copy_all_outlined),
              title: const Text("複製課表"),
              onTap: () {
                Navigator.pop(context);
                onClone();
              },
            ),
            if (scheduleCount > 1)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text(
                  "刪除課表",
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () {
                  Navigator.pop(context);
                  onDelete();
                },
              ),
          ],
        ),
      );
    },
  );
}

/// 重新命名課表對話框（原 _showRenameScheduleDialog）
void showRenameScheduleDialog(
  BuildContext context,
  AssistantSchedule schedule, {
  required Future<void> Function(AssistantSchedule schedule, String newName) onRename,
}) {
  final colorScheme = Theme.of(context).colorScheme;
  String newName = schedule.name;

  showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        backgroundColor: colorScheme.cardBackground,
        title: const Text("重新命名課表"),
        content: TextField(
          controller: TextEditingController(text: schedule.name),
          style: TextStyle(color: colorScheme.primaryText),
          decoration: InputDecoration(
            labelText: '課表名稱',
            labelStyle: TextStyle(color: colorScheme.subtitleText),
            border: const OutlineInputBorder(),
            filled: true,
            fillColor: colorScheme.subtleBackground,
          ),
          onChanged: (val) => newName = val,
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
              if (newName.trim().isEmpty) {
                return;
              }
              Navigator.pop(context);
              await onRename(schedule, newName.trim());
            },
            child: const Text("儲存"),
          ),
        ],
      );
    },
  );
}

/// 複製課表對話框（原 _showCloneScheduleDialog）
void showCloneScheduleDialog(
  BuildContext context,
  AssistantSchedule schedule, {
  required Future<void> Function(AssistantSchedule source, String newName) onClone,
}) {
  final colorScheme = Theme.of(context).colorScheme;
  String newName = "${schedule.name} - 複製";

  showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        backgroundColor: colorScheme.cardBackground,
        title: const Text("複製課表"),
        content: TextField(
          controller: TextEditingController(text: newName),
          style: TextStyle(color: colorScheme.primaryText),
          decoration: InputDecoration(
            labelText: '新課表名稱',
            labelStyle: TextStyle(color: colorScheme.subtitleText),
            border: const OutlineInputBorder(),
            filled: true,
            fillColor: colorScheme.subtleBackground,
          ),
          onChanged: (val) => newName = val,
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
              if (newName.trim().isEmpty) {
                return;
              }
              Navigator.pop(context);
              await onClone(schedule, newName.trim());
            },
            child: const Text("複製"),
          ),
        ],
      );
    },
  );
}

/// 刪除課表確認對話框（原 _showDeleteScheduleConfirmDialog）
void showDeleteScheduleConfirmDialog(
  BuildContext context,
  AssistantSchedule schedule, {
  required Future<void> Function(AssistantSchedule schedule) onDelete,
}) {
  final colorScheme = Theme.of(context).colorScheme;

  showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        backgroundColor: colorScheme.cardBackground,
        title: const Text("確認刪除課表"),
        content: Text(
          "您確定要刪除「${schedule.name}」嗎？這將會永久刪除此課表中的所有模擬課程與自訂行程且無法復原。",
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
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(context);
              await onDelete(schedule);
            },
            child: const Text("確定刪除"),
          ),
        ],
      );
    },
  );
}

/// 管理課表 bottom sheet（原 _showManageSchedulesSheet）
///
/// onRename/onClone/onDelete 為「開啟對應對話框」的回呼（由主 State 提供）。
void showManageSchedulesSheet(
  BuildContext context, {
  required List<AssistantSchedule> schedules,
  required String currentScheduleId,
  required void Function(AssistantSchedule schedule) onRename,
  required void Function(AssistantSchedule schedule) onClone,
  required void Function(AssistantSchedule schedule) onDelete,
}) {
  final colorScheme = Theme.of(context).colorScheme;
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: colorScheme.cardBackground,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) {
      return StatefulBuilder(
        builder: (BuildContext context, StateSetter setModalState) {
          return Container(
            height: MediaQuery.of(context).size.height * 0.5,
            padding: const EdgeInsets.only(
              top: 16,
              left: 16,
              right: 16,
              bottom: 20,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "管理課表",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.primaryText,
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: colorScheme.iconColor),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                Divider(color: colorScheme.borderColor),
                Expanded(
                  child: ListView.builder(
                    itemCount: schedules.length,
                    itemBuilder: (context, index) {
                      final schedule = schedules[index];
                      final isCurrent = schedule.id == currentScheduleId;

                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Row(
                          children: [
                            Text(
                              schedule.name,
                              style: TextStyle(
                                fontWeight: isCurrent
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color: isCurrent
                                    ? colorScheme.primary
                                    : colorScheme.primaryText,
                              ),
                            ),
                            if (isCurrent) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: colorScheme.primary.withValues(
                                    alpha: 0.1,
                                  ),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  "當前使用中",
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: colorScheme.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, size: 20),
                              onPressed: () {
                                Navigator.pop(context); // Pop BottomSheet
                                onRename(schedule);
                              },
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.copy_all_outlined,
                                size: 20,
                              ),
                              onPressed: () {
                                Navigator.pop(context); // Pop BottomSheet
                                onClone(schedule);
                              },
                            ),
                            if (schedules.length > 1)
                              IconButton(
                                icon: const Icon(
                                  Icons.delete_outline,
                                  color: Colors.red,
                                  size: 20,
                                ),
                                onPressed: () {
                                  Navigator.pop(context); // Pop BottomSheet
                                  onDelete(schedule);
                                },
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}