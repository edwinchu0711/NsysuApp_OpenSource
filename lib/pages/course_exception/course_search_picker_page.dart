import 'dart:convert';
import 'package:flutter/material.dart';
import '../../../services/course_query_service.dart'; // 請確認路徑是否正確
import 'package:http/http.dart' as http;

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
    

    return Scaffold(
      appBar: AppBar(
        title: Text("$semDisplay 選擇課程"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            color: Colors.white,
            child: ElevatedButton.icon(
              onPressed: _showSearchSheet,
              icon: const Icon(Icons.search),
              label: const Text("開啟搜尋面板"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[50],
                foregroundColor: Colors.blue[800],
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(child: _buildSearchResults()),
        ],
      ),
    );
  }

  Widget _buildSearchResults() {
    if (_isQueryLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text("搜尋中...", style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }
    
    if (!_hasSearched) {
      return Center(child: Text("點擊上方按鈕搜尋想選取的課程", style: TextStyle(color: Colors.grey[400])));
    }
    
    if (_searchResults.isEmpty) {
      return const Center(child: Text("找不到符合條件的課程"));
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
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              title: Text(
                course.name.split('\n')[0], 
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              subtitle: Row(
                children: [
                  Icon(Icons.person, size: 14, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      course.teacher, 
                      style: TextStyle(color: Colors.grey[800]),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(4)),
                    child: Text(course.id, style: TextStyle(fontSize: 12, color: Colors.grey[700])),
                  ),
                ],
              ),
              trailing: ElevatedButton(
                onPressed: () => Navigator.pop(context, course.id), // ✅ 回傳課號
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[600],
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  minimumSize: const Size(60, 32),
                ),
                child: const Text("選取"),
              ),
              children: [
                const Divider(height: 1, thickness: 1, color: Colors.black12),
                Container(
                  color: Colors.blue[50]!.withOpacity(0.3),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(child: _buildDetailRow(Icons.school, "系所", course.department)),
                          Expanded(child: _buildDetailRow(Icons.grade, "學分", course.credit)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(child: _buildDetailRow(Icons.class_, "班級", "${course.grade}年級 ${course.className}")),
                          Expanded(child: _buildDetailRow(Icons.room, "教室", _parseRoomLocation(course.room))),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text("上課時間表", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                      ),
                      const SizedBox(height: 8),
                      _buildTimeDisplay(course.classTime),
                      const SizedBox(height: 16),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text("評分方式", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: FutureBuilder<List<String>>(
                          future: _getCourseEvaluation(course.id),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.waiting) {
                              return const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2));
                            }
                            if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
                              return const Text("無法取得評分資料", style: TextStyle(color: Colors.grey, fontSize: 13));
                            }
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: snapshot.data!.map((e) => Padding(
                                padding: const EdgeInsets.only(bottom: 6.0),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(Icons.check_circle_outline, size: 16, color: Colors.blue),
                                    const SizedBox(width: 6),
                                    Expanded(child: Text(e, style: const TextStyle(fontSize: 13, color: Colors.black87))),
                                  ],
                                ),
                              )).toList(),
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

  // --- 與 AssistantAddCoursePage 共用的私有方法組 ---

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: Colors.blueGrey),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
              Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTimeDisplay(List<String> times) {
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
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: Colors.blue[100], borderRadius: BorderRadius.circular(4)),
                  child: Text("星期${days[i]}", style: TextStyle(color: Colors.blue[900], fontSize: 12, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 12),
                Text("第 ${times[i]} 節", style: const TextStyle(fontSize: 14, color: Colors.black87)),
              ],
            ),
          ),
        );
      }
    }
    if (timeWidgets.isEmpty) return const Text("無時間資訊", style: TextStyle(color: Colors.grey));
    return Column(children: timeWidgets);
  }

  void _showSearchSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.85, minChildSize: 0.5, maxChildSize: 0.95, expand: false,
          builder: (context, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(context).viewInsets.bottom + 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Center(child: Text("課程查詢條件", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold))),
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
                      Expanded(child: _buildTextField("開課系所", _deptCtrl, hint: "例如: 資工")),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildDropdown(
                          label: "年級 (D2)", value: _selectedGrade,
                          items: const [
                            DropdownMenuItem(value: null, child: Text("全部")),
                            DropdownMenuItem(value: "1", child: Text("一年級")),
                            DropdownMenuItem(value: "2", child: Text("二年級")),
                            DropdownMenuItem(value: "3", child: Text("三年級")),
                            DropdownMenuItem(value: "4", child: Text("四年級")),
                          ],
                          onChanged: (v) => _selectedGrade = v,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildDropdown(
                          label: "班級 (CLASS)", value: _selectedClass,
                          items: const [
                            DropdownMenuItem(value: null, child: Text("全部")),
                            DropdownMenuItem(value: "0", child: Text("不分班")),
                            DropdownMenuItem(value: "1", child: Text("甲班")),
                            DropdownMenuItem(value: "2", child: Text("乙班")),
                            DropdownMenuItem(value: "5", child: Text("全英班")),
                          ],
                          onChanged: (v) => _selectedClass = v,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text("上課時間", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: _buildDropdown(
                          label: "星期", value: _selectedDay,
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
                          onChanged: (v) => _selectedDay = v,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildDropdown(
                          label: "節次", value: _selectedPeriod, items: _buildPeriodItems(),
                          onChanged: (v) => _selectedPeriod = v,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 30),
                  SizedBox(
                    width: double.infinity, height: 50,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context); 
                        _performSearch();
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
                      child: const Text("開始查詢", style: TextStyle(fontSize: 18)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Center(
                    child: TextButton(onPressed: _clearSearchFields, child: const Text("重設條件", style: TextStyle(color: Colors.grey))),
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
    setState(() { _isQueryLoading = true; _hasSearched = true; });
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
      setState(() { _searchResults = results; _isQueryLoading = false; });
    } catch (e) {
      setState(() => _isQueryLoading = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("搜尋失敗: $e")));
    }
  }

  void _clearSearchFields() {
    _crsNameCtrl.clear(); _teacherCtrl.clear(); _codeCtrl.clear(); _deptCtrl.clear();
    setState(() { _selectedGrade = null; _selectedClass = null; _selectedDay = null; _selectedPeriod = null; });
  }

  Widget _buildDropdown({required String label, required String? value, required List<DropdownMenuItem<String>> items, required ValueChanged<String?> onChanged}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
        const SizedBox(height: 4),
        DropdownButtonFormField<String>(
          value: value, items: items, onChanged: onChanged,
          decoration: InputDecoration(contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), isDense: true),
        ),
      ],
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, {String? hint}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
        const SizedBox(height: 4),
        TextField(controller: controller, decoration: InputDecoration(hintText: hint, contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), isDense: true)),
      ],
    );
  }

  List<DropdownMenuItem<String>> _buildPeriodItems() {
    final List<Map<String, String>> periods = [
      {"val": "A", "label": "A (07:00)"}, {"val": "1", "label": "1 (08:10)"}, {"val": "2", "label": "2 (09:10)"},
      {"val": "3", "label": "3 (10:10)"}, {"val": "4", "label": "4 (11:10)"}, {"val": "B", "label": "B (12:10)"},
      {"val": "5", "label": "5 (13:10)"}, {"val": "6", "label": "6 (14:10)"}, {"val": "7", "label": "7 (15:10)"},
      {"val": "8", "label": "8 (16:10)"}, {"val": "9", "label": "9 (17:10)"}, {"val": "C", "label": "C (18:20)"},
    ];
    return [const DropdownMenuItem(value: null, child: Text("不限")), ...periods.map((p) => DropdownMenuItem(value: p['val'], child: Text(p['label']!))).toList()];
  }

  String _parseRoomLocation(String rawRoom) {
    if (rawRoom.isEmpty) return "不明";
    final RegExp regex = RegExp(r'[(\uff08]([^)\uff09]*)[)\uff09]');
    final match = regex.firstMatch(rawRoom);
    if (match != null) return match.group(1)?.trim() ?? "不明";
    return "不明";
  }

  Future<List<String>> _getCourseEvaluation(String courseId) async {
    if (_evaluationCache.containsKey(courseId)) return _evaluationCache[courseId]!;
    final semStr = CourseQueryService.instance.currentSemester;
    if (semStr.length != 4) return ["無法取得學期資訊"];
    final syear = semStr.substring(0, 3);
    final sem = semStr.substring(3, 4);
    final url = Uri.parse('https://selcrs.nsysu.edu.tw/menu5/showoutline.asp?SYEAR=$syear&SEM=$sem&CrsDat=$courseId');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        String html = utf8.decode(response.bodyBytes, allowMalformed: true);
        final RegExp exp = RegExp(r'SS4_\d+1[^>]*>([^<]*)</span>[^<]*<span[^>]*SS4_\d+2[^>]*>([^<]*)</span>', caseSensitive: false);
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