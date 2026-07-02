import 'package:flutter/material.dart';

import '../../../models/course_model.dart';
import '../../../services/course_query_service.dart';
import '../../../theme/app_theme.dart';
import '../course_assistant_utils.dart';
import '../widgets/detail_row.dart';

/// 課程詳情對話框（原 _showCourseDetail 的 dialog 內容）
///
/// notifiers 與 API 快取由主 State 持有，避免每次開啟都重抓。
class CourseDetailDialog extends StatelessWidget {
  final Course course;
  final ValueNotifier<List<CourseJsonData>> apiCoursesNotifier;
  final ValueNotifier<bool> isApiLoadingNotifier;
  final Future<void> Function(Course course) onRemove;

  const CourseDetailDialog({
    super.key,
    required this.course,
    required this.apiCoursesNotifier,
    required this.isApiLoadingNotifier,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = colorScheme.isDark;
    final courseColor = getCourseColor(course.name);

    final gradient = LinearGradient(
      colors: [
        courseColor,
        HSVColor.fromColor(courseColor)
            .withValue(
              (HSVColor.fromColor(courseColor).value * 0.82).clamp(0.0, 1.0),
            )
            .toColor(),
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    return ValueListenableBuilder<bool>(
      valueListenable: isApiLoadingNotifier,
      builder: (context, isApiLoading, child) {
        return ValueListenableBuilder<List<CourseJsonData>>(
          valueListenable: apiCoursesNotifier,
          builder: (context, apiCourses, child) {
            // 尋找 API 中的系所與學程資訊
            var apiCourseList = apiCourses
                .where((e) => matchCourseCodeExact(e.id, course.code))
                .toList();
            if (apiCourseList.isEmpty) {
              apiCourseList = apiCourses
                  .where((e) => matchCourseCodeFuzzy(e.id, course.code))
                  .toList();
            }
            final CourseJsonData? apiCourse = apiCourseList.isNotEmpty
                ? apiCourseList.first
                : null;
            final hasApiData = apiCourse != null;
            final departmentText = hasApiData ? apiCourse.department : "未指定";
            final List<String> tags = hasApiData ? apiCourse.tags : [];

            // 中英文分離標題
            final nameParts = splitCourseName(course.name);
            final chineseName = nameParts["chinese"]!;
            final englishName = nameParts["english"]!;

            final List<Widget> detailRows = [];

            // 1. 學分與選別
            final showCredits =
                course.credits.isNotEmpty || course.required.isNotEmpty;
            if (showCredits) {
              detailRows.add(
                ModernDetailRow(
                  icon: Icons.stars_rounded,
                  iconColor: Colors.deepPurpleAccent,
                  label: "學分",
                  content: Text(
                    course.required.trim().isNotEmpty &&
                            course.required.trim() != "未指定"
                        ? "${course.credits}學分"
                        : "${course.credits}學分",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.primaryText,
                    ),
                  ),
                ),
              );
            }

            // 2. 教授
            final showProfessor =
                course.professor.isNotEmpty &&
                course.professor != "未指定" &&
                course.professor != "未提供";
            if (showProfessor) {
              detailRows.add(
                ModernDetailRow(
                  icon: Icons.person_rounded,
                  iconColor: Colors.orange,
                  label: "授課教授",
                  content: Text(
                    course.professor,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.primaryText,
                    ),
                  ),
                ),
              );
            }

            // 3. 地點
            final locationText = extractLocation(course.location);
            final showLocation =
                locationText.isNotEmpty &&
                locationText != "未指定" &&
                locationText != "無教室資料" &&
                locationText != "無上課地點資料";
            if (showLocation) {
              detailRows.add(
                ModernDetailRow(
                  icon: Icons.location_on_rounded,
                  iconColor: Colors.redAccent,
                  label: "上課教室",
                  content: Text(
                    locationText,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.primaryText,
                    ),
                  ),
                ),
              );
            }

            // 4. 開課系所 (從 API 抓取)
            final showDepartment =
                isApiLoading ||
                (hasApiData &&
                    departmentText.isNotEmpty &&
                    departmentText != "未指定" &&
                    departmentText != "未提供");
            if (showDepartment) {
              detailRows.add(
                ModernDetailRow(
                  icon: Icons.business_rounded,
                  iconColor: Colors.blueAccent,
                  label: "開課系所",
                  isLoading: isApiLoading,
                  content: Text(
                    departmentText,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.primaryText,
                    ),
                  ),
                ),
              );
            }

            // 5. 適用學程 (從 API 抓取)
            final showTags = isApiLoading || (hasApiData && tags.isNotEmpty);
            if (showTags) {
              detailRows.add(
                ModernDetailRow(
                  icon: Icons.school_rounded,
                  iconColor: Colors.teal,
                  label: "適用學程",
                  isLoading: isApiLoading,
                  content: Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: tags
                          .map(
                            (tag) => Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.teal.withOpacity(
                                  isDark ? 0.15 : 0.08,
                                ),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: Colors.teal.withOpacity(
                                    isDark ? 0.3 : 0.2,
                                  ),
                                  width: 0.8,
                                ),
                              ),
                              child: Text(
                                tag,
                                style: TextStyle(
                                  color: isDark
                                      ? Colors.teal[200]
                                      : Colors.teal[800],
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ),
              );
            }

            final prettyTime = formatCourseTimeWithRange(course);

            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              clipBehavior: Clip.antiAlias,
              titlePadding: EdgeInsets.zero,
              title: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 20,
                ),
                decoration: BoxDecoration(gradient: gradient),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (course.semester != null &&
                            course.semester!.isNotEmpty) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              formatSemester(course.semester),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            course.code,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      chineseName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        height: 1.3,
                      ),
                    ),
                    if (englishName.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        englishName,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.85),
                          fontSize: 12,
                          fontWeight: FontWeight.normal,
                          height: 1.2,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              contentPadding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
              content: Container(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (detailRows.isNotEmpty) ...[
                        for (int i = 0; i < detailRows.length; i++) ...[
                          detailRows[i],
                          if (i < detailRows.length - 1)
                            const Divider(height: 1),
                        ],
                      ],
                      const SizedBox(height: 16),
                      // 6. 上課時間區塊
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark
                              ? colorScheme.secondaryCardBackground
                              : Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: colorScheme.borderColor.withOpacity(0.5),
                            width: 0.8,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.access_time_filled_rounded,
                                  size: 16,
                                  color: colorScheme.subtitleText,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  "上課時間",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    color: colorScheme.subtitleText,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              prettyTime.isNotEmpty ? prettyTime : "無時間資料",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: isDark
                                    ? colorScheme.primaryText
                                    : Colors.blueGrey[800],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () async {
                    Navigator.pop(context);
                    await onRemove(course);
                  },
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                  child: const Text("從助手移除"),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    "關閉",
                    style: TextStyle(color: colorScheme.subtitleText),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
