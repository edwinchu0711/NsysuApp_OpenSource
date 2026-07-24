import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // <--- 新增這行，用於 Clipboard 剪貼簿功能
import 'package:shared_preferences/shared_preferences.dart';
import '../models/course_model.dart';
import '../services/course_service.dart';
import '../theme/app_theme.dart';
import '../theme/layout_style_notifier.dart';
import '../widgets/glass/glass_dropdown.dart';
import '../widgets/glass/glass_page_scaffold.dart';
import '../widgets/glass/glass_dialog.dart';
import '../services/course_query_service.dart';

class CourseSchedulePage extends StatefulWidget {
  const CourseSchedulePage({Key? key}) : super(key: key);

  @override
  State<CourseSchedulePage> createState() => _CourseSchedulePageState();
}

class _CourseSchedulePageState extends State<CourseSchedulePage> {
  // --- 資料狀態 ---
  Map<String, List<Course>> _allCourses = {}; // Key: "1131"
  List<String> _availableSemesters = [];
  String? _selectedSemester;
  Course? _selectedCourseForDetail;
  bool _isLoading = false;

  // --- API 資料狀態 (系所與學程) ---
  final ValueNotifier<List<CourseJsonData>> _apiCoursesNotifier = ValueNotifier(
    [],
  );
  final ValueNotifier<bool> _isApiLoadingNotifier = ValueNotifier(false);
  String? _apiLoadedSemester;

  // 定義節次與時間對照 (保留原有的對應表以便 UI 使用)
  final List<String> _periods = [
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
  final List<String> _fullWeekDays = ['一', '二', '三', '四', '五', '六', '日'];
  final Map<String, String> _timeMapping = {
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

  // 用於彈窗詳情顯示（清單格式）
  final Map<String, List<String>> _timeRangeMap = {
    'A': ['07:00', '07:50'],
    '1': ['08:10', '09:00'],
    '2': ['09:10', '10:00'],
    '3': ['10:10', '11:00'],
    '4': ['11:10', '12:00'],
    'B': ['12:10', '13:00'],
    '5': ['13:10', '14:00'],
    '6': ['14:10', '15:00'],
    '7': ['15:10', '16:00'],
    '8': ['16:10', '17:00'],
    '9': ['17:10', '18:00'],
    'C': ['18:20', '19:10'],
    'D': ['19:15', '20:05'],
    'E': ['20:10', '21:00'],
    'F': ['21:05', '21:55'],
  };

  @override
  void initState() {
    super.initState();
    _loadCachedData();
  }

  @override
  void dispose() {
    super.dispose();
  }

  // --- 核心邏輯：讀取快取 ---
  Future<void> _loadCachedData() async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      String? jsonStr = prefs.getString('cached_courses');

      if (jsonStr != null && jsonStr.isNotEmpty) {
        Map<String, dynamic> decoded = jsonDecode(jsonStr);
        Map<String, List<Course>> loadedData = {};

        decoded.forEach((key, value) {
          if (value is List) {
            loadedData[key] = value
                .map((v) => _courseFromJson(v, key))
                .toList();
          }
        });

        if (mounted) {
          setState(() {
            _allCourses = loadedData;
            _availableSemesters = _allCourses.keys.toList()
              ..sort((a, b) => b.compareTo(a));

            if (_availableSemesters.isNotEmpty) {
              _selectedSemester = _availableSemesters.first;
            }
          });
          _loadApiCourses();
        }
      }
    } catch (e) {
      debugPrint("❌ 課表展示頁：載入失敗 $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadApiCourses() async {
    final semester = _selectedSemester;
    if (semester == null) return;

    final apiSem = _getApiSemester(semester);
    if (_apiLoadedSemester == semester &&
        _apiCoursesNotifier.value.isNotEmpty) {
      return; // 已經載入此學期
    }

    setState(() {
      _isApiLoadingNotifier.value = true;
      _apiCoursesNotifier.value = []; // 避免在載入新學期時使用舊資料匹配
    });

    try {
      final courses = await CourseQueryService.instance.getCourses(
        semester: apiSem,
      );
      if (mounted && _selectedSemester == semester) {
        setState(() {
          _apiCoursesNotifier.value = courses;
          _apiLoadedSemester = semester;
          _isApiLoadingNotifier.value = false;
        });
      }
    } catch (e) {
      debugPrint("❌ [課程API] 載入失敗: $e");
      if (mounted && _selectedSemester == semester) {
        setState(() {
          _apiCoursesNotifier.value = [];
          _isApiLoadingNotifier.value = false;
        });
      }
    }
  }

  String _getApiSemester(String schoolSem) {
    return schoolSem;
  }

  String _normalizeCode(String code) {
    String s = code
        .replaceAll(RegExp(r'&nbsp;?', caseSensitive: false), '')
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll(RegExp(r'\s+'), '')
        .toUpperCase();

    // 將全形英文字母、數字轉換為半形
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
    return buffer.toString().replaceAll(' ', '');
  }

  bool _matchCourseCodeExact(String apiId, String schoolCode) {
    return _normalizeCode(apiId) == _normalizeCode(schoolCode);
  }

  bool _matchCourseCodeFuzzy(String apiId, String schoolCode) {
    final normApi = _normalizeCode(apiId);
    final normSchool = _normalizeCode(schoolCode);
    return normApi.contains(normSchool) || normSchool.contains(normApi);
  }

  Map<String, String> _splitCourseName(String fullName) {
    final String chinesePart = keepUntilLastChinese(fullName).trim();
    if (chinesePart.isEmpty) {
      return {"chinese": fullName, "english": ""};
    }
    final String englishPart = fullName.substring(chinesePart.length).trim();
    return {"chinese": chinesePart, "english": englishPart};
  }

  // JSON 解析輔助
  Course _courseFromJson(Map<String, dynamic> json, String semester) {
    var times =
        (json['parsedTimes'] as List?)
            ?.map((t) => CourseTime(t['day'], t['period']))
            .toList() ??
        [];
    return Course(
      name: json['name'] ?? "",
      code: json['code'] ?? "",
      professor: json['professor'] ?? "",
      location: json['location'] ?? "",
      timeString: json['timeString'] ?? "",
      credits: json['credits'] ?? "",
      required: json['required'] ?? "",
      detailUrl: json['detailUrl'] ?? "",
      parsedTimes: times,
      semester: semester,
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth >= 750;
    final double horizontalPadding = isTablet
        ? (screenWidth > 960 ? (screenWidth - 960) / 2 + 16.0 : 24.0)
        : 0.0;

    return GlassPageScaffold(
      appBar: AppBar(
        title: const Text("歷年課表查詢"),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: "重新整理",
            onPressed: _isLoading ? null : _refreshFromNetwork,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _allCourses.isEmpty
          ? _buildEmptyState()
          : SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                child: Column(
                  children: [
                    isTablet
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // 左邊課表區域
                              Expanded(
                                flex: 55,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 16),
                                    // 學期切換選擇器 (內含匯出按鈕)
                                    _buildSemesterSelector(isTablet: isTablet),
                                    const SizedBox(height: 16),
                                    // 課表主體
                                    _buildTimeTable(
                                      _allCourses[_selectedSemester!] ?? [],
                                      isTablet: isTablet,
                                      screenWidth: screenWidth,
                                    ),
                                    const SizedBox(height: 32),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 24),
                              // 右邊詳細資料區域
                              Expanded(
                                flex: 45,
                                child: Column(
                                  children: [
                                    const SizedBox(height: 16),
                                    _buildRightDetailsPane(isTablet: isTablet),
                                  ],
                                ),
                              ),
                            ],
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // 學期切換選擇器 (內含匯出按鈕)
                              _buildSemesterSelector(isTablet: isTablet),
                              // 課表主體 (移除 Expanded)
                              _buildTimeTable(
                                _allCourses[_selectedSemester!] ?? [],
                                isTablet: isTablet,
                                screenWidth: screenWidth,
                              ),
                            ],
                          ),
                    if (LayoutStyleNotifier.instance.isLiquidGlass)
                      const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
    );
  }

  // --- 核心邏輯：從網路抓取最新課表 ---
  Future<void> _refreshFromNetwork() async {
    setState(() => _isLoading = true);
    try {
      await CourseService.instance.refreshAndCache();
      final updatedData = CourseService.instance.allCoursesNotifier.value;

      if (mounted) {
        setState(() {
          _allCourses = updatedData;
          _availableSemesters = updatedData.keys.toList()
            ..sort((a, b) => b.compareTo(a));

          if (_availableSemesters.isNotEmpty) {
            _selectedSemester = _availableSemesters.first;
          }
        });
        _loadApiCourses();

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("課表已同步至最新")));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("更新失敗: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- 修改處 2：新增匯出課表的邏輯 ---
  void _exportTimetable() {
    if (_selectedSemester == null || _allCourses[_selectedSemester!] == null)
      return;

    final courses = _allCourses[_selectedSemester!]!;

    // 依據要求的格式轉換
    final exportData = courses.map((c) {
      return {"id": c.code, "name": c.name, "value": 50, "isSel": "+"};
    }).toList();

    // 將 List 轉為 JSON 字串並組合成最終格式
    final jsonStr = jsonEncode(exportData);
    final exportText = 'const exportClass = $jsonStr;';

    // 複製到剪貼簿
    Clipboard.setData(ClipboardData(text: exportText)).then((_) {
      if (mounted) {
        // 顯示匯出成功與引導前往選課助手的彈窗
        showGlassDialog(
          context: context,
          title: const Text("匯出成功 🎉"),
          content: const Text("課表代碼已複製到剪貼簿！\n\n你可以前往「選課助手」的頁面進行匯入操作。"),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
              child: const Text(
                "我知道了",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      }
    });
  }

  // 修改處 3：在選擇器內加入匯出按鈕 (設計為與課表完美融合的風格，並優化寬度與圖示)
  Widget _buildSemesterSelector({required bool isTablet}) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = colorScheme.isDark;

    return Padding(
      padding: isTablet
          ? const EdgeInsets.only(bottom: 12)
          : const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Text(
            "學期切換",
            style: TextStyle(
              fontSize: isTablet ? 14 : 12,
              fontWeight: FontWeight.w600,
              color: isDark ? colorScheme.subtitleText : Colors.grey[700],
            ),
          ),
          const SizedBox(width: 8),
          // 加上 Expanded 讓下拉選單最大化，避免小螢幕 Overflow
          Expanded(
            child: GlassSingleSelectDropdown(
              label: "",
              items: _availableSemesters,
              value: _selectedSemester!,
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    _selectedSemester = val;
                    _selectedCourseForDetail = null;
                  });
                  _loadApiCourses();
                }
              },
              displayMap: Map.fromEntries(
                _availableSemesters.map(
                  (s) => MapEntry(
                    s,
                    "${s.substring(0, 3)}學年 第${s.substring(3)}學期",
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // 匯出按鈕 (已更換為專屬匯出/上傳圖示)
          IconButton(
            icon: Icon(
              Icons.file_upload_rounded,
              color: isDark ? colorScheme.secondary : Colors.blue,
              size: isTablet ? 24 : 20,
            ),
            tooltip: "匯出課表代碼",
            onPressed: _exportTimetable,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.event_note, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          const Text(
            "尚未取得課表資料",
            style: TextStyle(color: Colors.grey, fontSize: 18),
          ),
          const SizedBox(height: 8),
          const Text("請回首頁自動同步或檢查網路連線", style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildTimeTable(
    List<Course> courses, {
    required bool isTablet,
    required double screenWidth,
  }) {
    int maxDay = 5;
    for (var c in courses) {
      for (var t in c.parsedTimes) {
        if (t.day == 6 && maxDay < 6) maxDay = 6;
        if (t.day == 7) maxDay = 7;
      }
    }
    List<String> visibleWeekDays = _fullWeekDays.sublist(0, maxDay);

    bool hasPeriodA = false;
    int maxPeriodIndex = _periods.indexOf('7');

    for (var c in courses) {
      for (var t in c.parsedTimes) {
        if (t.period == 'A') hasPeriodA = true;
        int currentIndex = _periods.indexOf(t.period);
        if (currentIndex > maxPeriodIndex) {
          maxPeriodIndex = currentIndex;
        }
      }
    }

    int displayEndIndex = maxPeriodIndex;
    if (displayEndIndex < _periods.length - 1) {
      displayEndIndex += 1;
    }

    int startIndex = hasPeriodA ? 0 : _periods.indexOf('1');
    List<String> visiblePeriods = _periods.sublist(
      startIndex,
      displayEndIndex + 1,
    );

    Map<String, Course> courseMap = {};
    for (var c in courses) {
      for (var t in c.parsedTimes) {
        courseMap["${t.day}-${t.period}"] = c;
      }
    }

    final colorScheme = Theme.of(context).colorScheme;
    final isDark = colorScheme.isDark;
    final isLiquidGlass = LayoutStyleNotifier.instance.isLiquidGlass;

    // 定義寬螢幕下的尺寸與字體大小優化 (使其更加精緻與緊湊)
    final double periodColWidth = maxDay > 5
        ? (isTablet ? 42.0 : 36.0)
        : (isTablet ? 52.0 : 45.0);
    final double headerHeight = isTablet ? 40.0 : 32.0;
    final double rowHeight = isTablet ? 76.0 : 70.0;

    final double headerTimePeriodFontSize = isTablet ? 12.0 : 10.0;
    final double headerDayFontSize = isTablet ? 14.0 : 13.0;
    final double periodNumFontSize = isTablet ? 15.0 : 14.0;
    final double periodTimeFontSize = isTablet ? 10.0 : 9.0;

    // Calculate font sizes dynamically for cells based on screen width
    double timetableWidth;
    if (isTablet) {
      final double horizontalPadding = screenWidth > 960
          ? (screenWidth - 960) / 2 + 16.0
          : 24.0;
      final double doublePadding = horizontalPadding * 2;
      timetableWidth = (screenWidth - doublePadding) * 0.55;
    } else {
      timetableWidth = screenWidth;
    }
    double columnWidth = (timetableWidth - periodColWidth) / maxDay;

    double courseNameFontSize = (10.0 + (columnWidth - 60.0) * 0.1).clamp(
      8.0,
      14.0,
    );
    double courseLocationFontSize = (8.0 + (columnWidth - 60.0) * 0.08).clamp(
      7.0,
      11.0,
    );

    Widget tableWidget = Table(
      border: TableBorder.all(
        color: isLiquidGlass
            ? (isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.white.withValues(alpha: 0.35))
            : (isDark ? colorScheme.borderColor : const Color(0xFFD0E2FF)),
        width: 0.5,
      ),
      columnWidths: {0: FixedColumnWidth(periodColWidth)},
      children: [
        TableRow(
          decoration: BoxDecoration(
            color: isLiquidGlass
                ? (isDark
                      ? Colors.white.withValues(alpha: 0.06)
                      : Colors.white.withValues(alpha: 0.45))
                : (isDark
                      ? colorScheme.secondaryCardBackground
                      : const Color(0xFFE8F0FE)),
          ),
          children: [
            SizedBox(
              height: headerHeight,
              child: Center(
                child: Text(
                  "時段",
                  style: TextStyle(
                    fontSize: headerTimePeriodFontSize,
                    color: isDark ? colorScheme.subtitleText : Colors.grey[600],
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
                    fontSize: headerDayFontSize,
                    color: isDark ? colorScheme.primaryText : Colors.black87,
                  ),
                ),
              ),
            ),
          ],
        ),
        ...visiblePeriods.map((period) {
          String timeInfo = _timeMapping[period] ?? "";

          // 計算此節次在整個星期中所有天的課程最高高度
          double maxCellHeight = rowHeight;
          for (int d = 1; d <= maxDay; d++) {
            var c = courseMap["$d-$period"];
            if (c != null) {
              final displayName = keepUntilLastChinese(c.name);
              double h = rowHeight;
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

          // 因為此頁面每格最多一堂課（無衝突），直接使用最長的高度作為此節次所有格子的基準高度
          double? overrideHeight = maxCellHeight;

          return TableRow(
            children: [
              TableCell(
                verticalAlignment: TableCellVerticalAlignment.fill,
                child: Container(
                  color: isLiquidGlass
                      ? (isDark
                            ? Colors.white.withValues(alpha: 0.04)
                            : Colors.white.withValues(alpha: 0.45))
                      : (isDark
                            ? colorScheme.cardBackground
                            : const Color(0xFFF0F4FE)),
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        period,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: periodNumFontSize,
                          color: isDark
                              ? colorScheme.primaryText
                              : Colors.black87,
                        ),
                      ),
                      if (timeInfo.isNotEmpty)
                        Text(
                          timeInfo,
                          style: TextStyle(
                            fontSize: periodTimeFontSize,
                            color: isDark
                                ? colorScheme.subtitleText
                                : Colors.grey[600],
                          ),
                          textAlign: TextAlign.center,
                        ),
                    ],
                  ),
                ),
              ),
              ...List.generate(maxDay, (dayIndex) {
                int currentDay = dayIndex + 1;
                var cellCourse = courseMap["$currentDay-$period"];

                double cellHeight = overrideHeight;
                String displayName = "";
                if (cellCourse != null) {
                  displayName = keepUntilLastChinese(cellCourse.name);
                }

                return Container(
                  height: cellHeight,
                  padding: const EdgeInsets.all(1),
                  child: cellCourse == null
                      ? Container(
                          color: isLiquidGlass
                              ? (isDark
                                    ? Colors.transparent
                                    : Colors.white.withValues(alpha: 0.15))
                              : (isDark
                                    ? Colors.transparent
                                    : const Color(0xFFF7FAFF)),
                        )
                      : Material(
                          color: _getCourseColor(cellCourse.name),
                          borderRadius: BorderRadius.circular(isTablet ? 6 : 4),
                          child: InkWell(
                            onTap: () {
                              if (isTablet) {
                                setState(() {
                                  _selectedCourseForDetail = cellCourse;
                                });
                              } else {
                                _showCourseDetail(cellCourse);
                              }
                            },
                            child: Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: isTablet ? 6 : 4,
                                vertical: isTablet ? 4 : 2,
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Flexible(
                                    child: Text(
                                      displayName,
                                      style: TextStyle(
                                        fontSize: courseNameFontSize,
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
                                    _extractLocation(cellCourse.location),
                                    style: TextStyle(
                                      fontSize: courseLocationFontSize,
                                      color: Colors.white70,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                );
              }),
            ],
          );
        }).toList(),
      ],
    );

    if (isTablet) {
      tableWidget = Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: isDark ? Colors.black26 : Colors.black12,
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: tableWidget,
        ),
      );
    }

    return tableWidget;
  }

  Widget _buildRightDetailsPane({required bool isTablet}) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = colorScheme.isDark;

    if (_selectedCourseForDetail == null) {
      return Container(
        height: 400, // Reasonable height for placeholder
        decoration: BoxDecoration(
          color: colorScheme.cardBackground,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colorScheme.borderColor.withValues(alpha: 0.5)),
          boxShadow: [
            BoxShadow(
              color: isDark ? Colors.black26 : Colors.black12,
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colorScheme.secondaryCardBackground,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.class_outlined,
                    size: 48,
                    color: colorScheme.accentBlue,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  "課程詳細資訊",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primaryText,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "請點擊左側課表中的任一課程\n以在此處查看教室、學分、教授與上課時間",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: colorScheme.subtitleText,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return FutureBuilder<SharedPreferences>(
      future: SharedPreferences.getInstance(),
      builder: (context, snapshot) {
        final showReviewButton =
            snapshot.data?.getBool('show_course_review_button') ?? false;

        final course = _selectedCourseForDetail!;
        final prettyTime = _formatCourseTimeWithRange(course);
        final courseColor = _getCourseColor(course.name);

        // Make a beautiful gradient using the course color
        final gradient = LinearGradient(
          colors: [
            courseColor,
            HSVColor.fromColor(courseColor)
                .withValue(
                  (HSVColor.fromColor(courseColor).value * 0.82).clamp(
                    0.0,
                    1.0,
                  ),
                )
                .toColor(),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );

        // 尋找 API 中的系所與學程資訊
        final normSchoolCode = _normalizeCode(course.code);
        debugPrint(
          "🔍 [比對偵錯-平板] 點擊課程: ${course.name}, 原始課號: '${course.code}', 規一化課號: '$normSchoolCode'",
        );
        debugPrint(
          "🔍 [比對偵錯-平板] 當前 API 下載的課程總數: ${_apiCoursesNotifier.value.length}",
        );

        var apiCourseList = _apiCoursesNotifier.value
            .where((e) => _matchCourseCodeExact(e.id, course.code))
            .toList();
        if (apiCourseList.isEmpty) {
          apiCourseList = _apiCoursesNotifier.value
              .where((e) => _matchCourseCodeFuzzy(e.id, course.code))
              .toList();
          if (apiCourseList.isNotEmpty) {
            debugPrint(
              "🔍 [比對偵錯-平板] 精確比對失敗，但模糊比對成功！匹配到: ${apiCourseList.map((e) => "${e.id}(${e.name.split('\n')[0]})").join(', ')}",
            );
          }
        } else {
          debugPrint(
            "🔍 [比對偵錯-平板] 精確比對成功！匹配到: ${apiCourseList.first.id}(${apiCourseList.first.name.split('\n')[0]})",
          );
        }

        if (apiCourseList.isEmpty && _apiCoursesNotifier.value.isNotEmpty) {
          debugPrint(
            "❌ [比對偵錯-平板] 完全找不到匹配課程！API 內前 10 筆課程代碼範例: ${_apiCoursesNotifier.value.take(10).map((e) => e.id).join(', ')}",
          );
        }

        final CourseJsonData? apiCourse = apiCourseList.isNotEmpty
            ? apiCourseList.first
            : null;
        final hasApiData = apiCourse != null;
        final departmentText = hasApiData ? apiCourse.department : "未指定";
        final List<String> tags = hasApiData ? apiCourse.tags : [];

        return Container(
          decoration: BoxDecoration(
            color: colorScheme.cardBackground,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: isDark ? Colors.black26 : Colors.black12,
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          foregroundDecoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colorScheme.borderColor.withValues(alpha: 0.5)),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // 精緻頂部 Banner (使用漸層)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 24,
                ),
                decoration: BoxDecoration(gradient: gradient),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        course.code,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // 中英文分離標題
                    (() {
                      final nameParts = _splitCourseName(course.name);
                      final chineseName = nameParts["chinese"]!;
                      final englishName = nameParts["english"]!;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            chineseName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              height: 1.2,
                            ),
                          ),
                          if (englishName.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              englishName,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.85),
                                fontSize: 13,
                                fontWeight: FontWeight.normal,
                                height: 1.2,
                              ),
                            ),
                          ],
                        ],
                      );
                    })(),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 收集有資料的欄位
                    (() {
                      final List<Widget> detailRows = [];

                      // 1. 學分與選別
                      final showCredits =
                          course.credits.isNotEmpty ||
                          course.required.isNotEmpty;
                      if (showCredits) {
                        detailRows.add(
                          _buildModernDetailRow(
                            icon: Icons.stars_rounded,
                            iconColor: Colors.deepPurpleAccent,
                            label: "學分與選別",
                            content: Text(
                              "${course.credits}學分 (${course.required})",
                              style: TextStyle(
                                fontSize: 15,
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
                          _buildModernDetailRow(
                            icon: Icons.person_rounded,
                            iconColor: Colors.orange,
                            label: "授課教授",
                            content: Text(
                              course.professor,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: colorScheme.primaryText,
                              ),
                            ),
                          ),
                        );
                      }

                      // 3. 地點
                      final locationText = _extractLocation(course.location);
                      final showLocation =
                          locationText.isNotEmpty &&
                          locationText != "未指定" &&
                          locationText != "無教室資料" &&
                          locationText != "無上課地點資料";
                      if (showLocation) {
                        detailRows.add(
                          _buildModernDetailRow(
                            icon: Icons.location_on_rounded,
                            iconColor: Colors.redAccent,
                            label: "上課教室",
                            content: Text(
                              locationText,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: colorScheme.primaryText,
                              ),
                            ),
                          ),
                        );
                      }

                      // 4. 系所 (從 API 抓取)
                      final showDepartment =
                          _isApiLoadingNotifier.value ||
                          (hasApiData &&
                              departmentText.isNotEmpty &&
                              departmentText != "未指定" &&
                              departmentText != "未提供");
                      if (showDepartment) {
                        detailRows.add(
                          _buildModernDetailRow(
                            icon: Icons.business_rounded,
                            iconColor: Colors.blueAccent,
                            label: "開課系所",
                            isLoading: _isApiLoadingNotifier.value,
                            content: Text(
                              departmentText,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: colorScheme.primaryText,
                              ),
                            ),
                          ),
                        );
                      }

                      // 5. 學程 (從 API 抓取)
                      final showTags =
                          _isApiLoadingNotifier.value ||
                          (hasApiData && tags.isNotEmpty);
                      if (showTags) {
                        detailRows.add(
                          _buildModernDetailRow(
                            icon: Icons.school_rounded,
                            iconColor: Colors.teal,
                            label: "適用學程",
                            isLoading: _isApiLoadingNotifier.value,
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
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
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
                                            fontSize: 12,
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

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (detailRows.isNotEmpty) ...[
                            for (int i = 0; i < detailRows.length; i++) ...[
                              detailRows[i],
                              if (i < detailRows.length - 1)
                                const Divider(height: 1),
                            ],
                          ],
                        ],
                      );
                    })(),
                    const SizedBox(height: 24),
                    // 6. 上課時間區塊
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark
                            ? colorScheme.secondaryCardBackground
                            : Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: colorScheme.borderColor.withValues(alpha: 0.5),
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
                                size: 18,
                                color: colorScheme.accentBlue,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                "上課時間與節次",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: isDark
                                      ? colorScheme.primaryText
                                      : Colors.blueGrey[800],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            prettyTime,
                            style: TextStyle(
                              fontSize: 14,
                              color: colorScheme.primaryText,
                              height: 1.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildModernDetailRow({
    required IconData icon,
    required Color iconColor,
    required String label,
    required Widget content,
    bool isLoading = false,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = colorScheme.isDark;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 36,
            height: 36,
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
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isDark ? colorScheme.subtitleText : Colors.grey[600],
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                isLoading
                    ? Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: SizedBox(
                          height: 16,
                          width: 80,
                          child: LinearProgressIndicator(
                            color: iconColor,
                            backgroundColor: iconColor.withValues(alpha: 0.1),
                            minHeight: 2.5,
                          ),
                        ),
                      )
                    : content,
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showCourseDetail(Course course) {
    String prettyTime = _formatCourseTimeWithRange(course);
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = colorScheme.isDark;

    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth >= 750;
    final courseColor = _getCourseColor(course.name);

    // Make a beautiful gradient using the course color
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

    showDialog(
      context: context,
      builder: (context) => FutureBuilder<SharedPreferences>(
        future: SharedPreferences.getInstance(),
        builder: (context, snapshot) {
          return ValueListenableBuilder<bool>(
            valueListenable: _isApiLoadingNotifier,
            builder: (context, isApiLoading, child) {
              return ValueListenableBuilder<List<CourseJsonData>>(
                valueListenable: _apiCoursesNotifier,
                builder: (context, apiCourses, child) {
                  // 尋找 API 中的系所與學程資訊
                  final normSchoolCode = _normalizeCode(course.code);
                  // debugPrint("🔍 [比對偵錯-手機] 點擊課程: ${course.name}, 原始課號: '${course.code}', 規一化課號: '$normSchoolCode'",);
                  // debugPrint("🔍 [比對偵錯-手機] 當前 API 下載的課程總數: ${apiCourses.length}");

                  var apiCourseList = apiCourses
                      .where((e) => _matchCourseCodeExact(e.id, course.code))
                      .toList();
                  if (apiCourseList.isEmpty) {
                    apiCourseList = apiCourses
                        .where((e) => _matchCourseCodeFuzzy(e.id, course.code))
                        .toList();
                    // if (apiCourseList.isNotEmpty) {
                    //   debugPrint("🔍 [比對偵錯-手機] 精確比對失敗，但模糊比對成功！匹配到: ${apiCourseList.map((e) => "${e.id}(${e.name.split('\n')[0]})").join(', ')}",);
                    // }
                  } else {
                    // debugPrint("🔍 [比對偵錯-手機] 精確比對成功！匹配到: ${apiCourseList.first.id}(${apiCourseList.first.name.split('\n')[0]})",);
                  }

                  if (apiCourseList.isEmpty && apiCourses.isNotEmpty) {
                    debugPrint(
                      "❌ [比對偵錯-手機] 完全找不到匹配課程！API 內前 10 筆課程代碼範例: ${apiCourses.take(10).map((e) => e.id).join(', ')}",
                    );
                  }

                  final CourseJsonData? apiCourse = apiCourseList.isNotEmpty
                      ? apiCourseList.first
                      : null;
                  final hasApiData = apiCourse != null;
                  final departmentText = hasApiData
                      ? apiCourse.department
                      : "未指定";
                  final List<String> tags = hasApiData ? apiCourse.tags : [];

                  // 中英文分離標題
                  final nameParts = _splitCourseName(course.name);
                  final chineseName = nameParts["chinese"]!;
                  final englishName = nameParts["english"]!;

                  final isLiquidGlass =
                      LayoutStyleNotifier.instance.isLiquidGlass;

                  final contentWidget = Container(
                    width: isTablet ? 500 : double.maxFinite,
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 收集有資料的欄位
                          (() {
                            final List<Widget> detailRows = [];

                            // 1. 學分與選別
                            final showCredits =
                                course.credits.isNotEmpty ||
                                course.required.isNotEmpty;
                            if (showCredits) {
                              detailRows.add(
                                _buildModernDetailRow(
                                  icon: Icons.stars_rounded,
                                  iconColor: Colors.deepPurpleAccent,
                                  label: "學分與選別",
                                  content: Text(
                                    "${course.credits}學分 (${course.required})",
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
                                _buildModernDetailRow(
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
                            final locationText = _extractLocation(
                              course.location,
                            );
                            final showLocation =
                                locationText.isNotEmpty &&
                                locationText != "未指定" &&
                                locationText != "無教室資料" &&
                                locationText != "無上課地點資料";
                            if (showLocation) {
                              detailRows.add(
                                _buildModernDetailRow(
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

                            // 4. 系所 (從 API 抓取)
                            final showDepartment =
                                isApiLoading ||
                                (hasApiData &&
                                    departmentText.isNotEmpty &&
                                    departmentText != "未指定" &&
                                    departmentText != "未提供");
                            if (showDepartment) {
                              detailRows.add(
                                _buildModernDetailRow(
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

                            // 5. 學程 (從 API 抓取)
                            final showTags =
                                isApiLoading || (hasApiData && tags.isNotEmpty);
                            if (showTags) {
                              detailRows.add(
                                _buildModernDetailRow(
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
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 10,
                                                    vertical: 4,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: Colors.teal.withValues(alpha: 
                                                  isDark ? 0.15 : 0.08,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(20),
                                                border: Border.all(
                                                  color: Colors.teal
                                                      .withValues(alpha: 
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

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (detailRows.isNotEmpty) ...[
                                  for (
                                    int i = 0;
                                    i < detailRows.length;
                                    i++
                                  ) ...[
                                    detailRows[i],
                                    if (i < detailRows.length - 1)
                                      const Divider(height: 1),
                                  ],
                                ],
                              ],
                            );
                          })(),
                          const SizedBox(height: 16),
                          // 6. 上課時間區塊
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isLiquidGlass
                                  ? (isDark
                                        ? Colors.white.withValues(alpha: 0.04)
                                        : Colors.white.withValues(alpha: 0.35))
                                  : (isDark
                                        ? colorScheme.secondaryCardBackground
                                        : Colors.grey.shade50),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isLiquidGlass
                                    ? (isDark
                                          ? Colors.white.withValues(alpha: 0.1)
                                          : Colors.white.withValues(alpha: 0.35))
                                    : colorScheme.borderColor.withValues(alpha: 0.5),
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
                                      color: colorScheme.accentBlue,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      "上課時間與節次",
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
                                const SizedBox(height: 8),
                                Text(
                                  prettyTime,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: colorScheme.primaryText,
                                    height: 1.4,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );

                  if (isLiquidGlass) {
                    return Dialog(
                      backgroundColor: Colors.transparent,
                      elevation: 0,
                      insetPadding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 40,
                      ),
                      child: Container(
                        width: isTablet ? 500 : double.maxFinite,
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF1C2333).withValues(alpha: 0.92)
                              : Colors.white.withValues(alpha: 0.94),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.18)
                                : Colors.white.withValues(alpha: 0.70),
                            width: 1.2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 
                                isDark ? 0.45 : 0.15,
                              ),
                              blurRadius: 28,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(19),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Title
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 20,
                                ),
                                decoration: BoxDecoration(gradient: gradient),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
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
                              // Content
                              Flexible(
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    20,
                                    10,
                                    20,
                                    10,
                                  ),
                                  child: contentWidget,
                                ),
                              ),
                              // Actions
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  20,
                                  0,
                                  20,
                                  16,
                                ),
                                child: Row(
                                  children: [
                                    const Spacer(),
                                    TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: Text(
                                        "關閉",
                                        style: TextStyle(
                                          color: isDark
                                              ? colorScheme.primary
                                              : null,
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
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
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 20,
                      ),
                      decoration: BoxDecoration(gradient: gradient),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
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
                    content: contentWidget,
                    actions: [
                      Row(
                        children: [
                          const Spacer(),
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: Text(
                              "關閉",
                              style: TextStyle(
                                color: isDark ? colorScheme.primary : null,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  String keepUntilLastChinese(String input) {
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

  String _extractLocation(String raw) {
    final regex = RegExp(r'[\(（](.*?)[\)）]');
    final match = regex.firstMatch(raw);
    return match?.group(1) ?? raw;
  }

  String _formatCourseTimeWithRange(Course c) {
    if (c.parsedTimes.isEmpty) return "無時間資料";

    Map<int, List<String>> dayGroups = {};
    for (var t in c.parsedTimes) {
      if (!dayGroups.containsKey(t.day)) dayGroups[t.day] = [];
      dayGroups[t.day]!.add(t.period);
    }

    List<String> results = [];
    List<int> sortedDays = dayGroups.keys.toList()..sort();

    for (var d in sortedDays) {
      List<String> periods = dayGroups[d]!;
      periods.removeWhere((p) {
        return p.contains("&nbsp") || p.trim().isEmpty;
      });

      if (periods.isEmpty) continue;
      periods.sort(
        (a, b) => _periods.indexOf(a).compareTo(_periods.indexOf(b)),
      );

      String dayName = "星期${_fullWeekDays[d - 1]}";
      String periodStr = periods.join(", ");

      String timeRange = "";

      if (_timeRangeMap.isNotEmpty) {
        String? startT = _timeRangeMap[periods.first]?[0];
        String? endT = _timeRangeMap[periods.last]?[1];
        if (startT != null && endT != null) {
          timeRange = " ($startT - $endT)";
        }
      }

      results.add("$dayName ($periodStr節)$timeRange");
    }

    return results.join("\n");
  }

  Color _getCourseColor(String name, {String? id}) {
    final colors = [
      Colors.blue[700]!, // 藍
      Colors.orange[800]!, // 橘
      Colors.purple[600]!, // 紫
      Colors.teal[700]!, // 藍綠
      Colors.pink[600]!, // 粉紅      // 金黃
      Colors.indigo[600]!, // 靛藍
      Colors.deepOrange[600]!, // 橘紅
      Colors.cyan[700]!, // 青
      Colors.red[600]!, // 紅
      Colors.deepPurple[600]!, // 深紫
      Colors.green[700]!, // 正綠
    ];

    // 組合 key 並取絕對值雜湊
    final String key = id != null ? name + id : name;
    final int hash = key.hashCode.abs();

    return colors[hash % colors.length];
  }
}
