// 檔案名稱：widgets/inline_course_picker.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../../theme/app_theme.dart'; // 引入 AppTheme 與 AppColors 擴充
import '../../../theme/layout_style_notifier.dart';
import '../../../widgets/glass/glass_card.dart';
import '../../../services/course_query_service.dart';
import '../../../services/http_client_factory.dart';

/// 寬螢幕模式下的行內課程搜尋選取器
class InlineCoursePicker extends StatefulWidget {
  final ValueChanged<CourseJsonData> onCourseSelected;
  final VoidCallback onBack;

  const InlineCoursePicker({
    Key? key,
    required this.onCourseSelected,
    required this.onBack,
  }) : super(key: key);

  @override
  State<InlineCoursePicker> createState() => _InlineCoursePickerState();
}

class _InlineCoursePickerState extends State<InlineCoursePicker> {
  bool _isQueryLoading = false;
  List<CourseJsonData> _searchResults = [];
  bool _hasSearched = false;
  bool _inlineSearchFiltersExpanded = true;

  final TextEditingController _crsNameCtrl = TextEditingController();
  final TextEditingController _teacherCtrl = TextEditingController();
  final TextEditingController _codeCtrl = TextEditingController();
  final TextEditingController _deptCtrl = TextEditingController();

  String? _selectedGrade;
  String? _selectedClass;
  String? _selectedDay;
  String? _selectedPeriod;

  final Map<String, List<String>> _evaluationCache = {};

  @override
  void dispose() {
    _crsNameCtrl.dispose();
    _teacherCtrl.dispose();
    _codeCtrl.dispose();
    _deptCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isLiquidGlass = LayoutStyleNotifier.instance.isLiquidGlass;
    final isDark = colorScheme.isDark;
    String semDisplay = "";
    final semStr = CourseQueryService.instance.currentSemester;
    if (semStr.length == 4) {
      final syear = semStr.substring(0, 3);
      final sem = semStr.substring(3, 4);
      semDisplay = "$syear-$sem";
    }

    return Column(
      children: [
        // 行內選取器標頭
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          color: isLiquidGlass
              ? (isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : Colors.white.withValues(alpha: 0.45))
              : colorScheme.cardBackground,
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: widget.onBack,
                tooltip: "返回預設列表",
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "$semDisplay 選擇課程",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.primaryText,
                      ),
                    ),
                    Text(
                      "正在為自填項目填寫課號",
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.subtitleText,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _inlineSearchFiltersExpanded =
                        !_inlineSearchFiltersExpanded;
                  });
                },
                icon: Icon(
                  _inlineSearchFiltersExpanded
                      ? Icons.filter_list_off
                      : Icons.filter_list,
                  size: 16,
                ),
                label: Text(
                  _inlineSearchFiltersExpanded ? "收合條件" : "篩選條件",
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
        Divider(height: 1, color: colorScheme.borderColor),

        // 搜尋條件卡片 (在寬螢幕時可收合)
        if (_inlineSearchFiltersExpanded)
          Container(
            padding: const EdgeInsets.all(16.0),
            color: isLiquidGlass
                ? (isDark
                    ? Colors.white.withValues(alpha: 0.04)
                    : Colors.white.withValues(alpha: 0.35))
                : colorScheme.subtleBackground,
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _buildInlineTextField("課程名稱", _crsNameCtrl),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildInlineTextField("授課教師", _teacherCtrl),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildInlineTextField(
                        "課別代號",
                        _codeCtrl,
                        hint: "例如: T3",
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildInlineTextField(
                        "開課系所",
                        _deptCtrl,
                        hint: "例如: 資工",
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildInlineDropdown(
                        label: "年級",
                        value: _selectedGrade,
                        items: const [
                          DropdownMenuItem(value: null, child: Text("全部")),
                          DropdownMenuItem(value: "1", child: Text("一年級")),
                          DropdownMenuItem(value: "2", child: Text("二年級")),
                          DropdownMenuItem(value: "3", child: Text("三年級")),
                          DropdownMenuItem(value: "4", child: Text("四年級")),
                        ],
                        onChanged: (v) => setState(() => _selectedGrade = v),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildInlineDropdown(
                        label: "班級",
                        value: _selectedClass,
                        items: const [
                          DropdownMenuItem(value: null, child: Text("全部")),
                          DropdownMenuItem(value: "0", child: Text("不分班")),
                          DropdownMenuItem(value: "1", child: Text("甲班")),
                          DropdownMenuItem(value: "2", child: Text("乙班")),
                          DropdownMenuItem(value: "5", child: Text("全英班")),
                        ],
                        onChanged: (v) => setState(() => _selectedClass = v),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildInlineDropdown(
                        label: "星期",
                        value: _selectedDay,
                        items: const [
                          DropdownMenuItem(value: null, child: Text("不限")),
                          DropdownMenuItem(value: "1", child: Text("星期一")),
                          DropdownMenuItem(value: "2", child: Text("星期二")),
                          DropdownMenuItem(value: "3", child: Text("星期三")),
                          DropdownMenuItem(value: "4", child: Text("星期四")),
                          DropdownMenuItem(value: "5", child: Text("星期五")),
                          DropdownMenuItem(value: "6", child: Text("星期六")),
                          DropdownMenuItem(value: "7", child: Text("星期日")),
                        ],
                        onChanged: (v) => setState(() => _selectedDay = v),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildInlineDropdown(
                        label: "節次",
                        value: _selectedPeriod,
                        items: _buildInlinePeriodItems(),
                        onChanged: (v) => setState(() => _selectedPeriod = v),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      onPressed: _clearSearchFields,
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                      ),
                      child: Text(
                        "重設",
                        style: TextStyle(color: colorScheme.subtitleText),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: _performSearch,
                      icon: const Icon(Icons.search, size: 16),
                      label: const Text(
                        "開始查詢",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colorScheme.primary,
                        foregroundColor: colorScheme.onPrimary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        elevation: 0,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        Divider(height: 1, color: colorScheme.borderColor),

        // 搜尋結果列表
        Expanded(child: _buildInlineSearchResults()),
      ],
    );
  }

  Widget _buildInlineSearchResults() {
    final colorScheme = Theme.of(context).colorScheme;
    final isLiquidGlass = LayoutStyleNotifier.instance.isLiquidGlass;
    if (_isQueryLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: colorScheme.primary),
            const SizedBox(height: 16),
            Text("搜尋中...", style: TextStyle(color: colorScheme.subtitleText)),
          ],
        ),
      );
    }

    if (!_hasSearched) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_outlined, size: 48, color: colorScheme.iconColor),
            const SizedBox(height: 12),
            Text(
              "請在上方輸入條件後開始查詢",
              style: TextStyle(color: colorScheme.subtitleText),
            ),
          ],
        ),
      );
    }

    if (_searchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.sentiment_dissatisfied,
              size: 48,
              color: colorScheme.iconColor,
            ),
            const SizedBox(height: 12),
            Text(
              "找不到符合條件的課程",
              style: TextStyle(color: colorScheme.primaryText),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final course = _searchResults[index];

        final Widget tileChild = Theme(
          data: Theme.of(context).copyWith(
            dividerColor: Colors.transparent,
            unselectedWidgetColor: colorScheme.iconColor,
          ),
          child: ExpansionTile(
              iconColor: colorScheme.primary,
              collapsedIconColor: colorScheme.iconColor,
              tilePadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 6,
              ),
              title: Text(
                course.name.split('\n')[0],
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: colorScheme.primaryText,
                ),
              ),
              subtitle: Row(
                children: [
                  Icon(Icons.person, size: 14, color: colorScheme.iconColor),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      course.teacher,
                      style: TextStyle(
                        color: colorScheme.primaryText,
                        fontSize: 13,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 12),
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
                        fontSize: 11,
                        color: colorScheme.subtitleText,
                      ),
                    ),
                  ),
                ],
              ),
              trailing: ElevatedButton(
                onPressed: () => widget.onCourseSelected(course),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  minimumSize: const Size(60, 32),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  "選取",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
              children: [
                Divider(
                  height: 1,
                  thickness: 1,
                  color: colorScheme.borderColor,
                ),
                Container(
                  color: colorScheme.subtleBackground,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _buildInlineDetailRow(
                              Icons.school,
                              "系所",
                              course.department,
                            ),
                          ),
                          Expanded(
                            child: _buildInlineDetailRow(
                              Icons.grade,
                              "學分",
                              course.credit,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _buildInlineDetailRow(
                              Icons.class_,
                              "班級",
                              "${course.grade}年級 ${course.className}",
                            ),
                          ),
                          Expanded(
                            child: _buildInlineDetailRow(
                              Icons.room,
                              "教室",
                              _parseRoomLocation(course.room),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          "上課時間表",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.subtitleText,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      _buildInlineTimeDisplay(course.classTime),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          "評分方式",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.subtitleText,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: FutureBuilder<List<String>>(
                          future: _getCourseEvaluation(course.id),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return SizedBox(
                                height: 16,
                                width: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: colorScheme.primary,
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
                                  fontSize: 12,
                                ),
                              );
                            }
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: snapshot.data!
                                  .map(
                                    (e) => Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 4.0,
                                      ),
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Icon(
                                            Icons.check_circle_outline,
                                            size: 14,
                                            color: colorScheme.primary,
                                          ),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Text(
                                              e,
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: colorScheme.bodyText,
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

        return isLiquidGlass
            ? Container(
                margin: const EdgeInsets.only(bottom: 12),
                clipBehavior: Clip.antiAlias,
                decoration: glassCardDecoration(context, borderRadius: 12),
                child: tileChild,
              )
            : Card(
                elevation: 1,
                margin: const EdgeInsets.only(bottom: 12),
                clipBehavior: Clip.antiAlias,
                color: colorScheme.cardBackground,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: colorScheme.borderColor, width: 0.5),
                ),
                child: tileChild,
              );
      },
    );
  }

  Widget _buildInlineDetailRow(IconData icon, String label, String value) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: colorScheme.iconColor),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 10, color: colorScheme.subtitleText),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: colorScheme.primaryText,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInlineTimeDisplay(List<String> times) {
    final colorScheme = Theme.of(context).colorScheme;
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
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    "星期${days[i]}",
                    style: TextStyle(
                      color: colorScheme.primary,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  "第 ${times[i]} 節",
                  style: TextStyle(
                    fontSize: 13,
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
      return Text(
        "無時間資訊",
        style: TextStyle(color: colorScheme.subtitleText, fontSize: 12),
      );
    return Column(children: timeWidgets);
  }

  Future<List<String>> _getCourseEvaluation(String courseId) async {
    if (_evaluationCache.containsKey(courseId))
      return _evaluationCache[courseId]!;
    final semStr = CourseQueryService.instance.currentSemester;
    if (semStr.length != 4) return ["無法取得學期資訊"];
    final syear = semStr.substring(0, 3);
    final sem = semStr.substring(3, 4);
    final url = Uri.parse(
      'https://selcrs.nsysu.edu.tw/menu5/showoutline.asp?SYEAR=$syear&SEM=$sem&CrsDat=$courseId',
    );
    try {
      final client = createHttpClient();
      final response = await client.get(url);
      client.close();
      if (response.statusCode == 200) {
        String html = utf8.decode(response.bodyBytes, allowMalformed: true);
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
        _evaluationCache[courseId] = evals;
        return evals;
      }
    } catch (e) {
      return ["載入失敗"];
    }
    return ["查無資料"];
  }

  String _parseRoomLocation(String rawRoom) {
    if (rawRoom.isEmpty) return "不明";
    final RegExp regex = RegExp(r'[(\uff08]([^)\uff09]*)[)\uff09]');
    final match = regex.firstMatch(rawRoom);
    if (match != null) return match.group(1)?.trim() ?? "不明";
    return "不明";
  }

  List<DropdownMenuItem<String>> _buildInlinePeriodItems() {
    final List<Map<String, String>> periods = [
      {"val": "A", "label": "A (07:00)"},
      {"val": "1", "label": "1 (08:10)"},
      {"val": "2", "label": "2 (09:10)"},
      {"val": "3", "label": "3 (10:10)"},
      {"val": "4", "label": "4 (11:10)"},
      {"val": "B", "label": "B (12:10)"},
      {"val": "5", "label": "5 (13:10)"},
      {"val": "6", "label": "6 (14:10)"},
      {"val": "7", "label": "7 (15:10)"},
      {"val": "8", "label": "8 (16:10)"},
      {"val": "9", "label": "9 (17:10)"},
      {"val": "C", "label": "C (18:20)"},
    ];
    return [
      const DropdownMenuItem(value: null, child: Text("不限")),
      ...periods
          .map(
            (p) => DropdownMenuItem(value: p['val'], child: Text(p['label']!)),
          )
          .toList(),
    ];
  }

  Widget _buildInlineDropdown({
    required String label,
    required String? value,
    required List<DropdownMenuItem<String>> items,
    required ValueChanged<String?> onChanged,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 11,
            color: colorScheme.primaryText,
          ),
        ),
        const SizedBox(height: 4),
        DropdownButtonFormField<String>(
          dropdownColor: colorScheme.cardBackground,
          value: value,
          items: items.map((item) {
            return DropdownMenuItem(
              value: item.value,
              child: DefaultTextStyle(
                style: TextStyle(color: colorScheme.primaryText, fontSize: 13),
                child: item.child,
              ),
            );
          }).toList(),
          onChanged: onChanged,
          style: TextStyle(color: colorScheme.primaryText, fontSize: 13),
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 8,
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            isDense: true,
          ),
        ),
      ],
    );
  }

  Widget _buildInlineTextField(
    String label,
    TextEditingController controller, {
    String? hint,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 11,
            color: colorScheme.primaryText,
          ),
        ),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          style: TextStyle(color: colorScheme.primaryText, fontSize: 13),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: colorScheme.subtitleText, fontSize: 12),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 8,
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            isDense: true,
          ),
        ),
      ],
    );
  }

  Future<void> _performSearch() async {
    setState(() {
      _isQueryLoading = true;
      _hasSearched = true;
    });
    try {
      await CourseQueryService.instance.getCourses();
      String? classText;
      if (_selectedClass == "0") classText = "不分班";
      if (_selectedClass == "1") classText = "甲班";
      if (_selectedClass == "2") classText = "乙班";
      if (_selectedClass == "5") classText = "全英班";

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
      setState(() {
        _searchResults = results;
        _isQueryLoading = false;
      });
    } catch (e) {
      setState(() => _isQueryLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("搜尋失敗: $e"), duration: const Duration(seconds: 2)));
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
  }
}
