import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/course_model.dart'; // 請確認路徑
import 'assistant_import_page.dart';
import 'assistant_add_course_page.dart';
import 'assistant_export_page.dart';
import 'dart:math'; // 記得檔案頂部要有這行

// ✅ 新增：自訂行程的資料模型
class CustomEvent {
  final String id;
  final String title;
  final String details;
  final String location; // ✅ 新增：位置
  final int day;
  final List<String> periods;

  CustomEvent({
    required this.id,
    required this.title,
    required this.location, // ✅ 新增
    required this.details,
    required this.day,
    required this.periods,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'details': details,
        'location': location, // ✅ 新增
        'day': day,
        'periods': periods,
      };

  factory CustomEvent.fromJson(Map<String, dynamic> json) => CustomEvent(
        id: json['id'],
        title: json['title'],
        details: json['details'],
        location: json['location'] ?? '', // ✅ 新增
        day: json['day'],
        periods: List<String>.from(json['periods'] ?? []),
      );
}

class CourseAssistantPage extends StatefulWidget {
  const CourseAssistantPage({Key? key}) : super(key: key);

  @override
  State<CourseAssistantPage> createState() => _CourseAssistantPageState();
}

class _CourseAssistantPageState extends State<CourseAssistantPage> {
  List<Course> _assistantCourses = [];
  List<CustomEvent> _customEvents = []; // ✅ 新增：存放自訂行程的列表
  bool _isLoading = false;

  final List<String> _periods = ['A', '1', '2', '3', '4', 'B', '5', '6', '7', '8', '9', 'C', 'D', 'E', 'F'];
  final List<String> _fullWeekDays = ['一', '二', '三', '四', '五', '六', '日'];
  final Map<String, String> _timeMapping = {
    'A': '07:00\n07:50', '1': '08:10\n09:00', '2': '09:10\n10:00',
    '3': '10:10\n11:00', '4': '11:10\n12:00', 'B': '12:10\n13:00',
    '5': '13:10\n14:00', '6': '14:10\n15:00', '7': '15:10\n16:00',
    '8': '16:10\n17:00', '9': '17:10\n18:00', 'C': '18:20\n19:10',
    'D': '19:15\n20:05', 'E': '20:10\n21:00', 'F': '21:05\n21:55',
  };

  final Map<String, List<String>> _timeRangeMap = {
    'A': ['07:00', '07:50'], '1': ['08:10', '09:00'], '2': ['09:10', '10:00'],
    '3': ['10:10', '11:00'], '4': ['11:10', '12:00'], 'B': ['12:10', '13:00'],
    '5': ['13:10', '14:00'], '6': ['14:10', '15:00'], '7': ['15:10', '16:00'],
    '8': ['16:10', '17:00'], '9': ['17:10', '18:00'], 'C': ['18:20', '19:10'],
    'D': ['19:15', '20:05'], 'E': ['20:10', '21:00'], 'F': ['21:05', '21:55'],
  };

  // ✅ 新增：計算中英文字數 (中文字算 1，英數字算 0.5)
  double _calculateTextLength(String text) {
    double length = 0.0;
    for (var rune in text.runes) {
      // 簡單判斷：ASCII 範圍內的字元 (英數字/半形符號) 算 0.5，其他算 1
      if (rune <= 128) {
        length += 0.5;
      } else {
        length += 1.0;
      }
    }
    return length;
  }

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  // ✅ 統一載入課程與自訂行程
  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // 讀取課程
      String? courseJson = prefs.getString('assistant_courses');
      if (courseJson != null && courseJson.isNotEmpty) {
        List<dynamic> decoded = jsonDecode(courseJson);
        _assistantCourses = decoded.map((v) => Course.fromJson(Map<String, dynamic>.from(v))).toList();
      } else {
        _assistantCourses = [];
      }

      // 讀取自訂行程
      String? eventJson = prefs.getString('custom_events');
      if (eventJson != null && eventJson.isNotEmpty) {
        List<dynamic> decoded = jsonDecode(eventJson);
        _customEvents = decoded.map((v) => CustomEvent.fromJson(Map<String, dynamic>.from(v))).toList();
      } else {
        _customEvents = [];
      }
    } catch (e) {
      print("讀取資料失敗: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _removeCourseFromAssistant(Course course) async {
    setState(() {
      _assistantCourses.removeWhere((c) => c.code == course.code);
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('assistant_courses', jsonEncode(_assistantCourses.map((c) => c.toJson()).toList()));
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("已移除 ${course.name}")));
  }

  // ✅ 新增：移除自訂行程
  Future<void> _removeCustomEvent(String eventId) async {
    setState(() {
      _customEvents.removeWhere((e) => e.id == eventId);
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('custom_events', jsonEncode(_customEvents.map((e) => e.toJson()).toList()));
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("已移除自訂行程")));
  }

  Future<void> _clearAllData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('assistant_courses');
    await prefs.remove('custom_events');
    _loadAllData();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("已清空所有課表與行程")));
  }

  String _getTotalCredits() {
    double total = 0.0;
    for (var c in _assistantCourses) {
      double? cred = double.tryParse(c.credits);
      if (cred != null) total += cred;
    }
    return total.toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '');
  }

  void _handleMenuSelection(String value) {
    switch (value) {
      case 'add':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const AssistantAddCoursePage()),
        ).then((_) => _loadAllData());
        break;
      case 'add_event': // ✅ 新增：呼叫自訂行程 Dialog
        _showAddCustomEventDialog();
        break;
      case 'import':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const AssistantImportPage()),
        ).then((_) => _loadAllData());
        break;
      case 'export':
        Navigator.push(context, MaterialPageRoute(builder: (context) => const AssistantExportPage()));
        break;
      case 'clear':
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text("確認清除"),
            content: const Text("確定要清空選課助手裡的所有課程與自訂行程嗎？(不影響正式課表)"),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text("取消")),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _clearAllData();
                },
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text("確定清除"),
              ),
            ],
          ),
        );
        break;
    }
  }

  // ✅ 新增：填寫與儲存自訂行程的對話框
  void _showAddCustomEventDialog() {
    String title = '';
    String details = '';
    String location = '';
    int selectedDay = 1; // 預設星期一
    Set<String> selectedPeriods = {};

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text("新增其他行程", style: TextStyle(fontWeight: FontWeight.bold)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      decoration: const InputDecoration(labelText: '標題 (如: 工讀、社團)', border: OutlineInputBorder()),
                      onChanged: (val) => title = val,
                    ),
                    const SizedBox(height: 12),
                    // ✅ 新增：位置的輸入框
                    TextField(
                      decoration: const InputDecoration(labelText: '位置', border: OutlineInputBorder()),
                      onChanged: (val) => location = val,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      decoration: const InputDecoration(labelText: '詳細內容 (地點、備註)', border: OutlineInputBorder()),
                      maxLines: 2,
                      onChanged: (val) => details = val,
                    ),
                    const SizedBox(height: 16),
                    const Text("選擇星期：", style: TextStyle(fontWeight: FontWeight.bold)),
                    DropdownButton<int>(
                      isExpanded: true,
                      value: selectedDay,
                      items: List.generate(7, (index) {
                        return DropdownMenuItem(value: index + 1, child: Text("星期${_fullWeekDays[index]}"));
                      }),
                      onChanged: (val) {
                        if (val != null) setDialogState(() => selectedDay = val);
                      },
                    ),
                    const SizedBox(height: 16),
                    const Text("選擇節次 (可多選)：", style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6.0,
                      runSpacing: 4.0,
                      children: _periods.map((p) {
                        final isSelected = selectedPeriods.contains(p);
                        return FilterChip(
                          label: Text(p),
                          selected: isSelected,
                          selectedColor: Colors.blue[100],
                          showCheckmark: false,
                          onSelected: (bool selected) {
                            setDialogState(() {
                              if (selected) {
                                selectedPeriods.add(p);
                              } else {
                                selectedPeriods.remove(p);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text("取消")),
                ElevatedButton(
                  onPressed: () async {
                    if (title.trim().isEmpty || selectedPeriods.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("請填寫標題並至少選擇一節課")));
                      return;
                    }
                    if (_calculateTextLength(location.trim()) > 6.0) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("位置輸入過長，請縮減至6個中文字或12個英數字以內")));
                      return;
                    }
                    final newEvent = CustomEvent(
                      id: DateTime.now().millisecondsSinceEpoch.toString(), // 產生唯一ID
                      title: title.trim(),
                      details: details.trim(),
                      day: selectedDay,
                      periods: selectedPeriods.toList()..sort((a, b) => _periods.indexOf(a).compareTo(_periods.indexOf(b))),
                      location: location.trim(),
                    );
                    
                    _customEvents.add(newEvent);
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setString('custom_events', jsonEncode(_customEvents.map((e) => e.toJson()).toList()));
                    
                    if (mounted) {
                      Navigator.pop(context);
                      _loadAllData(); // 重新整理課表
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("行程已加入！")));
                    }
                  },
                  child: const Text("儲存"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showManageCoursesSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.6,
              padding: const EdgeInsets.only(top: 16, left: 16, right: 16, bottom: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("管理已加入課程與行程", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      )
                    ],
                  ),
                  const Divider(),
                  Expanded(
                    child: (_assistantCourses.isEmpty && _customEvents.isEmpty)
                      ? const Center(child: Text("目前沒有任何模擬課程或行程", style: TextStyle(color: Colors.grey)))
                      : ListView(
                          children: [
                            if (_assistantCourses.isNotEmpty) ...[
                              const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text("正規課程", style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold))),
                              ..._assistantCourses.map((c) => ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(c.name.split('\n')[0], style: const TextStyle(fontWeight: FontWeight.bold)),
                                subtitle: Text("${c.code} · ${c.professor}\n${_formatCourseTimeWithRange(c).replaceAll('\n', ' ')}"),
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                                  onPressed: () async {
                                    await _removeCourseFromAssistant(c);
                                    setModalState(() {}); 
                                  }
                                ),
                              )).toList(),
                            ],
                            if (_customEvents.isNotEmpty) ...[
                              const Divider(),
                              const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text("其他行程", style: TextStyle(color: Colors.blueGrey, fontWeight: FontWeight.bold))),
                              ..._customEvents.map((e) => ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(e.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                                subtitle: Text("星期${_fullWeekDays[e.day - 1]} (${e.periods.join(', ')}節)\n${e.details}"),
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                                  onPressed: () async {
                                    await _removeCustomEvent(e.id);
                                    setModalState(() {}); 
                                  }
                                ),
                              )).toList(),
                            ]
                          ],
                        ),
                  ),
                ],
              ),
            );
          }
        );
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("選課助手"),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: "功能說明",
            onPressed: _showInfoDialog,
          ),
          PopupMenuButton<String>(
            onSelected: _handleMenuSelection,
            itemBuilder: (BuildContext context) => [
              const PopupMenuItem(value: 'add', child: Row(children: [Icon(Icons.add_box, color: Colors.blue), SizedBox(width: 8), Text("新增課程")])),
              const PopupMenuItem(value: 'add_event', child: Row(children: [Icon(Icons.event_note, color: Colors.blueGrey), SizedBox(width: 8), Text("新增其他行程")])), // ✅ 新增選項
              const PopupMenuItem(value: 'import', child: Row(children: [Icon(Icons.download), SizedBox(width: 8), Text("匯入課表")])),
              const PopupMenuItem(value: 'export', child: Row(children: [Icon(Icons.upload), SizedBox(width: 8), Text("匯出至選課")])),
              const PopupMenuDivider(),
              const PopupMenuItem(value: 'clear', child: Row(children: [Icon(Icons.delete_forever, color: Colors.red), SizedBox(width: 8), Text("清除全部資料", style: TextStyle(color: Colors.red))])),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : (_assistantCourses.isEmpty && _customEvents.isEmpty)
              ? _buildEmptyState()
              : SingleChildScrollView(
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
                        color: Colors.blue[50],
                        width: double.infinity,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  Icon(Icons.info_outline, size: 18, color: Colors.blue[800]),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      " ${_assistantCourses.length} 門課程 / ${_getTotalCredits()} 學分", 
                                      style: TextStyle(color: Colors.blue[900], fontWeight: FontWeight.bold),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            TextButton.icon(
                              onPressed: _showManageCoursesSheet, 
                              icon: const Icon(Icons.list_alt, size: 18),
                              label: const Text("管理清單"),
                              style: TextButton.styleFrom(foregroundColor: Colors.blue[800]),
                            )
                          ],
                        ),
                      ),
                      _buildTimeTable(),
                    ],
                  ),
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.dashboard_customize, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          const Text("助手課表目前是空的", style: TextStyle(color: Colors.grey, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text("點擊右上角選單開始排課", style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  final Color _paleBlueColor = const Color(0xFFF4F8FF);
  
  // ✅ 修改：將 _assistantCourses 與 _customEvents 合併計算表格大小
  Widget _buildTimeTable() {
    int maxDay = 5;
    
    // 計算課程的最大天數與節次
    for (var c in _assistantCourses) {
      for (var t in c.parsedTimes) {
        if (t.day == 6 && maxDay < 6) maxDay = 6;
        if (t.day == 7) maxDay = 7;
      }
    }
    // 計算自訂行程的最大天數與節次
    for (var e in _customEvents) {
      if (e.day == 6 && maxDay < 6) maxDay = 6;
      if (e.day == 7) maxDay = 7;
    }

    List<String> visibleWeekDays = _fullWeekDays.sublist(0, maxDay);

    bool hasPeriodA = false;
    int maxPeriodIndex = _periods.indexOf('7'); 

    for (var c in _assistantCourses) {
      for (var t in c.parsedTimes) {
        if (t.period == 'A') hasPeriodA = true;
        int currentIndex = _periods.indexOf(t.period);
        if (currentIndex > maxPeriodIndex) maxPeriodIndex = currentIndex;
      }
    }
    for (var e in _customEvents) {
      for (var p in e.periods) {
        if (p == 'A') hasPeriodA = true;
        int currentIndex = _periods.indexOf(p);
        if (currentIndex > maxPeriodIndex) maxPeriodIndex = currentIndex;
      }
    }

    int displayEndIndex = maxPeriodIndex;
    if (displayEndIndex < _periods.length - 1) displayEndIndex += 1;
    int startIndex = hasPeriodA ? 0 : _periods.indexOf('1');
    List<String> visiblePeriods = _periods.sublist(startIndex, displayEndIndex + 1);

    // 建立課程 Map
    Map<String, List<Course>> courseMap = {};
    for (var c in _assistantCourses) {
      for (var t in c.parsedTimes) {
        String key = "${t.day}-${t.period}";
        if (!courseMap.containsKey(key)) courseMap[key] = [];
        courseMap[key]!.add(c);
      }
    }

    // 建立自訂行程 Map
    Map<String, List<CustomEvent>> eventMap = {};
    for (var e in _customEvents) {
      for (var p in e.periods) {
        String key = "${e.day}-$p";
        if (!eventMap.containsKey(key)) eventMap[key] = [];
        eventMap[key]!.add(e);
      }
    }

    return Container(
      color: Colors.grey[30], 
      child: Table(
        border: TableBorder.all(color: Colors.grey[350]!, width: 0.5),
        columnWidths: const { 0: FixedColumnWidth(50) },
        defaultVerticalAlignment: TableCellVerticalAlignment.middle, 
        children: [
          TableRow(
            decoration: BoxDecoration(color: _paleBlueColor), 
            children: [
              SizedBox(height: 35, child: Center(child: Text("時段", style: TextStyle(fontSize: 10, color: Colors.blueGrey[600])))), 
              ...visibleWeekDays.map((d) => Container(
                height: 35, alignment: Alignment.center,
                child: Text(d, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.blueGrey[900])),
              )),
            ],
          ),
          ...visiblePeriods.map((period) {
            String timeInfo = _timeMapping[period] ?? "";
            return TableRow(
              children: [
                TableCell(
                  verticalAlignment: TableCellVerticalAlignment.fill,
                  child: Container(
                    color: _paleBlueColor,
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(period, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.blueGrey[900])),
                        if (timeInfo.isNotEmpty)
                          Text(timeInfo, style: TextStyle(fontSize: 9, color: Colors.blueGrey[600]), textAlign: TextAlign.center),
                      ],
                    ),
                  ),
                ),
                ...List.generate(maxDay, (dayIndex) {
                  int currentDay = dayIndex + 1;
                  List<Course> cellCourses = courseMap["$currentDay-$period"] ?? [];
                  List<CustomEvent> cellEvents = eventMap["$currentDay-$period"] ?? [];

                  // 情況一：完全空堂
                  if (cellCourses.isEmpty && cellEvents.isEmpty) {
                    return Container(height: 70);
                  }

                  // 情況二：這個時段「只有一堂正規課程」
                  if (cellCourses.length == 1 && cellEvents.isEmpty) {
                    final cellCourse = cellCourses.first;
                    return Container(
                      height: 70, // 保留基本高度，不被壓縮
                      padding: const EdgeInsets.all(1.0),
                      child: Material(
                        color: _getCourseColor(cellCourse.name),
                        borderRadius: BorderRadius.circular(4),
                        child: InkWell(
                          onTap: () => _showCourseDetail(cellCourse),
                          child: Container(
                            width: double.infinity,
                            height: double.infinity, // 內部撐滿高度
                            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  keepUntilLastChinese(cellCourse.name), 
                                  style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
                                  maxLines: 3, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _extractLocation(cellCourse.location),
                                  style: const TextStyle(fontSize: 8, color: Colors.white70),
                                  maxLines: 1, overflow: TextOverflow.ellipsis,
                                )
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
                    return Container(
                      height: 70, // 保留基本高度，不被壓縮
                      padding: const EdgeInsets.all(1.0),
                      child: Material(
                        color: _getCourseColor(cellEvent.title), // 套用彩色
                        borderRadius: BorderRadius.circular(4),
                        child: InkWell(
                          onTap: () => _showCustomEventDetail(cellEvent),
                          child: Container(
                            width: double.infinity,
                            height: double.infinity, // 內部撐滿高度
                            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  cellEvent.title, 
                                  style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
                                  maxLines: 3, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 2),
                                if (cellEvent.location.isNotEmpty) // 有位置才顯示
                                  Text(
                                    cellEvent.location,
                                    style: const TextStyle(fontSize: 8, color: Colors.white70),
                                    maxLines: 1, overflow: TextOverflow.ellipsis,
                                  )
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
                          color: _getCourseColor(cellCourse.name),
                          borderRadius: BorderRadius.circular(4),
                          child: InkWell(
                            onTap: () => _showCourseDetail(cellCourse),
                            child: Container(
                              width: double.infinity, 
                              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    keepUntilLastChinese(cellCourse.name), 
                                    style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
                                    maxLines: 3, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _extractLocation(cellCourse.location),
                                    style: const TextStyle(fontSize: 8, color: Colors.white70),
                                    maxLines: 1, overflow: TextOverflow.ellipsis,
                                  )
                                ],
                              ),
                            ),
                          ),
                        ),
                      )
                    );
                  }

                  // 渲染多個自訂行程
                  for (var cellEvent in cellEvents) {
                    cellWidgets.add(
                      Padding(
                        padding: const EdgeInsets.only(bottom: 2.0),
                        child: Material(
                          color: _getCourseColor(cellEvent.title),
                          borderRadius: BorderRadius.circular(4),
                          child: InkWell(
                            onTap: () => _showCustomEventDetail(cellEvent),
                            child: Container(
                              width: double.infinity, 
                              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    cellEvent.title, 
                                    style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
                                    maxLines: 3, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 2),
                                  if (cellEvent.location.isNotEmpty)
                                    Text(
                                      cellEvent.location,
                                      style: const TextStyle(fontSize: 8, color: Colors.white70),
                                      maxLines: 1, overflow: TextOverflow.ellipsis,
                                    )
                                ],
                              ),
                            ),
                          ),
                        ),
                      )
                    );
                  }

                  return Container(
                    constraints: const BoxConstraints(minHeight: 70), // 多堂課時讓他自適應長高
                    padding: const EdgeInsets.all(1),
                    color: Colors.grey[30], 
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: cellWidgets,
                    ),
                  );
                }),
              ],
            );
          }).toList(),
        ],
      ),
    );
  }
  void _showCourseDetail(Course course) {
    String prettyTime = _formatCourseTimeWithRange(course);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(course.name, style: const TextStyle(fontWeight: FontWeight.bold)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDetailRow("課號", course.code),
                _buildDetailRow("學分", "${course.credits} (${course.required})"),
                _buildDetailRow("教授", course.professor),
                _buildDetailRow("地點", _extractLocation(course.location)),
                const Divider(height: 20),
                const Text("上課時間", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                const SizedBox(height: 4),
                Text(prettyTime.isNotEmpty ? prettyTime : "無時間資料", style: const TextStyle(fontSize: 15, color: Colors.black87)),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _removeCourseFromAssistant(course);
            }, 
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text("從助手移除")
          ),
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("關閉"))
        ],
      ),
    );
  }

  // ✅ 新增：顯示自訂行程詳細內容的 Dialog
  void _showCustomEventDetail(CustomEvent event) {
    String timeStr = "星期${_fullWeekDays[event.day - 1]} (${event.periods.join(', ')}節)";
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.event_note, color: Colors.blueGrey),
            const SizedBox(width: 8),
            Expanded(child: Text(event.title, style: const TextStyle(fontWeight: FontWeight.bold))),
          ],
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDetailRow("時間", timeStr),
                if (event.details.isNotEmpty) ...[
                  const Divider(height: 20),
                  const Text("詳細內容", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                  const SizedBox(height: 4),
                  Text(event.details, style: const TextStyle(fontSize: 15, color: Colors.black87)),
                ]
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _removeCustomEvent(event.id);
            }, 
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text("刪除此行程")
          ),
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("關閉"))
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 40, child: Text(label, style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.bold))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 15))),
        ],
      ),
    );
  }

  String keepUntilLastChinese(String input) {
    final RegExp chineseRegex = RegExp(r'[\u4e00-\u9fa5]');
    final Iterable<Match> matches = chineseRegex.allMatches(input);
    if (matches.isEmpty) return "";
    int lastIndex = matches.last.end;
    return input.substring(0, lastIndex);
  }

  String _extractLocation(String raw) {
    final regex = RegExp(r'[\(（](.*?)[\)）]'); 
    final match = regex.firstMatch(raw);
    return match?.group(1) ?? raw;
  }

  String _formatCourseTimeWithRange(Course c) {
    if (c.parsedTimes.isEmpty) return "";
    Map<int, List<String>> dayGroups = {};
    for (var t in c.parsedTimes) {
      if (!dayGroups.containsKey(t.day)) dayGroups[t.day] = [];
      dayGroups[t.day]!.add(t.period);
    }
    List<String> results = [];
    List<int> sortedDays = dayGroups.keys.toList()..sort();

    for (var d in sortedDays) {
      List<String> periods = dayGroups[d]!;
      periods.removeWhere((p) => p.contains("&nbsp") || p.trim().isEmpty);
      if (periods.isEmpty) continue;
      periods.sort((a, b) => _periods.indexOf(a).compareTo(_periods.indexOf(b)));

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
      Colors.blue[700]!,       // 藍
      Colors.orange[800]!,     // 橘
      Colors.purple[600]!,     // 紫
      Colors.teal[700]!,       // 藍綠
      Colors.pink[500]!,       // 粉紅      // 金黃
      Colors.indigo[600]!,     // 靛藍
      Colors.deepOrange[600]!, // 橘紅
      Colors.cyan[700]!,       // 青
      Colors.red[700]!,        // 紅
      Colors.deepPurple[600]!, // 深紫
      Colors.green[700]!,      // 正綠
    ];
    
    // 組合 key 並取絕對值雜湊
    final String key = id != null ? name + id : name;
    final int hash = key.hashCode.abs();
    
    return colors[hash % colors.length];
  }

  void _showInfoDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.lightbulb_outline, color: Colors.orange),
            SizedBox(width: 8),
            Text("選課助手功能說明", style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          "1. 提供自訂排課功能，模擬你的專屬課表。\n\n"
          "2. 方便在加簽時快速查看教室與上課時間等資訊。\n\n"
          "3. 支援新增「其他行程」(如工讀、社團)，協助管理個人時間。\n\n"
          "4. 支援從「選課小幫手」網站匯入課表。\n\n"
          "5. 排好的正規課程可直接匯出至「選課系統」進行快速選課。",
          style: TextStyle(height: 1.5, fontSize: 15),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("我知道了", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}