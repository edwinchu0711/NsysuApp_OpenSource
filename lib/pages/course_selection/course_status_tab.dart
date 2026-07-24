import 'package:flutter/material.dart';
import '../../services/course_selection_service.dart';
import '../../services/course_query_service.dart';
import '../../services/offline_error_handler.dart';
import '../../theme/app_theme.dart';
import '../../theme/layout_style_notifier.dart';
import '../../widgets/glass/glass_card.dart';
import '../../widgets/glass/glass_page_scaffold.dart';

class CourseStatusTab extends StatelessWidget {
  final bool isLoading;
  final String message;
  final bool isSystemClosed;
  final List<CourseSelectionData> courses;
  final Future<void> Function() onRefresh;
  final bool showPreviewButton;
  final bool isCompact;

  const CourseStatusTab({
    super.key,
    required this.isLoading,
    required this.message,
    required this.isSystemClosed,
    required this.courses,
    required this.onRefresh,
    this.showPreviewButton = true,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(message, style: TextStyle(color: colorScheme.subtitleText)),
          ],
        ),
      );
    }

    // if (isSystemClosed) {
    //   return const Center(child: Text("選課系統未開放"));
    // }

    if (courses.isEmpty) {
      return Center(
        child: Text(
          "目前沒有任何選課紀錄",
          style: TextStyle(color: colorScheme.subtitleText, fontSize: 16),
        ),
      );
    }

    // --- 1. 計算學分 與 課程分類 ---
    double selectedCredits = 0;
    double registeringCredits = 0;

    // 定義三個暫存清單
    List<CourseSelectionData> registeringList = []; // 登記/加選 (置頂)
    List<CourseSelectionData> selectedList = []; // 選上 (中間)
    List<CourseSelectionData> otherList = []; // 未選上/退選 (置底)

    for (var course in courses) {
      double credit = double.tryParse(course.credits) ?? 0.0;

      // 分類邏輯
      if (course.status.contains("未選上")) {
        otherList.add(course);
      } else if (course.status.contains("選上")) {
        selectedCredits += credit;
        selectedList.add(course);
      } else if (course.status.contains("登記") || course.status.contains("加選")) {
        registeringCredits += credit;
        registeringList.add(course);
      }
      // else {
      //   // 包含 "未選上", "退選" 等等
      //   otherList.add(course);
      // }
    }

    double totalCredits = selectedCredits + registeringCredits;

    // --- 2. 建構顯示用的 Widget 清單 ---
    List<Widget> listChildren = [];

    // Part A: 登記中 (最優先)
    listChildren.addAll(
      registeringList.map((c) => _buildCourseCard(context, c)),
    );

    // Part B: 已選上
    listChildren.addAll(selectedList.map((c) => _buildCourseCard(context, c)));

    // Part C: 未選上 (如果有資料，先加分隔線)
    if (otherList.isNotEmpty) {
      listChildren.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0),
          child: Row(
            children: [
              const Expanded(child: Divider(thickness: 1.5)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Text(
                  "未選上 / 退選紀錄",
                  style: TextStyle(
                    color: colorScheme.subtitleText,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const Expanded(child: Divider(thickness: 1.5)),
            ],
          ),
        ),
      );
      // 接著加入未選上的卡片
      listChildren.addAll(
        otherList.map((c) => _buildCourseCard(context, c, isDimmed: true)),
      );
    }

    final isLiquidGlass = LayoutStyleNotifier.instance.isLiquidGlass;

    // 頂部資訊卡片 (學分 + 預覽按鈕) - 調整為 Card 並配合 isCompact 對齊
    final Widget topInner = Padding(
      padding: EdgeInsets.symmetric(
        horizontal: 12,
        vertical: isCompact ? 8 : 12,
      ),
      child: Row(
        children: [
          // 左側：學分統計
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "學分統計",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.subtitleText,
                    fontSize: isCompact ? 12 : 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text.rich(
                  TextSpan(
                    style: TextStyle(
                      fontSize: isCompact ? 14 : 16,
                      color: colorScheme.primaryText,
                    ),
                    children: [
                      TextSpan(
                        text: selectedCredits.toStringAsFixed(0),
                        style: TextStyle(
                          color: colorScheme.isDark
                              ? Colors.green[300]
                              : Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextSpan(
                        text: " (已選上) + ",
                        style: TextStyle(
                          color: colorScheme.subtitleText,
                          fontSize: isCompact ? 10 : 12,
                        ),
                      ),
                      TextSpan(
                        text: registeringCredits.toStringAsFixed(0),
                        style: TextStyle(
                          color: colorScheme.isDark
                              ? Colors.deepOrange[300]
                              : Colors.deepOrange,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextSpan(
                        text: " (登記加選) = ",
                        style: TextStyle(
                          color: colorScheme.subtitleText,
                          fontSize: isCompact ? 10 : 12,
                        ),
                      ),
                      TextSpan(
                        text: totalCredits.toStringAsFixed(0),
                        style: TextStyle(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: isCompact ? 16 : 20,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // 右側：課表預覽按鈕
          if (showPreviewButton)
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        CoursePreviewPage(courses: courses),
                  ),
                );
              },
              icon: Icon(Icons.calendar_month, size: isCompact ? 16 : 18),
              label: Text(
                "課表預覽",
                style: TextStyle(fontSize: isCompact ? 12 : 14),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: colorScheme.primary,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(
                  horizontal: isCompact ? 12 : 16,
                  vertical: isCompact ? 6 : 8,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
        ],
      ),
    );

    final Widget topInfoCard = isLiquidGlass
        ? Container(
            margin: EdgeInsets.fromLTRB(12, 12, 12, isCompact ? 4 : 0),
            clipBehavior: Clip.antiAlias,
            decoration: glassCardDecoration(context, borderRadius: 12),
            child: topInner,
          )
        : Card(
            elevation: 2,
            color: colorScheme.cardBackground,
            margin: EdgeInsets.fromLTRB(12, 12, 12, isCompact ? 4 : 0),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: topInner,
          );

    return Column(
      children: [
        topInfoCard,

        // 列表區域 - 修正對齊邊距
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              try {
                await onRefresh();
              } catch (e) {
                if (context.mounted) await OfflineErrorHandler.show(context, e);
              }
            },
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                12,
                isCompact ? 8 : 12,
                12,
                isLiquidGlass ? 100 : 12,
              ),
              children: listChildren,
            ),
          ),
        ),
      ],
    );
  }

  // 增加 isDimmed 參數，讓未選上的卡片看起來稍微淡一點；支援 isCompact 緊湊顯示
  Widget _buildCourseCard(
    BuildContext context,
    CourseSelectionData course, {
    bool isDimmed = false,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final isLiquidGlass = LayoutStyleNotifier.instance.isLiquidGlass;
    Color statusColor = Colors.grey;
    bool isRegistration = false;

    if (course.status.contains("退選") || course.status.contains("未選上")) {
      statusColor = Colors.grey; // 未選上用灰色
    } else if (course.status.contains("選上")) {
      statusColor = Colors.green;
    } else if (course.status.contains("登記") || course.status.contains("加選")) {
      statusColor = const Color.fromARGB(255, 255, 106, 61); // 登記加選用明顯的橘色
      isRegistration = true;
    }

    Widget topRightWidget;
    if (isRegistration) {
      String points = course.remarks.isEmpty ? "0" : course.remarks;
      topRightWidget = Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            "點數/志願",
            style: TextStyle(
              fontSize: isCompact ? 11 : 13,
              color: colorScheme.subtitleText,
            ),
          ),
          Text(
            points,
            style: TextStyle(
              color: colorScheme.isDark
                  ? const Color(0xFF64B5F6)
                  : Colors.blueAccent,
              fontWeight: FontWeight.bold,
              fontSize: isCompact ? 16 : 20,
            ),
          ),
        ],
      );
    } else {
      topRightWidget = Text(
        course.dept,
        style: TextStyle(
          color: colorScheme.subtitleText,
          fontSize: isCompact ? 11 : 12,
        ),
      );
    }

    // 如果是未選上(isDimmed)，整張卡片透明度降低
    final Widget cardInner = Padding(
      padding: EdgeInsets.all(isCompact ? 12 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isCompact ? 6 : 8,
                  vertical: isCompact ? 2 : 4,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  border: Border.all(color: statusColor),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  course.status,
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                    fontSize: isCompact ? 11 : 12,
                  ),
                ),
              ),
              topRightWidget,
            ],
          ),
          SizedBox(height: isCompact ? 6 : 8),
          Text(
            course.name,
            style: TextStyle(
              fontSize: isCompact ? 15 : 18,
              fontWeight: FontWeight.bold,
              decoration: isDimmed
                  ? TextDecoration.lineThrough
                  : null, // 未選上可考慮加刪除線，不需要可拿掉
              color: isDimmed
                  ? colorScheme.subtitleText
                  : colorScheme.primaryText,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            "${course.courseNo} • ${course.credits}學分 • ${course.grade}年級",
            style: TextStyle(
              color: colorScheme.bodyText,
              fontSize: isCompact ? 12 : 13,
            ),
          ),
          Divider(height: isCompact ? 16 : 24),
          Row(
            children: [
              Icon(
                Icons.person,
                size: isCompact ? 14 : 16,
                color: colorScheme.subtitleText,
              ),
              const SizedBox(width: 4),
              Text(
                course.professor,
                style: TextStyle(
                  color: colorScheme.primaryText,
                  fontSize: isCompact ? 12 : 13,
                ),
              ),
              SizedBox(width: isCompact ? 12 : 16),
              Icon(
                Icons.location_on,
                size: isCompact ? 14 : 16,
                color: colorScheme.subtitleText,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  course.timeRoom,
                  style: TextStyle(
                    color: colorScheme.bodyText,
                    fontSize: isCompact ? 11 : 12,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );

    final Widget cardWidget = isLiquidGlass
        ? Container(
            margin: EdgeInsets.only(bottom: isCompact ? 8 : 12),
            clipBehavior: Clip.antiAlias,
            decoration: glassCardDecoration(context, borderRadius: 16),
            child: cardInner,
          )
        : Card(
            elevation: isDimmed ? 0 : 2, // 未選上的陰影拿掉，讓它看起來比較扁平
            color: isDimmed
                ? colorScheme.secondaryCardBackground
                : colorScheme.cardBackground, // 未選上的背景稍微灰一點
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ), // 增加圓角至 16
            margin: EdgeInsets.only(bottom: isCompact ? 8 : 12),
            child: cardInner,
          );

    return Opacity(
      opacity: isDimmed ? 0.6 : 1.0,
      child: cardWidget,
    );
  }
}

// CoursePreviewPage wraps the reusable CoursePreviewWidget in a Scaffold
class CoursePreviewPage extends StatelessWidget {
  final List<CourseSelectionData> courses;

  const CoursePreviewPage({super.key, required this.courses});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isLiquidGlass = LayoutStyleNotifier.instance.isLiquidGlass;
    return GlassPageScaffold(
      appBar: AppBar(
        title: const Text("課表預覽"),
        centerTitle: true,
        backgroundColor: isLiquidGlass
            ? Colors.transparent
            : (colorScheme.isDark
                ? colorScheme.scaffoldBackground
                : Colors.white),
        surfaceTintColor: isLiquidGlass ? Colors.transparent : null,
        elevation: isLiquidGlass ? 0 : 1,
        scrolledUnderElevation: isLiquidGlass ? 0 : null,
        foregroundColor: colorScheme.primaryText,
      ),
      body: CoursePreviewWidget(courses: courses),
    );
  }
}

// Reusable CoursePreviewWidget that can be used inline in larger screens
class CoursePreviewWidget extends StatelessWidget {
  final List<CourseSelectionData> courses;

  const CoursePreviewWidget({super.key, required this.courses});

  // --- API 資料狀態 ---
  static final ValueNotifier<List<CourseJsonData>> _apiCoursesNotifier = ValueNotifier([]);
  static final ValueNotifier<bool> _isApiLoadingNotifier = ValueNotifier(false);
  static String? _apiLoadedSemester;

  static String _formatSemester(String? sem) {
    if (sem == null || sem.isEmpty) return "";
    if (sem.length >= 4) {
      final year = sem.substring(0, sem.length - 1);
      final term = sem.substring(sem.length - 1);
      return "$year-$term";
    }
    return sem;
  }

  static String _normalizeCode(String code) {
    String s = code
        .replaceAll(RegExp(r'&nbsp;?', caseSensitive: false), '')
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll(RegExp(r'\s+'), '')
        .toUpperCase();

    final buffer = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      int char = s.codeUnitAt(i);
      if (char >= 0xFF01 && char <= 0xFF5E) {
        buffer.writeCharCode(char - 0xFEE0);
      } else if (char == 0x3000) {
        buffer.writeCharCode(0x0020);
      } else {
        buffer.writeCharCode(char);
      }
    }
    return buffer.toString();
  }

  static bool _matchCourseCodeExact(String apiId, String schoolCode) {
    return _normalizeCode(apiId) == _normalizeCode(schoolCode);
  }

  static bool _matchCourseCodeFuzzy(String apiId, String schoolCode) {
    final normApi = _normalizeCode(apiId);
    final normSchool = _normalizeCode(schoolCode);
    if (normApi.isEmpty || normSchool.isEmpty) return false;
    return normApi.contains(normSchool) || normSchool.contains(normApi);
  }

  static Map<String, String> _splitCourseName(String fullName) {
    final cleanName = fullName.split('\n')[0];
    final String chinesePart = keepUntilLastChinese(cleanName).trim();
    if (chinesePart.isEmpty) {
      return {"chinese": cleanName, "english": ""};
    }
    final String englishPart = cleanName.substring(chinesePart.length).trim();
    return {"chinese": chinesePart, "english": englishPart};
  }

  static Widget _buildModernDetailRow(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String label,
    required Widget content,
    bool isLoading = false,
  }) {
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
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
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

  static Future<void> _loadApiCourses(String? semester) async {
    String targetSem = semester ?? "";
    if (targetSem.isEmpty) {
      try {
        final data = await CourseQueryService.instance.getSemesters();
        targetSem = data['latest'] as String;
      } catch (e) {
        debugPrint("❌ [選課預覽-課程API] 取得學期失敗: $e");
        return;
      }
    }

    if (_apiLoadedSemester == targetSem && _apiCoursesNotifier.value.isNotEmpty) {
      return; // 已經載入
    }

    _isApiLoadingNotifier.value = true;
    _apiCoursesNotifier.value = [];

    try {
      final courses = await CourseQueryService.instance.getCourses(
        semester: targetSem,
      );
      _apiCoursesNotifier.value = courses;
      _apiLoadedSemester = targetSem;
      _isApiLoadingNotifier.value = false;
    } catch (e) {
      debugPrint("❌ [選課預覽-課程API] 載入失敗: $e");
      _apiCoursesNotifier.value = [];
      _isApiLoadingNotifier.value = false;
    }
  }

  void _showCourseDetail(BuildContext context, CourseSelectionData course) {
    _loadApiCourses(course.semester);

    final colorScheme = Theme.of(context).colorScheme;
    final isDark = colorScheme.isDark;

    Color baseColor;
    if (course.status.contains("選上")) {
      baseColor = isDark ? const Color(0xFF2E7D32) : Colors.green[600]!;
    } else if (course.status.contains("退選") || course.status.contains("未選上")) {
      baseColor = isDark ? const Color(0xFFC62828) : Colors.red[600]!;
    } else {
      baseColor = isDark ? const Color(0xFFEF6C00) : Colors.orange[600]!;
    }

    final gradient = LinearGradient(
      colors: [
        baseColor,
        HSVColor.fromColor(baseColor)
            .withValue((HSVColor.fromColor(baseColor).value * 0.82).clamp(0.0, 1.0))
            .toColor(),
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    showDialog(
      context: context,
      builder: (context) => ValueListenableBuilder<bool>(
        valueListenable: _isApiLoadingNotifier,
        builder: (context, isApiLoading, child) {
          return ValueListenableBuilder<List<CourseJsonData>>(
            valueListenable: _apiCoursesNotifier,
            builder: (context, apiCourses, child) {
              // 尋找 API 中的系所與學程資訊
              var apiCourseList = apiCourses
                  .where((e) => _matchCourseCodeExact(e.id, course.code))
                  .toList();
              if (apiCourseList.isEmpty) {
                apiCourseList = apiCourses
                    .where((e) => _matchCourseCodeFuzzy(e.id, course.code))
                    .toList();
              }
              final CourseJsonData? apiCourse = apiCourseList.isNotEmpty
                  ? apiCourseList.first
                  : null;
              final hasApiData = apiCourse != null;
              final departmentText = hasApiData ? apiCourse.department : "未指定";
              final List<String> tags = hasApiData ? apiCourse.tags : [];

              // 中英文分離標題
              final nameParts = _splitCourseName(course.name);
              final chineseName = nameParts["chinese"]!;
              final englishName = nameParts["english"]!;

              final List<Widget> detailRows = [];

              // 1. 學分與選別
              final showCredits = course.credits.isNotEmpty || course.type.isNotEmpty;
              if (showCredits) {
                detailRows.add(
                  _buildModernDetailRow(
                    context,
                    icon: Icons.stars_rounded,
                    iconColor: Colors.deepPurpleAccent,
                    label: "學分與選別",
                    content: Text(
                      course.type.trim().isNotEmpty && course.type.trim() != "未指定"
                          ? "${course.credits}學分 (${course.type})"
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
              final showProfessor = course.professor.isNotEmpty && course.professor != "未指定" && course.professor != "未提供";
              if (showProfessor) {
                detailRows.add(
                  _buildModernDetailRow(
                    context,
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

              // 3. 地點與時間
              final showLocation = course.timeRoom.isNotEmpty && course.timeRoom != "未指定" && course.timeRoom != "無教室資料";
              if (showLocation) {
                detailRows.add(
                  _buildModernDetailRow(
                    context,
                    icon: Icons.location_on_rounded,
                    iconColor: Colors.redAccent,
                    label: "上課時間與教室",
                    content: Text(
                      course.timeRoom,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.primaryText,
                      ),
                    ),
                  ),
                );
              }

              // 4. 開課系所
              final showDepartment = isApiLoading || (hasApiData && departmentText.isNotEmpty && departmentText != "未指定" && departmentText != "未提供");
              if (showDepartment) {
                detailRows.add(
                  _buildModernDetailRow(
                    context,
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

              // 5. 適用學程
              final showTags = isApiLoading || (hasApiData && tags.isNotEmpty);
              if (showTags) {
                detailRows.add(
                  _buildModernDetailRow(
                    context,
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
                                  color: Colors.teal.withValues(alpha: 
                                    isDark ? 0.15 : 0.08,
                                  ),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: Colors.teal.withValues(alpha: 
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
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              if (course.semester != null && course.semester!.isNotEmpty) ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    _formatSemester(course.semester),
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
                                  color: Colors.white.withValues(alpha: 0.2),
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
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              course.status,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
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
                            color: Colors.white.withValues(alpha: 0.85),
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
                            if (i < detailRows.length - 1) const Divider(height: 1),
                          ],
                        ],
                      ],
                    ),
                  ),
                ),
                actions: [
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
      ),
    );
  }

  static const List<String> _allPeriods = [
    'A',
    '1',
    '2',
    '3',
    '4',
    'B',
    '5',
    '6',
    '7',
    '8',
    '9',
    'C',
    'D',
    'E',
    'F',
  ];

  static const Map<String, String> _timeMapping = {
    'A': '07:00\n07:50',
    '1': '08:10\n09:00',
    '2': '09:10\n10:00',
    '3': '10:10\n11:00',
    '4': '11:10\n12:00',
    'B': '12:10\n13:00',
    '5': '13:10\n14:00',
    '6': '14:10\n15:00',
    '7': '15:10\n16:00',
    '8': '16:10\n17:00',
    '9': '17:10\n18:00',
    'C': '18:20\n19:10',
    'D': '19:15\n20:05',
    'E': '20:10\n21:00',
    'F': '21:05\n21:55',
  };

  static const List<String> _weekDays = ['一', '二', '三', '四', '五', '六', '日'];

  static String keepUntilLastChinese(String input) {
    final RegExp chineseRegex = RegExp(r'[\u4e00-\u9fa5]');
    final Iterable<Match> matches = chineseRegex.allMatches(input);
    if (matches.isEmpty) return input.split('\n')[0];
    int lastIndex = matches.last.end;
    String prefix = input.substring(0, lastIndex);

    // Count unmatched open parentheses in prefix
    int standardOpen = 0;
    int fullwidthOpen = 0;
    for (int i = 0; i < prefix.length; i++) {
      String char = prefix[i];
      if (char == '(') {
        standardOpen++;
      } else if (char == '（') {
        fullwidthOpen++;
      } else if (char == ')') {
        if (standardOpen > 0) standardOpen--;
      } else if (char == '）') {
        if (fullwidthOpen > 0) fullwidthOpen--;
      }
    }

    // Scan remaining string to find matching closing parentheses
    String suffix = "";
    for (int i = lastIndex; i < input.length; i++) {
      if (standardOpen == 0 && fullwidthOpen == 0) {
        break;
      }
      String char = input[i];
      suffix += char;
      if (char == ')') {
        if (standardOpen > 0) standardOpen--;
      } else if (char == '）') {
        if (fullwidthOpen > 0) fullwidthOpen--;
      }
    }

    return prefix + suffix;
  }

  String _parseRoomName(String timeRoom) {
    final RegExp regex = RegExp(r'[(\uff08]([^)\uff09]*)[)\uff09]');
    final match = regex.firstMatch(timeRoom);
    return match?.group(1)?.trim() ?? "";
  }

  Widget _buildCourseCell(
    BuildContext context,
    CourseSelectionData course,
    double titleFontSize,
    double locationFontSize, {
    double? height,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final isLiquidGlass = LayoutStyleNotifier.instance.isLiquidGlass;
    final isDark = colorScheme.isDark;
    Color bgColor;
    if (course.status.contains("選上")) {
      bgColor = colorScheme.isDark
          ? const Color(0xFF2E7D32)
          : Colors.green[400]!;
    } else if (course.status.contains("退選") || course.status.contains("未選上")) {
      bgColor = colorScheme.isDark ? const Color(0xFFC62828) : Colors.red[200]!;
    } else {
      bgColor = colorScheme.isDark
          ? const Color(0xFFEF6C00)
          : Colors.orange[300]!;
    }

    final displayName = keepUntilLastChinese(course.name);
    String room = _parseRoomName(course.timeRoom);

    return Container(
      width: double.infinity,
      height: height,
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
      decoration: BoxDecoration(
        color: isLiquidGlass ? bgColor.withValues(alpha: 0.82) : bgColor,
        borderRadius: BorderRadius.circular(4),
        border: isLiquidGlass
            ? Border.all(
                color: Colors.white.withValues(alpha: isDark ? 0.15 : 0.25),
                width: 0.5,
              )
            : null,
      ),
      child: Column(
        mainAxisSize: height != null ? MainAxisSize.max : MainAxisSize.min,
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
          if (room.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              room,
              style: TextStyle(
                fontSize: locationFontSize,
                color: Colors.white70,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isLiquidGlass = LayoutStyleNotifier.instance.isLiquidGlass;
    final scheduleMap = _parseCoursesToSchedule();

    List<int> visibleDays = [0, 1, 2, 3, 4];
    if (_hasCourseInDay(scheduleMap, 5)) visibleDays.add(5);
    if (_hasCourseInDay(scheduleMap, 6)) visibleDays.add(6);

    List<String> visiblePeriods = _calculateVisiblePeriods(scheduleMap);
    int maxDay = visibleDays.length;

    final headerBgColor = isLiquidGlass
        ? (colorScheme.isDark
            ? Colors.white.withValues(alpha: 0.06)
            : Colors.white.withValues(alpha: 0.4))
        : (colorScheme.isDark
            ? const Color(0xFF252B3B)
            : const Color(0xFFF4F8FF));

    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isTablet = screenWidth >= 750;
    final double periodColWidth = maxDay > 5
        ? (isTablet ? 42.0 : 36.0)
        : (isTablet ? 52.0 : 45.0);
    final double headerHeight = isTablet ? 40.0 : 32.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final double width = constraints.maxWidth;
        double titleFontSize = 10.0;
        double locationFontSize = 8.0;

        double columnWidth = (width - periodColWidth) / maxDay;
        titleFontSize = (10.0 + (columnWidth - 60.0) * 0.1).clamp(8.0, 14.0);
        locationFontSize = (8.0 + (columnWidth - 60.0) * 0.08).clamp(7.0, 11.0);

        return Container(
          color: isLiquidGlass
              ? Colors.transparent
              : (colorScheme.isDark
                  ? colorScheme.scaffoldBackground
                  : Colors.grey[50]),
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.only(
              bottom: isLiquidGlass ? 100 : 0,
            ),
            child: Table(
              border: TableBorder.all(
                color: isLiquidGlass
                    ? (colorScheme.isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.black.withValues(alpha: 0.05))
                    : colorScheme.borderColor,
                width: 0.5,
              ),
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
                    ...visibleDays.map(
                      (dayIndex) => Container(
                        height: headerHeight,
                        alignment: Alignment.center,
                        child: Text(
                          _weekDays[dayIndex],
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
                  String timeInfo = _timeMapping[period] ?? "";

                  // 檢查此節次中，是否每一天都只有最多一堂課程（無衝突）
                  bool hasConflict = false;
                  double maxCellHeight = 70.0;

                  for (var dayIndex in visibleDays) {
                    final cellCourses = scheduleMap[dayIndex]?[period] ?? [];
                    if (cellCourses.length >= 2) {
                      hasConflict = true;
                    } else if (cellCourses.length == 1) {
                      final c = cellCourses.first;
                      final displayName = keepUntilLastChinese(c.name);
                      final room = _parseRoomName(c.timeRoom);
                      double h = 70.0;
                      if (displayName.length > 20) {
                        h += 30.0;
                      } else if (displayName.length > 15) {
                        h += 20.0;
                      } else if (displayName.length > 10) {
                        h += 10.0;
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
                      ...visibleDays.map((dayIndex) {
                        final cellCourses =
                            scheduleMap[dayIndex]?[period] ?? [];

                        if (cellCourses.isEmpty) {
                          return Container(height: overrideHeight ?? 70);
                        }

                        // 情況一：只有一堂課程，設定固定高度
                        if (cellCourses.length == 1) {
                          final c = cellCourses.first;
                          final displayName = keepUntilLastChinese(c.name);
                          final room = _parseRoomName(c.timeRoom);
                          double cellHeight = overrideHeight ?? 70.0;
                          if (overrideHeight == null) {
                            if (displayName.length > 20) {
                              cellHeight += 30.0;
                            } else if (displayName.length > 15) {
                              cellHeight += 20.0;
                            } else if (displayName.length > 10) {
                              cellHeight += 10.0;
                            }
                            // 如果教室名稱較長，可能換行，增加些許高度以防擠壓
                            if (room.length > 5) {
                              cellHeight += 10.0;
                            }
                          }

                          return Container(
                            height: cellHeight,
                            padding: const EdgeInsets.all(1.0),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () => _showCourseDetail(context, c),
                                borderRadius: BorderRadius.circular(4),
                                child: _buildCourseCell(
                                  context,
                                  c,
                                  titleFontSize,
                                  locationFontSize,
                                  height: double.infinity,
                                ),
                              ),
                            ),
                          );
                        }

                        // 情況二：多堂課衝堂，設定最低高度，讓 Column 自適應增高
                        return Container(
                          constraints: const BoxConstraints(minHeight: 70),
                          padding: const EdgeInsets.all(1.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: cellCourses.map((c) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 2.0),
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: () => _showCourseDetail(context, c),
                                    borderRadius: BorderRadius.circular(4),
                                    child: _buildCourseCell(
                                      context,
                                      c,
                                      titleFontSize,
                                      locationFontSize,
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        );
                      }),
                    ],
                  );
                }).toList(),
              ],
            ),
          ),
        );
      },
    );
  }

  List<String> _calculateVisiblePeriods(
    Map<int, Map<String, List<CourseSelectionData>>> map,
  ) {
    List<String> result = [];
    List<String> corePeriods = [
      '1',
      '2',
      '3',
      '4',
      'B',
      '5',
      '6',
      '7',
      '8',
      '9',
      'C',
    ];

    bool hasA = _checkPeriodHasCourse(map, 'A');
    if (hasA) result.add('A');

    result.addAll(corePeriods);

    bool hasD = _checkPeriodHasCourse(map, 'D');
    bool hasE = _checkPeriodHasCourse(map, 'E');
    bool hasF = _checkPeriodHasCourse(map, 'F');

    if (hasF) {
      result.addAll(['D', 'E', 'F']);
    } else if (hasE) {
      result.addAll(['D', 'E']);
    } else if (hasD) {
      result.addAll(['D']);
    }

    return result;
  }

  bool _checkPeriodHasCourse(
    Map<int, Map<String, List<CourseSelectionData>>> map,
    String period,
  ) {
    for (var dayData in map.values) {
      if (dayData.containsKey(period) && dayData[period]!.isNotEmpty) {
        return true;
      }
    }
    return false;
  }

  bool _hasCourseInDay(
    Map<int, Map<String, List<CourseSelectionData>>> map,
    int dayIndex,
  ) {
    return map.containsKey(dayIndex) && map[dayIndex]!.isNotEmpty;
  }

  Map<int, Map<String, List<CourseSelectionData>>> _parseCoursesToSchedule() {
    Map<int, Map<String, List<CourseSelectionData>>> map = {};

    for (var course in courses) {
      if (course.status.contains("退選") ||
          course.status.contains("未選上") ||
          course.status.contains("失敗")) {
        continue;
      }

      if (course.timeRoom.isEmpty) continue;

      String rawTimeOnly = course.timeRoom.replaceAll(
        RegExp(r'[(\uff08].*?[)\uff09]'),
        '',
      );

      int? currentDay;

      for (int i = 0; i < rawTimeOnly.length; i++) {
        String char = rawTimeOnly[i];

        int dayIndex = _weekDays.indexOf(char);
        if (dayIndex != -1) {
          currentDay = dayIndex;
          continue;
        }

        if (_allPeriods.contains(char)) {
          if (currentDay != null) {
            if (!map.containsKey(currentDay)) map[currentDay] = {};
            if (!map[currentDay]!.containsKey(char))
              map[currentDay]![char] = [];

            if (!map[currentDay]![char]!.contains(course)) {
              map[currentDay]![char]!.add(course);
            }
          }
        }
      }
    }
    return map;
  }
}
