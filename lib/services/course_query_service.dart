import 'dart:convert';
import 'package:http/http.dart' as http;

class CourseJsonData {
  final String id;        // 科號 (T3)
  final String name;      // 課名 (crsname)
  final String teacher;   // 老師 (teacher)
  final String grade;     // 年級 (D2)
  final String className; // 班級 (CLASS_COD 對應文字)
  final String department;// 系所
  final List<String> classTime; // 時間 [Mon, Tue, ...]
  final String room;      // 教室
  final String credit;    // 學分

  CourseJsonData({
    required this.id,
    required this.name,
    required this.teacher,
    required this.grade,
    required this.className,
    required this.department,
    required this.classTime,
    required this.room,
    required this.credit,
  });

  factory CourseJsonData.fromJson(Map<String, dynamic> json) {
    return CourseJsonData(
      id: json['id'] ?? "",
      name: json['name'] ?? "",
      teacher: json['teacher'] ?? "",
      grade: json['grade'] ?? "",
      className: json['class'] ?? "", // API 欄位叫 class
      department: json['department'] ?? "",
      classTime: List<String>.from(json['classTime'] ?? []),
      room: json['room'] ?? "",
      credit: json['credit'] ?? "",
    );
  }
}

class CourseQueryService {
  static final CourseQueryService instance = CourseQueryService._privateConstructor();
  CourseQueryService._privateConstructor();

  List<CourseJsonData> _cachedCourses = [];
  bool _isDataLoaded = false;
  String _currentSemester = "";

  String get currentSemester => _currentSemester;
  // 取得資料 (三階段請求)
  Future<List<CourseJsonData>> getCourses({bool forceRefresh = false}) async {
    if (_isDataLoaded && !forceRefresh && _cachedCourses.isNotEmpty) {
      return _cachedCourses;
    }

    print("🔍 [課程API] 開始抓取課程資料...");
    final client = http.Client();

    try {
      // 1. 取得 latest semester (例如 1142)
      final vRes = await client.get(Uri.parse("https://nsysu-opendev.github.io/NSYSUCourseAPI/version.json"));
      if (vRes.statusCode != 200) throw "Version API Error";
      final vJson = jsonDecode(vRes.body);
      final String latestSem = vJson['latest'];
      _currentSemester = latestSem;
      print("   -> 最新學期: $latestSem");

      // 2. 取得該學期的 latest time
      final tRes = await client.get(Uri.parse("https://nsysu-opendev.github.io/NSYSUCourseAPI/$latestSem/version.json"));
      if (tRes.statusCode != 200) throw "Time API Error";
      final tJson = jsonDecode(tRes.body);
      final String latestTime = tJson['latest'];
      print("   -> 最新時間戳: $latestTime");

      // 3. 取得 all.json
      final url = "https://nsysu-opendev.github.io/NSYSUCourseAPI/$latestSem/$latestTime/all.json";
      print("   -> 下載大檔: $url");
      final allRes = await client.get(Uri.parse(url));
      if (allRes.statusCode != 200) throw "All JSON API Error";

      // 解析 List
      final List<dynamic> rawList = jsonDecode(utf8.decode(allRes.bodyBytes));
      _cachedCourses = rawList.map((e) => CourseJsonData.fromJson(e)).toList();
      _isDataLoaded = true;
      
      print("✅ [課程API] 資料載入完成，共 ${_cachedCourses.length} 筆");
      return _cachedCourses;

    } catch (e) {
      print("❌ [課程API] 錯誤: $e");
      throw e;
    } finally {
      client.close();
    }
  }

  // 搜尋邏輯
  List<CourseJsonData> search({
    String? keyword,      // 課名
    String? teacher,      // 老師
    String? code,         // 代號
    String? grade,        // 年級 (1-5)
    String? classType,    // 班別 (對應 text)
    String? day,          // 星期 (1-7)
    String? period,       // 節次 (1-9, A, B...)
    String? dept,         // 系所
  }) {
    if (_cachedCourses.isEmpty) return [];

    return _cachedCourses.where((course) {
      // 1. 課名 (模糊)
      if (keyword != null && keyword.isNotEmpty) {
        if (!course.name.contains(keyword)) return false;
      }
      // 2. 老師 (模糊)
      if (teacher != null && teacher.isNotEmpty) {
        if (!course.teacher.contains(teacher)) return false;
      }
      // 3. 代號 (開頭符合或包含)
      if (code != null && code.isNotEmpty) {
        if (!course.id.toUpperCase().contains(code.toUpperCase())) return false;
      }
      // 4. 年級 (精確)
      if (grade != null && grade.isNotEmpty) {
        if (course.grade != grade) return false;
      }
      // 5. 班別 (JSON 內的 class 是中文，如 "甲班", "不分班")
      if (classType != null && classType.isNotEmpty) {
        // 使用者選 "1" -> 轉成 "甲班" 的邏輯在 UI 層做，這裡傳進來的要是中文
        if (course.className != classType) return false;
      }
      // 6. 系所 (模糊)
      if (dept != null && dept.isNotEmpty) {
        if (!course.department.contains(dept)) return false;
      }
      // 7. 時間 (星期 & 節次)
      if (day != null && day.isNotEmpty) {
        int dayIndex = int.parse(day) - 1; // 1(Mon) -> index 0
        if (dayIndex >= 0 && dayIndex < course.classTime.length) {
          String periods = course.classTime[dayIndex];
          
          // 如果只要查星期幾有課 (節次為空)
          if (period == null || period.isEmpty) {
             if (periods.isEmpty) return false;
          } else {
             // 查特定節次
             if (!periods.contains(period)) return false;
          }
        }
      }

      return true;
    }).take(35).toList(); // 限制 35 筆
  }
}