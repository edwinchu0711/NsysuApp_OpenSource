import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:html/parser.dart' as parser;
import 'package:path_provider/path_provider.dart';

// --- 模型 ---
class ElearnTask {
  final int id;
  final double? score; // 新增分數欄位
  final String courseName;
  final String title;
  final String type;
  final bool isSubmitted;
  final DateTime? endTime;
  String statusRaw; 
  bool isIgnored;   

  ElearnTask({
    required this.id,
    required this.courseName,
    required this.title,
    required this.type,
    required this.isSubmitted,
    this.endTime,
    required this.statusRaw,
    this.score,
    this.isIgnored = false,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'courseName': courseName,
    'title': title,
    'type': type,
    'score': score,
    'isSubmitted': isSubmitted,
    'endTime': endTime?.toIso8601String(),
    'statusRaw': statusRaw,
    'isIgnored': isIgnored,
  };

  factory ElearnTask.fromJson(Map<String, dynamic> json) {
    return ElearnTask(
      id: json['id'] ?? 0,
      courseName: json['courseName'],
      title: json['title'],
      type: json['type'],
      isSubmitted: json['isSubmitted'],
      score: json['score']?.toDouble(),
      endTime: json['endTime'] != null ? DateTime.parse(json['endTime']) : null,
      statusRaw: json['statusRaw'],
      isIgnored: json['isIgnored'] ?? false,
    );
  }
}

class ElearnService {
  static final ElearnService instance = ElearnService._init();
  ElearnService._init();

  final String _baseUrl = "https://elearn.nsysu.edu.tw";
  final Map<String, String> _baseHeaders = {
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
    "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8",
    "Connection": "keep-alive",
    "Upgrade-Insecure-Requests": "1",
  };

  Map<String, String> _cookieJar = {};
  DateTime? _lastLoginTime;
  
  static const String _ignoredKey = "ignored_task_ids";
  static const String _cachedTasksKey = "cached_elearn_tasks";

  // --- 公用方法 ---

  Future<List<ElearnTask>> fetchTasks(String semesterCode) async {
    await _ensureAuthenticated();
    
    // 1. 抓取網路資料
    List<ElearnTask> tasks = await _getCourseData(semesterCode);

    // 2. 應用忽略清單
    final prefs = await SharedPreferences.getInstance();
    final List<String> ignoredIds = prefs.getStringList(_ignoredKey) ?? [];

    for (var task in tasks) {
      if (ignoredIds.contains(task.id.toString())) {
        task.isIgnored = true;
        task.statusRaw = "已忽略";
      }
    }

    // 3. 更新快取 (很重要，不然下次進來沒資料)
    await cacheTasks(tasks);

    return tasks;
  }

  Future<void> toggleIgnoreTask(int id, bool ignore) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> ignoredIds = prefs.getStringList(_ignoredKey) ?? [];
    String idStr = id.toString();

    if (ignore) {
      if (!ignoredIds.contains(idStr)) ignoredIds.add(idStr);
    } else {
      ignoredIds.remove(idStr);
    }
    
    await prefs.setStringList(_ignoredKey, ignoredIds);
    
    // 更新目前的快取資料，確保狀態一致
    await _updateCacheIgnoreStatus(id, ignore);
  }

  // 輔助：單獨更新快取中的某個任務忽略狀態，避免需要重新聯網
  Future<void> _updateCacheIgnoreStatus(int id, bool ignore) async {
    var tasks = await loadCachedTasks();
    bool changed = false;
    for (var t in tasks) {
      if (t.id == id) {
        t.isIgnored = ignore;
        t.statusRaw = ignore ? "已忽略" : (t.isSubmitted ? "已繳交" : "未繳交"); // 簡單恢復狀態
        changed = true;
        break;
      }
    }
    if (changed) {
      await cacheTasks(tasks);
    }
  }

  Future<void> clearAllCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cachedTasksKey);
    await prefs.remove(_ignoredKey);
    await prefs.remove('last_elearn_fetch_time'); // 清除時間戳記
    _cookieJar.clear();
    _lastLoginTime = null;
    print("🧹 ElearnService 快取已清除");
  }

  // 讀取快取 (並重新應用忽略邏輯)
  Future<List<ElearnTask>> loadCachedTasks() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.containsKey(_cachedTasksKey)) {
      final String jsonStr = prefs.getString(_cachedTasksKey)!;
      final List<dynamic> jsonList = jsonDecode(jsonStr);
      List<ElearnTask> tasks = jsonList.map((e) => ElearnTask.fromJson(e)).toList();
      
      // 重新檢查忽略清單 (防止快取存的是舊狀態)
      final List<String> ignoredIds = prefs.getStringList(_ignoredKey) ?? [];
      for (var task in tasks) {
        if (ignoredIds.contains(task.id.toString())) {
          task.isIgnored = true;
          task.statusRaw = "已忽略";
        }
      }
      return tasks;
    }
    return [];
  }

  // 儲存快取
  Future<void> cacheTasks(List<ElearnTask> tasks) async {
    final prefs = await SharedPreferences.getInstance();
    final String jsonStr = jsonEncode(tasks.map((e) => e.toJson()).toList());
    await prefs.setString(_cachedTasksKey, jsonStr);
  }

  // ... (fetchDetails, downloadFile, login logic 保持不變) ...
  Future<Map<String, dynamic>> fetchExamDetails(int examId) async {
    await _ensureAuthenticated();
    final client = http.Client();
    try {
      final infoRes = await _get("$_baseUrl/api/exams/$examId", client);
      if (infoRes.statusCode != 200) throw Exception("無法讀取測驗資料");
      final subRes = await _get("$_baseUrl/api/exams/$examId/submissions", client);
      if (subRes.statusCode != 200) throw Exception("無法讀取繳交紀錄");
      return {"info": jsonDecode(infoRes.body), "submissions": jsonDecode(subRes.body)};
    } finally { client.close(); }
  }

  Future<Map<String, dynamic>> fetchHomeworkDetails(int homeworkId) async {
    await _ensureAuthenticated();
    final client = http.Client();
    try {
      final res = await _get("$_baseUrl/api/activities/$homeworkId", client);
      if (res.statusCode != 200) throw Exception("無法讀取作業資料");
      return jsonDecode(res.body);
    } finally { client.close(); }
  }

  Future<File> downloadFile(int referenceId, String fileName) async {
    await _ensureAuthenticated();
    final client = http.Client();
    try {
      final url = "$_baseUrl/api/uploads/reference/$referenceId/blob";
      final response = await client.get(Uri.parse(url), headers: {..._baseHeaders, "Cookie": _generateCookieHeader()});
      if (response.statusCode == 200) {
        final dir = await getTemporaryDirectory();
        final safeName = fileName.replaceAll(RegExp(r'[^\w\s\.]'), '_');
        final file = File('${dir.path}/$safeName');
        await file.writeAsBytes(response.bodyBytes);
        return file;
      } else { throw Exception("下載失敗: ${response.statusCode}"); }
    } finally { client.close(); }
  }

  // ... (內部 Login 邏輯保持不變) ...
  Future<void> _ensureAuthenticated() async {
    final prefs = await SharedPreferences.getInstance();
    final username = (prefs.getString('username') ?? "").trim();
    final password = (prefs.getString('password') ?? "").trim();
    if (username.isEmpty || password.isEmpty) throw Exception("尚未設定帳號密碼");

    bool needsLogin = _cookieJar.isEmpty || _lastLoginTime == null;
    if (!needsLogin) {
      if (DateTime.now().difference(_lastLoginTime!).inMinutes >= 10) {
        print("⏳ Cookie 已過期 (>10min)，正在自動重新登入...");
        needsLogin = true;
      }
    }
    if (needsLogin) {
      _cookieJar.clear();
      await _login(username, password);
      _lastLoginTime = DateTime.now();
      print("✅ E-learn 登入成功");
    }
  }

  Future<void> _login(String username, String password) async {
    final client = http.Client();
    try {
      final startUrl = Uri.parse("$_baseUrl/login?next=/user/index");
      final res1 = await client.get(startUrl, headers: _baseHeaders);
      _updateCookies(res1);

      var document = parser.parse(res1.body);
      var form = document.querySelector("form[action*='login-actions']");
      if (form == null && res1.body.contains("登出")) return; 
      if (form == null) throw Exception("找不到登入表單");

      String authUrl = form.attributes['action']!;
      if (authUrl.startsWith('/')) authUrl = "https://identity.nsysu.edu.tw$authUrl";

      final request = http.Request('POST', Uri.parse(authUrl))
        ..followRedirects = false
        ..headers.addAll(_baseHeaders)
        ..headers['Content-Type'] = 'application/x-www-form-urlencoded'
        ..headers['Cookie'] = _generateCookieHeader()
        ..bodyFields = {"username": username, "password": password};

      final streamedRes = await client.send(request);
      final res2 = await http.Response.fromStream(streamedRes);
      _updateCookies(res2);
      await _followRedirectChain(res2, client);
    } catch (e) {
      print("Login Error: $e");
      rethrow;
    } finally { client.close(); }
  }

  Future<void> _followRedirectChain(http.Response response, http.Client client) async {
    http.Response currentRes = response;
    int limit = 10;
    while (limit > 0 && (currentRes.statusCode == 302 || currentRes.statusCode == 301)) {
      String? location = currentRes.headers['location'];
      if (location == null) break;
      if (location.startsWith('/')) {
         if (currentRes.request!.url.host.contains("identity")) {
             if (!location.startsWith("http")) location = "$_baseUrl$location";
         } else {
             location = "$_baseUrl$location";
         }
      }
      final nextReq = http.Request('GET', Uri.parse(location))
        ..followRedirects = false
        ..headers.addAll(_baseHeaders)
        ..headers['Cookie'] = _generateCookieHeader();

      final streamedRes = await client.send(nextReq);
      currentRes = await http.Response.fromStream(streamedRes);
      _updateCookies(currentRes);
      limit--;
    }
  }

  Future<List<ElearnTask>> _getCourseData(String semesterCode) async {
    List<ElearnTask> allTasks = [];
    final client = http.Client();
    try {
      var courseRes = await _post(
        "$_baseUrl/api/my-courses", client,
        body: jsonEncode({
          "fields": "id,name,semester",
          "page_size": 100,
          "conditions": {"status": ["ongoing", "notStarted", "closed"]}
        }),
        isJson: true
      );
      if (courseRes.statusCode != 200) throw Exception("API Error: ${courseRes.statusCode}");
      var courseData = jsonDecode(courseRes.body)["courses"] as List;
      var targetCourses = courseData.where((c) => c["semester"]?["code"] == semesterCode).toList();

      for (var course in targetCourses) {
        String courseId = course["id"].toString();
        String courseName = course["name"];
        // HW
        var hwRes = await _get("$_baseUrl/api/courses/$courseId/homework-activities?page_size=100", client);
        if (hwRes.statusCode == 200) {
          var hws = jsonDecode(hwRes.body)["homework_activities"] as List;
          for (var hw in hws) {
            bool submitted = hw["submitted"] ?? false;
            allTasks.add(ElearnTask(
              id: hw["id"],
              courseName: courseName,
              title: hw["title"],
              type: "作業",
              isSubmitted: submitted,
              endTime: _parseTime(hw["end_time"]),
              statusRaw: submitted ? "已繳交" : "未繳交",
            ));
          }
        }
        // Exam
        var exRes = await _get("$_baseUrl/api/courses/$courseId/exam-list?page_size=100", client);
        if (exRes.statusCode == 200) {
          var exJson = jsonDecode(exRes.body);
          var exams = (exJson["exams"] ?? exJson["exam_activities"] ?? []) as List;
          for (var ex in exams) {
             int submitCount = ex["submission_count"] ?? 0;
             bool submitted = submitCount > 0;
             var rawScore = ex["final_score"] ?? ex["score"];
             double? currentScore = rawScore != null ? double.tryParse(rawScore.toString()) : null;
             allTasks.add(ElearnTask(
              id: ex["id"],
              courseName: courseName,
              title: ex["title"] ?? ex["name"],
              type: "測驗",
              isSubmitted: submitted,
              endTime: _parseTime(ex["end_time"]),
              statusRaw: submitted ? "已測驗" : "未測驗",
              score: currentScore, // 存入分數
            ));
          }
        }
      }
    } finally { client.close(); }
    return allTasks;
  }

  // --- Helpers ---
  Future<http.Response> _get(String url, http.Client client) async {
    final response = await client.get(Uri.parse(url), headers: {..._baseHeaders, "Cookie": _generateCookieHeader()});
    _updateCookies(response);
    return response;
  }
  Future<http.Response> _post(String url, http.Client client, {Object? body, bool isJson = false}) async {
    final response = await client.post(Uri.parse(url), headers: {..._baseHeaders, "Cookie": _generateCookieHeader(), if (isJson) "Content-Type": "application/json"}, body: body);
    _updateCookies(response);
    return response;
  }
  void _updateCookies(http.Response response) {
    String? setCookieRaw = response.headers['set-cookie'];
    if (setCookieRaw == null) return;
    var cookies = _splitSetCookie(setCookieRaw);
    final ignoreKeys = {'path', 'expires', 'domain', 'max-age', 'secure', 'httponly', 'samesite', 'priority'};
    for (var c in cookies) {
      int idx = c.indexOf('=');
      if (idx == -1) continue;
      String key = c.substring(0, idx).trim();
      String value = c.substring(idx + 1).trim();
      if (value.contains(';')) value = value.substring(0, value.indexOf(';'));
      if (!ignoreKeys.contains(key.toLowerCase())) _cookieJar[key] = value;
    }
  }
  List<String> _splitSetCookie(String setCookie) {
    List<String> cookies = [];
    RegExp splitter = RegExp(r',(?=\s*[a-zA-Z0-9_-]+=)');
    int start = 0;
    for (Match m in splitter.allMatches(setCookie)) {
      cookies.add(setCookie.substring(start, m.start).trim());
      start = m.end;
    }
    cookies.add(setCookie.substring(start).trim());
    return cookies;
  }
  String _generateCookieHeader() => _cookieJar.entries.map((e) => "${e.key}=${e.value}").join("; ");
  DateTime? _parseTime(String? timeStr) {
    if (timeStr == null) return null;
    try { return DateTime.parse(timeStr).toLocal(); } catch (e) { return null; }
  }
}