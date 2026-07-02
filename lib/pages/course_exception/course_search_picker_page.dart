import 'dart:convert';
import 'package:flutter/material.dart';
import '../../../services/course_query_service.dart'; // 請確認路徑是否正確
import 'package:http/http.dart' as http;
import '../../theme/app_theme.dart'; // 引入 AppTheme 與 AppColors 擴充
import '../../widgets/glass_dropdown.dart';

class CourseSearchPickerPage extends StatefulWidget {
  const CourseSearchPickerPage({Key? key}) : super(key: key);

  @override
  State<CourseSearchPickerPage> createState() => _CourseSearchPickerPageState();
}

class _CourseSearchPickerPageState extends State<CourseSearchPickerPage> {
  bool _isQueryLoading = false;
  List<CourseJsonData> _searchResults = [];
  bool _hasSearched = false;
  final Map<String, List<String>> _evaluationCache = {};

  final TextEditingController _crsNameCtrl = TextEditingController();
  final TextEditingController _teacherCtrl = TextEditingController();
  final TextEditingController _codeCtrl = TextEditingController();
  final TextEditingController _deptCtrl = TextEditingController();
  String? _selectedGrade;
  String? _selectedClass;
  String? _selectedDay;
  String? _selectedPeriod;

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
    String semDisplay = "";
    final semStr = CourseQueryService.instance.currentSemester;
    if (semStr.length == 4) {
      final syear = semStr.substring(0, 3);
      final sem = semStr.substring(3, 4);
      semDisplay = "$syear-$sem";
    }

    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.pageBackground,
      appBar: AppBar(
        title: Text(
          "$semDisplay 選擇課程",
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: colorScheme.cardBackground,
        foregroundColor: colorScheme.primaryText,
        elevation: 0.5,
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            color: colorScheme.pageBackground,
            child: ElevatedButton.icon(
              onPressed: _showSearchSheet,
              icon: const Icon(Icons.search),
              label: const Text(
                "開啟搜尋面板",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: colorScheme.accentBlue.withValues(alpha: 0.15),
                foregroundColor: colorScheme.accentBlue,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
          Divider(height: 1, color: colorScheme.borderColor),
          Expanded(child: _buildSearchResults()),
        ],
      ),
    );
  }

  Widget _buildSearchResults() {
    final colorScheme = Theme.of(context).colorScheme;
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
        child: Text(
          "點擊上方按鈕搜尋想選取的課程",
          style: TextStyle(color: colorScheme.subtitleText),
        ),
      );
    }

    if (_searchResults.isEmpty) {
      return Center(
        child: Text(
          "找不到符合條件的課程",
          style: TextStyle(color: colorScheme.primaryText),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final course = _searchResults[index];

        return Card(
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 12),
          clipBehavior: Clip.antiAlias,
          color: colorScheme.cardBackground,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: colorScheme.borderColor, width: 0.5),
          ),
          child: Theme(
            data: Theme.of(context).copyWith(
              dividerColor: Colors.transparent,
              unselectedWidgetColor: colorScheme.iconColor,
            ),
            child: ExpansionTile(
              iconColor: colorScheme.primary,
              collapsedIconColor: colorScheme.iconColor,
              tilePadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              title: Text(
                course.name.split('\n')[0],
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
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
                      style: TextStyle(color: colorScheme.primaryText),
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
                        fontSize: 12,
                        color: colorScheme.subtitleText,
                      ),
                    ),
                  ),
                ],
              ),
              trailing: ElevatedButton(
                onPressed: () => Navigator.pop(context, course.id), // ✅ 回傳課號
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
                  style: TextStyle(fontWeight: FontWeight.bold),
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
                            ),
                          ),
                          Expanded(
                            child: _buildDetailRow(
                              Icons.grade,
                              "學分",
                              course.credit,
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
                            ),
                          ),
                          Expanded(
                            child: _buildDetailRow(
                              Icons.room,
                              "教室",
                              _parseRoomLocation(course.room),
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
                      _buildTimeDisplay(course.classTime),
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
                      Align(
                        alignment: Alignment.centerLeft,
                        child: FutureBuilder<List<String>>(
                          future: _getCourseEvaluation(course.id),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return SizedBox(
                                height: 20,
                                width: 20,
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
                                  fontSize: 13,
                                ),
                              );
                            }
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: snapshot.data!
                                  .map(
                                    (e) => Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 6.0,
                                      ),
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Icon(
                                            Icons.check_circle_outline,
                                            size: 16,
                                            color: colorScheme.primary,
                                          ),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Text(
                                              e,
                                              style: TextStyle(
                                                fontSize: 13,
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
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    final colorScheme = Theme.of(context).colorScheme;
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

  Widget _buildTimeDisplay(List<String> times) {
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
                    horizontal: 8,
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

  void _showSearchSheet() {
    final colorScheme = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: colorScheme.cardBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.85,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Text(
                      "課程查詢條件",
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.primaryText,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(child: _buildTextField("課程名稱", _crsNameCtrl)),
                      const SizedBox(width: 12),
                      Expanded(child: _buildTextField("授課教師", _teacherCtrl)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _buildTextField("課別代號 (T3)", _codeCtrl)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildTextField(
                          "開課系所",
                          _deptCtrl,
                          hint: "例如: 資工",
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: _buildDropdown(
                          label: "年級 (D2)",
                          value: _selectedGrade ?? "",
                          items: const ["", "1", "2", "3", "4"],
                          displayMap: const {
                            "": "全部",
                            "1": "一年級",
                            "2": "二年級",
                            "3": "三年級",
                            "4": "四年級",
                          },
                          onChanged: (v) => setState(() {
                            _selectedGrade = (v == null || v.isEmpty)
                                ? null
                                : v;
                          }),
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
                          onChanged: (v) => setState(() {
                            _selectedClass = (v == null || v.isEmpty)
                                ? null
                                : v;
                          }),
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
                          onChanged: (v) => setState(() {
                            _selectedDay = (v == null || v.isEmpty) ? null : v;
                          }),
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
                          onChanged: (v) => setState(() {
                            _selectedPeriod = (v == null || v.isEmpty)
                                ? null
                                : v;
                          }),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 30),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _performSearch();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colorScheme.primary,
                        foregroundColor: colorScheme.onPrimary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        "開始查詢",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Center(
                    child: TextButton(
                      onPressed: _clearSearchFields,
                      child: Text(
                        "重設條件",
                        style: TextStyle(color: colorScheme.subtitleText),
                      ),
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
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("搜尋失敗: $e")));
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.bold,
            fontSize: 12,
            color: colorScheme.primaryText,
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
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            isDense: true,
          ),
        ),
      ],
    );
  }

  String _parseRoomLocation(String rawRoom) {
    if (rawRoom.isEmpty) return "不明";
    final RegExp regex = RegExp(r'[(\uff08]([^)\uff09]*)[)\uff09]');
    final match = regex.firstMatch(rawRoom);
    if (match != null) return match.group(1)?.trim() ?? "不明";
    return "不明";
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
      final response = await http.get(url);
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
}
