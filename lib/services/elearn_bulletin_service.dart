import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:html/parser.dart' as parser;
import 'package:html/dom.dart' as dom;
import 'package:path_provider/path_provider.dart';

// --- 資料模型 ---

class BulletinAttachment {
  final int id;
  final int referenceId;
  final String name;
  final int size;

  BulletinAttachment({
    required this.id,
    required this.referenceId,
    required this.name,
    required this.size,
  });

  factory BulletinAttachment.fromJson(Map<String, dynamic> json) {
    return BulletinAttachment(
      id: json['id'] ?? 0,
      referenceId: json['reference_id'] ?? 0,
      name: json['name'] ?? "未知檔案",
      size: json['size'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'reference_id': referenceId,
        'name': name,
        'size': size,
      };
}

class ElearnBulletin {
  final int id;
  final int courseId;
  final String courseName;
  final String title;
  final String contentRaw;
  final DateTime? createdAt;
  final DateTime? updatedAt; // 新增欄位
  final List<BulletinAttachment> uploads;

  ElearnBulletin({
    required this.id,
    required this.courseId,
    this.courseName = "",
    required this.title,
    required this.contentRaw,
    this.createdAt,
    this.updatedAt, // 新增
    required this.uploads,
  });

  // 取得優先顯示的時間：如果有 update 就用 update，否則用 create
  DateTime get effectiveTime => updatedAt ?? createdAt ?? DateTime.now();

  // 修改 ElearnBulletin 的 fromJson
  factory ElearnBulletin.fromJson(Map<String, dynamic> json, {String courseName = ""}) {
    List<BulletinAttachment> atts = [];
    if (json['uploads'] != null) {
      atts = (json['uploads'] as List).map((e) => BulletinAttachment.fromJson(e)).toList();
    }

    return ElearnBulletin(
      id: json['id'] ?? 0,
      courseId: json['course_id'] ?? 0,
      // [修正重點]：如果傳入的 courseName 是空的，就嘗試從 JSON (快取) 中讀取
      courseName: (courseName.isNotEmpty) ? courseName : (json['courseName'] ?? ""), 
      title: json['title'] ?? "無標題",
      contentRaw: json['content'] ?? "",
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']).toLocal() : null,
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']).toLocal() : null,
      uploads: atts,
    );
  }
  Map<String, dynamic> toJson() => {
        'id': id,
        'course_id': courseId,
        'courseName': courseName,
        'title': title,
        'content': contentRaw,
        'created_at': createdAt?.toIso8601String(),
        'updated_at': updatedAt?.toIso8601String(), // 新增
        'uploads': uploads.map((e) => e.toJson()).toList(),
      };
}

// --- Service ---

class ElearnBulletinService {
  static final ElearnBulletinService instance = ElearnBulletinService._init();
  ElearnBulletinService._init();

  final String _baseUrl = "https://elearn.nsysu.edu.tw";
  final Map<String, String> _baseHeaders = {
    "User-Agent":
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
    "Accept": "application/json, text/plain, */*",
    "Connection": "keep-alive",
  };

  Map<String, String> _cookieJar = {};
  DateTime? _lastLoginTime;
  DateTime? _lastFetchTime; // 上次抓取時間

  static const String _cachedBulletinsKey = "cached_elearn_bulletins";
  static const String _cachedFetchTimeKey = "last_elearn_bulletin_fetch_time";

  // --- 公用方法 ---

  /// 取得公告列表
  /// [forceRefresh] 強制刷新
  /// [pageSize] 設定抓取筆數 (預設30, 最大100)
  Future<List<ElearnBulletin>> fetchBulletins({bool forceRefresh = false, int pageSize = 30}) async {
    // 1. 檢查快取時間 (3分鐘內不自動重抓)
    if (!forceRefresh && await _isCacheValid()) {
      print("🚀 使用公告快取資料");
      return await loadCachedBulletins();
    }

    await _ensureAuthenticated();

    // 2. 先取得課程列表 (為了拿到 Course ID 對應 Course Name)
    Map<int, String> courseMap = await _getCourseNameMap();

    // 3. 抓取公告
    List<ElearnBulletin> bulletins = await _getBulletinData(pageSize, courseMap);

    // 4. 更新快取
    await cacheBulletins(bulletins);

    return bulletins;
  }

  /// 下載檔案
  Future<File> downloadFile(int referenceId, String fileName) async {
    await _ensureAuthenticated();
    final client = http.Client();
    try {
      final url = "$_baseUrl/api/uploads/reference/$referenceId/blob";
      final response = await client.get(Uri.parse(url),
          headers: {..._baseHeaders, "Cookie": _generateCookieHeader()});

      if (response.statusCode == 200) {
        final dir = await getTemporaryDirectory();
        // 處理檔名非法字元
        final safeName = fileName.replaceAll(RegExp(r'[^\w\s\.\-\(\)]'), '_');
        final file = File('${dir.path}/$safeName');
        await file.writeAsBytes(response.bodyBytes);
        return file;
      } else {
        throw Exception("下載失敗: ${response.statusCode}");
      }
    } finally {
      client.close();
    }
  }

  /// 清除快取 (登出用)
  Future<void> clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cachedBulletinsKey);
    await prefs.remove(_cachedFetchTimeKey);
    _cookieJar.clear();
    _lastLoginTime = null;
    _lastFetchTime = null;
    print("🧹 ElearnBulletinService 快取已清除");
  }

  // --- 內部邏輯 & 爬蟲 ---

  Future<bool> _isCacheValid() async {
    if (_lastFetchTime != null) {
      return DateTime.now().difference(_lastFetchTime!).inMinutes < 3;
    }
    final prefs = await SharedPreferences.getInstance();
    if (!prefs.containsKey(_cachedFetchTimeKey)) return false;
    
    final timeStr = prefs.getString(_cachedFetchTimeKey);
    if (timeStr == null) return false;
    
    final lastTime = DateTime.parse(timeStr);
    _lastFetchTime = lastTime;
    return DateTime.now().difference(lastTime).inMinutes < 3;
  }

  Future<List<ElearnBulletin>> loadCachedBulletins() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.containsKey(_cachedBulletinsKey)) {
      final String jsonStr = prefs.getString(_cachedBulletinsKey)!;
      final List<dynamic> jsonList = jsonDecode(jsonStr);
      return jsonList.map((e) => ElearnBulletin.fromJson(e)).toList();
    }
    return [];
  }

  Future<void> cacheBulletins(List<ElearnBulletin> list) async {
    final prefs = await SharedPreferences.getInstance();
    final String jsonStr = jsonEncode(list.map((e) => e.toJson()).toList());
    
    final now = DateTime.now();
    await prefs.setString(_cachedBulletinsKey, jsonStr);
    await prefs.setString(_cachedFetchTimeKey, now.toIso8601String());
    _lastFetchTime = now;
  }

  // 取得課程 ID -> 名稱 對照表
  Future<Map<int, String>> _getCourseNameMap() async {
    final client = http.Client();
    Map<int, String> map = {};
    try {
      var courseRes = await _post(
          "$_baseUrl/api/my-courses", client,
          body: jsonEncode({
            "fields": "id,name,semester",
            "page_size": 100, // 抓多一點確保都有
            "conditions": {"status": ["ongoing", "notStarted", "closed"]}
          }),
          isJson: true);

      if (courseRes.statusCode == 200) {
        var courseData = jsonDecode(courseRes.body)["courses"] as List;
        for (var c in courseData) {
          int id = c["id"];
          String name = c["name"];
          map[id] = name;
        }
      }
    } catch (e) {
      print("⚠️ 取得課程名稱失敗: $e");
    } finally {
      client.close();
    }
    return map;
  }

  // 實際抓取公告 API
  Future<List<ElearnBulletin>> _getBulletinData(int pageSize, Map<int, String> courseMap) async {
    final client = http.Client();
    List<ElearnBulletin> results = [];
    try {
      // 建構參數
      Map<String, dynamic> conditions = {
        "keyword": "",
        "start_date": "",
        "end_date": "",
        "course_ids": []
      };
      
      String params = Uri(queryParameters: {
        "conditions": jsonEncode(conditions),
        "page": "1",
        "page_size": pageSize.toString(),
      }).query;

      final res = await _get("$_baseUrl/api/course-bulletins?$params", client);
      
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final List bulletins = data['bulletins'] ?? [];

        for (var b in bulletins) {
          int cId = b['course_id'] ?? 0;
          String cName = courseMap[cId] ?? "未知課程 ($cId)";
          results.add(ElearnBulletin.fromJson(b, courseName: cName));
        }
      } else {
        throw Exception("API Error: ${res.statusCode}");
      }
    } finally {
      client.close();
    }
    return results;
  }

  // --- 認證與網路請求 (與 Task Service 共用邏輯) ---
  
  Future<void> _ensureAuthenticated() async {
    final prefs = await SharedPreferences.getInstance();
    final username = (prefs.getString('username') ?? "").trim();
    final password = (prefs.getString('password') ?? "").trim();
    if (username.isEmpty || password.isEmpty) throw Exception("尚未設定帳號密碼");

    bool needsLogin = _cookieJar.isEmpty || _lastLoginTime == null;
    if (!needsLogin) {
      if (DateTime.now().difference(_lastLoginTime!).inMinutes >= 10) {
        needsLogin = true;
      }
    }
    if (needsLogin) {
      _cookieJar.clear();
      await _login(username, password);
      _lastLoginTime = DateTime.now();
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
    } finally {
      client.close();
    }
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

  Future<http.Response> _get(String url, http.Client client) async {
    final response = await client.get(Uri.parse(url), headers: {..._baseHeaders, "Cookie": _generateCookieHeader()});
    _updateCookies(response);
    return response;
  }

  Future<http.Response> _post(String url, http.Client client, {Object? body, bool isJson = false}) async {
    final response = await client.post(Uri.parse(url), 
      headers: {
        ..._baseHeaders, 
        "Cookie": _generateCookieHeader(), 
        if (isJson) "Content-Type": "application/json"
      }, body: body);
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
}