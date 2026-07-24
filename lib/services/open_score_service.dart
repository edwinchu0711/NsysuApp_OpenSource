import 'dart:convert';
import 'dart:isolate';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as parser;
import '../utils/utils.dart';
import 'storage_service.dart';
import 'http_client_factory.dart';

class LoginPasswordErrorException implements Exception {
  final String message;
  LoginPasswordErrorException(this.message);
  @override
  String toString() => message;
}

class OpenScoreService {
  // 單例模式
  static final OpenScoreService instance = OpenScoreService._internal();

  OpenScoreService._internal() {
    loadFromCache();
  }

  http.Client _client = createHttpClient();

  void _recreateClient() {
    try {
      _client.close();
    } catch (_) {}
    _client = createHttpClient();
  }

  static const String CACHE_KEY = "cached_open_scores_plain_v1";
  static const String LAST_UPDATED_KEY = "cached_open_scores_last_updated";

  // 狀態監聽器
  final ValueNotifier<List<Map<String, dynamic>>> resultsNotifier =
      ValueNotifier([]);
  final ValueNotifier<bool> isLoadingNotifier = ValueNotifier(false);
  final ValueNotifier<String> statusMessageNotifier = ValueNotifier("");
  final ValueNotifier<double> progressNotifier = ValueNotifier(0.0);
  final ValueNotifier<String?> errorCodeNotifier = ValueNotifier(null);
  final ValueNotifier<String?> lastUpdatedNotifier = ValueNotifier<String?>(
    null,
  );
  final ValueNotifier<String?> lastRawHtmlNotifier = ValueNotifier<String?>(
    null,
  );

  static bool _hasChinese(String input) =>
      RegExp(r"[\u4e00-\u9fff]").hasMatch(input);

  /// [讀取快取]：將 JSON 字串安全轉換為正確的 List<Map> 結構
  Future<void> loadFromCache() async {
    try {
      String? updatedStr = await StorageService.instance.read(LAST_UPDATED_KEY);
      if (updatedStr != null) {
        lastUpdatedNotifier.value = updatedStr;
      }

      String? jsonStr = await StorageService.instance.read(CACHE_KEY);

      if (jsonStr != null && jsonStr.isNotEmpty) {
        final List<dynamic> decodedRaw = jsonDecode(jsonStr);

        // 深度轉型：確保內部的 scores 也是 List<Map<String, String>>
        List<Map<String, dynamic>> processed = decodedRaw.map((course) {
          final courseMap = Map<String, dynamic>.from(course as Map);
          final scoresRaw = courseMap["scores"] as List? ?? [];

          return {
            "course_name": courseMap["course_name"] ?? "未知課程",
            "course_no": courseMap["course_no"] ?? "",
            "scores": scoresRaw
                .map((s) => Map<String, String>.from(s as Map))
                .toList(),
          };
        }).toList();

        // 使用 List.from 建立新引用，強制觸發 ValueNotifier 的 listeners
        resultsNotifier.value = List.from(processed);
        // debugPrint("📦 OpenScoreService: 已成功載入 ${resultsNotifier.value.length} 筆快取資料",);
      }
    } catch (e) {
      debugPrint("❌ OpenScoreService 載入快取失敗: $e");
    }
  }

  /// [儲存快取]
  Future<void> _saveToCache() async {
    try {
      // 儲存當前 notifier 中的最新快照
      String encoded = jsonEncode(resultsNotifier.value);
      await StorageService.instance.save(CACHE_KEY, encoded);
      if (lastUpdatedNotifier.value != null) {
        await StorageService.instance.save(
          LAST_UPDATED_KEY,
          lastUpdatedNotifier.value!,
        );
      }
      //debugPrint("💾 OpenScoreService: 資料已同步至硬碟");
    } catch (e) {
      debugPrint("❌ OpenScoreService 儲存快取失敗: $e");
    }
  }

  /// [清除快取]：登出時使用
  Future<void> clearCache() async {
    resultsNotifier.value = [];
    statusMessageNotifier.value = "";
    progressNotifier.value = 0.0;
    lastUpdatedNotifier.value = null;
    errorCodeNotifier.value = null;
    lastRawHtmlNotifier.value = null;

    try {
      await StorageService.instance.remove(CACHE_KEY);
      await StorageService.instance.remove(LAST_UPDATED_KEY);
      debugPrint("🗑️ OpenScoreService: 快取已清空");
    } catch (e) {
      debugPrint("❌ OpenScoreService 刪除失敗: $e");
    }
  }

  Future<void> _warmUpSession(String cookies) async {
    await _client.get(
      Uri.parse("https://selcrs.nsysu.edu.tw/scoreqry/sco_query_prs_sso2.asp"),
      headers: {"Cookie": cookies, "User-Agent": "Mozilla/5.0"},
    );
  }

  /// [主要抓取流程]
  Future<void> fetchOpenScores() async {
    if (isLoadingNotifier.value) return;

    errorCodeNotifier.value = null;
    lastRawHtmlNotifier.value = null;

    isLoadingNotifier.value = true;
    progressNotifier.value = 0.0;
    statusMessageNotifier.value = "檢查身分中...";

    try {
      // 確保在嘗試抓取前，記憶體至少有舊的快取資料
      if (resultsNotifier.value.isEmpty) {
        await loadFromCache();
      }

      final credentials = await StorageService.instance.getCredentials();
      String? username = credentials['username']?.trim();
      String? password = credentials['password']?.trim();

      if (username == null || password == null || username.isEmpty) {
        errorCodeNotifier.value = "[ERR_01] 找不到帳號資訊";
        return;
      }

      const int maxFetchRetry = 15;
      bool success = false;
      bool hasPasswordError = false;

      for (int i = 1; i <= maxFetchRetry; i++) {
        debugPrint("開放成績抓資料（第 $i 次嘗試）");

        // 每次嘗試都重建 Client，清除所有舊的連線與快取
        _recreateClient();

        if (i > 1) {
          statusMessageNotifier.value = "連線重試中 ($i/$maxFetchRetry)...";
          await Future.delayed(Duration(milliseconds: 800 * i));
        }

        statusMessageNotifier.value = "正在登入成績系統 ($i/$maxFetchRetry)...";

        try {
          String? cookies = await _loginToScoreSystem(username, password);
          if (cookies == null) {
            debugPrint("❌ 第 $i 次登入失敗");
            if (!hasPasswordError && i >= 5) {
              debugPrint("一般登入失敗且已嘗試 $i 次，停止重試");
              break;
            }
            continue;
          }

          debugPrint("開放成績-第 $i 次登入成功，開始暖機與抓取");
          await Future.delayed(const Duration(milliseconds: 800));

          // 暖機請求
          try {
            await _warmUpSession(cookies);
            // debugPrint("🔥 warm-up 完成");
          } catch (_) {}

          bool ok = await _startLinearFetchingProcess(
            cookies,
            clearIfEmpty: false,
          );

          final count = resultsNotifier.value.length;
          // debugPrint("📊 筆數: $count");

          if (ok && count > 0) {
            success = true;
            break;
          }

          if (!hasPasswordError && i >= 5) {
            debugPrint("一般抓取失敗且已嘗試 $i 次，停止重試");
            break;
          }
        } on LoginPasswordErrorException {
          hasPasswordError = true;
          debugPrint("偵測到密碼錯誤代碼，允許最多重試 15 次");
          if (i >= 15) {
            break;
          }
          continue;
        }

        debugPrint("開放成績失敗 - 第 $i 次嘗試失敗或資料未 ready");
      }

      if (success) {
        final now = DateTime.now();
        String formatted =
            "${now.year}/${now.month.toString().padLeft(2, '0')}/${now.day.toString().padLeft(2, '0')} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}";
        lastUpdatedNotifier.value = formatted;
        await _saveToCache();
      } else {
        statusMessageNotifier.value = "更新失敗";
        errorCodeNotifier.value = "查無公開成績，更新失敗，請稍待片刻或嘗試重啟應用程式。";
      }
    } catch (e, stack) {
      debugPrint("❌ 錯誤: $e");
      debugPrint("$stack");
      errorCodeNotifier.value = "[ERR_99] $e";
      lastRawHtmlNotifier.value = "【例外錯誤資訊】\n$e\n\n$stack";
    } finally {
      isLoadingNotifier.value = false;
      // debugPrint('[OS] fetchOpenScores 總耗時 (+${sw.elapsedMilliseconds}ms)');
    }
  }

  /// 登入成績系統獲取 Session
  Future<String?> _loginToScoreSystem(String username, String password) async {
    final loginUrl = Uri.parse(
      "https://selcrs.nsysu.edu.tw/scoreqry/sco_query_prs_sso2.asp",
    );
    try {
      final response = await _client
          .post(
            loginUrl,
            headers: {
              "Content-Type": "application/x-www-form-urlencoded",
              "User-Agent":
                  "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
            },
            body: {
              'SID': username.toUpperCase(),
              'PASSWD': Utils.base64md5(password),
              'ACTION': '0',
              'INTYPE': '1',
            },
          )
          .timeout(const Duration(seconds: 15));

      final bodyText = response.body;
      if (bodyText.contains(
            '&#30331;&#37636;&#23494;&#30908;&#37679;&#35492;&#65292;&#28961;&#27861;&#20351;&#29992;&#35531;&#37325;&#26032;&#30331;&#37636;&#65281;',
          ) ||
          bodyText.contains('登錄密碼錯誤，無法使用請重新登錄！')) {
        throw LoginPasswordErrorException("登錄密碼錯誤");
      }

      String? rawCookie = response.headers['set-cookie'];
      if (rawCookie != null && !bodyText.contains("不符")) {
        return rawCookie;
      } else {
        lastRawHtmlNotifier.value = "【登入失敗，伺服器回應】";
      }
    } on LoginPasswordErrorException {
      rethrow;
    } catch (e) {
      debugPrint("Login Network Error: $e");
      lastRawHtmlNotifier.value = "【登入網路錯誤】\n$e";
    }
    return null;
  }

  /// 解析課程並逐一讀取細節
  Future<bool> _startLinearFetchingProcess(
    String cookies, {
    bool clearIfEmpty = false,
  }) async {
    final headers = {
      "User-Agent":
          "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
      "Cookie": cookies,
      "Content-Type": "application/x-www-form-urlencoded",
    };

    statusMessageNotifier.value = "正在讀取課程清單...";
    final listUrl = Uri.parse(
      "https://selcrs.nsysu.edu.tw/scoreqry/sco_query.asp?action=813&KIND=1&LANGS=cht",
    );

    final listResponse = await _client.get(listUrl, headers: headers);
    String listContent = utf8.decode(
      listResponse.bodyBytes,
      allowMalformed: true,
    );
    lastRawHtmlNotifier.value = listContent;

    if (listContent.contains(
          '&#30331;&#37636;&#23494;&#30908;&#37679;&#35492;&#65292;&#28961;&#27861;&#20351;&#29992;&#35531;&#37325;&#26032;&#30331;&#37636;&#65281;',
        ) ||
        listContent.contains('登錄密碼錯誤，無法使用請重新登錄！')) {
      throw LoginPasswordErrorException("登錄密碼錯誤");
    }

    final coursesToFetch = await Isolate.run(() {
      var listSoup = parser.parse(listContent);
      var rows = listSoup.getElementsByTagName('tr');
      List<Map<String, String>> results = [];

      for (int i = 1; i < rows.length; i++) {
        var cols = rows[i].getElementsByTagName('td');
        if (cols.length >= 3) {
          String no = cols[1].text.trim();
          String name = cols[2].text.trim();
          if (no.isNotEmpty && !_hasChinese(no) && no != "學號") {
            results.add({"no": no, "name": name});
          }
        }
      }
      return results;
    });

    if (coursesToFetch.isEmpty) {
      statusMessageNotifier.value = "目前尚無公開成績";
      if (clearIfEmpty) {
        resultsNotifier.value = []; // 確定沒資料時才清空
        await _saveToCache();
      }
      return false;
    }

    List<Map<String, dynamic>> rawResults = [];
    final random = Random();

    for (int i = 0; i < coursesToFetch.length; i++) {
      var course = coursesToFetch[i];
      statusMessageNotifier.value =
          "讀取中 (${i + 1}/${coursesToFetch.length}): ${course['name']}";
      progressNotifier.value = i / coursesToFetch.length;

      try {
        final detail = await _fetchSingleCourse(
          course['no']!,
          course['name']!,
          headers,
        );
        rawResults.add(detail);
        // 延遲防止請求過於頻繁
        await Future.delayed(Duration(milliseconds: 100 + random.nextInt(150)));
      } catch (e) {
        rawResults.add({
          "course_name": course['name'],
          "course_no": course['no'],
          "scores": [],
        });
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
    return true;
  }

  /// 讀取單一課程詳細分數
  Future<Map<String, dynamic>> _fetchSingleCourse(
    String no,
    String name,
    Map<String, String> headers,
  ) async {
    final queryUrl = Uri.parse(
      "https://selcrs.nsysu.edu.tw/scoreqry/sco_query.asp?ACTION=814&KIND=1&LANGS=cht",
    );

    final response = await _client
        .post(
          queryUrl,
          headers: headers,
          body: {"CRSNO": no, "SCO_TYP_COD": "--"},
        )
        .timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) throw "Network Error";
    String content = utf8.decode(response.bodyBytes, allowMalformed: true);

    if (content.contains("重新登入")) throw "Session Timeout";

    final scoreDetails = await Isolate.run(() {
      var soup = parser.parse(content);
      var detailRows = soup.getElementsByTagName('tr');
      List<Map<String, String>> details = [];

      for (var row in detailRows.skip(1)) {
        var cols = row.getElementsByTagName('td');
        if (cols.length >= 5) {
          var texts = cols.map((e) => e.text.trim()).toList();
          String itemTitle = texts.length > 2 ? texts[2] : "";

          if (itemTitle.isNotEmpty &&
              itemTitle != "項目" &&
              itemTitle != "評分項目") {
            details.add({
              "item": itemTitle,
              "percentage": texts.length > 3 ? texts[3] : "",
              "raw_score": texts.length > 4 ? texts[4] : "",
              "note": texts.length > 6 ? texts[6] : "",
            });
          }
        }
      }
      return details;
    });
    return {"course_name": name, "course_no": no, "scores": scoreDetails};
  }

  void dispose() {
    _client.close();
  }
}
