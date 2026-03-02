import 'package:flutter/material.dart';
import '../../services/course_selection_service.dart';

class CourseStatusTab extends StatelessWidget {
  final bool isLoading;
  final String message;
  final bool isSystemClosed;
  final List<CourseSelectionData> courses;
  final Future<void> Function() onRefresh;

  const CourseStatusTab({
    Key? key,
    required this.isLoading,
    required this.message,
    required this.isSystemClosed,
    required this.courses,
    required this.onRefresh,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(message, style: const TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    // if (isSystemClosed) {
    //   return const Center(child: Text("選課系統未開放"));
    // }

    if (courses.isEmpty) {
      return const Center(child: Text("目前沒有任何選課紀錄"));
    }

    // --- 1. 計算學分 與 課程分類 ---
    double selectedCredits = 0;
    double registeringCredits = 0;

    // 定義三個暫存清單
    List<CourseSelectionData> registeringList = []; // 登記/加選 (置頂)
    List<CourseSelectionData> selectedList = [];    // 選上 (中間)
    List<CourseSelectionData> otherList = [];       // 未選上/退選 (置底)

    for (var course in courses) {
      double credit = double.tryParse(course.credits) ?? 0.0;
      
      // 分類邏輯
      if (course.status.contains("未選上")) {
        otherList.add(course);
      }
      else if (course.status.contains("選上")) {
        selectedCredits += credit;
        selectedList.add(course);
      } 
      else if (course.status.contains("登記") || course.status.contains("加選")) {
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
    listChildren.addAll(registeringList.map((c) => _buildCourseCard(c)));
    
    // Part B: 已選上
    listChildren.addAll(selectedList.map((c) => _buildCourseCard(c)));

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
                  style: TextStyle(color: Colors.grey[500], fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ),
              const Expanded(child: Divider(thickness: 1.5)),
            ],
          ),
        ),
      );
      // 接著加入未選上的卡片
      listChildren.addAll(otherList.map((c) => _buildCourseCard(c, isDimmed: true)));
    }

    return Column(
      children: [
        // 頂部資訊卡片 (學分 + 預覽按鈕) - 保持不變
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                spreadRadius: 1,
                blurRadius: 3,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              // 左側：學分統計
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("學分統計", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                    const SizedBox(height: 4),
                    RichText(
                      text: TextSpan(
                        style: const TextStyle(fontSize: 16, color: Colors.black),
                        children: [
                          TextSpan(
                            text: "${selectedCredits.toStringAsFixed(0)}",
                            style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                          ),
                          const TextSpan(text: " (已選上) + ", style: TextStyle(color: Colors.grey, fontSize: 12)),
                          TextSpan(
                            text: "${registeringCredits.toStringAsFixed(0)}",
                            style: const TextStyle(color: Colors.deepOrange, fontWeight: FontWeight.bold),
                          ),
                          const TextSpan(text: " (登記加選) = ", style: TextStyle(color: Colors.grey, fontSize: 12)),
                          TextSpan(
                            text: "${totalCredits.toStringAsFixed(0)}",
                            style: TextStyle(color: Colors.blue[800], fontWeight: FontWeight.bold, fontSize: 20),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // 右側：課表預覽按鈕
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => CoursePreviewPage(courses: courses),
                    ),
                  );
                },
                icon: const Icon(Icons.calendar_month, size: 18),
                label: const Text("課表預覽"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
              ),
            ],
          ),
        ),

        // 列表區域
        Expanded(
          child: RefreshIndicator(
            onRefresh: onRefresh,
            // 這裡改用 ListView 接收 children，而不是 builder，因為我們已經手動組好順序了
            child: ListView(
              padding: const EdgeInsets.all(12),
              children: listChildren,
            ),
          ),
        ),
      ],
    );
  }

  // 增加 isDimmed 參數，讓未選上的卡片看起來稍微淡一點
  Widget _buildCourseCard(CourseSelectionData course, {bool isDimmed = false}) {
    Color statusColor = Colors.grey;
    bool isRegistration = false;

    if (course.status.contains("退選") || course.status.contains("未選上")) {
      statusColor = Colors.grey; // 未選上用灰色
    }
    else if (course.status.contains("選上")) {
      statusColor = Colors.green;
    }else if (course.status.contains("登記") || course.status.contains("加選")) {
      statusColor = const Color.fromARGB(255, 255, 106, 61); // 登記加選用明顯的橘色
      isRegistration = true;
    }

    Widget topRightWidget;
    if (isRegistration) {
      String points = course.remarks ?? "0";
      topRightWidget = Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          const Text("點數/志願", style: TextStyle(fontSize: 13, color: Colors.grey)),
          Text(
            points,
            style: const TextStyle(
              color: Colors.blueAccent,
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
        ],
      );
    } else {
      topRightWidget = Text(
        "${course.dept}",
        style: TextStyle(color: Colors.grey[600], fontSize: 12),
      );
    }

    // 如果是未選上(isDimmed)，整張卡片透明度降低
    return Opacity(
      opacity: isDimmed ? 0.6 : 1.0, 
      child: Card(
        elevation: isDimmed ? 0 : 2, // 未選上的陰影拿掉，讓它看起來比較扁平
        color: isDimmed ? Colors.grey[50] : Colors.white, // 未選上的背景稍微灰一點
        margin: const EdgeInsets.only(bottom: 12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      border: Border.all(color: statusColor),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      course.status,
                      style: TextStyle(color: statusColor, fontWeight: FontWeight.bold),
                    ),
                  ),
                  topRightWidget,
                ],
              ),
              const SizedBox(height: 8),
              Text(
                course.name, 
                style: TextStyle(
                  fontSize: 18, 
                  fontWeight: FontWeight.bold,
                  decoration: isDimmed ? TextDecoration.lineThrough : null, // 未選上可考慮加刪除線，不需要可拿掉
                  color: isDimmed ? Colors.grey[700] : Colors.black,
                )
              ),
              Text("${course.code} • ${course.credits}學分 • ${course.grade}年級"),
              const Divider(height: 24),
              Row(
                children: [
                  Icon(Icons.person, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(course.professor),
                  const SizedBox(width: 16),
                  Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Expanded(child: Text(course.timeRoom, overflow: TextOverflow.ellipsis)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// CoursePreviewPage 保持原樣，不需要修改，直接複製貼上原本的即可
class CoursePreviewPage extends StatelessWidget {
  final List<CourseSelectionData> courses;

  CoursePreviewPage({Key? key, required this.courses}) : super(key: key);

  final List<String> _allPeriods = ['A', '1', '2', '3', '4', 'B', '5', '6', '7', '8','9','C', 'D','E','F'];
  
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

  final List<String> _weekDays = ['一', '二', '三', '四', '五', '六', '日'];

  @override
  Widget build(BuildContext context) {
    final scheduleMap = _parseCoursesToSchedule();

    List<int> visibleDays = [0, 1, 2, 3, 4];
    if (_hasCourseInDay(scheduleMap, 5)) visibleDays.add(5);
    if (_hasCourseInDay(scheduleMap, 6)) visibleDays.add(6);

    List<String> visiblePeriods = _calculateVisiblePeriods(scheduleMap);

    return Scaffold(
      appBar: AppBar(
        title: const Text("課表預覽"),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      body: Column(
        children: [
          Container(
            height: 40,
            color: Colors.grey[100],
            child: Row(
              children: [
                const SizedBox(width: 40),
                ...visibleDays.map((dayIndex) {
                  return Expanded(
                    child: Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        border: Border(left: BorderSide(color: Colors.grey[300]!)),
                      ),
                      child: Text(
                        _weekDays[dayIndex],
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1),
          
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: visiblePeriods.map((period) {
                  return IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          width: 40,
                          constraints: const BoxConstraints(minHeight: 60),
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            border: Border(
                              bottom: BorderSide(color: Colors.grey[200]!),
                              right: BorderSide(color: Colors.grey[300]!),
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(period, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                              const SizedBox(height: 2),
                              Text(
                                _timeMapping[period]?.replaceAll('\n', '\n') ?? "",
                                style: const TextStyle(fontSize: 9, color: Colors.grey),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                        
                        ...visibleDays.map((dayIndex) {
                          final coursesInThisSlot = scheduleMap[dayIndex]?[period] ?? [];
                          
                          return Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(color: Colors.grey[200]!),
                                  left: BorderSide(color: Colors.grey[200]!),
                                ),
                              ),
                              padding: const EdgeInsets.all(1),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: coursesInThisSlot.isEmpty
                                    ? []
                                    : coursesInThisSlot.map((c) => _buildCourseCell(c)).toList(),
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<String> _calculateVisiblePeriods(Map<int, Map<String, List<CourseSelectionData>>> map) {
    List<String> result = [];
    List<String> corePeriods = ['1', '2', '3', '4', 'B', '5', '6', '7', '8', '9','C'];
    
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

  Widget _buildCourseCell(CourseSelectionData course) {
    Color bgColor;
    // 這裡的邏輯也可以稍微對應未選上的狀況，不過課表預覽通常只顯示有時段的，未選上通常不會顯示在課表上
    // 若真的有時間但狀態是退選，顯示紅色
    if (course.status.contains("選上")) {
      bgColor = Colors.green[400]!; 
    } else if (course.status.contains("退選") || course.status.contains("未選上")) {
      bgColor = Colors.red[200]!;
    } else {
      bgColor = Colors.orange[300]!;
    }

    String room = _parseRoomName(course.timeRoom);

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 50), 
      margin: const EdgeInsets.only(bottom: 2), 
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            course.name,
            style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            maxLines: 2,
          ),
          if (room.isNotEmpty) ...[
            const SizedBox(height: 2),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(2),
              ),
              child: Text(
                room,
                style: const TextStyle(fontSize: 9, color: Colors.white),
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ]
        ],
      ),
    );
  }

  bool _checkPeriodHasCourse(Map<int, Map<String, List<CourseSelectionData>>> map, String period) {
    for (var dayData in map.values) {
      if (dayData.containsKey(period) && dayData[period]!.isNotEmpty) {
        return true;
      }
    }
    return false;
  }

  bool _hasCourseInDay(Map<int, Map<String, List<CourseSelectionData>>> map, int dayIndex) {
    return map.containsKey(dayIndex) && map[dayIndex]!.isNotEmpty;
  }

  String _parseRoomName(String timeRoom) {
    final RegExp regex = RegExp(r'[(\uff08]([^)\uff09]*)[)\uff09]');
    final match = regex.firstMatch(timeRoom);
    return match?.group(1)?.trim() ?? ""; 
  }

  Map<int, Map<String, List<CourseSelectionData>>> _parseCoursesToSchedule() {
    Map<int, Map<String, List<CourseSelectionData>>> map = {};

    for (var course in courses) {
      // 如果狀態是 退選 或 未選上，通常不應該出現在課表中，這裡可以加一個判斷過濾掉
      // 依您的需求決定，如果想看原本想選的時間衝突，則保留
      if (course.status.contains("退選") || course.status.contains("未選上")) continue;

      if (course.timeRoom.isEmpty) continue;

      String rawTimeOnly = course.timeRoom.replaceAll(RegExp(r'[(\uff08].*?[)\uff09]'), '');
      
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
            if (!map[currentDay]!.containsKey(char)) map[currentDay]![char] = [];

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