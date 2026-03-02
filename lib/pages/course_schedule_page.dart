import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // <--- 新增這行，用於 Clipboard 剪貼簿功能
import 'package:shared_preferences/shared_preferences.dart';
import '../models/course_model.dart';
import '../services/course_service.dart';

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
  bool _isLoading = false;

  // 定義節次與時間對照 (保留原有的對應表以便 UI 使用)
  final List<String> _periods = ['A', '1', '2', '3', '4', 'B', '5', '6', '7', '8','9','C', 'D','E','F'];
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
            loadedData[key] = value.map((v) => _courseFromJson(v)).toList();
          }
        });

        if (mounted) {
          setState(() {
            _allCourses = loadedData;
            _availableSemesters = _allCourses.keys.toList()..sort((a, b) => b.compareTo(a));
            
            if (_availableSemesters.isNotEmpty) {
              _selectedSemester = _availableSemesters.first;
            }
          });
        }
      }
    } catch (e) {
      print("❌ 課表展示頁：載入失敗 $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // JSON 解析輔助
  Course _courseFromJson(Map<String, dynamic> json) {
    var times = (json['parsedTimes'] as List?)?.map((t) => CourseTime(t['day'], t['period'])).toList() ?? [];
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
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
              // 修改處 1：把 SingleChildScrollView 移到最外層，讓標題列可以一起滑動
              : SingleChildScrollView(
                  child: Column(
                    children: [
                      // 學期切換選擇器 (內含匯出按鈕)
                      _buildSemesterSelector(),
                      // 課表主體 (移除 Expanded)
                      _buildTimeTable(_allCourses[_selectedSemester!] ?? []),
                    ],
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
          _availableSemesters = updatedData.keys.toList()..sort((a, b) => b.compareTo(a));
          
          if (_availableSemesters.isNotEmpty) {
            _selectedSemester = _availableSemesters.first;
          }
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("課表已同步至最新")),
        );
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

  Future<void> _saveCachedData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      Map<String, dynamic> toSave = {};
      
      _allCourses.forEach((sem, courses) {
        toSave[sem] = courses.map((c) => _courseToJson(c)).toList();
      });
      
      await prefs.setString('cached_courses', jsonEncode(toSave));
    } catch (e) {
      print("❌ 儲存快取失敗: $e");
    }
  }

  Map<String, dynamic> _courseToJson(Course c) => {
    'name': c.name, 
    'code': c.code, 
    'professor': c.professor,
    'location': c.location, 
    'timeString': c.timeString,
    'credits': c.credits, 
    'required': c.required, 
    'detailUrl': c.detailUrl,
    'parsedTimes': c.parsedTimes.map((t) => {'day': t.day, 'period': t.period}).toList(),
  };

  // --- 修改處 2：新增匯出課表的邏輯 ---
  void _exportTimetable() {
    if (_selectedSemester == null || _allCourses[_selectedSemester!] == null) return;
    
    final courses = _allCourses[_selectedSemester!]!;
    
    // 依據要求的格式轉換
    final exportData = courses.map((c) {
      return {
        "id": c.code,
        "name": c.name,
        "value": 50,
        "isSel": "+"
      };
    }).toList();

    // 將 List 轉為 JSON 字串並組合成最終格式
    final jsonStr = jsonEncode(exportData);
    final exportText = 'const exportClass = $jsonStr;';

    // 複製到剪貼簿
    Clipboard.setData(ClipboardData(text: exportText)).then((_) {
      if (mounted) {
        // 顯示匯出成功與引導前往選課助手的彈窗
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text("匯出成功 🎉"),
            content: const Text("課表代碼已複製到剪貼簿！\n\n你可以前往「選課助手」的頁面進行匯入操作。"),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("我知道了", style: TextStyle(fontWeight: FontWeight.bold)),
              )
            ],
          ),
        );
      }
    });
  }

  // 修改處 3：在選擇器內加入匯出按鈕
  Widget _buildSemesterSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 2)],
      ),
      child: Row(
        children: [
          const Icon(Icons.calendar_today, size: 18, color: Colors.blue),
          const SizedBox(width: 10),
          const Text("目前學期：", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(width: 10),
          // 加上 Expanded 避免小螢幕 Overflow
          Expanded(
            child: DropdownButton<String>(
              isExpanded: true,
              value: _selectedSemester,
              underline: Container(), // 移除底線
              items: _availableSemesters.map((s) {
                return DropdownMenuItem(
                  value: s,
                  child: Text("${s.substring(0, 3)}學年 第${s.substring(3)}學期", 
                    style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.w600)),
                );
              }).toList(),
              onChanged: (val) {
                setState(() => _selectedSemester = val);
              },
            ),
          ),
          // 匯出按鈕
          IconButton(
            icon: const Icon(Icons.ios_share, color: Colors.blue),
            tooltip: "匯出課表代碼",
            onPressed: _exportTimetable,
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
          const Text("尚未取得課表資料", style: TextStyle(color: Colors.grey, fontSize: 18)),
          const SizedBox(height: 8),
          const Text("請回首頁自動同步或檢查網路連線", style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
  
  Widget _buildTimeTable(List<Course> courses) {
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
    List<String> visiblePeriods = _periods.sublist(startIndex, displayEndIndex + 1);

    Map<String, Course> courseMap = {};
    for (var c in courses) {
      for (var t in c.parsedTimes) {
        courseMap["${t.day}-${t.period}"] = c;
      }
    }

    return Table(
      border: TableBorder.all(color: Colors.grey[300]!, width: 0.5),
      columnWidths: const {
        0: FixedColumnWidth(50), 
      },
      children: [
        TableRow(
          decoration: BoxDecoration(color: Colors.grey[100]),
          children: [
            SizedBox(height: 35, child: Center(child: Text("時段", style: TextStyle(fontSize: 10, color: Colors.grey[600])))), 
            ...visibleWeekDays.map((d) => Container(
              height: 35,
              alignment: Alignment.center,
              child: Text(d, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            )),
          ],
        ),
        ...visiblePeriods.map((period) {
          String timeInfo = _timeMapping[period] ?? "";
          return TableRow(
            children: [
              Container(
                height: 70,
                color: Colors.grey[50],
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(period, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    if (timeInfo.isNotEmpty)
                      Text(timeInfo, 
                        style: TextStyle(fontSize: 9, color: Colors.grey[600]), 
                        textAlign: TextAlign.center
                      ),
                  ],
                ),
              ),
              ...List.generate(maxDay, (dayIndex) {
                int currentDay = dayIndex + 1;
                var cellCourse = courseMap["$currentDay-$period"];

                return Container(
                  height: 70,
                  padding: const EdgeInsets.all(1),
                  child: cellCourse == null 
                    ? const SizedBox() 
                    : Material(
                        color: _getCourseColor(cellCourse.name),
                        borderRadius: BorderRadius.circular(4),
                        child: InkWell(
                          onTap: () => _showCourseDetail(cellCourse),
                          child: Padding(
                            padding: const EdgeInsets.all(3),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  keepUntilLastChinese(cellCourse.name), 
                                  style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
                                  maxLines: 3, 
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _extractLocation(cellCourse.location),
                                  style: const TextStyle(fontSize: 8, color: Colors.white70),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                )
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
  }
  
  void _showCourseDetail(Course course) {
    String prettyTime = _formatCourseTimeWithRange(course);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(course.name, style: TextStyle(fontWeight: FontWeight.bold)),
        contentPadding: EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        content: Container(
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
                Divider(height: 20),
                Text("上課時間", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                SizedBox(height: 4),
                Text(prettyTime, style: TextStyle(fontSize: 15, color: Colors.black87)),
                SizedBox(height: 15),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text("關閉"))
        ],
      ),
    );
  }

  String keepUntilLastChinese(String input) {
    final RegExp chineseRegex = RegExp(r'[\u4e00-\u9fa5]');
    final Iterable<Match> matches = chineseRegex.allMatches(input);
    if (matches.isEmpty) {
      return "";
    }
    int lastIndex = matches.last.end;
    return input.substring(0, lastIndex);
  }

  String _extractLocation(String raw) {
    final regex = RegExp(r'[\(（](.*?)[\)）]'); 
    final match = regex.firstMatch(raw);
    return match?.group(1) ?? raw;
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 40, child: Text(label, style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.bold))),
          Expanded(child: Text(value, style: TextStyle(fontSize: 15))),
        ],
      ),
    );
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
      Colors.pink[600]!,       // 粉紅      // 金黃
      Colors.indigo[600]!,     // 靛藍
      Colors.deepOrange[600]!, // 橘紅
      Colors.cyan[700]!,       // 青
      Colors.red[600]!,        // 紅
      Colors.deepPurple[600]!, // 深紫
      Colors.green[700]!,      // 正綠
    ];
    
    // 組合 key 並取絕對值雜湊
    final String key = id != null ? name + id : name;
    final int hash = key.hashCode.abs();
    
    return colors[hash % colors.length];
  }
}