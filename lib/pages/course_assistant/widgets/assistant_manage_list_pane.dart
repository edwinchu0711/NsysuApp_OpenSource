import 'package:flutter/material.dart';

import '../../../models/course_assistant_models.dart';
import '../../../models/course_model.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/layout_style_notifier.dart';
import '../../../widgets/glass/glass_card.dart';
import '../course_assistant_constants.dart';
import '../course_assistant_utils.dart';

/// 寬版面左側的管理清單面板（原 _buildManageListPaneInline）
class ManageListPaneInline extends StatelessWidget {
  final List<Course> courses;
  final List<CustomEvent> events;
  final Future<void> Function(Course course) onRemoveCourse;
  final Future<void> Function(String eventId) onRemoveEvent;

  const ManageListPaneInline({
    super.key,
    required this.courses,
    required this.events,
    required this.onRemoveCourse,
    required this.onRemoveEvent,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isLiquidGlass = LayoutStyleNotifier.instance.isLiquidGlass;

    return Container(
      decoration: BoxDecoration(
        color: isLiquidGlass ? Colors.transparent : colorScheme.cardBackground,
        border: Border(
          right: BorderSide(
            color: isLiquidGlass
                ? (colorScheme.isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.white.withValues(alpha: 0.35))
                : colorScheme.borderColor,
            width: 0.5,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(
              left: 16.0,
              right: 16.0,
              top: 16.0,
              bottom: 12.0,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "管理清單",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primaryText,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    "${courses.length} 門課程 / ${getTotalCredits(courses)} 學分",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Divider(
            height: 1,
            color: isLiquidGlass
                ? (colorScheme.isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.white.withValues(alpha: 0.35))
                : colorScheme.borderColor,
          ),
          Expanded(
            child: (courses.isEmpty && events.isEmpty)
                ? Center(
                    child: Text(
                      "目前沒有任何項目",
                      style: TextStyle(color: colorScheme.subtitleText),
                    ),
                  )
                : ListView(
                    padding: EdgeInsets.only(
                      left: 16,
                      right: 16,
                      top: 8,
                      bottom: isLiquidGlass ? 100 : 8,
                    ),
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
                          (c) => Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: isLiquidGlass
                                ? glassCardDecoration(context, borderRadius: 8)
                                : BoxDecoration(
                                    color: colorScheme.subtleBackground,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: colorScheme.borderColor,
                                      width: 0.5,
                                    ),
                                  ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 4,
                              ),
                              title: Text(
                                c.name.split('\n')[0],
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.primaryText,
                                  fontSize: 14,
                                ),
                              ),
                              subtitle: Text(
                                "${c.code} · ${c.professor}\n${formatCourseTimeWithRange(c).replaceAll('\n', ' ')}",
                                style: TextStyle(
                                  color: colorScheme.subtitleText,
                                  fontSize: 12,
                                ),
                              ),
                              trailing: IconButton(
                                icon: const Icon(
                                  Icons.delete_outline,
                                  color: Colors.red,
                                  size: 20,
                                ),
                                onPressed: () => onRemoveCourse(c),
                              ),
                            ),
                          ),
                        ),
                      ],
                      if (events.isNotEmpty) ...[
                        if (courses.isNotEmpty) const SizedBox(height: 12),
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
                          (e) => Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: isLiquidGlass
                                ? glassCardDecoration(context, borderRadius: 8)
                                : BoxDecoration(
                                    color: colorScheme.subtleBackground,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: colorScheme.borderColor,
                                      width: 0.5,
                                    ),
                                  ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 4,
                              ),
                              title: Text(
                                e.title,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.primaryText,
                                  fontSize: 14,
                                ),
                              ),
                              subtitle: Text(
                                "星期${kFullWeekDays[e.day - 1]} (${e.periods.join(', ')}節)\n${e.details}",
                                style: TextStyle(
                                  color: colorScheme.subtitleText,
                                  fontSize: 12,
                                ),
                              ),
                              trailing: IconButton(
                                icon: const Icon(
                                  Icons.delete_outline,
                                  color: Colors.red,
                                  size: 20,
                                ),
                                onPressed: () => onRemoveEvent(e.id),
                              ),
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
}