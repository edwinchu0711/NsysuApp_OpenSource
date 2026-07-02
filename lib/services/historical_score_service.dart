import 'dart:convert';
import 'dart:io'; // 用於 HttpClient
import 'dart:isolate';
import 'dart:async';
import 'package:http/io_client.dart'; // 用於將 HttpClient 包裝成 http.Client
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as parser;
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/utils.dart';
import 'storage_service.dart';

// --- 資料模型 ---
class CourseScore {
  final String id;
  final String name;
  final String credits;
  final String score;
  CourseScore({
    required this.id,
    required this.name,
    required this.credits,
    required this.score,
  });
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

class LoginPasswordErrorException implements Exception {
  final String message;
  LoginPasswordErrorException(this.message);
  @override
  String toString() => message;
}

// --- Service 主體 ---
class HistoricalScoreService {
  static final HistoricalScoreService instance =
      HistoricalScoreService._internal();
  HistoricalScoreService._internal() {
    // 移除構造函數中的異步調用以避免競爭條件
    // 改由外部 (如 main.dart) 在存儲系統就緒後顯式調用 loadFromCache()
  }

  http.Client _client = http.Client();

  void _recreateClient() {
    try {
      _client.close();
    } catch (_) {}
    _client = http.Client();
  }

  static const String CACHE_KEY = "historical_scores_data_plain_v3";
  static const String LAST_UPDATED_KEY = "historical_scores_last_updated";

  // 狀態監聽器
  final ValueNotifier<Map<String, List<CourseScore>>> coursesNotifier =
      ValueNotifier({});
  final ValueNotifier<Map<String, ScoreSummary>> summaryNotifier =
      ValueNotifier({});
  // ★★★ 新增：存放預覽名次的 Notifier (Key: year-sem, Value: {rank, classSize})
  final ValueNotifier<Map<String, Map<String, String>>> previewRanksNotifier =
      ValueNotifier({});
  final ValueNotifier<String?> lastUpdatedNotifier = ValueNotifier<String?>(
    null,
  );
  final ValueNotifier<String?> syncErrorNotifier = ValueNotifier<String?>(null);

  final ValueNotifier<bool> isLoadingNotifier = ValueNotifier(false);
  final ValueNotifier<String> statusMessageNotifier = ValueNotifier("");
  final ValueNotifier<double> progressNotifier = ValueNotifier(0.0);
  final ValueNotifier<Set<String>> validYearsNotifier = ValueNotifier({});
  final ValueNotifier<Map<String, List<String>>> validSemestersNotifier =
      ValueNotifier({});

  /// [清除快取]
  Future<void> clearCache() async {
    coursesNotifier.value = {};
    summaryNotifier.value = {};
    previewRanksNotifier.value = {}; // 清除預覽資料
    validYearsNotifier.value = {};
    validSemestersNotifier.value = {};
    statusMessageNotifier.value = "";
    progressNotifier.value = 0.0;
    lastUpdatedNotifier.value = null;
    syncErrorNotifier.value = null;

    try {
      await StorageService.instance.remove(CACHE_KEY);
      await StorageService.instance.remove(LAST_UPDATED_KEY);
      // debugPrint("🗑️ HistoricalScoreService: 歷年成績快取已完全清除");
    } catch (e) {
      // debugPrint("❌ HistoricalScoreService 清除失敗: $e");
    }
  }

  /// 從本地 SharedPreferences 載入快取
  Future<void> loadFromCache() async {
    // debugPrint("📂 HistoricalScoreService: 開始從快取載入資料...");
    try {
      String? updatedStr = await StorageService.instance.read(LAST_UPDATED_KEY);
      if (updatedStr != null) {
        lastUpdatedNotifier.value = updatedStr;
      }

      String? jsonStr = await StorageService.instance.read(CACHE_KEY);
      if (jsonStr != null && jsonStr.isNotEmpty && jsonStr.startsWith('{')) {
        // debugPrint("✅ HistoricalScoreService: 讀取到純文字快取資料，長度: ${jsonStr.length}",);
        Map<String, dynamic> decoded = json.decode(jsonStr);
        _processAndNotify(decoded);
        // debugPrint("✅ HistoricalScoreService: 快取資料解析並通知完成 (plain_v3)");
      } else {
        // debugPrint("ℹ️ HistoricalScoreService: 找不到可用快取資料或格式不正確 (plain_v3)");
      }
    } catch (e) {
      // debugPrint("❌ HistoricalScoreService: 讀取快取失敗: $e");
    }
  }

  /// 將目前的資料存入快取
  Future<void> _saveToCache() async {
    try {
      Map<String, dynamic> dataToSave = {};

      coursesNotifier.value.forEach((key, list) {
        dataToSave[key] = {
          'courses': list
              .map(
                (c) => {
                  'id': c.id,
                  'name': c.name,
                  'credits': c.credits,
                  'score': c.score,
                },
              )
              .toList(),
          'summary': {
            'creditsTaken': summaryNotifier.value[key]?.creditsTaken,
            'creditsEarned': summaryNotifier.value[key]?.creditsEarned,
            'average': summaryNotifier.value[key]?.average,
            'rank': summaryNotifier.value[key]?.rank,
            'classSize': summaryNotifier.value[key]?.classSize,
          },
          // 儲存預覽資料
          'previewRank': previewRanksNotifier.value[key],
        };
      });
      await StorageService.instance.save(CACHE_KEY, json.encode(dataToSave));
      if (lastUpdatedNotifier.value != null) {
        await StorageService.instance.save(
          LAST_UPDATED_KEY,
          lastUpdatedNotifier.value!,
        );
      }
    } catch (e) {
      // debugPrint("儲存快取失敗: $e");
    }
  }

  /// [主要進入點]
  Future<void> _warmUpSession(String cookies) async {
    await _client.get(
      Uri.parse("https://selcrs.nsysu.edu.tw/scoreqry/sco_query_prs_sso2.asp"),
      headers: {"Cookie": cookies, "User-Agent": "Mozilla/5.0"},
    );
  }

  /// [主要進入點]
  Future<void> fetchAllData({
    bool forceFullRefresh = false,
    bool fetchPreview = true,
  }) async {
    if (isLoadingNotifier.value) {
      // debugPrint("HistoricalScoreService: 已經在同步中，忽略此次 fetchAllData()");
      return;
    }

    isLoadingNotifier.value = true;
    progressNotifier.value = 0.0;
    statusMessageNotifier.value = "檢查帳號資訊...";
    syncErrorNotifier.value = null;
    final sw = Stopwatch()..start();

    try {
      final credentials = await StorageService.instance.getCredentials();
      String? username = credentials['username']?.trim();
      String? password = credentials['password']?.trim();

      // 1. 讀取使用者設定
      final prefs = await SharedPreferences.getInstance();
      
      int previewRankMode = 2; // 預設選項是 2
      if (prefs.containsKey('preview_rank_mode')) {
        previewRankMode = prefs.getInt('preview_rank_mode') ?? 2;
      } else if (prefs.containsKey('is_preview_rank_enabled')) {
        bool? oldVal = prefs.getBool('is_preview_rank_enabled');
        if (oldVal == false) {
          previewRankMode = 1; // 關閉
        } else if (oldVal == true) {
          previewRankMode = 2; // 部分期間開啟
        }
      }

      if (username == null || password == null || username.isEmpty) {
        statusMessageNotifier.value = "找不到帳號密碼";
        return;
      }

      // ===== 2. 判斷日期區間 =====
      DateTime now = DateTime.now();
      int m = now.month;
      int d = now.day;

      bool shouldFetchPreview = false;
      if (previewRankMode == 2) {
        // Option 2: 部分期間開啟 (5/25~10/10 和 12/25~3/20 開啟，其餘時間關閉)
        // 3/21 ~ 5/24 關閉
        bool isSpringClosed =
            (m == 3 && d >= 21) || (m == 4) || (m == 5 && d <= 24);
        // 10/11 ~ 12/24 關閉
        bool isFallClosed =
            (m == 10 && d >= 11) || (m == 11) || (m == 12 && d <= 24);

        shouldFetchPreview = fetchPreview && !(isSpringClosed || isFallClosed);
      } else if (previewRankMode == 3) {
        // Option 3: 永久開啟
        shouldFetchPreview = fetchPreview;
      } else {
        // Option 1: 關閉
        shouldFetchPreview = false;
      }

      int x = now.year - 1911;

      // 啟動預覽名次非同步抓取
      Future<Map<String, Map<String, String>>>? previewFuture;
      if (shouldFetchPreview) {
        // debugPrint("🚀 啟動非同步抓取預覽名次...");
        previewFuture = _fetchPreviewRanks(
          username,
          password,
          null, // 不傳 progress callback 以免干擾主進度條
        ).timeout(const Duration(seconds: 45));
      }

      Map<String, List<CourseScore>> newCourses = Map.from(
        coursesNotifier.value,
      );
      Map<String, ScoreSummary> newSummary = Map.from(summaryNotifier.value);

      bool hasAnyData = false;
      const int maxFetchRetry = 15;

      // ===== 4. 登入與抓取學期成績 (加入重試與重建 client 機制) =====
      for (int i = 1; i <= maxFetchRetry; i++) {
        // 每次嘗試都重建 Client，清除所有舊的連線與快取
        _recreateClient();

        if (i > 1) {
          // debugPrint("🔄 [重試] 開始第 $i 次/共 $maxFetchRetry 次抓取嘗試...");
          statusMessageNotifier.value = "連線重試中 ($i/$maxFetchRetry)...";
          int delayMs = 500 * i;
          if (delayMs > 2500) delayMs = 2500;
          await Future.delayed(Duration(milliseconds: delayMs));
        }

        statusMessageNotifier.value = "正在登入系統 ($i/$maxFetchRetry)...";
        String? sessionCookie = await _loginToScoreSystem(username, password);
        if (sessionCookie == null) {
          debugPrint("❌ [重試] 第 $i 次登入成績系統失敗。");
          continue;
        }

        // 給 backend 初始化時間與暖機
        await Future.delayed(const Duration(milliseconds: 800));
        try {
          await _warmUpSession(sessionCookie);
        } catch (_) {}

        // 新增：僅在完整/首次同步時，訪問 sco_query.asp?action=1 並嘗試取得 STUID
        int? entryYear;
        String? parsedStuid = username;

        final digitMatch = RegExp(r'\d{2}').firstMatch(username);
        if (digitMatch != null) {
          int? digits = int.tryParse(digitMatch.group(0)!);
          if (digits != null) {
            if (digits >= 80) {
              entryYear = digits;
            } else {
              entryYear = 100 + digits;
            }
          }
        }

        bool isFullRefresh = coursesNotifier.value.isEmpty || forceFullRefresh;
        bool shouldAbortAndRetryFromStuid = false;

        if (isFullRefresh && entryYear == null) {
          try {
            final action1Url = Uri.parse(
              "https://selcrs.nsysu.edu.tw/scoreqry/sco_query.asp?action=1",
            );
            final action1Response = await _client.get(
              action1Url,
              headers: {
                "User-Agent":
                    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
                "Cookie": sessionCookie,
              },
            );

            final bodyText = action1Response.body;
            if (bodyText.contains(
                  '&#30331;&#37636;&#23494;&#30908;&#37679;&#35492;&#65292;&#28961;&#27861;&#20351;&#29992;&#35531;&#37325;&#26032;&#30331;&#37636;&#65281;',
                ) ||
                bodyText.contains('登錄密碼錯誤，無法使用請重新登錄！')) {
              // debugPrint("⚠️ [STUID 重試] 偵測到密碼錯誤！原始碼如下：\n$bodyText");
              throw LoginPasswordErrorException("登錄密碼錯誤");
            }

            bool isLoginFailed =
                bodyText.contains("不符") ||
                bodyText.contains("錯誤") ||
                bodyText.contains("SCO_QUERY.asp");

            if (action1Response.statusCode != 200 || isLoginFailed) {
              // debugPrint(
              //   "⚠️ [STUID 重試] 狀態碼異常或偵測到失敗字眼。狀態碼: ${action1Response.statusCode}。原始碼：\n$bodyText",
              // );
              shouldAbortAndRetryFromStuid = true;
            } else {
              String content = utf8.decode(
                action1Response.bodyBytes,
                allowMalformed: true,
              );
              if (content.contains("請重新登入")) {
                // debugPrint("⚠️ [STUID 重試] 偵測到 '請重新登入'。原始碼：\n$content");
                shouldAbortAndRetryFromStuid = true;
              } else {
                final stuidMatch = RegExp(
                  r'STUID=([A-Za-z0-9]+)',
                  caseSensitive: false,
                ).firstMatch(action1Response.body);

                if (stuidMatch != null) {
                  String stuid = stuidMatch.group(1)!;
                  parsedStuid = stuid;
                  final digitMatch = RegExp(r'\d{2}').firstMatch(stuid);
                  if (digitMatch != null) {
                    int? digits = int.tryParse(digitMatch.group(0)!);
                    if (digits != null) {
                      if (digits >= 80) {
                        entryYear = digits;
                      } else {
                        entryYear = 100 + digits;
                      }
                    }
                  }
                }
              }
            }
          } on LoginPasswordErrorException catch (e) {
            debugPrint("⚠️ [STUID 重試] 捕獲 LoginPasswordErrorException: $e");
            shouldAbortAndRetryFromStuid = true;
          } catch (e) {
            debugPrint("❌ 取得 STUID 發生錯誤: $e");
          }
        }

        if (shouldAbortAndRetryFromStuid) {
          debugPrint("🔄 [STUID 觸發重試] 第 $i 次嘗試失敗，準備進行下一次重試。");
          continue;
        }

        // 依據是否解析出 entryYear 來定義本輪抓取的 tasks 範圍
        List<MapEntry<String, String>> localTasks = [];
        if (coursesNotifier.value.isEmpty || forceFullRefresh) {
          int startYear = x;
          int endYear = (entryYear != null) ? entryYear : (x - 4);
          if (endYear > startYear) endYear = startYear; // 防呆

          for (int yearVal = startYear; yearVal >= endYear; yearVal--) {
            String yearStr = yearVal.toString();
            localTasks.add(MapEntry(yearStr, "0")); // 碩專暑
            localTasks.add(MapEntry(yearStr, "1"));
            localTasks.add(MapEntry(yearStr, "2"));
            localTasks.add(MapEntry(yearStr, "3"));
          }
        } else {
          if (m >= 1 && m <= 6) {
            String targetYear = (x - 1).toString();
            localTasks.add(MapEntry(targetYear, "0"));
            if (m != 6) {
              localTasks.add(MapEntry(targetYear, "1"));
            }
            localTasks.add(MapEntry(targetYear, "2"));
            if (m != 6) {
              localTasks.add(MapEntry(targetYear, "3"));
            }
          } else {
            String lastYear = (x - 1).toString();
            String thisYear = x.toString();
            localTasks.add(MapEntry(lastYear, "0"));
            if (m != 11 && m != 12) {
              localTasks.add(MapEntry(lastYear, "2"));
            }
            localTasks.add(MapEntry(lastYear, "3"));
            localTasks.add(MapEntry(thisYear, "0"));
            if (m != 7) {
              localTasks.add(MapEntry(thisYear, "1"));
            }
          }
          // 排除小於入學年限的任務
          if (entryYear != null) {
            localTasks.removeWhere(
              (task) => (int.tryParse(task.key) ?? 0) < entryYear!,
            );
          }
        }

        // 如果學號（帳號或解析出的 STUID）開頭為 'B' 或 'b'，則排除學期別為 "0" (碩專暑)
        bool isUndergrad =
            username.toUpperCase().startsWith('B') ||
            (parsedStuid != null && parsedStuid.toUpperCase().startsWith('B'));
        if (isUndergrad) {
          localTasks.removeWhere((task) => task.value == "0");
        }

        int completed = 0;
        hasAnyData = false;
        bool shouldAbortAndRetry = false;

        for (int taskIdx = 0; taskIdx < localTasks.length; taskIdx++) {
          var task = localTasks[taskIdx];
          String year = task.key;
          String sem = task.value;
          statusMessageNotifier.value = "同步中: $year-$sem ($i/$maxFetchRetry)";

          try {
            final result = await _fetchSingleSemester(
              sessionCookie,
              year,
              sem,
              debugPrintRawHtml: taskIdx == 0,
            );

            if (result != null && result.courses.isNotEmpty) {
              String key = "$year-$sem";
              newCourses[key] = result.courses;
              newSummary[key] = result.summary;
              hasAnyData = true;

              // 即時更新 Notifier，讓 UI 在同步過程中能先顯示已抓取的學期
              _processAndNotifyFromMaps(
                newCourses,
                newSummary,
                previewRanksNotifier.value,
              );
            }
          } on LoginPasswordErrorException {
            if (taskIdx == 0) {
              debugPrint("⚠️ [學期重試] 第一學期捕獲到 LoginPasswordErrorException，觸發重試。");
              // 第一個學期若出現登錄密碼錯誤，直接中斷目前迴圈並進行重試
              shouldAbortAndRetry = true;
              break;
            }
          }

          completed++;
          progressNotifier.value = localTasks.isNotEmpty
              ? (completed / localTasks.length) * 0.9
              : 0.0;
          await Future.delayed(const Duration(milliseconds: 120));
        }

        if (shouldAbortAndRetry) {
          // debugPrint("🔄 [學期觸發重試] 第 $i 次嘗試失敗，準備進行下一次重試。");
          continue;
        }

        // 如果有抓到任何資料，視為正常並跳出重試
        if (hasAnyData) {
          // debugPrint("✅ [同步成功] 第 $i 次嘗試成功取得資料，跳出重試迴圈。");
          break;
        } else {
          debugPrint("❌ [重試] 第 $i 次嘗試未取得任何成績資料。");
        }
      }

      if (!hasAnyData) {
        syncErrorNotifier.value = "同步失敗，查無成績資料，請重新登入、重啟App或稍後再試。";
        statusMessageNotifier.value = "同步失敗，查無成績資料，請重新登入、重啟App或稍後再試。";
        return;
      }

      syncErrorNotifier.value = null;

      _processAndNotifyFromMaps(
        newCourses,
        newSummary,
        previewRanksNotifier.value,
      );

      // ===== 6. 合併預覽名次 =====
      if (previewFuture != null) {
        statusMessageNotifier.value = "正在完成預覽名次合併...";
        try {
          Map<String, Map<String, String>> fetched = await previewFuture;
          Map<String, Map<String, String>> newPreview = Map.from(
            previewRanksNotifier.value,
          );
          newPreview.addAll(fetched);

          _processAndNotifyFromMaps(newCourses, newSummary, newPreview);
        } catch (e) {
          // debugPrint("HistoricalScoreService: 合併預覽名次發生錯誤或逾時: $e");
        }
      }

      progressNotifier.value = 1.0;
      final updateTime = DateTime.now();
      String formatted =
          "${updateTime.year}/${updateTime.month.toString().padLeft(2, '0')}/${updateTime.day.toString().padLeft(2, '0')} ${updateTime.hour.toString().padLeft(2, '0')}:${updateTime.minute.toString().padLeft(2, '0')}:${updateTime.second.toString().padLeft(2, '0')}";
      lastUpdatedNotifier.value = formatted;
      await _saveToCache();
      statusMessageNotifier.value = "同步完成";
    } catch (e) {
      statusMessageNotifier.value = "同步發生異常";
      syncErrorNotifier.value = "同步發生異常: $e";
      // debugPrint("Historical Fetch Error: $e");
    } finally {
      isLoadingNotifier.value = false;
      // debugPrint('[HS] fetchAllData 總耗時 (+${sw.elapsedMilliseconds}ms)');
    }
  }

  // --- 修正後的預覽名次抓取邏輯 (加強錯誤防護版) ---
  Future<Map<String, Map<String, String>>> _fetchPreviewRanks(
    String username,
    String password,
    void Function(int done, int total)? onProgress,
  ) async {
    Map<String, Map<String, String>> results = {};

    final ioClient = HttpClient()
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;
    final client = IOClient(ioClient);

    Map<String, String> cookieJar = {};

    try {
      // 進行身分驗證，限制在 5 秒內完成，超時或失敗則跳過預覽名次抓取
      try {
        await Future(() async {
          await _sendRequest(
            client,
            'GET',
            "https://epp.nsysu.edu.tw/Index.php?ccsForm=Login",
            cookieJar,
          );

          final loginReq =
              http.Request(
                  'POST',
                  Uri.parse("https://epp.nsysu.edu.tw/Index.php?ccsForm=Login"),
                )
                ..followRedirects = false
                ..headers.addAll({
                  "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64)",
                  "Content-Type": "application/x-www-form-urlencoded",
                  "Cookie": _generateCookieHeader(cookieJar),
                })
                ..bodyFields = {
                  "login_name": username,
                  "login_password": password,
                  "login_identity": "3",
                  "Button_DoLogin": "登入",
                };

          final loginRes = await http.Response.fromStream(
            await client.send(loginReq),
          );
          _updateCookieJar(loginRes, cookieJar);
        }).timeout(const Duration(seconds: 5));
      } catch (e) {
        // debugPrint("⚠️ 預覽名次身分驗證超時或失敗 (5秒)，跳過名次抓取: $e");
        return results;
      }

      final gridRes = await _sendRequest(
        client,
        'GET',
        "https://epp.nsysu.edu.tw/Apps/SCOList.php?SCO_MAINPageSize=100&SCO_MAINPage=1",
        cookieJar,
      );

      var doc = parser.parse(
        utf8.decode(gridRes.bodyBytes, allowMalformed: true),
      );

      var gridTable = doc.querySelector('#ContentSCO_MAIN table.Grid');
      if (gridTable == null) {
        gridTable = doc.querySelector('table.Grid');
      }

      Map<String, List<String>> groupToCourseCodes = {};

      if (gridTable != null) {
        var rows = gridTable.querySelectorAll('tr');
        for (var row in rows) {
          if (row.classes.contains('Caption') ||
              row.classes.contains('Separator')) {
            continue;
          }
          var tds = row.querySelectorAll('td');
          if (tds.length < 5) continue;

          String year = tds[0].text
              .replaceAll(RegExp(r'[\s\u00A0]+'), '')
              .trim();
          if (year.isEmpty || int.tryParse(year) == null) continue;

          String semText = tds[1].text;
          String sem = "1";
          if (semText.contains("二") || semText.contains("下")) {
            sem = "2";
          } else if (semText.contains("暑")) {
            sem = "3";
          }

          String courseCode = tds[3].text
              .replaceAll(RegExp(r'[\s\u00A0]+'), '')
              .trim();
          if (courseCode.isEmpty) continue;

          String key = "$year-$sem";
          groupToCourseCodes.putIfAbsent(key, () => []).add(courseCode);
        }
      }

      // 篩選出最新（排序後最上面）的 3 個不同學年度學期
      List<String> sortedKeys = groupToCourseCodes.keys.toList();
      sortedKeys.sort((a, b) {
        var partsA = a.split('-');
        var partsB = b.split('-');
        int yA = int.parse(partsA[0]);
        int yB = int.parse(partsB[0]);
        if (yA != yB) return yB.compareTo(yA);
        int sA = int.parse(partsA[1]);
        int sB = int.parse(partsB[1]);
        return sB.compareTo(sA);
      });

      List<String> targetKeys = sortedKeys.take(3).toList();

      List<MapEntry<String, String>> fetchTasks = [];
      for (String key in targetKeys) {
        var codes = groupToCourseCodes[key] ?? [];
        int limit = codes.length < 2 ? codes.length : 2;
        for (int i = 0; i < limit; i++) {
          fetchTasks.add(MapEntry(key, codes[i]));
        }
      }

      int total = fetchTasks.length;
      int done = 0;

      RegExp commentRegExp = RegExp(r'<!--([\s\S]*?)-->', dotAll: true);
      Set<String> completedGroups = {};

      for (var task in fetchTasks) {
        String key = task.key;
        String courseCode = task.value;

        if (completedGroups.contains(key)) {
          done++;
          onProgress?.call(done, total);
          continue;
        }

        try {
          String url =
              "https://epp.nsysu.edu.tw/Apps/CRSView.php?CRS_COD=$courseCode";
          final res = await _sendRequest(client, 'GET', url, cookieJar);
          String html = utf8.decode(res.bodyBytes, allowMalformed: true);

          for (var m in commentRegExp.allMatches(html)) {
            String block = m.group(1)!;
            if (!block.contains('class="Row"')) continue;

            var tr = parser.parseFragment(block).querySelector('tr.Row');
            if (tr == null) continue;

            var tds = tr.querySelectorAll('td');
            if (tds.length < 9) continue;

            String? parsedKey = _safeParseSemester(tds[0].text.trim());
            if (parsedKey == null) continue;

            if (parsedKey == key) {
              String rank = tds[7].text.trim();
              String classSize = tds[8].text.trim();
              results[key] = {"rank": rank, "classSize": classSize};
              completedGroups.add(key);
              break;
            }
          }
        } catch (e) {
          // debugPrint("❌ 抓取課歷名次錯誤 (課號 $courseCode): $e");
        }

        done++;
        onProgress?.call(done, total);
      }
    } finally {
      client.close();
    }

    return results;
  }

  // --- 輔助：安全的學期解析函式 ---
  static String? _safeParseSemester(String raw) {
    try {
      // 1. 強力清理：移除 &nbsp;, \u00A0 (non-breaking space), 以及所有空白
      // RegExp(r'[\s\u00A0]+') 可以匹配標準空白、Tab、換行以及 &nbsp; 產生的字元
      String text = raw
          .replaceAll(RegExp(r'[\s\u00A0]+'), '')
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
      // debugPrint("⚠️ 解析學期字串錯誤: $raw ($e)");
      return null;
    }
  }

  // --- 通用請求 ---
  Future<http.Response> _sendRequest(
    http.Client client,
    String method,
    String url,
    Map<String, String> cookieJar,
  ) async {
    final req = http.Request(method, Uri.parse(url));
    req.followRedirects = false;
    req.headers.addAll({
      "User-Agent":
          "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
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

      List<String> ignoreKeys = [
        'expires',
        'path',
        'domain',
        'secure',
        'httponly',
        'samesite',
        'max-age',
      ];

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

  static int _chineseToNumber(String input) {
    // 如果原本就是阿拉伯數字 (e.g., "112")，直接回傳
    if (int.tryParse(input) != null) return int.parse(input);

    const nums = {
      '○': 0,
      '〇': 0,
      '零': 0,
      '一': 1,
      '二': 2,
      '三': 3,
      '四': 4,
      '五': 5,
      '六': 6,
      '七': 7,
      '八': 8,
      '九': 9,
    };
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
  Future<({List<CourseScore> courses, ScoreSummary summary})?>
  _fetchSingleSemester(
    String cookies,
    String year,
    String sem, {
    bool debugPrintRawHtml = false,
  }) async {
    try {
      final queryUrl = Uri.parse(
        "https://selcrs.nsysu.edu.tw/scoreqry/sco_query.asp?ACTION=804&KIND=2&LANGS=cht",
      );
      final response = await _client.post(
        queryUrl,
        headers: {
          "User-Agent":
              "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
          "Content-Type": "application/x-www-form-urlencoded",
          "Cookie": cookies,
          "Referer": "https://selcrs.nsysu.edu.tw/scoreqry/sco_query.asp",
        },
        body: {"SYEAR": year, "SEM": sem},
      );

      // 若出現登錄密碼錯誤的特定標籤與訊息，丟出特定 Exception
      final bodyText = response.body;
      if (bodyText.contains(
            '&#30331;&#37636;&#23494;&#30908;&#37679;&#35492;&#65292;&#28961;&#27861;&#20351;&#29992;&#35531;&#37325;&#26032;&#30331;&#37636;&#65281;',
          ) ||
          bodyText.contains('登錄密碼錯誤，無法使用請重新登錄！')) {
        if (debugPrintRawHtml) {
          // debugPrint("⚠️ [學期重試] 第一學期抓取偵測到密碼錯誤！原始碼如下：\n$bodyText");
        }
        throw LoginPasswordErrorException("登錄密碼錯誤");
      }

      String? rawCookie = response.headers['set-cookie'];
      // 檢查是否包含登入失敗的關鍵字 (考慮到 BIG5 亂碼，改用較保險的判斷)
      bool isLoginFailed =
          response.body.contains("不符") ||
          response.body.contains("錯誤") ||
          response.body.contains("SCO_QUERY.asp");

      if (response.statusCode != 200 || isLoginFailed) {
        if (debugPrintRawHtml) {
          // debugPrint(
          //   "⚠️ [學期重試] 第一學期抓取狀態碼異常或偵測到失敗字眼。狀態碼: ${response.statusCode}。原始碼：\n$bodyText",
          // );
        }
        return null;
      }
      String content = utf8.decode(response.bodyBytes, allowMalformed: true);
      if (content.contains("請重新登入")) {
        if (debugPrintRawHtml) {
          debugPrint("⚠️ [學期重試] 第一學期抓取偵測到 '請重新登入'。原始碼：\n$content");
        }
        return null;
      }
      var parsed = await Isolate.run(() => _parseHtml(content));
      return parsed.courses.isEmpty ? null : parsed;
    } on LoginPasswordErrorException {
      rethrow;
    } catch (e) {
      if (debugPrintRawHtml) {
        debugPrint("⚠️ [學期重試] 第一學期抓取發生異常: $e");
      }
      return null;
    }
  }

  // (原有) 登入
  Future<String?> _loginToScoreSystem(String username, String password) async {
    final loginUrl = Uri.parse(
      "https://selcrs.nsysu.edu.tw/scoreqry/sco_query_prs_sso2.asp",
    );
    final String base64md5Password = Utils.base64md5(password);

    try {
      final response = await _client.post(
        loginUrl,
        headers: {
          "Content-Type": "application/x-www-form-urlencoded",
          "User-Agent":
              "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
        },
        body: {
          'SID': username.toUpperCase(),
          'PASSWD': base64md5Password,
          'ACTION': '0',
          'INTYPE': '1',
        },
      );
      String? rawCookie = response.headers['set-cookie'];
      // 檢查是否包含登入失敗的關鍵字 (考慮到 BIG5 亂碼，改用較保險的判斷)
      bool isLoginFailed =
          response.body.contains("不符") ||
          response.body.contains("錯誤") ||
          response.body.contains("SCO_QUERY.asp");

      if (rawCookie != null && !isLoginFailed) {
        return rawCookie;
      }
    } catch (e) {
      // debugPrint("Login Error: $e");
    }
    return null;
  }

  void _processAndNotify(Map<String, dynamic> rawJson) {
    Map<String, List<CourseScore>> cMap = {};
    Map<String, ScoreSummary> sMap = {};
    Map<String, Map<String, String>> pMap = {};

    rawJson.forEach((key, value) {
      var cList = (value['courses'] as List)
          .map(
            (i) => CourseScore(
              id: i['id'],
              name: i['name'],
              credits: i['credits'],
              score: i['score'],
            ),
          )
          .toList();

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
      // // debugPrint(pMap);
    });

    _processAndNotifyFromMaps(cMap, sMap, pMap);
  }

  void _processAndNotifyFromMaps(
    Map<String, List<CourseScore>> cMap,
    Map<String, ScoreSummary> sMap,
    Map<String, Map<String, String>> pMap,
  ) {
    // debugPrint("\n====== 🟢 開始執行 _processAndNotifyFromMaps ======");

    // 1. 先印出三張表所有的 Keys，確認格式是否一致 (例如 "112-1" vs "112-01")
    // debugPrint("🔍 [cMap Keys] (課程): ${cMap.keys.toList()}");
    // debugPrint("🔍 [sMap Keys] (摘要): ${sMap.keys.toList()}");
    // debugPrint("🔍 [pMap Keys] (預覽): ${pMap.keys.toList()}");

    // 顯示 pMap 的詳細內容，確認是否有抓到東西
    if (pMap.isNotEmpty) {
      // debugPrint("📋 [pMap 詳細內容]:");
      // pMap.forEach((k, v) => debugPrint("   -> Key: $k, Value: $v"));
    } else {
      // debugPrint("⚠️ [pMap] 是空的！(抓取預覽名次可能失敗)");
    }

    // ===== 核心合併邏輯 =====
    // debugPrint("\n🔄 開始合併 pMap 到 sMap...");

    pMap.forEach((key, preview) {
      // debugPrint("   👉 正在處理預覽 Key: [$key]");

      // 檢測 sMap 是否有這個 Key
      if (!sMap.containsKey(key)) {
        // debugPrint("      ⚠️ sMap 找不到 [$key]，正在補建空資料...");
        sMap[key] = ScoreSummary(); // 建立空的 Summary
        // 順便補上空的課程列表，避免 UI 端報錯
        if (!cMap.containsKey(key)) {
          cMap[key] = [];
          // debugPrint("      ⚠️ cMap 也找不到 [$key]，已補上空列表");
        }
      } else {
        // debugPrint("      ✅ sMap 已存在 [$key]，準備檢查是否需要覆蓋...");
      }

      final summary = sMap[key]!;

      // 印出合併前的狀態
      // debugPrint( "      [合併前] Rank: ${summary.rank}, ClassSize: ${summary.classSize}",);

      // 邏輯判斷：只有正式成績是 "-" 或空字串時才補
      bool updated = false;

      if ((summary.rank == "-" || summary.rank.isEmpty) &&
          preview['rank'] != null) {
        // debugPrint("      ⚡ 更新 Rank: ${summary.rank} -> ${preview['rank']}");
        summary.rank = preview['rank']!;
        updated = true;
      }

      if ((summary.classSize == "-" || summary.classSize.isEmpty) &&
          preview['classSize'] != null) {
        // debugPrint("      ⚡ 更新 ClassSize: ${summary.classSize} -> ${preview['classSize']}",);
        summary.classSize = preview['classSize']!;
        updated = true;
      }

      if (!updated) {
        // debugPrint("      💤 未進行任何更新 (可能正式成績已有值，或預覽資料為空)");
      }
    });

    // debugPrint("✅ 合併作業結束。\n");

    // ===== 更新 Notifier =====
    coursesNotifier.value = cMap;
    summaryNotifier.value = sMap;
    previewRanksNotifier.value = pMap;

    // ===== 有效學年 / 學期 =====
    Set<String> ySet = {};
    Map<String, List<String>> semMap = {};

    // 這裡改用合併後的 keys (包含 cMap 和 sMap)
    Set<String> allKeys = {...cMap.keys, ...sMap.keys};
    // debugPrint("📊 最終有效的 Keys (顯示在選單): $allKeys");

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

    // debugPrint("====== 🏁 流程結束 ======\n");
  }

  // (原有) 解析 HTML
  static ({List<CourseScore> courses, ScoreSummary summary}) _parseHtml(
    String htmlContent,
  ) {
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

        if (int.tryParse(credit) == null && double.tryParse(credit) == null)
          continue;
        if (score.contains("成績") || possibleName.contains("科目名稱")) continue;

        if (possibleId.length > 2) {
          courses.add(
            CourseScore(
              id: possibleId,
              name: possibleName,
              credits: credit,
              score: score,
            ),
          );
        }
      }
    }

    var allTds = document.getElementsByTagName('td');
    for (var td in allTds) {
      String text = td.text.trim();
      if (text.startsWith("修習學分："))
        summary.creditsTaken = text.replaceAll("修習學分：", "").trim();
      else if (text.startsWith("平均分數："))
        summary.average = text.replaceAll("平均分數：", "").trim();
      else if (text.startsWith("本學期名次："))
        summary.rank = text.replaceAll("本學期名次：", "").trim();
      else if (text.startsWith("實得學分："))
        summary.creditsEarned = text.replaceAll("實得學分：", "").trim();
      else if (text.startsWith("全班人數："))
        summary.classSize = text.replaceAll("全班人數：", "").trim();
    }

    return (courses: courses, summary: summary);
  }

  void dispose() {
    try {
      _client.close();
    } catch (_) {}
  }
}
