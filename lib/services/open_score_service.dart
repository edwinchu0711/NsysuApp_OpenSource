import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as parser;
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/utils.dart';

class OpenScoreService {
  // 單例模式
  static final OpenScoreService instance = OpenScoreService._internal();
  
  OpenScoreService._internal() {
    // 初始化時異步載入快取，但不阻塞構造函數
    loadFromCache();
  }

  final http.Client _client = http.Client();
  static const String CACHE_KEY = "cached_open_scores_v2"; // 升級版本號以避免舊格式干擾

  // 狀態監聽器
  final ValueNotifier<List<Map<String, dynamic>>> resultsNotifier = ValueNotifier([]);
  final ValueNotifier<bool> isLoadingNotifier = ValueNotifier(false);
  final ValueNotifier<String> statusMessageNotifier = ValueNotifier("");
  final ValueNotifier<double> progressNotifier = ValueNotifier(0.0);

  bool _hasChinese(String input) => RegExp(r"[\u4e00-\u9fff]").hasMatch(input);

  /// [讀取快取]：將 JSON 字串安全轉換為正確的 List<Map> 結構
  Future<void> loadFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? jsonStr = prefs.getString(CACHE_KEY);
      
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final List<dynamic> decodedRaw = jsonDecode(jsonStr);
        
        // 深度轉型：確保內部的 scores 也是 List<Map<String, String>>
        List<Map<String, dynamic>> processed = decodedRaw.map((course) {
          final courseMap = Map<String, dynamic>.from(course as Map);
          final scoresRaw = courseMap["scores"] as List? ?? [];
          
          return {
            "course_name": courseMap["course_name"] ?? "未知課程",
            "course_no": courseMap["course_no"] ?? "",
            "scores": scoresRaw.map((s) => Map<String, String>.from(s as Map)).toList(),
          };
        }).toList();

        // 使用 List.from 建立新引用，強制觸發 ValueNotifier 的 listeners
        resultsNotifier.value = List.from(processed);
        print("📦 OpenScoreService: 已成功載入 ${resultsNotifier.value.length} 筆快取資料");
      }
    } catch (e) {
      print("❌ OpenScoreService 載入快取失敗: $e");
    }
  }

  /// [儲存快取]
  Future<void> _saveToCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // 儲存當前 notifier 中的最新快照
      String encoded = jsonEncode(resultsNotifier.value);
      await prefs.setString(CACHE_KEY, encoded);
      print("💾 OpenScoreService: 資料已同步至硬碟");
    } catch (e) {
      print("❌ OpenScoreService 儲存快取失敗: $e");
    }
  }

  /// [清除快取]：登出時使用
  Future<void> clearCache() async {
    resultsNotifier.value = [];
    statusMessageNotifier.value = "";
    progressNotifier.value = 0.0;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(CACHE_KEY);
      print("🗑️ OpenScoreService: 快取已清空");
    } catch (e) {
      print("❌ OpenScoreService 刪除失敗: $e");
    }
  }

  /// [主要抓取流程]
  Future<void> fetchOpenScores() async {
    if (isLoadingNotifier.value) return;

    isLoadingNotifier.value = true;
    progressNotifier.value = 0.0;
    statusMessageNotifier.value = "檢查身分中...";

    try {
      // 確保在嘗試抓取前，記憶體至少有舊的快取資料
      if (resultsNotifier.value.isEmpty) {
        await loadFromCache();
      }

      final SharedPreferences prefs = await SharedPreferences.getInstance();
      String? username = prefs.getString('username')?.trim();
      String? password = prefs.getString('password')?.trim();

      if (username == null || password == null || username.isEmpty) {
        statusMessageNotifier.value = "找不到帳號資訊，請重新登入";
        return;
      }

      String? cookies = await _loginToScoreSystem(username, password);
      if (cookies == null) {
        statusMessageNotifier.value = "系統登入失敗，請確認網路或密碼";
        return;
      }

      await _startLinearFetchingProcess(cookies);
    } catch (e) {
      statusMessageNotifier.value = "連線異常: $e";
      print("❌ OpenScore 流程錯誤: $e");
    } finally {
      isLoadingNotifier.value = false;
    }
  }

  /// 登入成績系統獲取 Session
  Future<String?> _loginToScoreSystem(String username, String password) async {
    final loginUrl = Uri.parse("https://selcrs.nsysu.edu.tw/scoreqry/sco_query_prs_sso2.asp");
    try {
      final response = await _client.post(
        loginUrl,
        headers: {
          "Content-Type": "application/x-www-form-urlencoded",
          "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
        },
        body: {
          'SID': username.toUpperCase(),
          'PASSWD': Utils.base64md5(password),
          'ACTION': '0',
          'INTYPE': '1',
        },
      ).timeout(const Duration(seconds: 15));

      String? rawCookie = response.headers['set-cookie'];
      if (rawCookie != null && !response.body.contains("不符")) {
        return rawCookie;
      }
    } catch (e) {
      print("Login Network Error: $e");
    }
    return null;
  }

  /// 解析課程並逐一讀取細節
  Future<void> _startLinearFetchingProcess(String cookies) async {
    final headers = {
      "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
      "Cookie": cookies,
      "Content-Type": "application/x-www-form-urlencoded",
    };

    statusMessageNotifier.value = "正在讀取課程清單...";
    final listUrl = Uri.parse("https://selcrs.nsysu.edu.tw/scoreqry/sco_query.asp?action=813&KIND=1&LANGS=cht");
    
    final listResponse = await _client.get(listUrl, headers: headers);
    String listContent = utf8.decode(listResponse.bodyBytes, allowMalformed: true);

    var listSoup = parser.parse(listContent);
    var rows = listSoup.getElementsByTagName('tr');
    List<Map<String, String>> coursesToFetch = [];

    for (int i = 1; i < rows.length; i++) {
      var cols = rows[i].getElementsByTagName('td');
      if (cols.length >= 3) {
        String no = cols[1].text.trim();
        String name = cols[2].text.trim();
        if (no.isNotEmpty && !_hasChinese(no) && no != "學號") {
          coursesToFetch.add({"no": no, "name": name});
        }
      }
    }

    if (coursesToFetch.isEmpty) {
      statusMessageNotifier.value = "目前尚無公開成績";
      resultsNotifier.value = []; // 確定沒資料時才清空
      await _saveToCache();
      return;
    }

    List<Map<String, dynamic>> rawResults = [];
    final random = Random();

    for (int i = 0; i < coursesToFetch.length; i++) {
      var course = coursesToFetch[i];
      statusMessageNotifier.value = "讀取中 (${i + 1}/${coursesToFetch.length}): ${course['name']}";
      progressNotifier.value = i / coursesToFetch.length;

      try {
        final detail = await _fetchSingleCourse(course['no']!, course['name']!, headers);
        rawResults.add(detail);
        // 延遲防止請求過於頻繁
        await Future.delayed(Duration(milliseconds: 100 + random.nextInt(150)));
      } catch (e) {
        rawResults.add({"course_name": course['name'], "course_no": course['no'], "scores": []});
      }
    }

    // 資料去重與優化：保留有分數的那一筆
    Map<String, Map<String, dynamic>> uniqueMap = {};
    for (var res in rawResults) {
      String name = res['course_name'];
      bool hasScores = (res['scores'] as List).isNotEmpty;

      if (!uniqueMap.containsKey(name) || hasScores) {
        uniqueMap[name] = res;
      }
    }

    List<Map<String, dynamic>> processedList = uniqueMap.values.toList();

    // 排序：有分數的排前面
    processedList.sort((a, b) {
      bool aHas = (a['scores'] as List).isNotEmpty;
      bool bHas = (b['scores'] as List).isNotEmpty;
      if (aHas && !bHas) return -1;
      if (!aHas && bHas) return 1;
      return 0;
    });

    // 關鍵更新：必須賦予新 List 實例
    resultsNotifier.value = [...processedList];
    statusMessageNotifier.value = "更新成功";
    progressNotifier.value = 1.0;

    await _saveToCache();
  }

  /// 讀取單一課程詳細分數
  Future<Map<String, dynamic>> _fetchSingleCourse(String no, String name, Map<String, String> headers) async {
    final queryUrl = Uri.parse("https://selcrs.nsysu.edu.tw/scoreqry/sco_query.asp?ACTION=814&KIND=1&LANGS=cht");
    
    final response = await _client.post(
      queryUrl,
      headers: headers,
      body: {"CRSNO": no, "SCO_TYP_COD": "--"}
    ).timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) throw "Network Error";
    String content = utf8.decode(response.bodyBytes, allowMalformed: true);
    
    if (content.contains("重新登入")) throw "Session Timeout";

    var soup = parser.parse(content);
    var detailRows = soup.getElementsByTagName('tr');
    List<Map<String, String>> scoreDetails = [];

    for (var row in detailRows.skip(1)) {
      var cols = row.getElementsByTagName('td');
      if (cols.length >= 5) {
        var texts = cols.map((e) => e.text.trim()).toList();
        String itemTitle = texts.length > 2 ? texts[2] : "";

        if (itemTitle.isNotEmpty && itemTitle != "項目" && itemTitle != "評分項目") {
          scoreDetails.add({
            "item": itemTitle,
            "percentage": texts.length > 3 ? texts[3] : "",
            "raw_score": texts.length > 4 ? texts[4] : "",
            "note": texts.length > 6 ? texts[6] : "",
          });
        }
      }
    }
    return {"course_name": name, "course_no": no, "scores": scoreDetails};
  }

  void dispose() {
    _client.close();
  }
}