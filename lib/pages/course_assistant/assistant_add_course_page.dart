import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../services/course_query_service.dart'; // 請確認路徑是否正確
import '../../theme/app_theme.dart';
import '../../theme/layout_style_notifier.dart';
import '../../widgets/glass/glass_dropdown.dart';
import '../../widgets/glass/glass_page_scaffold.dart';
import '../../widgets/glass/glass_bottom_sheet.dart';
import '../../widgets/glass/glass_card.dart';
import '../../services/http_client_factory.dart';

class AssistantAddCoursePage extends StatefulWidget {
  final bool isInline;
  final VoidCallback? onCourseAdded;
  const AssistantAddCoursePage({
    super.key,
    this.isInline = false,
    this.onCourseAdded,
  });

  @override
  State<AssistantAddCoursePage> createState() => _AssistantAddCoursePageState();
}

class _AssistantAddCoursePageState extends State<AssistantAddCoursePage> {
  bool _isQueryLoading = false;
  List<CourseJsonData> _searchResults = [];
  bool _hasSearched = false;
  bool _showInlineSearch = false; // ✅ 新增：控制寬/中螢幕下的內嵌搜尋面板顯示
  final Map<String, List<String>> _evaluationCache = {};
  // 已存在助手課表中的課程 ID 集合 (用來防呆顯示已加入)
  Set<String> _existingAssistantCourseIds = {};

  final TextEditingController _crsNameCtrl = TextEditingController();
  final TextEditingController _teacherCtrl = TextEditingController();
  final TextEditingController _codeCtrl = TextEditingController();
  final TextEditingController _deptCtrl = TextEditingController();
  String? _selectedGrade;
  String? _selectedClass;
  String? _selectedDay;
  String? _selectedPeriod;

  List<String> _semesterOptions = [];
  Map<String, String> _semesterDisplayMap = {};
  String? _selectedSemester;
  bool _isSemesterLoading = true;

  @override
  void initState() {
    super.initState();
    _loadExistingAssistantCourses();
    _loadSemesters();
  }

  Future<void> _loadSemesters() async {
    try {
      final data = await CourseQueryService.instance.getSemesters();
      final latest = data['latest'] as String;
      final history = data['history'] as Map<String, dynamic>;

      final List<String> sems = history.keys.map((e) => e.toString()).toList();
      if (!sems.contains(latest)) {
        sems.add(latest);
      }

      sems.sort((a, b) => b.compareTo(a));

      final Map<String, String> displayMap = {};
      for (var sem in sems) {
        if (sem.length == 4) {
          final syear = sem.substring(0, 3);
          final sterm = sem.substring(3, 4);
          displayMap[sem] = "$syear-$sterm";
        } else {
          displayMap[sem] = sem;
        }
      }

      if (!mounted) return;
      setState(() {
        _semesterOptions = sems;
        _semesterDisplayMap = displayMap;
        _selectedSemester = latest;
        _isSemesterLoading = false;
      });
    } catch (e) {
      debugPrint("載入學期清單失敗: $e");
      if (!mounted) return;
      setState(() {
        _isSemesterLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _crsNameCtrl.dispose();
    _teacherCtrl.dispose();
    _codeCtrl.dispose();
    _deptCtrl.dispose();
    super.dispose();
  }

  String _getCourseKey(String scheduleId) {
    return scheduleId == 'default'
        ? 'assistant_courses'
        : 'assistant_courses_$scheduleId';
  }

  // 讀取已經加到助手的課程，用來在畫面上顯示 "已加入"
  Future<void> _loadExistingAssistantCourses() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final currentScheduleId =
          prefs.getString('current_assistant_schedule_id') ?? 'default';
      final courseKey = _getCourseKey(currentScheduleId);
      String? jsonStr = prefs.getString(courseKey);
      if (!mounted) return;
      if (jsonStr != null && jsonStr.isNotEmpty) {
        List<dynamic> decoded = jsonDecode(jsonStr);
        setState(() {
          _existingAssistantCourseIds = decoded
              .map((v) => v['code'].toString())
              .toSet();
        });
      } else {
        setState(() {
          _existingAssistantCourseIds = {};
        });
      }
    } catch (e) {
      debugPrint("讀取既有助手課表失敗: $e");
    }
  }

  // 將 CourseJsonData 轉換為 Course 模型並存入快取
  Future<void> _addCourseToAssistant(CourseJsonData courseData) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      final currentScheduleId =
          prefs.getString('current_assistant_schedule_id') ?? 'default';
      final courseKey = _getCourseKey(currentScheduleId);
      List<dynamic> currentList = [];
      String? jsonStr = prefs.getString(courseKey);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        currentList = jsonDecode(jsonStr);
      }

      // 檢查是否重複
      if (currentList.any((c) => c['code'] == courseData.id)) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("此課程已經在助手中了！")));
        return;
      }

      // ✅ 修改這裡：將時間字串精準拆分 (支援 "234" 或 "2,3,4" 等格式)
      List<Map<String, dynamic>> parsedTimes = [];
      for (int i = 0; i < courseData.classTime.length; i++) {
        String dayPeriods = courseData.classTime[i];
        if (dayPeriods.isNotEmpty) {
          // 去除逗號與空白，確保剩下純節次字元 (例如 "2, 3, 4" 或 "234" 都變成 "234")
          String cleaned = dayPeriods.replaceAll(',', '').replaceAll(' ', '');

          // 逐字元拆開 (中山的節次皆為單一字元: 1~9, A~F)
          for (int j = 0; j < cleaned.length; j++) {
            parsedTimes.add({'day': i + 1, 'period': cleaned[j]});
          }
        }
      }

      // 建立存檔用 Map
      Map<String, dynamic> newCourse = {
        'name': courseData.name.split('\n')[0],
        'code': courseData.id,
        'professor': courseData.teacher,
        'location': courseData.room,
        'timeString': "",
        'credits': courseData.credit,
        'required': "",
        'detailUrl': "",
        'parsedTimes': parsedTimes,
        'semester': _selectedSemester,
      };

      currentList.add(newCourse);
      await prefs.setString(courseKey, jsonEncode(currentList));

      if (!mounted) return;
      setState(() {
        _existingAssistantCourseIds.add(courseData.id);
      });

      widget.onCourseAdded?.call();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("已排入模擬課表：${courseData.name.split('\n')[0]}"),
          backgroundColor: Colors.green,
          duration: const Duration(milliseconds: 1500), // ⏱️ 1.5 秒
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("加入失敗：$e")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final semStr = CourseQueryService.instance.currentSemester;
    String semDisplay = "";
    if (semStr.length == 4) {
      final syear = semStr.substring(0, 3); // 前三碼 (114)
      final sem = semStr.substring(3, 4); // 最後一碼 (2)
      semDisplay = "$syear-${sem}";
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth >= 750;
    final isLiquidGlass = LayoutStyleNotifier.instance.isLiquidGlass;
    final isDark = colorScheme.isDark;

    final Widget bodyContent = Stack(
      children: [
        Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              color: isLiquidGlass
                  ? Colors.transparent
                  : colorScheme.cardBackground,
              child: ElevatedButton.icon(
                onPressed: () {
                  if (widget.isInline) {
                    setState(() {
                      _showInlineSearch = !_showInlineSearch;
                    });
                  } else {
                    _showSearchSheet();
                  }
                },
                icon: Icon(
                  widget.isInline && _showInlineSearch
                      ? Icons.close
                      : Icons.search,
                ),
                label: Text(
                  widget.isInline && _showInlineSearch ? "收起搜尋面板" : "開啟搜尋面板",
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.primaryContainer,
                  foregroundColor: colorScheme.primary,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            Divider(
              height: 1,
              color: isLiquidGlass
                  ? (isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.black.withValues(alpha: 0.06))
                  : colorScheme.borderColor,
            ),
            Expanded(child: _buildSearchResults()),
          ],
        ),
        if (widget.isInline && _showInlineSearch && !isTablet)
          Positioned(
            top: 62,
            left: 8,
            right: 8,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height - 200,
              ),
              child: Material(
                color: Colors.transparent,
                elevation: isLiquidGlass ? 0 : 8,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  decoration: isLiquidGlass
                      ? BoxDecoration(
                          color: isDark
                              ? const Color(0xFF1E222D).withValues(alpha: 0.90)
                              : Colors.white.withValues(alpha: 0.90),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.12)
                                : Colors.black.withValues(alpha: 0.08),
                            width: 1.0,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.05),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        )
                      : BoxDecoration(
                          color: colorScheme.cardBackground,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: colorScheme.borderColor,
                            width: 0.5,
                          ),
                        ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(16),
                          child: _buildSearchFormContent(
                            context,
                            isInlineSearch: true,
                            onClose: () {
                              setState(() {
                                _showInlineSearch = false;
                              });
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
        if (isTablet && _showInlineSearch)
          Positioned.fill(
            child: Container(
              decoration: isLiquidGlass
                  ? (glassCardDecoration(context, borderRadius: 12)?.copyWith(
                      color: isDark
                          ? const Color(0xFF1E222D).withValues(alpha: 0.88)
                          : Colors.white.withValues(alpha: 0.92),
                    ))
                  : BoxDecoration(color: colorScheme.cardBackground),
              child: _buildInlineSearchView(colorScheme),
            ),
          ),
      ],
    );

    if (widget.isInline) {
      return Scaffold(
        appBar: null,
        backgroundColor: isLiquidGlass ? Colors.transparent : null,
        body: bodyContent,
      );
    }

    return GlassPageScaffold(
      appBar: AppBar(
        title: Text("新增課程"),
        backgroundColor: isLiquidGlass
            ? Colors.transparent
            : colorScheme.scaffoldBackground,
        surfaceTintColor: isLiquidGlass ? Colors.transparent : null,
        foregroundColor: colorScheme.primaryText,
        elevation: isLiquidGlass ? 0 : 0.5,
        scrolledUnderElevation: isLiquidGlass ? 0 : null,
      ),
      body: bodyContent,
    );
  }

  Widget _buildSearchResults() {
    final colorScheme = Theme.of(context).colorScheme;
    final isLiquidGlass = LayoutStyleNotifier.instance.isLiquidGlass;
    if (_isQueryLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              "搜尋中 (可能需要下載課程資料)...",
              style: TextStyle(color: colorScheme.subtitleText),
            ),
          ],
        ),
      );
    }

    if (!_hasSearched) {
      return Center(
        child: Text(
          "點擊上方按鈕搜尋想加入的課程",
          style: TextStyle(color: colorScheme.subtitleText),
        ),
      );
    }

    if (_searchResults.isEmpty) {
      return Center(
        child: Text(
          "找不到符合條件的課程",
          style: TextStyle(color: colorScheme.subtitleText),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final course = _searchResults[index];
        bool isAdded = _existingAssistantCourseIds.contains(course.id);

        final cardChild = Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: EdgeInsets.symmetric(
              horizontal: 16,
              vertical: widget.isInline ? 3 : 8,
            ),
            collapsedIconColor: colorScheme.subtitleText,
            iconColor: colorScheme.subtitleText,
            title: Text(
              course.name.split('\n')[0],
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: widget.isInline ? 14 : 16,
                color: colorScheme.primaryText,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: widget.isInline ? 2 : 4),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.person,
                          size: 14,
                          color: colorScheme.subtitleText,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          course.teacher,
                          style: TextStyle(
                            color: colorScheme.bodyText,
                            fontSize: widget.isInline ? 12 : 13,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.subtleBackground,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        course.id,
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.subtitleText,
                        ),
                      ),
                    ),
                    _buildProbabilityChip(course, colorScheme),
                  ],
                ),
              ],
            ),
            trailing: isAdded
                ? Icon(
                    Icons.check_circle,
                    color: Colors.green,
                    size: widget.isInline ? 26 : 32,
                  )
                : ElevatedButton(
                    onPressed: () => _addCourseToAssistant(course),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[600],
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: EdgeInsets.symmetric(
                        horizontal: widget.isInline ? 8 : 12,
                      ),
                      minimumSize: Size(
                        widget.isInline ? 56 : 60,
                        widget.isInline ? 28 : 32,
                      ),
                    ),
                    child: Text(
                      "加入排課",
                      style: TextStyle(fontSize: widget.isInline ? 12 : 14),
                    ),
                  ),
            children: [
              Divider(height: 1, thickness: 1, color: colorScheme.borderColor),
              Container(
                color: isLiquidGlass
                    ? Colors.transparent
                    : colorScheme.primaryContainer.withValues(alpha: 0.15),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _buildDetailRow(
                            Icons.school,
                            "系所",
                            course.department,
                            colorScheme,
                          ),
                        ),
                        Expanded(
                          child: _buildDetailRow(
                            Icons.grade,
                            "學分",
                            course.credit,
                            colorScheme,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildDetailRow(
                            Icons.class_,
                            "班級",
                            "${course.grade}年級 ${course.className}",
                            colorScheme,
                          ),
                        ),
                        Expanded(
                          child: _buildDetailRow(
                            Icons.room,
                            "教室",
                            _parseRoomLocation(course.room),
                            colorScheme,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildDetailRow(
                            Icons.people,
                            "名額 / 已選 / 餘額",
                            "${course.restrict} / ${course.select} / ${course.remaining}",
                            colorScheme,
                            valueColor: course.remaining > 0
                                ? (colorScheme.isDark
                                      ? Colors.green[300]
                                      : Colors.green[700])
                                : Colors.redAccent,
                          ),
                        ),
                        Expanded(
                          child: _buildDetailRow(
                            Icons.pie_chart,
                            "選上機率",
                            _calculateProbability(course),
                            colorScheme,
                            valueColor: colorScheme.isDark
                                ? Colors.orange[300]
                                : Colors.orange[700],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        "上課時間表",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.subtitleText,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildTimeDisplay(course.classTime, colorScheme),
                    // ✅ 新增：評分方式區塊
                    const SizedBox(height: 16),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        "評分方式",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.subtitleText,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // 使用 FutureBuilder 動態載入
                    Align(
                      alignment: Alignment.centerLeft,
                      child: FutureBuilder<List<String>>(
                        future: _getCourseEvaluation(course.id),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Padding(
                              padding: EdgeInsets.all(8.0),
                              child: SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            );
                          }
                          if (snapshot.hasError ||
                              !snapshot.hasData ||
                              snapshot.data!.isEmpty) {
                            return Text(
                              "無法取得評分資料",
                              style: TextStyle(
                                color: colorScheme.subtitleText,
                                fontSize: 13,
                              ),
                            );
                          }
                          // 渲染抓取到的評分清單
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: snapshot.data!
                                .map(
                                  (e) => Padding(
                                    padding: const EdgeInsets.only(bottom: 6.0),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            e,
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: colorScheme.primaryText,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                                .toList(),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );

        if (isLiquidGlass) {
          return Container(
            margin: EdgeInsets.only(bottom: widget.isInline ? 8 : 12),
            clipBehavior: Clip.antiAlias,
            decoration:
                glassCardDecoration(context, borderRadius: 15) ??
                const BoxDecoration(color: Colors.transparent),
            child: Material(color: Colors.transparent, child: cardChild),
          );
        }
        return Card(
          elevation: 2,
          color: colorScheme.cardBackground,
          margin: EdgeInsets.only(bottom: widget.isInline ? 8 : 12),
          clipBehavior: Clip.antiAlias,
          child: cardChild,
        );
      },
    );
  }

  String _calculateProbability(CourseJsonData course) {
    if (course.remaining <= 0) return "0% (已滿)";
    double prob = course.remaining / course.select;
    if (course.select <= 0 || prob > 1) return "100%";
    return "${(prob * 100).toStringAsFixed(1)}%";
  }

  Widget _buildProbabilityChip(CourseJsonData course, ColorScheme colorScheme) {
    double prob = 1.0;
    if (course.remaining <= 0) {
      prob = 0.0;
    } else if (course.select > 0) {
      prob = course.remaining / course.select;
      if (prob > 1.0) prob = 1.0;
    }

    final isDark = colorScheme.isDark;
    Color backgroundColor;
    Color textColor;

    if (prob >= 0.7) {
      backgroundColor = isDark
          ? Colors.green[900]!.withValues(alpha: 0.3)
          : Colors.green[50]!;
      textColor = isDark ? Colors.green[200]! : Colors.green[800]!;
    } else if (prob >= 0.3) {
      backgroundColor = isDark
          ? Colors.orange[900]!.withValues(alpha: 0.3)
          : Colors.orange[50]!;
      textColor = isDark ? Colors.orange[200]! : Colors.orange[800]!;
    } else {
      backgroundColor = isDark
          ? Colors.red[900]!.withValues(alpha: 0.3)
          : Colors.red[50]!;
      textColor = isDark ? Colors.red[200]! : Colors.red[800]!;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            "機率: ${_calculateProbability(course)}",
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(
    IconData icon,
    String label,
    String value,
    ColorScheme colorScheme, {
    Color? valueColor,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: colorScheme.iconColor),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 11, color: colorScheme.subtitleText),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: valueColor ?? colorScheme.primaryText,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTimeDisplay(List<String> times, ColorScheme colorScheme) {
    final days = ["一", "二", "三", "四", "五", "六", "日"];
    List<Widget> timeWidgets = [];
    for (int i = 0; i < times.length && i < 7; i++) {
      if (times[i].isNotEmpty) {
        timeWidgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    "星期${days[i]}",
                    style: TextStyle(
                      color: colorScheme.isDark
                          ? const Color(0xFF90CAF9)
                          : colorScheme.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  "第 ${times[i]} 節",
                  style: TextStyle(
                    fontSize: 14,
                    color: colorScheme.primaryText,
                  ),
                ),
              ],
            ),
          ),
        );
      }
    }
    if (timeWidgets.isEmpty)
      return Text("無時間資訊", style: TextStyle(color: colorScheme.subtitleText));
    return Column(children: timeWidgets);
  }

  Widget _buildSearchFormContent(
    BuildContext context, {
    required bool isInlineSearch,
    required VoidCallback onClose,
    StateSetter? setModalState,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    void updateState(VoidCallback fn) {
      if (setModalState != null) {
        setModalState(fn);
      }
      setState(fn);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!isInlineSearch)
          Center(
            child: Text(
              "課程查詢條件",
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: colorScheme.primaryText,
              ),
            ),
          )
        else
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "課程查詢條件",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.primaryText,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 20),
                onPressed: onClose,
              ),
            ],
          ),
        Row(
          children: [
            Expanded(
              child: _isSemesterLoading
                  ? const Center(
                      child: SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : _buildDropdown(
                      label: "學期",
                      value: _selectedSemester ?? "",
                      items: _semesterOptions,
                      displayMap: _semesterDisplayMap,
                      onChanged: (v) =>
                          updateState(() => _selectedSemester = v),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(child: _buildTextField("課程名稱", _crsNameCtrl)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _buildTextField("授課教師", _teacherCtrl)),
            const SizedBox(width: 12),
            Expanded(child: _buildTextField("開課系所", _deptCtrl, hint: "例如: 資工")),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildDropdown(
                label: "年級 (D2)",
                value: _selectedGrade ?? "",
                items: const ["", "1", "2", "3", "4", "5"],
                displayMap: const {
                  "": "全部",
                  "1": "一年級",
                  "2": "二年級",
                  "3": "三年級",
                  "4": "四年級",
                  "5": "五年級",
                },
                onChanged: (v) => updateState(
                  () => _selectedGrade = (v == null || v.isEmpty) ? null : v,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildDropdown(
                label: "班級 (CLASS)",
                value: _selectedClass ?? "",
                items: const ["", "0", "1", "2", "5"],
                displayMap: const {
                  "": "全部",
                  "0": "不分班",
                  "1": "甲班",
                  "2": "乙班",
                  "5": "全英班",
                },
                onChanged: (v) => updateState(
                  () => _selectedClass = (v == null || v.isEmpty) ? null : v,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          "上課時間",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: colorScheme.subtitleText,
            fontFamily: Theme.of(context).textTheme.bodyMedium?.fontFamily,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: _buildDropdown(
                label: "星期",
                value: _selectedDay ?? "",
                items: const ["", "1", "2", "3", "4", "5", "6", "7"],
                displayMap: const {
                  "": "不限",
                  "1": "星期一",
                  "2": "星期二",
                  "3": "星期三",
                  "4": "星期四",
                  "5": "星期五",
                  "6": "星期六",
                  "7": "星期日",
                },
                onChanged: (v) => updateState(
                  () => _selectedDay = (v == null || v.isEmpty) ? null : v,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildDropdown(
                label: "節次",
                value: _selectedPeriod ?? "",
                items: const [
                  "",
                  "A",
                  "1",
                  "2",
                  "3",
                  "4",
                  "B",
                  "5",
                  "6",
                  "7",
                  "8",
                  "9",
                  "C",
                ],
                displayMap: const {
                  "": "不限",
                  "A": "A (07:00)",
                  "1": "1 (08:10)",
                  "2": "2 (09:10)",
                  "3": "3 (10:10)",
                  "4": "4 (11:10)",
                  "B": "B (12:10)",
                  "5": "5 (13:10)",
                  "6": "6 (14:10)",
                  "7": "7 (15:10)",
                  "8": "8 (16:10)",
                  "9": "9 (17:10)",
                  "C": "C (18:20)",
                },
                onChanged: (v) => updateState(
                  () => _selectedPeriod = (v == null || v.isEmpty) ? null : v,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          height: 45,
          child: ElevatedButton(
            onPressed: () {
              onClose();
              _performSearch();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: colorScheme.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text("開始查詢", style: TextStyle(fontSize: 16)),
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: TextButton(
            onPressed: () {
              updateState(() {
                _clearSearchFields();
              });
            },
            child: Text(
              "重設條件",
              style: TextStyle(color: colorScheme.subtitleText),
            ),
          ),
        ),
      ],
    );
  }

  void _showSearchSheet() {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = colorScheme.isDark;
    final isLiquidGlass = LayoutStyleNotifier.instance.isLiquidGlass;
    showGlassModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: colorScheme.cardBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return DraggableScrollableSheet(
              initialChildSize: 0.85,
              minChildSize: 0.5,
              maxChildSize: 0.95,
              expand: false,
              builder: (context, scrollController) {
                final formContent = SingleChildScrollView(
                  controller: scrollController,
                  padding: EdgeInsets.only(
                    left: 20,
                    right: 20,
                    top: 20,
                    bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                  ),
                  child: _buildSearchFormContent(
                    context,
                    isInlineSearch: false,
                    onClose: () => Navigator.pop(context),
                    setModalState: setModalState,
                  ),
                );
                if (!isLiquidGlass) return formContent;
                return Container(
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF1E222D).withValues(alpha: 0.90)
                        : Colors.white.withValues(alpha: 0.90),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.12)
                          : Colors.black.withValues(alpha: 0.08),
                      width: 1.0,
                    ),
                  ),
                  child: formContent,
                );
              },
            );
          },
        );
      },
    );
  }

  // ✅ 核心變更：加入了 await CourseQueryService.instance.getCourses()
  Future<void> _performSearch() async {
    setState(() {
      _isQueryLoading = true;
      _hasSearched = true;
    });

    try {
      // 1. 確保資料已經透過 API 下載完畢 (初次點擊時會下載 all.json，之後就有 cache)
      await CourseQueryService.instance.getCourses(semester: _selectedSemester);

      // 2. 處理班級下拉選單對應的中文字 (因為 API JSON 的 class 欄位是中文字)
      String? classText;
      if (_selectedClass == "0") classText = "不分班";
      if (_selectedClass == "1") classText = "甲班";
      if (_selectedClass == "2") classText = "乙班";
      if (_selectedClass == "5") classText = "全英班";

      // 3. 呼叫 Search 邏輯
      final results = CourseQueryService.instance.search(
        keyword: _crsNameCtrl.text.trim(),
        teacher: _teacherCtrl.text.trim(),
        code: _codeCtrl.text.trim(),
        grade: _selectedGrade,
        classType: classText,
        day: _selectedDay,
        period: _selectedPeriod,
        dept: _deptCtrl.text.trim(),
      );

      if (!mounted) return;
      setState(() {
        _searchResults = results;
        _isQueryLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isQueryLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("搜尋失敗或資料載入錯誤: $e")));
      }
    }
  }

  void _clearSearchFields() {
    _crsNameCtrl.clear();
    _teacherCtrl.clear();
    _codeCtrl.clear();
    _deptCtrl.clear();
    setState(() {
      _selectedGrade = null;
      _selectedClass = null;
      _selectedDay = null;
      _selectedPeriod = null;
    });
    Navigator.pop(context);
  }

  Widget _buildDropdown({
    required String label,
    required String value,
    required List<String> items,
    Map<String, String>? displayMap,
    required ValueChanged<String?> onChanged,
  }) {
    return GlassSingleSelectDropdown(
      label: label,
      items: items,
      value: value,
      displayMap: displayMap,
      onChanged: onChanged,
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller, {
    String? hint,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final isLiquidGlass = LayoutStyleNotifier.instance.isLiquidGlass;
    final isDark = colorScheme.isDark;
    final Color fill = isLiquidGlass
        ? (isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.white.withValues(alpha: 0.4))
        : colorScheme.subtleBackground;
    final Color borderCol = isLiquidGlass
        ? (isDark
              ? Colors.white.withValues(alpha: 0.35)
              : Colors.black.withValues(alpha: 0.08))
        : colorScheme.borderColor;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.bold,
            fontSize: 12,
            color: colorScheme.subtitleText,
          ),
        ),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: colorScheme.primaryText),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: colorScheme.subtitleText),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 8,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: borderCol, width: 1.0),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: borderCol, width: 1.0),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
            ),
            isDense: true,
            filled: true,
            fillColor: fill,
          ),
        ),
      ],
    );
  }

  String _parseRoomLocation(String rawRoom) {
    if (rawRoom.isEmpty) return "不明";
    final RegExp regex = RegExp(r'[(\uff08]([^)\uff09]*)[)\uff09]');
    final match = regex.firstMatch(rawRoom);
    if (match != null) {
      String content = match.group(1)?.trim() ?? "";
      return content.isNotEmpty ? content : "不明";
    }
    return "不明";
  }

  // ✅ 新增抓取評分方式的核心方法
  Future<List<String>> _getCourseEvaluation(String courseId) async {
    // 1. 如果已經抓過，直接回傳快取
    if (_evaluationCache.containsKey(courseId)) {
      return _evaluationCache[courseId]!;
    }

    // 取得當前學期字串 (請確認 CourseQueryService 中有這個屬性)
    final semStr = CourseQueryService.instance.currentSemester;
    if (semStr.length != 4) return ["無法取得學期資訊"];

    final syear = semStr.substring(0, 3); // 前三碼 (114)
    final sem = semStr.substring(3, 4); // 最後一碼 (2)
    final url = Uri.parse(
      'https://selcrs.nsysu.edu.tw/menu5/showoutline.asp?SYEAR=$syear&SEM=$sem&CrsDat=$courseId',
    );

    try {
      final client = createHttpClient();
      final response = await client.get(url);
      client.close();
      if (response.statusCode == 200) {
        // 中山舊系統編碼處理
        String html = utf8.decode(response.bodyBytes, allowMalformed: true);

        // 使用最安全的抓法：確保只有兩個捕獲群組 ()
        final RegExp exp = RegExp(
          r'SS4_\d+1[^>]*>([^<]*)</span>[^<]*<span[^>]*SS4_\d+2[^>]*>([^<]*)</span>',
          caseSensitive: false,
        );

        final matches = exp.allMatches(html);
        List<String> evals = [];
        int index = 1;

        for (var match in matches) {
          String item = match.group(1)?.trim() ?? "";
          String pct = match.group(2)?.trim() ?? "";

          if (item.isNotEmpty) {
            evals.add('$index. $item：${pct.isNotEmpty ? pct : "0"}%');
            index++;
          }
        }

        if (evals.isEmpty) evals.add("尚無評分方式資料");

        _evaluationCache[courseId] = evals; // 存入快取
        return evals;
      }
    } catch (e) {
      return ["載入失敗，請稍後再試"];
    }
    return ["查無資料"];
  }

  // ✅ 新增：寬螢幕下在右側面板內嵌顯示搜尋面板的元件
  Widget _buildInlineSearchView(ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: _buildSearchFormContent(
              context,
              isInlineSearch: true,
              onClose: () {
                setState(() {
                  _showInlineSearch = false;
                });
              },
            ),
          ),
        ),
      ],
    );
  }
}
