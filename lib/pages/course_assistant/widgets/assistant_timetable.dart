import 'package:flutter/material.dart';

import '../../../models/course_assistant_models.dart';
import '../../../models/course_model.dart';
import '../../../theme/app_theme.dart';
import '../course_assistant_constants.dart';
import '../course_assistant_utils.dart';

/// 選課助手課表渲染（原 _buildTimeTable）
class AssistantTimetable extends StatelessWidget {
  final List<Course> courses;
  final List<CustomEvent> events;
  final void Function(Course course) onCourseTap;
  final void Function(CustomEvent event) onEventTap;
  final double? screenWidth;

  const AssistantTimetable({
    super.key,
    required this.courses,
    required this.events,
    required this.onCourseTap,
    required this.onEventTap,
    this.screenWidth,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final headerBgColor = colorScheme.isDark
        ? const Color(0xFF252B3B)
        : const Color(0xFFF4F8FF);
    int maxDay = 5;

    // 計算課程的最大天數與節次
    for (var c in courses) {
      for (var t in c.parsedTimes) {
        if (t.day == 6 && maxDay < 6) maxDay = 6;
        if (t.day == 7) maxDay = 7;
      }
    }
    // 計算自訂行程的最大天數與節次
    for (var e in events) {
      if (e.day == 6 && maxDay < 6) maxDay = 6;
      if (e.day == 7) maxDay = 7;
    }

    List<String> visibleWeekDays = kFullWeekDays.sublist(0, maxDay);

    final double actualWidth = screenWidth ?? MediaQuery.of(context).size.width;
    final bool isTablet = actualWidth >= 750;
    final double periodColWidth = maxDay > 5
        ? (isTablet ? 42.0 : 36.0)
        : (isTablet ? 52.0 : 45.0);
    final double headerHeight = isTablet ? 40.0 : 32.0;

    // Calculate font sizes dynamically for cells based on screen width
    double titleFontSize = 10.0;
    double locationFontSize = 8.0;
    final sw = screenWidth;
    if (sw != null) {
      double timetableWidth;
      if (sw < 800) {
        timetableWidth = sw;
      } else if (sw < 1200) {
        timetableWidth = sw * 0.6;
      } else {
        timetableWidth = sw * 0.38;
      }
      double columnWidth = (timetableWidth - periodColWidth) / maxDay;

      titleFontSize = (10.0 + (columnWidth - 60.0) * 0.1).clamp(8.0, 14.0);
      locationFontSize = (8.0 + (columnWidth - 60.0) * 0.08).clamp(7.0, 11.0);
    }

    bool hasPeriodA = false;
    int maxPeriodIndex = kPeriods.indexOf('7');

    for (var c in courses) {
      for (var t in c.parsedTimes) {
        if (t.period == 'A') hasPeriodA = true;
        int currentIndex = kPeriods.indexOf(t.period);
        if (currentIndex > maxPeriodIndex) maxPeriodIndex = currentIndex;
      }
    }
    for (var e in events) {
      for (var p in e.periods) {
        if (p == 'A') hasPeriodA = true;
        int currentIndex = kPeriods.indexOf(p);
        if (currentIndex > maxPeriodIndex) maxPeriodIndex = currentIndex;
      }
    }

    int displayEndIndex = maxPeriodIndex;
    if (displayEndIndex < kPeriods.length - 1) displayEndIndex += 1;
    int startIndex = hasPeriodA ? 0 : kPeriods.indexOf('1');
    List<String> visiblePeriods = kPeriods.sublist(
      startIndex,
      displayEndIndex + 1,
    );

    // 建立課程 Map
    Map<String, List<Course>> courseMap = {};
    for (var c in courses) {
      for (var t in c.parsedTimes) {
        String key = "${t.day}-${t.period}";
        if (!courseMap.containsKey(key)) courseMap[key] = [];
        courseMap[key]!.add(c);
      }
    }

    // 建立自訂行程 Map
    Map<String, List<CustomEvent>> eventMap = {};
    for (var e in events) {
      for (var p in e.periods) {
        String key = "${e.day}-$p";
        if (!eventMap.containsKey(key)) eventMap[key] = [];
        eventMap[key]!.add(e);
      }
    }

    return Container(
      color: colorScheme.isDark
          ? colorScheme.scaffoldBackground
          : Colors.grey[50],
      child: Table(
        border: TableBorder.all(color: colorScheme.borderColor, width: 0.5),
        columnWidths: {0: FixedColumnWidth(periodColWidth)},
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        children: [
          TableRow(
            decoration: BoxDecoration(color: headerBgColor),
            children: [
              SizedBox(
                height: headerHeight,
                child: Center(
                  child: Text(
                    "時段",
                    style: TextStyle(
                      fontSize: 10,
                      color: colorScheme.subtitleText,
                    ),
                  ),
                ),
              ),
              ...visibleWeekDays.map(
                (d) => Container(
                  height: headerHeight,
                  alignment: Alignment.center,
                  child: Text(
                    d,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: colorScheme.primaryText,
                    ),
                  ),
                ),
              ),
            ],
          ),
          ...visiblePeriods.map((period) {
            String timeInfo = kTimeMapping[period] ?? "";

            // 檢查此節次中，是否每一天都只有最多一個項目（無衝突）
            bool hasConflict = false;
            double maxCellHeight = 70.0;

            for (int d = 1; d <= maxDay; d++) {
              var cellCourses = courseMap["$d-$period"] ?? [];
              var cellEvents = eventMap["$d-$period"] ?? [];
              int cellItemCount = cellCourses.length + cellEvents.length;

              if (cellItemCount >= 2) {
                hasConflict = true;
              } else if (cellItemCount == 1) {
                double h = 70.0;
                if (cellCourses.isNotEmpty) {
                  final displayName = keepUntilLastChinese(cellCourses.first.name);
                  if (displayName.length > 20) {
                    h += 30.0;
                  } else if (displayName.length > 15) {
                    h += 20.0;
                  } else if (displayName.length > 10) {
                    h += 10.0;
                  }
                } else if (cellEvents.isNotEmpty) {
                  final displayName = cellEvents.first.title;
                  if (displayName.length > 20) {
                    h += 30.0;
                  } else if (displayName.length > 15) {
                    h += 20.0;
                  } else if (displayName.length > 10) {
                    h += 10.0;
                  }
                }
                if (h > maxCellHeight) {
                  maxCellHeight = h;
                }
              }
            }

            // 如果整個星期中此節次都沒有任何天有衝突，就計算最高的高度作為 overrideHeight
            double? overrideHeight;
            if (!hasConflict) {
              overrideHeight = maxCellHeight;
            }

            return TableRow(
              children: [
                TableCell(
                  verticalAlignment: TableCellVerticalAlignment.fill,
                  child: Container(
                    color: headerBgColor,
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          period,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: colorScheme.primaryText,
                          ),
                        ),
                        if (timeInfo.isNotEmpty)
                          Text(
                            timeInfo,
                            style: TextStyle(
                              fontSize: 9,
                              color: colorScheme.subtitleText,
                            ),
                            textAlign: TextAlign.center,
                          ),
                      ],
                    ),
                  ),
                ),
                ...List.generate(maxDay, (dayIndex) {
                  int currentDay = dayIndex + 1;
                  List<Course> cellCourses =
                      courseMap["$currentDay-$period"] ?? [];
                  List<CustomEvent> cellEvents =
                      eventMap["$currentDay-$period"] ?? [];

                  // 情況一：完全空堂
                  if (cellCourses.isEmpty && cellEvents.isEmpty) {
                    return Container(height: overrideHeight ?? 70);
                  }

                  // 情況二：這個時段「只有一堂正規課程」
                  if (cellCourses.length == 1 && cellEvents.isEmpty) {
                    final cellCourse = cellCourses.first;
                    final displayName = keepUntilLastChinese(cellCourse.name);
                    double cellHeight = overrideHeight ?? 70.0;
                    if (overrideHeight == null) {
                      if (displayName.length > 20) {
                        cellHeight += 30.0;
                      } else if (displayName.length > 15) {
                        cellHeight += 20.0;
                      } else if (displayName.length > 10) {
                        cellHeight += 10.0;
                      }
                    }
                    return Container(
                      height: cellHeight, // 保留基本高度，不被壓縮
                      padding: const EdgeInsets.all(1.0),
                      child: Material(
                        color: getCourseColor(cellCourse.name),
                        borderRadius: BorderRadius.circular(4),
                        child: InkWell(
                          onTap: () => onCourseTap(cellCourse),
                          child: Container(
                            width: double.infinity,
                            height: double.infinity, // 內部撐滿高度
                            padding: const EdgeInsets.symmetric(
                              vertical: 4,
                              horizontal: 2,
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Flexible(
                                  child: Text(
                                    displayName,
                                    style: TextStyle(
                                      fontSize: titleFontSize,
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  extractLocation(cellCourse.location),
                                  style: TextStyle(
                                    fontSize: locationFontSize,
                                    color: Colors.white70,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }

                  // 情況三：這個時段「只有一個自訂行程」
                  if (cellEvents.length == 1 && cellCourses.isEmpty) {
                    final cellEvent = cellEvents.first;
                    final displayName = cellEvent.title;
                    double cellHeight = overrideHeight ?? 70.0;
                    if (overrideHeight == null) {
                      if (displayName.length > 20) {
                        cellHeight += 30.0;
                      } else if (displayName.length > 15) {
                        cellHeight += 20.0;
                      } else if (displayName.length > 10) {
                        cellHeight += 10.0;
                      }
                    }
                    return Container(
                      height: cellHeight, // 保留基本高度，不被壓縮
                      padding: const EdgeInsets.all(1.0),
                      child: Material(
                        color: getCourseColor(cellEvent.title), // 套用彩色
                        borderRadius: BorderRadius.circular(4),
                        child: InkWell(
                          onTap: () => onEventTap(cellEvent),
                          child: Container(
                            width: double.infinity,
                            height: double.infinity, // 內部撐滿高度
                            padding: const EdgeInsets.symmetric(
                              vertical: 4,
                              horizontal: 2,
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Flexible(
                                  child: Text(
                                    displayName,
                                    style: TextStyle(
                                      fontSize: titleFontSize,
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                if (cellEvent.location.isNotEmpty) // 有位置才顯示
                                  Text(
                                    cellEvent.location,
                                    style: TextStyle(
                                      fontSize: locationFontSize,
                                      color: Colors.white70,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }

                  // 情況四：同一個時段有多個項目 (衝堂：包含多堂課、多個行程、或課跟行程重疊)
                  List<Widget> cellWidgets = [];

                  // 渲染多堂正規課程
                  for (var cellCourse in cellCourses) {
                    cellWidgets.add(
                      Padding(
                        padding: const EdgeInsets.only(bottom: 2.0),
                        child: Material(
                          color: getCourseColor(cellCourse.name),
                          borderRadius: BorderRadius.circular(4),
                          child: InkWell(
                            onTap: () => onCourseTap(cellCourse),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                vertical: 4,
                                horizontal: 2,
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    keepUntilLastChinese(cellCourse.name),
                                    style: TextStyle(
                                      fontSize: titleFontSize,
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    extractLocation(cellCourse.location),
                                    style: TextStyle(
                                      fontSize: locationFontSize,
                                      color: Colors.white70,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }

                  // 渲染多個自訂行程
                  for (var cellEvent in cellEvents) {
                    cellWidgets.add(
                      Padding(
                        padding: const EdgeInsets.only(bottom: 2.0),
                        child: Material(
                          color: getCourseColor(cellEvent.title),
                          borderRadius: BorderRadius.circular(4),
                          child: InkWell(
                            onTap: () => onEventTap(cellEvent),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                vertical: 4,
                                horizontal: 2,
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    cellEvent.title,
                                    style: TextStyle(
                                      fontSize: titleFontSize,
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 2),
                                  if (cellEvent.location.isNotEmpty)
                                    Text(
                                      cellEvent.location,
                                      style: TextStyle(
                                        fontSize: locationFontSize,
                                        color: Colors.white70,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }

                  return Container(
                    constraints: const BoxConstraints(
                      minHeight: 70,
                    ), // 多堂課時讓他自適應長高
                    padding: const EdgeInsets.all(1),
                    color: colorScheme.isDark
                        ? colorScheme.scaffoldBackground
                        : Colors.grey[50],
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: cellWidgets,
                    ),
                  );
                }),
              ],
            );
          }),
        ],
      ),
    );
  }
}