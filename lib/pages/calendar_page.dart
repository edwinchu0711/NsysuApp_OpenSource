import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:uuid/uuid.dart';
import 'package:collection/collection.dart';

// ---------------------------------------------------------------------------
// 1. Data Models (資料模型)
// ---------------------------------------------------------------------------

enum EventType { school, user }

class CalendarEvent {
  final String id;
  final String title;
  final DateTime date;
  final EventType type;

  CalendarEvent({
    required this.id,
    required this.title,
    required this.date,
    required this.type,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'date': date.toIso8601String(),
      'type': 'user',
    };
  }

  factory CalendarEvent.fromMap(Map<String, dynamic> map) {
    return CalendarEvent(
      id: map['id'],
      title: map['title'],
      date: DateTime.parse(map['date']),
      type: EventType.user,
    );
  }
}

// ---------------------------------------------------------------------------
// 2. Service (負責抓取資料、快取)
// ---------------------------------------------------------------------------

class CalendarService {
  static const String _schoolDataUrl =
      'https://edwinchu0711.github.io/CourseSelectionDateUpdate/calendar.json';
  static const String _prefKeySchoolData = 'cached_school_calendar_json';
  static const String _prefKeyFetchTime = 'last_fetch_time_calendar';
  static const String _prefKeyUserEvents = 'user_custom_events';

  Future<Map<String, dynamic>> fetchAllData() async {
    final prefs = await SharedPreferences.getInstance();
    
    List<CalendarEvent> schoolEvents = [];
    String? cachedJson = prefs.getString(_prefKeySchoolData);
    int? lastFetchMillis = prefs.getInt(_prefKeyFetchTime);
    DateTime now = DateTime.now();

    bool shouldFetch = false;
    if (cachedJson == null || lastFetchMillis == null) {
      shouldFetch = true;
    } else {
      DateTime lastFetch = DateTime.fromMillisecondsSinceEpoch(lastFetchMillis);
      if (now.difference(lastFetch).inDays >= 1) {
        shouldFetch = true;
      }
    }

    if (shouldFetch) {
      try {
        final response = await http.get(Uri.parse(_schoolDataUrl));
        if (response.statusCode == 200) {
          cachedJson = utf8.decode(response.bodyBytes);
          await prefs.setString(_prefKeySchoolData, cachedJson);
          await prefs.setInt(_prefKeyFetchTime, now.millisecondsSinceEpoch);
        }
      } catch (e) {
        print("抓取行事曆失敗，使用舊快取: $e");
      }
    }

    DateTime? semesterStartDate;
    if (cachedJson != null) {
      try {
        final data = json.decode(cachedJson);
        final List events = data['events'] ?? [];
        for (var e in events) {
          final String summary = e['summary'] ?? '';
          final String startStr = e['start'] ?? '';
          if (startStr.isEmpty) continue;

          DateTime date = DateTime.parse(startStr);
          date = DateTime(date.year, date.month, date.day);

          schoolEvents.add(CalendarEvent(
            id: const Uuid().v4(),
            title: summary,
            date: date,
            type: EventType.school,
          ));

          if (summary.contains("學生開始上課")) {
            semesterStartDate = date;
          }
        }
      } catch (e) {
        print("解析 JSON 失敗: $e");
      }
    }

    List<CalendarEvent> userEvents = [];
    List<String>? userEventStrs = prefs.getStringList(_prefKeyUserEvents);
    if (userEventStrs != null) {
      userEvents = userEventStrs
          .map((e) => CalendarEvent.fromMap(json.decode(e)))
          .toList();
    }

    return {
      'schoolEvents': schoolEvents,
      'userEvents': userEvents,
      'semesterStartDate': semesterStartDate,
    };
  }

  Future<void> saveUserEvent(CalendarEvent event) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> list = prefs.getStringList(_prefKeyUserEvents) ?? [];
    list.add(json.encode(event.toMap()));
    await prefs.setStringList(_prefKeyUserEvents, list);
  }

  Future<void> removeUserEvent(String id) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> list = prefs.getStringList(_prefKeyUserEvents) ?? [];
    list.removeWhere((str) {
      final map = json.decode(str);
      return map['id'] == id;
    });
    await prefs.setStringList(_prefKeyUserEvents, list);
  }
}

// ---------------------------------------------------------------------------
// 3. UI Page
// ---------------------------------------------------------------------------

class CalendarPage extends StatefulWidget {
  const CalendarPage({Key? key}) : super(key: key);

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  final CalendarService _service = CalendarService();
  bool _isLoading = true;
  bool _isMonthView = true;
  
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  List<CalendarEvent> _searchResults = [];

  List<CalendarEvent> _allEvents = [];
  Map<DateTime, List<CalendarEvent>> _groupedEvents = {};
  
  DateTime? _semesterStartDate;
  int? _semesterStartWeekNumber;

  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  
  // ★ 新增：控制該月是否顯示週次欄位
  bool _shouldShowWeekNumber = true;

  ScrollController? _listScrollController;

  @override
  void initState() {
    super.initState();
    _selectedDay = DateTime.now();
    _focusedDay = DateTime.now();
    _loadData();
  }
  // ★ 補上這個函式：判斷兩個日期是否在同一個月份
  bool isSameMonth(DateTime? a, DateTime? b) {
    if (a == null || b == null) {
      return false;
    }
    return a.year == b.year && a.month == b.month;
  }

  @override
  void dispose() {
    _searchController.dispose();
    _listScrollController?.dispose();
    super.dispose();
  }

  int _getWeekOfYear(DateTime date) {
    int dayOfYear = int.parse(DateFormat("D").format(date));
    return ((dayOfYear - date.weekday + 10) / 7).floor();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final data = await _service.fetchAllData();
    
    List<CalendarEvent> school = data['schoolEvents'];
    List<CalendarEvent> user = data['userEvents'];
    _semesterStartDate = data['semesterStartDate'];

    if (_semesterStartDate != null) {
      _semesterStartWeekNumber = _getWeekOfYear(_semesterStartDate!);
    }

    _allEvents = [...school, ...user];
    
    _groupedEvents = {};
    for (var event in _allEvents) {
      final dateKey = DateTime(event.date.year, event.date.month, event.date.day);
      if (_groupedEvents[dateKey] == null) {
        _groupedEvents[dateKey] = [];
      }
      _groupedEvents[dateKey]!.add(event);
    }

    _allEvents.sort((a, b) => a.date.compareTo(b.date));

    // 資料載入後，先檢查一次當前月份是否需要顯示週次
    _checkIfMonthHasSemesterWeeks(_focusedDay);

    if (mounted) setState(() => _isLoading = false);
  }

  // ★ 檢查該月份是否有任何一週在學期週次範圍內
  void _checkIfMonthHasSemesterWeeks(DateTime focusedDay) {
    if (_semesterStartWeekNumber == null) {
      if (_shouldShowWeekNumber) setState(() => _shouldShowWeekNumber = false);
      return;
    }

    // 取得該月的第一天與最後一天
    DateTime firstDay = DateTime(focusedDay.year, focusedDay.month, 1);
    DateTime lastDay = DateTime(focusedDay.year, focusedDay.month + 1, 0);

    bool hasSemesterWeek = false;

    // 每隔7天檢查一次週次，或者檢查每週的第一天
    // 簡單作法：從該月第一天開始，每週檢查一次
    DateTime current = firstDay;
    while (current.isBefore(lastDay) || isSameDay(current, lastDay)) {
      int weekNum = _getWeekOfYear(current);
      String label = _convertWeekNumberToSemesterWeek(weekNum);
      if (label.isNotEmpty) {
        hasSemesterWeek = true;
        break;
      }
      current = current.add(const Duration(days: 7));
    }

    if (_shouldShowWeekNumber != hasSemesterWeek) {
      setState(() {
        _shouldShowWeekNumber = hasSemesterWeek;
      });
    }
  }

  List<CalendarEvent> _getEventsForDay(DateTime day) {
    final dateKey = DateTime(day.year, day.month, day.day);
    return _groupedEvents[dateKey] ?? [];
  }

  bool _isHoliday(DateTime day) {
    final dateKey = DateTime(day.year, day.month, day.day);
    final events = _groupedEvents[dateKey] ?? [];
    
    bool explicitHoliday = false; 
    bool explicitWorkDay = false; 

    for (var e in events) {
      if (e.type == EventType.school) {
        final title = e.title;
        if (title.contains("放假")) explicitHoliday = true;
        if (title.contains("停課")) explicitHoliday = true;
        if (title.contains("補課")) explicitWorkDay = true;

        if (title.contains("補假")) {
          bool isWeekend = (day.weekday == DateTime.saturday || day.weekday == DateTime.sunday);
          if (isWeekend && title.length < 10) {
            explicitWorkDay = true;
          } else if (!isWeekend) {
            explicitHoliday = true;
          }
        }
      }
    }

    if (explicitWorkDay) return false;
    if (explicitHoliday) return true;

    if (day.weekday == DateTime.saturday || day.weekday == DateTime.sunday) {
      return true;
    }

    return false;
  }

  String _convertWeekNumberToSemesterWeek(int weekNumber) {
    if (_semesterStartWeekNumber == null) return "";
    
    int diff = weekNumber - _semesterStartWeekNumber!;
    if (diff < -20) diff += 52; 

    int semesterWeek = diff + 1;

    if (semesterWeek >= 1 && semesterWeek <= 18) {
      return "$semesterWeek";
    } else if (semesterWeek == 0) {
      return "前1";
    } else if (semesterWeek == -1) {
      return "前2";
    }
    return "";
  }

  String? _getWeekLabelFull(DateTime day) {
    if (_semesterStartDate == null) return null;
    
    final start = DateTime(_semesterStartDate!.year, _semesterStartDate!.month, _semesterStartDate!.day);
    final startOfWeekStart = start.subtract(Duration(days: start.weekday - 1));
    final targetOfWeek = day.subtract(Duration(days: day.weekday - 1));

    final diffDays = targetOfWeek.difference(startOfWeekStart).inDays;
    final weekIndex = (diffDays / 7).floor() + 1;

    if (weekIndex >= 1 && weekIndex <= 18) {
      return "第$weekIndex週";
    } else if (weekIndex == 0) {
      return "開學前1週";
    } else if (weekIndex == -1) {
      return "開學前2週";
    }
    return null;
  }

  double _calculateInitialScrollOffset() {
    if (_groupedEvents.isEmpty) return 0.0;
    final sortedDates = _groupedEvents.keys.toList()..sort();
    
    final today = DateTime.now();
    final todayKey = DateTime(today.year, today.month, today.day);
    
    int targetIndex = 0;
    for (int i = 0; i < sortedDates.length; i++) {
      if (sortedDates[i].isAfter(todayKey) || isSameDay(sortedDates[i], todayKey)) {
        targetIndex = i;
        break;
      }
    }

    double offset = 0.0;
    for (int i = 0; i < targetIndex; i++) {
      final date = sortedDates[i];
      final events = _groupedEvents[date]!;
      
      double headerHeight = 36.0; 
      String? currentWeek = _getWeekLabelFull(date);
      String? prevWeek;
      if (i > 0) prevWeek = _getWeekLabelFull(sortedDates[i-1]);
      
      if (currentWeek != null && currentWeek != prevWeek) {
        headerHeight += 52.0; 
      }
      
      offset += headerHeight;
      offset += (events.length * 70.0); 
      offset += 8.0;
    }
    return offset;
  }

  void _runSearch(String query) {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
      });
      return;
    }
    final results = _allEvents.where((e) {
      return e.title.toLowerCase().contains(query.toLowerCase());
    }).toList();

    setState(() {
      _searchResults = results;
    });
  }

  void _showAddEventDialog() {
    final titleController = TextEditingController();
    DateTime tempDate = _selectedDay ?? DateTime.now();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("新增個人事項"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(labelText: "事項內容"),
            ),
            const SizedBox(height: 10),
            Text("日期: ${DateFormat('yyyy/MM/dd').format(tempDate)}"),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("取消")),
          ElevatedButton(
            onPressed: () async {
              if (titleController.text.isNotEmpty) {
                final newEvent = CalendarEvent(
                  id: const Uuid().v4(),
                  title: titleController.text,
                  date: tempDate,
                  type: EventType.user,
                );
                await _service.saveUserEvent(newEvent);
                if (mounted) {
                  Navigator.pop(context);
                  _loadData(); 
                }
              }
            },
            child: const Text("新增"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: !_isSearching,
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                style: const TextStyle(color: Colors.black),
                decoration: const InputDecoration(
                  hintText: '輸入關鍵字搜尋...',
                  border: InputBorder.none,
                  hintStyle: TextStyle(color: Colors.grey),
                ),
                onChanged: _runSearch,
              )
            : Text(_isMonthView ? "行事曆" : "學期總覽"),
        centerTitle: true,
        actions: [
          if (_isSearching)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () {
                setState(() {
                  _isSearching = false;
                  _searchController.clear();
                  _searchResults = [];
                });
              },
            )
          else
            IconButton(
              icon: const Icon(Icons.search),
              onPressed: () {
                setState(() {
                  _isSearching = true;
                });
              },
            ),

          if (!_isSearching)
            IconButton(
              icon: Icon(_isMonthView ? Icons.list_alt_rounded : Icons.calendar_month_rounded),
              onPressed: () {
                setState(() {
                  _isMonthView = !_isMonthView;
                });
              },
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildBody(),
      floatingActionButton: !_isSearching
          ? FloatingActionButton(
              onPressed: _showAddEventDialog,
              backgroundColor: Colors.pinkAccent,
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
    );
  }

  Widget _buildBody() {
    if (_isSearching) {
      return _buildSearchResults();
    } else if (_isMonthView) {
      return _buildMonthViewLayout();
    } else {
      return _buildListViewLayout();
    }
  }

  Widget _buildSearchResults() {
    if (_searchResults.isEmpty && _searchController.text.isNotEmpty) {
      return const Center(child: Text("找不到相關活動"));
    }
    if (_searchResults.isEmpty) {
      return const Center(child: Text("請輸入關鍵字"));
    }
    return ListView.builder(
      itemCount: _searchResults.length,
      padding: const EdgeInsets.all(16),
      itemBuilder: (context, index) {
        final event = _searchResults[index];
        return Column(
          children: [
            _buildEventCard(event, showDate: true),
          ],
        );
      },
    );
  }

  // ★ 自訂標頭 (解決週次漂浮問題)
  Widget _buildCustomHeader() {
    // 建立 7 個星期的標題
    List<Widget> dayHeaders = [];
    for (int i = 1; i <= 7; i++) {
      // 星期一 = 1, ... 星期日 = 7
      // 這裡要對應 TableCalendar 的 startingDayOfWeek: StartingDayOfWeek.monday
      // 所以順序是 Mon, Tue, Wed, Thu, Fri, Sat, Sun
      // 若 intl 星期日是 0 或 7，需注意。 DateTime.monday = 1
      DateTime temp = DateTime.now();
      while (temp.weekday != i) {
        temp = temp.add(const Duration(days: 1));
      }
      dayHeaders.add(
        Expanded(
          child: Container(
             height: 40,
             alignment: Alignment.center,
             child: Text(
               DateFormat.E('zh_TW').format(temp),
               style: const TextStyle(color: Colors.grey, fontSize: 14),
             ),
          ),
        ),
      );
    }

    return Row(
      children: [
        // 如果週次顯示開啟，加上左邊的 "週次" 標題
        if (_shouldShowWeekNumber)
          Container(
            width: 50, // 需對應 weekNumberBuilder 的寬度
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              border: Border(right: BorderSide(color: Colors.grey[300]!)),
            ),
            child: const Text(
              "週次",
              style: TextStyle(
                fontSize: 10, 
                color: Colors.grey, 
                fontWeight: FontWeight.bold
              ),
            ),
          ),
        
        // 剩餘空間給星期標題
        Expanded(
          child: Row(
            children: dayHeaders,
          ),
        ),
      ],
    );
  }
  // ★ 新增：自訂的月份切換標題
  Widget _buildMonthHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () {
              setState(() {
                // 減一個月
                _focusedDay = DateTime(_focusedDay.year, _focusedDay.month - 1, 1);
                // 更新週次檢查
                _checkIfMonthHasSemesterWeeks(_focusedDay);
              });
            },
          ),
          const SizedBox(width: 10),
          Text(
            DateFormat.yMMM('zh_TW').format(_focusedDay), // 顯示 "2026年 1月"
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueGrey),
          ),
          const SizedBox(width: 10),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () {
              setState(() {
                // 加一個月
                _focusedDay = DateTime(_focusedDay.year, _focusedDay.month + 1, 1);
                _checkIfMonthHasSemesterWeeks(_focusedDay);
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMonthViewLayout() {
    final currentEvents = _getEventsForDay(_selectedDay ?? DateTime.now());
    final weekLabel = _getWeekLabelFull(_selectedDay ?? DateTime.now());

    return Column(
      children: [
        // 1. 年份月份標題 (放在最上面)
        _buildMonthHeader(),

        // 2. 星期與週次標題 (放在中間)
        _buildCustomHeader(),

        // 3. 日曆本體
        TableCalendar<CalendarEvent>(
          locale: 'zh_TW',
          firstDay: DateTime.utc(2020, 1, 1),
          lastDay: DateTime.utc(2030, 12, 31),
          focusedDay: _focusedDay,
          calendarFormat: CalendarFormat.month,
          selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
          eventLoader: _getEventsForDay,
          startingDayOfWeek: StartingDayOfWeek.monday,
          
          weekNumbersVisible: _shouldShowWeekNumber,
          daysOfWeekVisible: false, 
          
          // ★ 隱藏內建標題 (因為我們自己寫了 _buildMonthHeader)
          headerVisible: false, 

          calendarStyle: const CalendarStyle(
             outsideDaysVisible: true,
          ),

          onDaySelected: (selectedDay, focusedDay) {
            if (!isSameMonth(selectedDay, focusedDay)) {
              return; 
            }
            setState(() {
              _selectedDay = selectedDay;
              _focusedDay = focusedDay;
            });
          },
          
          onPageChanged: (focusedDay) {
            DateTime firstDayOfNewMonth = DateTime(focusedDay.year, focusedDay.month, 1);
            setState(() {
              _focusedDay = focusedDay;
              _selectedDay = firstDayOfNewMonth;
            });
            _checkIfMonthHasSemesterWeeks(focusedDay);
          },

          calendarBuilders: CalendarBuilders(
            weekNumberBuilder: (context, weekNumber) {
              final text = _convertWeekNumberToSemesterWeek(weekNumber);
              if (text.isEmpty) return const SizedBox();

              return Container(
                decoration: BoxDecoration(
                  color: Colors.grey[100], 
                  border: Border(right: BorderSide(color: Colors.grey[300]!)),
                ),
                width: 50, 
                child: Center(
                  child: Text(
                    text,
                    style: const TextStyle(color: Colors.blueGrey, fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                ),
              );
            },

            outsideBuilder: (context, day, focusedDay) {
               return Container(
                 alignment: Alignment.center,
                 child: Text(
                   '${day.day}',
                   style: TextStyle(color: Colors.grey.withOpacity(0.4)),
                 ),
               );
            },

            defaultBuilder: (context, day, focusedDay) {
              return _buildCustomDayCell(day, isHoliday: _isHoliday(day));
            },
            todayBuilder: (context, day, focusedDay) {
              return _buildCustomDayCell(day, isToday: true, isHoliday: _isHoliday(day));
            },
            selectedBuilder: (context, day, focusedDay) {
              return _buildCustomDayCell(day, isSelected: true, isHoliday: _isHoliday(day));
            },
            
            markerBuilder: (context, day, events) {
              if (events.isEmpty) return null;
              
              // 非本月：顯示灰色小點
              if (!isSameMonth(day, _focusedDay)) {
                return Positioned(
                  bottom: 1,
                  child: Container(
                    width: 5, 
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.4),
                      shape: BoxShape.circle,
                    ),
                  ),
                );
              }

              // 本月：顯示橘色/粉色點
              bool hasSchool = events.any((e) => e.type == EventType.school);
              bool hasUser = events.any((e) => e.type == EventType.user);

              return Positioned(
                bottom: 1,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (hasSchool)
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 1.0),
                        width: 6, height: 6,
                        decoration: const BoxDecoration(color: Colors.orange, shape: BoxShape.circle),
                      ),
                    if (hasUser)
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 1.0),
                        width: 6, height: 6,
                        decoration: const BoxDecoration(color: Colors.pinkAccent, shape: BoxShape.circle),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
        
        const Divider(height: 1),
        
        Expanded(
          child: Container(
            color: Colors.grey[50],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (weekLabel != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.blue[100],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        weekLabel,
                        style: TextStyle(
                          color: Colors.blue[800],
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: Row(
                    children: [
                      Text(DateFormat('MM/dd (E)', 'zh_TW').format(_selectedDay!), 
                           style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const Spacer(),
                      Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.orange, shape: BoxShape.circle)),
                      const Text(" 學校 ", style: TextStyle(fontSize: 10)),
                      Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.pinkAccent, shape: BoxShape.circle)),
                      const Text(" 個人", style: TextStyle(fontSize: 10)),
                    ],
                  ),
                ),
                Expanded(
                  child: currentEvents.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.event_busy_rounded, size: 48, color: Colors.grey[300]),
                              const SizedBox(height: 8),
                              Text("今天沒有安排事項", style: TextStyle(color: Colors.grey[400])),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: currentEvents.length,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          itemBuilder: (context, index) {
                            return _buildEventCard(currentEvents[index]);
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
  Widget _buildCustomDayCell(DateTime day, {
    bool isSelected = false, 
    bool isToday = false,
    bool isHoliday = false,
  }) {
    Color? bgColor;
    Color textColor = Colors.black;
    BoxDecoration? decoration;

    if (isSelected) {
      bgColor = Colors.blue[700]; 
      textColor = Colors.white;
    } else if (isToday) {
      bgColor = Colors.blue[200]; 
      textColor = Colors.black;
    } else if (isHoliday) {
      bgColor = Colors.red[50]; 
    }

    if (isSelected || isToday) {
      decoration = BoxDecoration(
        color: bgColor,
        shape: BoxShape.circle,
      );
    } else if (isHoliday) {
      decoration = BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      );
    }

    return Center(
      child: Container(
        margin: const EdgeInsets.all(4.0),
        alignment: Alignment.center,
        decoration: decoration,
        width: 40, height: 40,
        child: Text(
          '${day.day}',
          style: TextStyle(
            color: (isHoliday && !isSelected && !isToday) ? Colors.red[800] : textColor,
            fontWeight: (isSelected || isToday) ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildListViewLayout() {
    if (_allEvents.isEmpty) {
      return const Center(child: Text("目前沒有任何行事曆資料"));
    }

    _listScrollController ??= ScrollController(
      initialScrollOffset: _calculateInitialScrollOffset(),
    );

    return ListView.builder(
      controller: _listScrollController,
      itemCount: _groupedEvents.keys.length,
      padding: const EdgeInsets.all(16),
      itemBuilder: (context, index) {
        final sortedDates = _groupedEvents.keys.toList()..sort();
        final date = sortedDates[index];
        final events = _groupedEvents[date]!;
        final weekLabel = _getWeekLabelFull(date);
        
        String? previousWeekLabel;
        if (index > 0) {
          previousWeekLabel = _getWeekLabelFull(sortedDates[index - 1]);
        }
        bool showWeekHeader = weekLabel != null && weekLabel != previousWeekLabel;

        bool isHoliday = _isHoliday(date);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showWeekHeader)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Row(
                  children: [
                    Container(width: 4, height: 20, color: Colors.blue[800]),
                    const SizedBox(width: 8),
                    Text(
                      weekLabel!,
                      style: TextStyle(
                        fontSize: 18, 
                        fontWeight: FontWeight.bold, 
                        color: Colors.blue[800]
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Divider(color: Colors.blue[200])),
                  ],
                ),
              ),
            
            Container(
              decoration: isHoliday ? BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(8)
              ) : null,
              padding: isHoliday ? const EdgeInsets.all(8) : const EdgeInsets.only(top: 8, bottom: 4, left: 4),
              child: Text(
                DateFormat('yyyy/MM/dd (E)', 'zh_TW').format(date),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: isHoliday ? Colors.red[800] : Colors.grey[700],
                ),
              ),
            ),
            
            ...events.map((e) => _buildEventCard(e)),
            const SizedBox(height: 8),
          ],
        );
      },
    );
  }

  Widget _buildEventCard(CalendarEvent event, {bool showDate = false}) {
    bool isUser = event.type == EventType.user;
    return Card(
      elevation: 1,
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      color: Colors.white,
      child: ListTile(
        visualDensity: VisualDensity.compact,
        leading: Container(
          width: 4,
          height: double.infinity,
          color: isUser ? Colors.pinkAccent : Colors.orange,
        ),
        title: Text(
          event.title,
          style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 15),
        ),
        subtitle: showDate 
          ? Text(DateFormat('yyyy/MM/dd (E)', 'zh_TW').format(event.date), style: const TextStyle(fontSize: 12))
          : (isUser 
              ? const Text("個人事項", style: TextStyle(fontSize: 12, color: Colors.pinkAccent)) 
              : null),
        trailing: isUser
            ? IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.grey, size: 20),
                onPressed: () async {
                  await _service.removeUserEvent(event.id);
                  _loadData();
                },
              )
            : null,
      ),
    );
  }
}