import 'package:flutter/material.dart';

import '../../../models/course_assistant_models.dart';
import '../../../models/course_model.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/layout_style_notifier.dart';
import '../course_assistant_constants.dart';
import '../course_assistant_utils.dart';

/// 管理已加入課程與行程 bottom sheet（原 _showManageCoursesSheet）
void showManageCoursesSheet(
  BuildContext context, {
  required List<Course> courses,
  required List<CustomEvent> events,
  required Future<void> Function(Course course) onRemoveCourse,
  required Future<void> Function(String eventId) onRemoveEvent,
}) {
  final colorScheme = Theme.of(context).colorScheme;
  final isLiquidGlass = LayoutStyleNotifier.instance.isLiquidGlass;
  final isDark = colorScheme.isDark;

  Widget buildBody(BuildContext modalContext, StateSetter setModalState) {
    return Container(
      height: MediaQuery.of(modalContext).size.height * 0.6,
      padding: const EdgeInsets.only(top: 16, left: 16, right: 16, bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "管理已加入課程與行程",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.primaryText,
                ),
              ),
              IconButton(
                icon: Icon(Icons.close, color: colorScheme.iconColor),
                onPressed: () => Navigator.pop(modalContext),
              ),
            ],
          ),
          Divider(color: colorScheme.borderColor),
          Expanded(
            child: (courses.isEmpty && events.isEmpty)
                ? Center(
                    child: Text(
                      "目前沒有任何模擬課程或行程",
                      style: TextStyle(color: colorScheme.subtitleText),
                    ),
                  )
                : ListView(
                    children: [
                      if (courses.isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            "正規課程",
                            style: TextStyle(
                              color: colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        ...courses.map(
                          (c) => ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              c.name.split('\n')[0],
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: colorScheme.primaryText,
                              ),
                            ),
                            subtitle: Text(
                              "${c.code} · ${c.professor}\n${formatCourseTimeWithRange(c).replaceAll('\n', ' ')}",
                              style: TextStyle(color: colorScheme.subtitleText),
                            ),
                            trailing: IconButton(
                              icon: const Icon(
                                Icons.delete_outline,
                                color: Colors.red,
                              ),
                              onPressed: () async {
                                await onRemoveCourse(c);
                                setModalState(() {});
                              },
                            ),
                          ),
                        ),
                      ],
                      if (events.isNotEmpty) ...[
                        Divider(color: colorScheme.borderColor),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            "其他行程",
                            style: TextStyle(
                              color: colorScheme.subtitleText,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        ...events.map(
                          (e) => ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              e.title,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: colorScheme.primaryText,
                              ),
                            ),
                            subtitle: Text(
                              "星期${kFullWeekDays[e.day - 1]} (${e.periods.join(', ')}節)\n${e.details}",
                              style: TextStyle(color: colorScheme.subtitleText),
                            ),
                            trailing: IconButton(
                              icon: const Icon(
                                Icons.delete_outline,
                                color: Colors.red,
                              ),
                              onPressed: () async {
                                await onRemoveEvent(e.id);
                                setModalState(() {});
                              },
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  if (isLiquidGlass) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black54,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Container(
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF1E222D).withValues(alpha: 0.90)
                    : Colors.white.withValues(alpha: 0.90),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.12)
                      : Colors.black.withValues(alpha: 0.08),
                  width: 1.0,
                ),
              ),
              child: buildBody(context, setModalState),
            );
          },
        );
      },
    );
    return;
  }

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
          return buildBody(context, setModalState);
        },
      );
    },
  );
}
