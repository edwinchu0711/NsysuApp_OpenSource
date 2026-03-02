import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/course_model.dart';
import '../utils/utils.dart';

class CourseService {
  static final CourseService instance = CourseService._privateConstructor();
  CourseService._privateConstructor();

  final String _baseUrl = "https://selcrs.nsysu.edu.tw";
  final http.Client _client = http.Client();

  final ValueNotifier<Map<String, List<Course>>> allCoursesNotifier = ValueNotifier({});
  final ValueNotifier<bool> isBusyNotifier = ValueNotifier(false);

  /// [初始化讀取]
  Future<void> loadFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? jsonStr = prefs.getString('cached_courses');
      if (jsonStr != null && jsonStr.isNotEmpty) {
        Map<String, dynamic> decoded = jsonDecode(jsonStr);
        Map<String, List<Course>> loadedData = {};
        
        decoded.forEach((key, value) {
          if (value is List) {
            loadedData[key] = value.map((v) => Course.fromJson(v)).toList();
          }
        });
        allCoursesNotifier.value = loadedData;
        print("📦 CourseService: 已從快取載入 ${loadedData.keys.length} 個學期的課表");
      }
    } catch (e) {
      print("❌ 快取載入失敗: $e");
    }
  }

  /// [核心刷新邏輯]
  Future<void> refreshAndCache() async {
    if (isBusyNotifier.value) return;
    isBusyNotifier.value = true;

    try {
      // --- 【修正點 1：強制同步前檢查快取】 ---
      // 如果目前記憶體變數是空的，主動去讀一次快取，防止因為 Hot Reload 遺失變數狀態
      if (allCoursesNotifier.value.isEmpty) {
        await loadFromCache();
      }

      final SharedPreferences prefs = await SharedPreferences.getInstance();
      String studentId = (prefs.getString('username') ?? "").trim();
      String password = (prefs.getString('password') ?? "").trim();

      if (studentId.isEmpty || password.isEmpty) throw "找不到儲存的帳號或密碼";

      String? sessionCookie = await _loginViaSSO2(studentId, password);
      if (sessionCookie == null) throw "登入驗證失敗";

      // 執行爬取
      Map<String, List<Course>> data = await _fetchAllSemesters(sessionCookie, studentId);

      // 資料清洗
      data.forEach((semester, courseList) {
        for (var course in courseList) {
          course.parsedTimes.removeWhere((time) => 
            time.period.contains("&nbsp;") || time.period.trim().isEmpty
          );
        }
      });

      allCoursesNotifier.value = data;

      // 存入快取
      String encoded = jsonEncode(data.map((k, v) => MapEntry(k, v.map((c) => c.toJson()).toList())));
      await prefs.setString('cached_courses', encoded);
      
      print("🚀 CourseService: 課表同步完成");
    } catch (e) {
      print("❌ 刷新課表失敗: $e");
      rethrow; 
    } finally {
      isBusyNotifier.value = false;
    }
  }

  Future<Map<String, List<Course>>> _fetchAllSemesters(String cookies, String studentId) async {
    // 取得當前已有的資料（如果是 Hot Reload 後，這裡會是從快取 load 進來的內容）
    Map<String, List<Course>> result = Map.from(allCoursesNotifier.value);
    
    String userAgent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36";
    String stuact = studentId.substring(0, 1);
    
    DateTime now = DateTime.now();
    int x = now.year - 1911; 
    int month = now.month;
    List<String> tasks = [];

    // --- 【修正點 2：更嚴謹的判斷邏輯】 ---
    // 只有在快取完全是空的情況下，才執行全量抓取。
    // 如果有舊資料，哪怕只有一個學期，也只執行「增量更新」。
    if (result.isEmpty) {
      print("📅 [全量同步] 偵測到無舊資料，抓取五年份...");
      for (int i = 0; i < 5; i++) {
        tasks.add("${x - i}2");
        tasks.add("${x - i}1");
      }
    } else {
      print("⚡ [增量同步] 偵測到已有快取，僅抓取目標學期...");
      if (month >= 1 && month <= 6) {
        // 1~6月：抓取 x-1 學年度的 2 學期 (因為 1 學期通常已結束)
        tasks.add("${x - 1}2");
      } else {
        // 7~12月：抓取 x 學年度的 1 學期
        tasks.add("${x}1");
      }
    }

    for (String yrsm in tasks) {
      await Future.delayed(const Duration(milliseconds: 150));
      var courses = await _fetchSingleSemester(cookies, userAgent, studentId, stuact, yrsm);
      
      if (courses.isNotEmpty) {
        result[yrsm] = courses;
        print("✅ $yrsm 更新成功");
      }
    }
    
    return result;
  }

  /// [清除快取]
  Future<void> clearCache() async {
    // 1. 重置記憶體中的狀態，這會通知 UI 更新（例如變回空列表）
    allCoursesNotifier.value = {};
    
    try {
      // 2. 移除 SharedPreferences 中的持久化資料
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('cached_courses');
      
      print("🗑️ CourseService: 快取已完全清除");
    } catch (e) {
      print("❌ CourseService 清除失敗: $e");
    }
  }
  
  Future<String?> _loginViaSSO2(String stuid, String password) async {
    final loginUri = Uri.parse("$_baseUrl/menu4/Studcheck_sso2.asp");
    String encryptedPass = Utils.base64md5(password);
    try {
      final response = await _client.post(
        loginUri,
        headers: {
          "Content-Type": "application/x-www-form-urlencoded",
          "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
        },
        body: {"stuid": stuid.toUpperCase(), "SPassword": encryptedPass},
      );
      String? rawCookie = response.headers['set-cookie'];
      if (rawCookie != null && !response.body.contains("不符")) return rawCookie;
    } catch (e) { print("❌ Login Error: $e"); }
    return null;
  }

  Future<List<Course>> _fetchSingleSemester(String cookies, String userAgent, String stuid, String stuact, String yrsm) async {
    final uri = Uri.parse("$_baseUrl/menu4/query/stu_slt_data.asp");
    String big5Submit = "%BD%54%A9%77%B0%65%A5%58";
    String body = "stuact=$stuact&YRSM=$yrsm&Stuid=$stuid&B1=$big5Submit";
    try {
      final response = await _client.post(uri, headers: {
        "Cookie": cookies, "User-Agent": userAgent,
        "Content-Type": "application/x-www-form-urlencoded",
        "Referer": "$_baseUrl/menu4/query/stu_slt_up.asp",
      }, body: body).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        String htmlContent = utf8.decode(response.bodyBytes, allowMalformed: true);
        if (htmlContent.contains("科目名稱")) return _parseHtml(htmlContent);
      }
    } catch (e) { print("❌ $yrsm Fetch Error: $e"); }
    return [];
  }

  List<Course> _parseHtml(String htmlString) {
    final rowRegex = RegExp(r'</tr>|</TR>', caseSensitive: false);
    List<String> sections = htmlString.split(rowRegex);
    List<Course> courses = [];
    final tagRegex = RegExp(r'<[^>]+>');
    final tdRegex = RegExp(r'<td[^>]*>(.*?)</td>', caseSensitive: false, dotAll: true);

    String clean(String html) => html.replaceAll(tagRegex, ' ').replaceAll(RegExp(r'\s+'), ' ').trim();

    for (var section in sections) {
      if (section.contains(">選上<") && !section.contains("選上否")) {
        var matches = tdRegex.allMatches(section);
        var cells = matches.map((m) => m.group(1) ?? "").toList();
        if (cells.length >= 17) {
          List<CourseTime> parsedTimes = [];
          List<String> timeStrings = [];
          for (int day = 1; day <= 7; day++) {
            String timeContent = clean(cells[9 + day]); 
            if (timeContent.isNotEmpty && timeContent != "&nbsp") {
              timeStrings.add("週$day:$timeContent");
              for (int i = 0; i < timeContent.length; i++) {
                parsedTimes.add(CourseTime(day, timeContent[i]));
              }
            }
          }
          courses.add(Course(
            name: clean(cells[4]), code: clean(cells[2]), professor: clean(cells[8]),
            location: clean(cells[9]), timeString: timeStrings.join(" "),
            parsedTimes: parsedTimes, credits: clean(cells[5]),
            required: clean(cells[7]), detailUrl: "",
          ));
        }
      }
    }
    return courses;
  }

  void dispose() => _client.close();
}