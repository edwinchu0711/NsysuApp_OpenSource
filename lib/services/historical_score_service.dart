import 'dart:convert';
import 'dart:io'; // 用於 HttpClient
import 'package:http/io_client.dart'; // 用於將 HttpClient 包裝成 http.Client
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as parser;
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/utils.dart';
import 'package:html/dom.dart' as dom; // ★ 1. 加上別名避免跟 Flutter 衝突

// --- 資料模型 ---
class CourseScore {
  final String id;
  final String name;
  final String credits;
  final String score;
  CourseScore({required this.id, required this.name, required this.credits, required this.score});
}

class ScoreSummary {
  String creditsTaken;
  String creditsEarned;
  String average;
  String rank;
  String classSize;
  ScoreSummary({
    this.creditsTaken = "-",
    this.creditsEarned = "-",
    this.average = "-",
    this.rank = "-",
    this.classSize = "-",
  });
  bool get isEmpty => average == "-" && rank == "-";
}

// --- Service 主體 ---
class HistoricalScoreService {
  static final HistoricalScoreService instance = HistoricalScoreService._internal();
  HistoricalScoreService._internal() {
    loadFromCache();
  }

  final http.Client _client = http.Client();
  static const String CACHE_KEY = "historical_scores_data_v1";

  // 狀態監聽器
  final ValueNotifier<Map<String, List<CourseScore>>> coursesNotifier = ValueNotifier({});
  final ValueNotifier<Map<String, ScoreSummary>> summaryNotifier = ValueNotifier({});
  // ★★★ 新增：存放預覽名次的 Notifier (Key: year-sem, Value: {rank, classSize})
  final ValueNotifier<Map<String, Map<String, String>>> previewRanksNotifier = ValueNotifier({});
  
  final ValueNotifier<bool> isLoadingNotifier = ValueNotifier(false);
  final ValueNotifier<String> statusMessageNotifier = ValueNotifier("");
  final ValueNotifier<double> progressNotifier = ValueNotifier(0.0);
  final ValueNotifier<Set<String>> validYearsNotifier = ValueNotifier({});
  final ValueNotifier<Map<String, List<String>>> validSemestersNotifier = ValueNotifier({});

  /// [清除快取]
  Future<void> clearCache() async {
      coursesNotifier.value = {};
      summaryNotifier.value = {};
      previewRanksNotifier.value = {}; // 清除預覽資料
      validYearsNotifier.value = {};
      validSemestersNotifier.value = {};
      statusMessageNotifier.value = "";
      progressNotifier.value = 0.0;
      
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(CACHE_KEY);
        print("🗑️ HistoricalScoreService: 歷年成績快取已完全清除");
      } catch (e) {
        print("❌ HistoricalScoreService 清除失敗: $e");
      }
    }

  /// 從本地 SharedPreferences 載入快取
  Future<void> loadFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? jsonStr = prefs.getString(CACHE_KEY);
      if (jsonStr != null) {
        Map<String, dynamic> decoded = json.decode(jsonStr);
        _processAndNotify(decoded);
      }
    } catch (e) {
      print("讀取快取失敗: $e");
    }
  }

  /// 將目前的資料存入快取
  Future<void> _saveToCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      Map<String, dynamic> dataToSave = {};
      
      coursesNotifier.value.forEach((key, list) {
        dataToSave[key] = {
          'courses': list.map((c) => {
            'id': c.id, 
            'name': c.name, 
            'credits': c.credits, 
            'score': c.score
          }).toList(),
          'summary': {
            'creditsTaken': summaryNotifier.value[key]?.creditsTaken,
            'creditsEarned': summaryNotifier.value[key]?.creditsEarned,
            'average': summaryNotifier.value[key]?.average,
            'rank': summaryNotifier.value[key]?.rank,
            'classSize': summaryNotifier.value[key]?.classSize,
          },
          // 儲存預覽資料
          'previewRank': previewRanksNotifier.value[key]
        };
      });
      await prefs.setString(CACHE_KEY, json.encode(dataToSave));
    } catch (e) {
      print("儲存快取失敗: $e");
    }
  }

  /// [主要進入點]
  Future<void> fetchAllData({bool forceFullRefresh = false}) async {
    if (isLoadingNotifier.value) return;

    isLoadingNotifier.value = true;
    progressNotifier.value = 0.0;
    statusMessageNotifier.value = "檢查帳號資訊...";

    try {
      final prefs = await SharedPreferences.getInstance();
      String? username = prefs.getString('username')?.trim();
      String? password = prefs.getString('password')?.trim();
      
      // 1. 讀取使用者設定
      bool isPreviewSettingOn = prefs.getBool('is_preview_rank_enabled') ?? false;

      if (username == null || password == null || username.isEmpty) {
        statusMessageNotifier.value = "找不到帳號密碼";
        return;
      }

      // ===== 2. 判斷日期區間 =====
      DateTime now = DateTime.now();
      int m = now.month;
      int d = now.day;


      // 區間一：3/20 ~ 6/5
      bool isSpringRange = (m == 3 && d >= 20) || (m == 4) || (m == 5) || (m == 6 && d <= 5);
      
      // 區間二：10/15 ~ 1/5 (跨年由 12月 和 1月 組成)
      bool isFallRange = (m == 10 && d >= 15) || (m == 11) || (m == 12) || (m == 1 && d <= 5);

      // 最終決定是否執行預覽抓取 (設定開啟 + 時間符合)
      bool shouldFetchPreview = isPreviewSettingOn && !(isSpringRange || isFallRange);
      print("今天是${m}月${d}日");

      // ===== 3. 準備學期任務 =====
      int x = now.year - 1911;
      List<MapEntry<String, String>> tasks = [];

      if (coursesNotifier.value.isEmpty || forceFullRefresh) {
        statusMessageNotifier.value = "首次同步，抓取五年份資料...";
        for (int i = 0; i < 5; i++) {
          String year = (x - i).toString();
          tasks.add(MapEntry(year, "1"));
          tasks.add(MapEntry(year, "2"));
          tasks.add(MapEntry(year, "3"));
        }
      } else {
        if (m >= 1 && m <= 6) {
          String targetYear = (x - 1).toString();
          tasks.add(MapEntry(targetYear, "1"));
          tasks.add(MapEntry(targetYear, "2"));
          tasks.add(MapEntry(targetYear, "3"));
        } else {
          tasks.add(MapEntry((x - 1).toString(), "2"));
          tasks.add(MapEntry((x - 1).toString(), "3"));
          tasks.add(MapEntry(x.toString(), "1"));
        }
      }

      // ===== 4. 登入成績系統 =====
      statusMessageNotifier.value = "正在登入系統...";
      String? sessionCookie = await _loginToScoreSystem(username, password);
      if (sessionCookie == null) {
        statusMessageNotifier.value = "登入失敗";
        return;
      }

      Map<String, List<CourseScore>> newCourses = Map.from(coursesNotifier.value);
      Map<String, ScoreSummary> newSummary = Map.from(summaryNotifier.value);

      // 計算總工作量 (依據是否抓取預覽來調整分母)
      int scoreTaskCount = tasks.length;
      int previewTaskCount = shouldFetchPreview ? 8 : 0; // 如果時間不對，這裡就是 0
      int totalWork = scoreTaskCount + previewTaskCount;

      int completed = 0;

      // ===== 5. 抓取學期成績 =====
      for (var task in tasks) {
        String year = task.key;
        String sem = task.value;
        statusMessageNotifier.value = "同步中: $year-$sem";

        final result = await _fetchSingleSemester(sessionCookie, year, sem);

        if (result != null && result.courses.isNotEmpty) {
          String key = "$year-$sem";
          newCourses[key] = result.courses;
          newSummary[key] = result.summary;
        }

        completed++;
        progressNotifier.value = totalWork > 0 ? (completed / totalWork) : 0.0;
        await Future.delayed(const Duration(milliseconds: 120));
      }

      _processAndNotifyFromMaps(
        newCourses,
        newSummary,
        previewRanksNotifier.value,
      );

      // ===== 6. 抓取預覽名次 (依據條件執行) =====
      if (shouldFetchPreview) {
        statusMessageNotifier.value = "正在抓取預覽名次...";

        Map<String, Map<String, String>> fetched = await _fetchPreviewRanks(
          username,
          password,
          (done, total) {
            statusMessageNotifier.value = "預覽名次抓取中 ($done / $total)";
            progressNotifier.value = (completed + done) / totalWork;
          },
        );

        Map<String, Map<String, String>> newPreview = Map.from(previewRanksNotifier.value);
        newPreview.addAll(fetched);

        _processAndNotifyFromMaps(
          newCourses,
          newSummary,
          newPreview,
        );
      } else if (isPreviewSettingOn && !shouldFetchPreview) {
        // (可選) 如果使用者開了設定，但因為時間不對而被略過，可以在這稍微停頓或Log
        // 但為了體驗流暢，通常直接結束即可
        print("DEBUG: 預覽名次功能已開啟，但目前不在開放時段，故略過。");
      }

      progressNotifier.value = 1.0;
      await _saveToCache();
      statusMessageNotifier.value = "同步完成";
    } catch (e) {
      statusMessageNotifier.value = "同步發生異常";
      print("Historical Fetch Error: $e");
    } finally {
      isLoadingNotifier.value = false;
    }
  }
// --- 修正後的預覽名次抓取邏輯 (加強錯誤防護版) ---
  Future<Map<String, Map<String, String>>> _fetchPreviewRanks(
    String username,
    String password,
    void Function(int done, int total)? onProgress,
  ) async {
    print("--- [DEBUG] 開始執行 _fetchPreviewRanks ---");

    Map<String, Map<String, String>> results = {};

    final ioClient = HttpClient()
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;
    final client = IOClient(ioClient);

    Map<String, String> cookieJar = {};

    try {
      await _sendRequest(
        client,
        'GET',
        "https://epp.nsysu.edu.tw/Index.php?ccsForm=Login",
        cookieJar,
      );

      final loginReq = http.Request(
        'POST',
        Uri.parse("https://epp.nsysu.edu.tw/Index.php?ccsForm=Login"),
      )
        ..followRedirects = false
        ..headers.addAll({
          "User-Agent":
              "Mozilla/5.0 (Windows NT 10.0; Win64; x64)",
          "Content-Type": "application/x-www-form-urlencoded",
          "Cookie": _generateCookieHeader(cookieJar),
        })
        ..bodyFields = {
          "login_name": username,
          "login_password": password,
          "login_identity": "3",
          "Button_DoLogin": "登入",
        };

      final loginRes =
          await http.Response.fromStream(await client.send(loginReq));
      _updateCookieJar(loginRes, cookieJar);

      final gridRes = await _sendRequest(
        client,
        'GET',
        "https://epp.nsysu.edu.tw/Apps/CRSGrid.php?course=pro",
        cookieJar,
      );

      var doc = parser.parse(
        utf8.decode(gridRes.bodyBytes, allowMalformed: true),
      );

      List<String> urls = doc
          .querySelectorAll('a span[style]')
          .where((e) =>
              e.attributes['style']!
                  .replaceAll(' ', '')
                  .toUpperCase()
                  .contains("COLOR:#009933"))
          .map((e) =>
              "https://epp.nsysu.edu.tw/Apps/${e.parent!.attributes['href']}")
          .toList();

      if (urls.length > 8) {
        urls = urls.sublist(urls.length - 8);
      }

      int total = urls.length;
      int done = 0;

      RegExp commentRegExp =
          RegExp(r'<!--([\s\S]*?)-->', dotAll: true);

      for (String url in urls) {
        try {
          final res =
              await _sendRequest(client, 'GET', url, cookieJar);
          String html =
              utf8.decode(res.bodyBytes, allowMalformed: true);

          for (var m in commentRegExp.allMatches(html)) {
            String block = m.group(1)!;
            if (!block.contains('class="Row"')) continue;

            var tr = parser
                .parseFragment(block)
                .querySelector('tr.Row');
            if (tr == null) continue;

            var tds = tr.querySelectorAll('td');
            if (tds.length < 9) continue;

            String? key =
                _safeParseSemester(tds[0].text.trim());
            if (key == null) continue;
            print("抓到了");

            results[key] = {
              "rank": tds[7].text.trim(),
              "classSize": tds[8].text.trim(),
            };
          }
        } catch (_) {}

        done++;
        onProgress?.call(done, total);
      }
    } finally {
      client.close();
    }

    return results;
  }

  // --- 輔助：安全的學期解析函式 ---
  String? _safeParseSemester(String raw) {
    try {
      // 1. 強力清理：移除 &nbsp;, \u00A0 (non-breaking space), 以及所有空白
      // RegExp(r'[\s\u00A0]+') 可以匹配標準空白、Tab、換行以及 &nbsp; 產生的字元
      String text = raw.replaceAll(RegExp(r'[\s\u00A0]+'), '')
                      .replaceAll('&nbsp;', ''); // 防呆：如果 raw 是原始 HTML 碼

      // text 現在應該是："一百一十二學年度第一學期"

      if (!text.contains("學年度")) return null;
      
      // 2. 切割
      List<String> parts = text.split('學年度');
      String yearStr = parts[0]; // "一百一十二"
      String semStr = parts.length > 1 ? parts[1] : ""; // "第一學期"
      
      // 3. 轉換年份 (支援 "112", "一一二", "一百一十二")
      int year = _chineseToNumber(yearStr);
      
      // 4. 轉換學期
      String semCode = "1";
      if (semStr.contains("二") || semStr.contains("下")) {
        semCode = "2";
      } else if (semStr.contains("暑")) {
        semCode = "3";
      }
      
      // 5. 輸出標準格式
      return "$year-$semCode"; // 回傳 "112-1"
      
    } catch (e) {
      print("⚠️ 解析學期字串錯誤: $raw ($e)");
      return null;
    }
  }
  // --- 通用請求 ---
  Future<http.Response> _sendRequest(http.Client client, String method, String url, Map<String, String> cookieJar) async {
      final req = http.Request(method, Uri.parse(url));
      req.followRedirects = false;
      req.headers.addAll({
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
        "Cookie": _generateCookieHeader(cookieJar),
      });

      final streamedRes = await client.send(req);
      final res = await http.Response.fromStream(streamedRes);
      _updateCookieJar(res, cookieJar);
      return res;
  }

  String _generateCookieHeader(Map<String, String> cookies) {
    return cookies.entries.map((e) => "${e.key}=${e.value}").join("; ");
  }

  // --- 修正後的 Cookie 更新 (更強健) ---
  void _updateCookieJar(http.Response response, Map<String, String> cookieJar) {
    String? setCookie = response.headers['set-cookie'];
    if (setCookie != null) {
      // 移除日期中的逗號 (如: Thu, 01-Jan...) 以免干擾分割，
      // 但為了安全，我們改用正則直接抓取 key=value 結構，忽略 expires 等屬性
      
      // 策略：尋找 "Name=Value;" 或 "Name=Value" 結構
      // 排除常見的屬性關鍵字
      RegExp reg = RegExp(r'([a-zA-Z0-9_-]+)=([^;,\s]+)');
      Iterable<Match> matches = reg.allMatches(setCookie);
      
      List<String> ignoreKeys = ['expires', 'path', 'domain', 'secure', 'httponly', 'samesite', 'max-age'];
      
      for (var m in matches) {
        String key = m.group(1)!;
        String value = m.group(2)!;
        
        if (ignoreKeys.contains(key.toLowerCase())) continue;
        
        if (value == 'deleted') {
           cookieJar.remove(key);
        } else {
           cookieJar[key] = value;
        }
      }
    }
  }
  // 輔助：將 "112學年度第二學期" 轉為 "112-2"
  String? _parseChineseSemester(String text) {
     text = text.replaceAll(RegExp(r'\s+'), ''); // 去空白
     if (!text.contains('學年度')) return null;
     
     try {
       var parts = text.split('學年度');
       String yearStr = parts[0]; // "112" 或 "一一二"
       String semStr = parts[1];  // "第二學期"
       
       // 簡單轉換中文數字
       int year = _chineseToNumber(yearStr);
       
       String sem = "1";
       if (semStr.contains("第二")) sem = "2";
       else if (semStr.contains("暑")) sem = "3";
       
       return "$year-$sem";
     } catch (e) {
       return null;
     }
  }

  int _chineseToNumber(String input) {
    // 如果原本就是阿拉伯數字 (e.g., "112")，直接回傳
    if (int.tryParse(input) != null) return int.parse(input);

    const nums = {'○': 0, '〇': 0, '零': 0, '一': 1, '二': 2, '三': 3, '四': 4, '五': 5, '六': 6, '七': 7, '八': 8, '九': 9};
    const units = {'十': 10, '百': 100, '千': 1000};

    // 判斷是否包含單位 (十、百)，如果沒有單位，通常是 "一一二" 這種直讀法
    bool isPositional = !input.split('').any((c) => units.containsKey(c));

    // --- 情況 A: 直讀法 (e.g., "一一二") ---
    if (isPositional) {
      String temp = "";
      for (var char in input.split('')) {
        if (nums.containsKey(char)) {
          temp += nums[char].toString();
        }
      }
      return int.tryParse(temp) ?? 0;
    }

    // --- 情況 B: 傳統讀法 (e.g., "一百一十二" 或 "十二") ---
    int total = 0;
    int current = 0; // 暫存目前的數字 (例如 "五"百 的 5)

    for (int i = 0; i < input.length; i++) {
      String char = input[i];

      if (nums.containsKey(char)) {
        current = nums[char]!;
      } else if (units.containsKey(char)) {
        int unitVal = units[char]!;
        
        // 特殊處理：如果是 "十二"，前面沒有數字，current 預設為 1 (代表一十)
        if (current == 0 && unitVal == 10 && i == 0) {
          current = 1; 
        }
        
        total += current * unitVal;
        current = 0; // 乘完歸零，準備讀下一個數字
      }
    }
    // 最後把剩下的數字加上去 (例如 "一百一十二" 的 "二")
    total += current;

    return total;
  }

  // (原有) 抓取單一學期
  Future<({List<CourseScore> courses, ScoreSummary summary})?> _fetchSingleSemester(String cookies, String year, String sem) async {
    try {
      final queryUrl = Uri.parse("https://selcrs.nsysu.edu.tw/scoreqry/sco_query.asp?ACTION=804&KIND=2&LANGS=cht");
      final response = await _client.post(
        queryUrl,
        headers: {
          "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
          "Content-Type": "application/x-www-form-urlencoded",
          "Cookie": cookies,
          "Referer": "https://selcrs.nsysu.edu.tw/scoreqry/sco_query.asp",
        },
        body: {"SYEAR": year, "SEM": sem},
      ).timeout(Duration(seconds: 15));

      if (response.statusCode != 200) return null;
      String content = utf8.decode(response.bodyBytes, allowMalformed: true);
      if (content.contains("請重新登入")) return null;
      var parsed = _parseHtml(content);
      return parsed.courses.isEmpty ? null : parsed;
    } catch (e) {
      return null;
    }
  }

  // (原有) 登入
  Future<String?> _loginToScoreSystem(String username, String password) async {
    final loginUrl = Uri.parse("https://selcrs.nsysu.edu.tw/scoreqry/sco_query_prs_sso2.asp");
    final String base64md5Password = Utils.base64md5(password);

    try {
      final response = await _client.post(
        loginUrl,
        headers: {
          "Content-Type": "application/x-www-form-urlencoded",
          "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
        },
        body: {
          'SID': username.toUpperCase(),
          'PASSWD': base64md5Password,
          'ACTION': '0',
          'INTYPE': '1',
        },
      );
      String? rawCookie = response.headers['set-cookie'];
      if (rawCookie != null && !response.body.contains("不符") && !response.body.contains("錯誤")) {
        return rawCookie;
      }
    } catch (e) {
      print("Login Error: $e");
    }
    return null;
  }

  void _processAndNotify(Map<String, dynamic> rawJson) {
    Map<String, List<CourseScore>> cMap = {};
    Map<String, ScoreSummary> sMap = {};
    Map<String, Map<String, String>> pMap = {};

    rawJson.forEach((key, value) {
      var cList = (value['courses'] as List).map((i) => CourseScore(
        id: i['id'], name: i['name'], credits: i['credits'], score: i['score']
      )).toList();
      
      var summ = value['summary'];
      var sObj = ScoreSummary(
        creditsTaken: summ['creditsTaken'] ?? "-",
        creditsEarned: summ['creditsEarned'] ?? "-",
        average: summ['average'] ?? "-",
        rank: summ['rank'] ?? "-",
        classSize: summ['classSize'] ?? "-",
      );

      cMap[key] = cList;
      sMap[key] = sObj;
      
      // 載入預覽資料
      if (value['previewRank'] != null) {
        pMap[key] = Map<String, String>.from(value['previewRank']);
      }
      print(pMap);
    });

    _processAndNotifyFromMaps(cMap, sMap, pMap);
  }

void _processAndNotifyFromMaps(
  Map<String, List<CourseScore>> cMap,
  Map<String, ScoreSummary> sMap,
  Map<String, Map<String, String>> pMap,
) {
  print("\n====== 🟢 開始執行 _processAndNotifyFromMaps ======");
  
  // 1. 先印出三張表所有的 Keys，確認格式是否一致 (例如 "112-1" vs "112-01")
  print("🔍 [cMap Keys] (課程): ${cMap.keys.toList()}");
  print("🔍 [sMap Keys] (摘要): ${sMap.keys.toList()}");
  print("🔍 [pMap Keys] (預覽): ${pMap.keys.toList()}");

  // 顯示 pMap 的詳細內容，確認是否有抓到東西
  if (pMap.isNotEmpty) {
    print("📋 [pMap 詳細內容]:");
    pMap.forEach((k, v) => print("   -> Key: $k, Value: $v"));
  } else {
    print("⚠️ [pMap] 是空的！(抓取預覽名次可能失敗)");
  }

  // ===== 核心合併邏輯 =====
  print("\n🔄 開始合併 pMap 到 sMap...");
  
  pMap.forEach((key, preview) {
    print("   👉 正在處理預覽 Key: [$key]");

    // 檢測 sMap 是否有這個 Key
    if (!sMap.containsKey(key)) {
      print("      ⚠️ sMap 找不到 [$key]，正在補建空資料...");
      sMap[key] = ScoreSummary(); // 建立空的 Summary
      // 順便補上空的課程列表，避免 UI 端報錯
      if (!cMap.containsKey(key)) {
        cMap[key] = [];
        print("      ⚠️ cMap 也找不到 [$key]，已補上空列表");
      }
    } else {
      print("      ✅ sMap 已存在 [$key]，準備檢查是否需要覆蓋...");
    }

    final summary = sMap[key]!;
    
    // 印出合併前的狀態
    print("      [合併前] Rank: ${summary.rank}, ClassSize: ${summary.classSize}");

    // 邏輯判斷：只有正式成績是 "-" 或空字串時才補
    bool updated = false;

    if ((summary.rank == "-" || summary.rank.isEmpty) && preview['rank'] != null) {
      print("      ⚡ 更新 Rank: ${summary.rank} -> ${preview['rank']}");
      summary.rank = preview['rank']!;
      updated = true;
    }

    if ((summary.classSize == "-" || summary.classSize.isEmpty) && preview['classSize'] != null) {
      print("      ⚡ 更新 ClassSize: ${summary.classSize} -> ${preview['classSize']}");
      summary.classSize = preview['classSize']!;
      updated = true;
    }

    if (!updated) {
      print("      💤 未進行任何更新 (可能正式成績已有值，或預覽資料為空)");
    }
  });
  
  print("✅ 合併作業結束。\n");

  // ===== 更新 Notifier =====
  coursesNotifier.value = cMap;
  summaryNotifier.value = sMap;
  previewRanksNotifier.value = pMap;

  // ===== 有效學年 / 學期 =====
  Set<String> ySet = {};
  Map<String, List<String>> semMap = {};

  // 這裡改用合併後的 keys (包含 cMap 和 sMap)
  Set<String> allKeys = {...cMap.keys, ...sMap.keys};
  print("📊 最終有效的 Keys (顯示在選單): $allKeys");

  for (var key in allKeys) {
    var parts = key.split('-');
    if (parts.length == 2) {
      ySet.add(parts[0]);
      semMap.putIfAbsent(parts[0], () => []).add(parts[1]);
    }
  }
  
  // 排序學期
  for (var key in semMap.keys) {
    semMap[key]!.sort(); 
  }

  validYearsNotifier.value = ySet;
  validSemestersNotifier.value = semMap;
  
  print("====== 🏁 流程結束 ======\n");
}

  // (原有) 解析 HTML
  ({List<CourseScore> courses, ScoreSummary summary}) _parseHtml(String htmlContent) {
    var document = parser.parse(htmlContent);
    List<CourseScore> courses = [];
    ScoreSummary summary = ScoreSummary();

    var rows = document.getElementsByTagName('tr');
    for (var row in rows) {
      var tds = row.getElementsByTagName('td');
      var cols = tds.map((e) => e.text.trim()).toList();
      if (cols.length >= 6) {
        String possibleId = cols[2];
        String possibleName = cols[3];
        String credit = cols[4];
        String score = cols[5];

        if (int.tryParse(credit) == null && double.tryParse(credit) == null) continue;
        if (score.contains("成績") || possibleName.contains("科目名稱")) continue;

        if (possibleId.length > 2) {
          courses.add(CourseScore(id: possibleId, name: possibleName, credits: credit, score: score));
        }
      }
    }


    var allTds = document.getElementsByTagName('td');
    for (var td in allTds) {
      String text = td.text.trim();
      if (text.startsWith("修習學分：")) summary.creditsTaken = text.replaceAll("修習學分：", "").trim();
      else if (text.startsWith("平均分數：")) summary.average = text.replaceAll("平均分數：", "").trim();
      else if (text.startsWith("本學期名次：")) summary.rank = text.replaceAll("本學期名次：", "").trim();
      else if (text.startsWith("實得學分：")) summary.creditsEarned = text.replaceAll("實得學分：", "").trim();
      else if (text.startsWith("全班人數：")) summary.classSize = text.replaceAll("全班人數：", "").trim();
    }
    
    return (courses: courses, summary: summary);
  }
}