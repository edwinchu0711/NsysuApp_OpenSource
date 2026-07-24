// 檔案名稱：course_selection_schedule_page.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'course_selection/course_selection_page.dart';
import 'course_exception/course_exception_handling_page.dart'; // 引入異常處理頁面
import '../../services/course_query_service.dart'; // 請確認路徑是否正確
import '../services/offline_error_handler.dart';
import '../theme/app_theme.dart';
import '../theme/layout_style_notifier.dart';
import '../../utils/utils.dart';
import '../widgets/glass/glass_card.dart';
import '../widgets/glass/glass_page_scaffold.dart';
import '../services/http_client_factory.dart';

bool test = false;

enum SelectionState {
  open, // 正常開放選課
  closed, // 選課系統關閉 (唯讀模式)
  needConfirmation, // 需要確認 (例如：必修確認階段)
  error, // 發生錯誤
}

class CourseSelectionSchedulePage extends StatefulWidget {
  const CourseSelectionSchedulePage({Key? key}) : super(key: key);

  @override
  State<CourseSelectionSchedulePage> createState() =>
      _CourseSelectionSchedulePageState();
}

class _CourseSelectionSchedulePageState
    extends State<CourseSelectionSchedulePage> {
  // --- 原有的時程表資料變數 ---
  bool _isLoading = true;
  String _dataUpdateTime = "";
  List<MapEntry<String, dynamic>> _mainList = [];
  List<MapEntry<String, dynamic>> _bottomList = [];
  List<String> _activeItemKeys = [];

  final Set<String> _bottomItems = {'必修課程確認', '系所輔導學生選課', '超修學分申請'};

  // --- 【新增】系統即時狀態檢查變數 ---
  bool _isCheckingSystem = true; // 是否正在連線檢查
  bool _isSystemOpen = false; // 系統是否實際開放
  String _systemStatusMessage = "檢查系統狀態中...";
  bool _experimentalAbnormalEnabled = false;

  // --- 連線設定 ---
  final http.Client _client = createHttpClient();
  final String _baseUrl = "https://selcrs.nsysu.edu.tw"; // 學校系統基底網址

  @override
  void initState() {
    super.initState();
    _loadExperimentalSetting();
    // 1. 載入 JSON 時程表 (顯示列表用)
    _checkAndLoadData();
    // 2. 直接連線學校檢查狀態 (顯示按鈕用)
    _checkRealTimeSystemStatus();
  }

  Future<void> _loadExperimentalSetting() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _experimentalAbnormalEnabled =
            prefs.getBool('experimental_abnormal_handling_enabled') ?? false;
      });
    }
  }

  @override
  void dispose() {
    _client.close(); // 關閉連線
    super.dispose();
  }

  DateTime? _getConfirmationEndTime() {
    // 合併搜尋 mainList 和 bottomList
    final allItems = [..._mainList, ..._bottomList];

    // 尋找 Key 包含 "選課確認" 的項目 (ex: "選課確認", "必修課程確認" 等)
    // 根據你的需求，如果 JSON Key 明確叫做 "選課確認"，可以精確比對
    // 這裡使用模糊比對 "確認" 且包含 "選課" 或 "課程" 來涵蓋 "必修課程確認"
    try {
      final entry = allItems.firstWhere(
        (e) =>
            e.key.contains("選課確認") ||
            (e.key.contains("課程") && e.key.contains("確認")),
        orElse: () => const MapEntry("", {}),
      );

      if (entry.key.isEmpty) return null; // 找不到

      final content = entry.value as Map<String, dynamic>;
      final String endTimeStr = content['結束時間'] ?? "";

      return _parseTwDate(endTimeStr);
    } catch (e) {
      return null;
    }
  }

  // ==========================================================
  // 【核心修改】實作你要求的伺服器檢查邏輯
  // ==========================================================
  Future<void> _checkRealTimeSystemStatus({bool forceRefresh = false}) async {
    if (!mounted) return;

    if (OfflineErrorHandler.isOffline) {
      setState(() {
        _isSystemOpen = false;
        _systemStatusMessage = "離線模式下無法使用";
        _isCheckingSystem = false;
      });
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();

      if (!forceRefresh) {
        final int lastCheckMillis =
            prefs.getInt('course_system_status_last_check') ?? 0;
        if (lastCheckMillis > 0) {
          final DateTime lastCheck = DateTime.fromMillisecondsSinceEpoch(
            lastCheckMillis,
          );
          final DateTime now = DateTime.now();

          final bool isSameDay =
              lastCheck.year == now.year &&
              lastCheck.month == now.month &&
              lastCheck.day == now.day;
          final bool isSameHour = lastCheck.hour == now.hour;
          final bool isSameHalfHour =
              (lastCheck.minute ~/ 30) == (now.minute ~/ 30);

          if (isSameDay && isSameHour && isSameHalfHour) {
            final bool lastOpen =
                prefs.getBool('course_system_status_is_open') ?? false;
            final String lastMsg =
                prefs.getString('course_system_status_message') ?? "目前非選課時段";
            setState(() {
              _isSystemOpen = lastOpen;
              _systemStatusMessage = lastMsg;
              _isCheckingSystem = false;
            });
            return;
          }
        }
      }

      // 初始化狀態
      setState(() {
        _isCheckingSystem = true;
        _systemStatusMessage = "正在連線學校系統確認...";
        _isSystemOpen = false;
      });

      // debugPrint("🔍 [偵錯] 開始執行 _checkRealTimeSystemStatus...");
      String studentId = (prefs.getString('username') ?? "").trim();
      String password = (prefs.getString('password') ?? "").trim();

      // 如果沒有帳密，就不檢查了，直接視為未開放
      if (studentId.isEmpty || password.isEmpty) {
        throw "未登入 (請先至設定頁面設定帳號)";
      }

      // 1. 取得 SSO Cookie
      String? cookie = await _loginViaSSO2(studentId, password);
      if (!mounted) return;

      if (cookie == null) {
        throw "SSO 登入失敗 (Cookie 為空)";
      }
      // debugPrint("✅ [偵錯] 登入成功，Cookie 取得");

      // 2. Request main_frame.asp 取得參數
      final mainFrameUrl = Uri.parse("$_baseUrl/menu4/main_frame.asp");
      // debugPrint("🔍 [偵錯] 請求 MainFrame: $mainFrameUrl");

      final mainFrameResponse = await _client.get(
        mainFrameUrl,
        headers: {
          "Cookie": cookie,
          "User-Agent":
              "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
        },
      );
      if (!mounted) return;

      String mainFrameBody = utf8.decode(
        mainFrameResponse.bodyBytes,
        allowMalformed: true,
      );

      // 解析 frame src 中的參數 (Studfun.asp?DEG_COD=B&...)
      RegExp paramRegex = RegExp(
        r'src="Studfun\.asp\?([^"]+)"',
        caseSensitive: false,
      );
      Match? paramMatch = paramRegex.firstMatch(mainFrameBody);

      String studFunParams = "";
      if (paramMatch != null) {
        studFunParams = paramMatch.group(1) ?? "";
        // debugPrint("✅ [偵錯] 成功抓取參數串: $studFunParams");
      } else {
        debugPrint("⚠️ [偵錯] 在 main_frame 無法抓取參數");
      }

      // 3. Request Studfun.asp (帶參數)
      String studFunUrlString = "$_baseUrl/menu4/Studfun.asp";
      if (studFunParams.isNotEmpty) {
        studFunUrlString += "?$studFunParams";
      }

      final studFunUrl = Uri.parse(studFunUrlString);
      // debugPrint("🔍 [偵錯] 請求選單頁面: $studFunUrl");

      final response = await _client.get(
        studFunUrl,
        headers: {
          "Cookie": cookie,
          "User-Agent":
              "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
        },
      );
      if (!mounted) return;

      String body = utf8.decode(response.bodyBytes, allowMalformed: true);

      // 4. 尋找第一個 <a> 連結
      RegExp hrefReg = RegExp(r'<a\s+href="([^"]+)"', caseSensitive: false);
      Match? match = hrefReg.firstMatch(body);

      if (match == null) {
        debugPrint("❌ [偵錯] 找不到選課入口連結");
        throw "無法讀取選課選單 (無連結)";
      }

      String firstLink = match.group(1) ?? "";
      // debugPrint("🔗 [偵錯] 抓到的第一個連結為: [$firstLink]");

      // 5. 判斷選課是否開放
      // 如果連結包含 query/result.asp，代表是「查詢系統」(未開放)
      // 如果連結包含 select_bar.asp 或其他，代表是「選課系統」(開放中)
      bool isOpen = !firstLink.contains("query/result.asp");

      await prefs.setInt(
        'course_system_status_last_check',
        DateTime.now().millisecondsSinceEpoch,
      );
      await prefs.setBool('course_system_status_is_open', isOpen);
      await prefs.setString(
        'course_system_status_message',
        isOpen ? "選課系統開放中" : "目前非選課時段",
      );

      setState(() {
        _isSystemOpen = isOpen;
        _systemStatusMessage = isOpen ? "選課系統開放中" : "目前非選課時段";
        _isCheckingSystem = false;
      });
    } catch (e) {
      if (!mounted) return;
      debugPrint("❌ [偵錯] 檢查流程發生錯誤: $e");
      setState(() {
        _isSystemOpen = false;
        // 錯誤訊息處理，把 Exception: 字樣拿掉比較好看
        String errorMsg = e.toString().replaceAll("Exception:", "").trim();
        // 如果是未登入，顯示比較友善的訊息
        if (errorMsg.contains("未登入")) {
          _systemStatusMessage = "未登入帳號";
        } else {
          _systemStatusMessage = "無法確認狀態 ($errorMsg)";
        }
        _isCheckingSystem = false;
      });
    }
  }

  // --- 檢查快取與載入 ---
  Future<void> _checkAndLoadData({bool forceRefresh = false}) async {
    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();

      if (!forceRefresh) {
        final String? cachedJson = prefs.getString('course_schedule_cache');
        final int? lastFetchMillis = prefs.getInt('course_schedule_last_fetch');

        if (cachedJson != null && lastFetchMillis != null) {
          final DateTime lastFetchTime = DateTime.fromMillisecondsSinceEpoch(
            lastFetchMillis,
          );
          final Duration diff = DateTime.now().difference(lastFetchTime);

          if (diff.inDays < 1) {
            final decoded = jsonDecode(cachedJson);
            if (decoded is Map) {
              _processData(Map<String, dynamic>.from(decoded));
            }
            return;
          }
        }
      }

      // 檢查網路連線狀態
      dynamic connectivityResult = await (Connectivity().checkConnectivity());
      bool isNone = (connectivityResult is List)
          ? connectivityResult.contains(ConnectivityResult.none)
          : connectivityResult == ConnectivityResult.none;

      if (isNone) {
        throw "no_network";
      }

      // 同時向學校網站與 GitHub 請求資料
      final fetchedData = await fetchScheduleFromNsysu();
      Map<String, dynamic> githubData = {};
      try {
        githubData = await fetchScheduleFromGithub();
      } catch (e) {
        debugPrint("無法取得 GitHub 選課時程: $e");
      }

      // 合併資料
      final mergedData = _mergeSchedules(fetchedData, githubData);

      // 將合併後的新資料存入本機快取
      await prefs.setString('course_schedule_cache', jsonEncode(mergedData));
      await prefs.setInt(
        'course_schedule_last_fetch',
        DateTime.now().millisecondsSinceEpoch,
      );

      // 呼叫資料處理，更新畫面
      _processData(mergedData);
    } catch (e) {
      debugPrint("載入錯誤: $e");
      if (mounted) {
        final prefs = await SharedPreferences.getInstance();
        final String? cachedJson = prefs.getString('course_schedule_cache');
        if (cachedJson != null) {
          final decoded = jsonDecode(cachedJson);
          _processData(Map<String, dynamic>.from(decoded));
        }

        // 判斷是否為網路連線錯誤
        bool isNetworkError = e == "no_network";
        if (!isNetworkError) {
          String errStr = e.toString().toLowerCase();
          if (errStr.contains('socketexception') ||
              errStr.contains('clientexception') ||
              errStr.contains('handshakeexception') ||
              errStr.contains('timeout') ||
              errStr.contains('failed host lookup') ||
              errStr.contains('connection failed') ||
              errStr.contains('connection refused') ||
              errStr.contains('network') ||
              errStr.contains('xmlhttprequest')) {
            isNetworkError = true;
          }
        }

        if (isNetworkError) {
          if (!OfflineErrorHandler.isOffline) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("目前沒有連線到網路"),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 2),
              ),
            );
          }
          setState(() => _isLoading = false);
        } else {
          // 沒有網路問題但抓不到資料，更新時間並提示
          setState(() {
            _dataUpdateTime = DateFormat(
              'yyyy/MM/dd HH:mm',
            ).format(DateTime.now());
            _isLoading = false;
          });
          if (!OfflineErrorHandler.isOffline) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("目前抓取不到選課時程資料"),
                backgroundColor: Colors.orange,
                duration: const Duration(seconds: 2),
              ),
            );
          }
        }
      }
    }
  }

  // --- 解析台灣格式日期字串 (通用化解析，相容多種格式) ---
  DateTime? _parseTwDate(String? dateStr) {
    if (dateStr == null || dateStr.trim().isEmpty) return null;
    try {
      final matches = RegExp(
        r'\d+',
      ).allMatches(dateStr).map((m) => int.parse(m.group(0)!)).toList();

      if (matches.length == 5) {
        int year = matches[0];
        if (year < 1000) {
          year += 1911; // 民國年轉西元年
        }
        int month = matches[1];
        int day = matches[2];
        int hour = matches[3];
        int minute = matches[4];
        return DateTime(year, month, day, hour, minute);
      } else if (matches.length == 4) {
        int year = DateTime.now().year;
        int month = matches[0];
        int day = matches[1];
        int hour = matches[2];
        int minute = matches[3];
        return DateTime(year, month, day, hour, minute);
      }
    } catch (e) {
      debugPrint("日期解析失敗: $dateStr, error: $e");
    }
    return null;
  }

  // --- 判斷名稱字元是否有兩個字以上相同 ---
  bool _hasTwoOrMoreCommonChars(String name1, String name2) {
    final set1 = name1.split('').toSet();
    final set2 = name2.split('').toSet();
    set1.removeWhere((c) => c.trim().isEmpty);
    set2.removeWhere((c) => c.trim().isEmpty);
    final intersection = set1.intersection(set2);
    return intersection.length >= 2;
  }

  // --- 合併原有的選課時程與 GitHub 的選課時程 ---
  Map<String, dynamic> _mergeSchedules(
    Map<String, dynamic> original,
    Map<String, dynamic> github,
  ) {
    final Map<String, dynamic> originalData = original['data'] != null
        ? Map<String, dynamic>.from(original['data'])
        : {};

    github.forEach((gitKey, gitVal) {
      if (gitVal is Map<String, dynamic> || gitVal is Map) {
        final Map<String, dynamic> gitItem = Map<String, dynamic>.from(gitVal);
        final String? gitStartStr = gitItem['開始時間'];
        final String? gitEndStr = gitItem['結束時間'];

        final DateTime? gitStart = _parseTwDate(gitStartStr);
        final DateTime? gitEnd = _parseTwDate(gitEndStr);

        bool isDuplicate = false;

        originalData.forEach((origKey, origVal) {
          if (origVal is Map<String, dynamic> || origVal is Map) {
            final Map<String, dynamic> origItem = Map<String, dynamic>.from(
              origVal,
            );
            final String? origStartStr = origItem['開始時間'];
            final String? origEndStr = origItem['結束時間'];

            final DateTime? origStart = _parseTwDate(origStartStr);
            final DateTime? origEnd = _parseTwDate(origEndStr);

            // 開始時間和結束時間都一樣，且名稱有兩個字以上相同
            if (origStart == gitStart && origEnd == gitEnd) {
              if (_hasTwoOrMoreCommonChars(origKey, gitKey)) {
                isDuplicate = true;
              }
            }
          }
        });

        if (!isDuplicate) {
          originalData[gitKey] = gitItem;
        }
      }
    });

    return {
      'data': originalData,
      'metadata':
          original['metadata'] ??
          {'update_time': DateTime.now().toIso8601String()},
    };
  }

  // --- 資料處理核心邏輯 (按開始時間排序，棄選時間置末) ---
  void _processData(Map<String, dynamic> fullData) {
    if (!mounted) return;

    final Map<String, dynamic> rawData = fullData['data'] != null
        ? Map<String, dynamic>.from(fullData['data'])
        : {};
    final Map<String, dynamic> metadata = fullData['metadata'] != null
        ? Map<String, dynamic>.from(fullData['metadata'])
        : {};

    String timeStr = "未知";
    dynamic updateTime = metadata['update_time'];
    if (updateTime != null) {
      try {
        DateTime dt = DateTime.parse(updateTime.toString());
        timeStr = DateFormat('yyyy/MM/dd HH:mm').format(dt);
      } catch (e) {
        /* ignore */
      }
    } else {
      timeStr = DateFormat('yyyy/MM/dd HH:mm').format(DateTime.now());
    }

    List<MapEntry<String, dynamic>> rawMain = [];
    List<MapEntry<String, dynamic>> rawBottom = [];

    rawData.forEach((key, value) {
      if (key == '更新時間') return;
      if (_bottomItems.contains(key)) {
        rawBottom.add(MapEntry(key, value));
      } else {
        rawMain.add(MapEntry(key, value));
      }
    });

    MapEntry<String, dynamic>? dropEntry;
    List<MapEntry<String, dynamic>> sortedMain = [];

    for (var entry in rawMain) {
      if (entry.key == '棄選時間') {
        dropEntry = entry;
      } else {
        sortedMain.add(entry);
      }
    }

    // 按開始時間升序排列
    sortedMain.sort((a, b) {
      final Map<String, dynamic> contentA = a.value as Map<String, dynamic>;
      final Map<String, dynamic> contentB = b.value as Map<String, dynamic>;

      final DateTime? startA = _parseTwDate(contentA['開始時間']);
      final DateTime? startB = _parseTwDate(contentB['開始時間']);

      if (startA == null && startB == null) return 0;
      if (startA == null) return 1;
      if (startB == null) return -1;

      int timeComp = startA.compareTo(startB);
      if (timeComp != 0) return timeComp;

      // 當開始時間相同時：只有「開始時間」而沒有「結束時間」的排在前面
      final DateTime? endA = _parseTwDate(contentA['結束時間']);
      final DateTime? endB = _parseTwDate(contentB['結束時間']);
      if (endA == null && endB != null) return -1;
      if (endA != null && endB == null) return 1;

      return a.key.compareTo(b.key);
    });

    if (dropEntry != null) {
      sortedMain.add(dropEntry);
    }

    rawMain = sortedMain;

    rawBottom.sort((a, b) {
      final Map<String, dynamic> contentA = a.value as Map<String, dynamic>;
      final Map<String, dynamic> contentB = b.value as Map<String, dynamic>;

      final DateTime? startA = _parseTwDate(contentA['開始時間']);
      final DateTime? startB = _parseTwDate(contentB['開始時間']);

      if (startA == null && startB == null) return 0;
      if (startA == null) return 1;
      if (startB == null) return -1;

      int timeComp = startA.compareTo(startB);
      if (timeComp != 0) return timeComp;

      final DateTime? endA = _parseTwDate(contentA['結束時間']);
      final DateTime? endB = _parseTwDate(contentB['結束時間']);
      if (endA == null && endB != null) return -1;
      if (endA != null && endB == null) return 1;

      return a.key.compareTo(b.key);
    });

    List<String> activeKeys = [];
    DateTime now = DateTime.now();

    for (int i = 0; i < rawMain.length; i++) {
      final entry = rawMain[i];
      final content = entry.value as Map<String, dynamic>;

      DateTime? start = _parseTwDate(content['開始時間']);
      DateTime? end = _parseTwDate(content['結束時間']);

      if (start == null) continue;

      bool isActive = false;

      if (end != null) {
        if (now.isAfter(start) && now.isBefore(end)) {
          isActive = true;
        }
      } else {
        DateTime? nextStart;
        if (i + 1 < rawMain.length) {
          nextStart = _parseTwDate((rawMain[i + 1].value as Map)['開始時間']);
        }

        if (nextStart != null) {
          if (now.isAfter(start) && now.isBefore(nextStart)) {
            isActive = true;
          }
        } else {
          if (now.isAfter(start)) {
            isActive = true;
          }
        }
      }

      if (isActive) {
        activeKeys.add(entry.key);
      }
    }

    setState(() {
      _dataUpdateTime = timeStr;
      _mainList = rawMain;
      _bottomList = rawBottom;
      _activeItemKeys = activeKeys;
      _isLoading = false;
    });
  }

  /// 格式化顯示用日期字串，使用 DateTime 物件輸出 MM/DD HH:mm（不含年份）
  /// 若無法解析則 fallback 到原始字串（移除年份前綴）
  String _formatDisplayDate(String rawText, DateTime? dateTime) {
    if (rawText.isEmpty) return "";
    if (dateTime == null) {
      return _removeYear(rawText);
    }
    final month = dateTime.month.toString().padLeft(2, '0');
    final day = dateTime.day.toString().padLeft(2, '0');
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return "$month/$day $hour:$minute";
  }

  String _removeYear(String text) {
    if (text.isEmpty) return "";
    // 移除 "115年" 格式
    String clean = text.replaceAll(RegExp(r'\d+年'), '').trim();
    // 移除 "115/" 或 "115." 開頭的年份前綴
    final prefixReg = RegExp(r'^\d+\s*[\./ ]\s*');
    clean = clean.replaceAll(prefixReg, '').trim();
    return clean;
  }

  // 跳轉函式
  void _navigateToCourseSelection({bool enableQuery = true}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CourseSelectionPage(enableQuery: enableQuery),
      ),
    );
  }

  Future<Map<String, dynamic>> fetchScheduleFromNsysu() async {
    try {
      final url = Uri.parse('https://selcrs.nsysu.edu.tw/');
      final client = createHttpClient();
      final response = await client.get(url);
      client.close();

      final String htmlContent = response.body;

      final RegExp regExp = RegExp(
        r'<tr><td><div[^>]*>(.*?)<\/div><\/td><td><div[^>]*>：(.*?)<\/div><\/td><\/tr>',
      );

      final matches = regExp.allMatches(htmlContent);

      Map<String, dynamic> dataMap = {};

      for (var match in matches) {
        final title = match.group(1)?.trim() ?? '';
        final timeStr = match.group(2)?.replaceAll('&nbsp;', ' ').trim() ?? '';

        String startTimeStr = "";
        String endTimeStr = "";

        if (timeStr.contains('~')) {
          final timeParts = timeStr.split('~');
          startTimeStr = _formatNsysuTimeToOldStyle(timeParts[0].trim());
          endTimeStr = _formatNsysuTimeToOldStyle(timeParts[1].trim());
        } else {
          startTimeStr = _formatNsysuTimeToOldStyle(timeStr.trim());
        }

        // 轉換為 _processData 預期的格式
        dataMap[title] = {'開始時間': startTimeStr, '結束時間': endTimeStr};
      }

      if (dataMap.isEmpty) {
        throw Exception("正則表達式沒有抓到任何資料，請檢查網頁結構是否改變");
      }

      // 回傳符合 _processData 解析邏輯的 Map
      return {
        'data': dataMap,
        'metadata': {'update_time': DateTime.now().toIso8601String()},
      };
    } catch (e) {
      debugPrint("爬取選課時間失敗: $e");
      throw Exception("爬取選課時間失敗: $e");
    }
  }

  // --- 從 GitHub 獲取選課時程 ---
  Future<Map<String, dynamic>> fetchScheduleFromGithub() async {
    final url = Uri.parse(
      'https://edwinchu0711.github.io/CourseSelectionDateUpdate/course-selection/selection_schedule.json',
    );
    final client = createHttpClient();
    final response = await client.get(url);
    client.close();
    if (response.statusCode == 200) {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    }
    throw Exception("GitHub 回應狀態碼為 ${response.statusCode}");
  }

  /// 將學校的「115.01.30(09:00)」轉成舊 JSON 格式「115年 01/30 09:00」
  /// 以相容原有的 _parseTwDate 與 _removeYear 邏輯
  String _formatNsysuTimeToOldStyle(String rawTime) {
    final regex = RegExp(r'(\d+)\.(\d+)\.(\d+)\((\d+):(\d+)\)');
    final match = regex.firstMatch(rawTime);

    if (match != null) {
      return "${match.group(1)}年 ${match.group(2)}/${match.group(3)} ${match.group(4)}:${match.group(5)}";
    }
    return rawTime;
  }

  /// 輔助函式：將「115.01.30(09:00)」格式轉為 DateTime

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isLiquidGlass = LayoutStyleNotifier.instance.isLiquidGlass;
    final semStr = CourseQueryService.instance.currentSemester;
    String semDisplay = "";
    if (semStr.length == 4) {
      final syear = semStr.substring(0, 3); // 前三碼 (114)
      final sem = semStr.substring(3, 4); // 最後一碼 (2)
      semDisplay = "$syear-$sem";
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth >= 800;

    return GlassPageScaffold(
      appBar: AppBar(
        title: Text("選課時程"),
        centerTitle: true,
        backgroundColor: isLiquidGlass ? Colors.transparent : null,
        surfaceTintColor: isLiquidGlass ? Colors.transparent : null,
        elevation: isLiquidGlass ? 0 : 0.5,
        scrolledUnderElevation: isLiquidGlass ? 0 : null,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: _isLoading
                ? const Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    ),
                  )
                : IconButton(
                    icon: const Icon(Icons.refresh_rounded),
                    tooltip: "重新整理與檢查",
                    onPressed: () async {
                      // 按下重新整理時：1. 刷新時程表 JSON  2. 重新戳學校伺服器檢查狀態
                      if (await OfflineErrorHandler.handleRefresh(context))
                        return;
                      try {
                        await _checkAndLoadData(forceRefresh: true);
                        await _checkRealTimeSystemStatus(forceRefresh: true);
                      } catch (e) {
                        if (mounted) {
                          await OfflineErrorHandler.show(context, e);
                        }
                      }
                    },
                  ),
          ),
        ],
      ),
      backgroundColor: colorScheme.pageBackground,
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text("載入資料中...", style: TextStyle(color: Colors.grey)),
                ],
              ),
            )
          : isWide
          ? Padding(
              padding: const EdgeInsets.all(24.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 左邊：時程表主列表
                  Expanded(
                    flex: 55,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(
                            left: 4.0,
                            bottom: 12.0,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.event_note_rounded,
                                color: colorScheme.primary,
                                size: 22,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                "選課時程表",
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.primaryText,
                                ),
                              ),
                              const Spacer(),
                              _buildUpdateTimeInline(),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Container(
                            decoration: isLiquidGlass
                                ? (glassCardDecoration(
                                        context,
                                        borderRadius: 16,
                                      ) ??
                                      BoxDecoration(
                                        color: colorScheme.cardBackground,
                                        borderRadius: BorderRadius.circular(16),
                                      ))
                                : BoxDecoration(
                                    color: colorScheme.cardBackground,
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [
                                      BoxShadow(
                                        color: colorScheme.isDark
                                            ? Colors.black26
                                            : Colors.black.withValues(
                                                alpha: 0.03,
                                              ),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                            foregroundDecoration: isLiquidGlass
                                ? null
                                : BoxDecoration(
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: colorScheme.borderColor,
                                      width: 0.8,
                                    ),
                                  ),
                            clipBehavior: Clip.antiAlias,
                            child: ListView.builder(
                              physics: const BouncingScrollPhysics(),
                              padding: EdgeInsets.only(
                                bottom: isLiquidGlass ? 100 : 0,
                              ),
                              itemCount: _mainList.length,
                              itemBuilder: (context, index) {
                                return _buildCleanRow(_mainList[index]);
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 24),
                  // 右邊：即時狀態檢查與控制面板
                  Expanded(
                    flex: 45,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(
                            left: 4.0,
                            bottom: 12.0,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.dashboard_customize_rounded,
                                color: colorScheme.primary,
                                size: 22,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                "系統即時控制台",
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.primaryText,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          decoration: isLiquidGlass
                              ? (glassCardDecoration(
                                      context,
                                      borderRadius: 16,
                                    ) ??
                                    BoxDecoration(
                                      color: colorScheme.cardBackground,
                                      borderRadius: BorderRadius.circular(16),
                                    ))
                              : BoxDecoration(
                                  color: colorScheme.cardBackground,
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: colorScheme.isDark
                                          ? Colors.black26
                                          : Colors.black.withValues(
                                              alpha: 0.03,
                                            ),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                          foregroundDecoration: isLiquidGlass
                              ? null
                              : BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: colorScheme.borderColor,
                                    width: 0.8,
                                  ),
                                ),
                          clipBehavior: Clip.antiAlias,
                          child: _buildActiveStatusRow(),
                        ),
                        const SizedBox(height: 24),
                        // 額外資訊（顯示 bottomList 輔助時程）
                        if (_bottomList.isNotEmpty) ...[
                          Padding(
                            padding: const EdgeInsets.only(
                              left: 4.0,
                              bottom: 12.0,
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.assignment_outlined,
                                  color: colorScheme.primary,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  "其他選課異動時程",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: colorScheme.primaryText,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            decoration: isLiquidGlass
                                ? (glassCardDecoration(
                                        context,
                                        borderRadius: 16,
                                      ) ??
                                      BoxDecoration(
                                        color: colorScheme.cardBackground,
                                        borderRadius: BorderRadius.circular(16),
                                      ))
                                : BoxDecoration(
                                    color: colorScheme.cardBackground,
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [
                                      BoxShadow(
                                        color: colorScheme.isDark
                                            ? Colors.black26
                                            : Colors.black.withValues(
                                                alpha: 0.03,
                                              ),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                            foregroundDecoration: isLiquidGlass
                                ? null
                                : BoxDecoration(
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: colorScheme.borderColor,
                                      width: 0.8,
                                    ),
                                  ),
                            clipBehavior: Clip.antiAlias,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: _bottomList
                                  .map((entry) => _buildCleanRow(entry))
                                  .toList(),
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(
                      16,
                      8,
                      16,
                      isLiquidGlass ? 100 : 16,
                    ),
                    children: [
                      // ✅ 狀態區塊 (改用全新的窄螢幕控制卡片)
                      _buildNarrowActiveStatusCard(),

                      const SizedBox(height: 16),

                      // 主日程表卡片
                      Container(
                        decoration: isLiquidGlass
                            ? (glassCardDecoration(context, borderRadius: 16) ??
                                  BoxDecoration(
                                    color: colorScheme.cardBackground,
                                    borderRadius: BorderRadius.circular(16),
                                  ))
                            : BoxDecoration(
                                color: colorScheme.cardBackground,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: colorScheme.isDark
                                        ? Colors.black38
                                        : Colors.black.withValues(alpha: 0.04),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                                border: Border.all(
                                  color: colorScheme.borderColor,
                                  width: 0.8,
                                ),
                              ),
                        clipBehavior: Clip.antiAlias,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // 卡片標頭
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16.0,
                                vertical: 12.0,
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.calendar_today_rounded,
                                    color: colorScheme.primary,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    "選課時程表",
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: colorScheme.primaryText,
                                    ),
                                  ),
                                  const Spacer(),
                                  _buildUpdateTimeInline(),
                                ],
                              ),
                            ),
                            const Divider(height: 1),
                            ..._mainList.map((entry) => _buildCleanRow(entry)),
                          ],
                        ),
                      ),

                      // 其他選課異動時程 (補齊窄螢幕原本漏掉的這部分)
                      if (_bottomList.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        Container(
                          decoration: isLiquidGlass
                              ? (glassCardDecoration(
                                      context,
                                      borderRadius: 16,
                                    ) ??
                                    BoxDecoration(
                                      color: colorScheme.cardBackground,
                                      borderRadius: BorderRadius.circular(16),
                                    ))
                              : BoxDecoration(
                                  color: colorScheme.cardBackground,
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: colorScheme.isDark
                                          ? Colors.black38
                                          : Colors.black.withValues(
                                              alpha: 0.04,
                                            ),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                  border: Border.all(
                                    color: colorScheme.borderColor,
                                    width: 0.8,
                                  ),
                                ),
                          clipBehavior: Clip.antiAlias,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // 卡片標頭
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16.0,
                                  vertical: 12.0,
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.assignment_outlined,
                                      color: colorScheme.primary,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      "其他選課異動時程",
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: colorScheme.primaryText,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Divider(height: 1),
                              ..._bottomList.map(
                                (entry) => _buildCleanRow(entry),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // 底部資料時間已移至「選課時程表」標題右側
              ],
            ),
    );
  }

  /// 簡化的更新時間（去掉年份）：將 "yyyy/MM/dd HH:mm" 轉為 "MM/dd HH:mm"。
  String get _dataUpdateShort {
    final full = _dataUpdateTime;
    if (full.length >= 16) return full.substring(5);
    return full;
  }

  /// 顯示在「選課時程表」標題右側的精簡更新時間（icon + 更新時間）。
  Widget _buildUpdateTimeInline() {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.update_rounded, size: 13, color: colorScheme.subtitleText),
        const SizedBox(width: 4),
        Text(
          "更新 $_dataUpdateShort",
          style: TextStyle(
            fontSize: 11,
            color: colorScheme.subtitleText,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  // ✅ 設計全新的窄螢幕控制卡片方法
  Widget _buildNarrowActiveStatusCard() {
    final colorScheme = Theme.of(context).colorScheme;
    final isLiquidGlass = LayoutStyleNotifier.instance.isLiquidGlass;

    final bool isOffline = OfflineErrorHandler.isOffline;

    // 1. 計算選課狀態
    Color statusTextColor;
    IconData statusIcon;
    String statusTitle;
    bool showStatusButton = false;

    if (isOffline) {
      statusTextColor = colorScheme.subtitleText;
      statusIcon = Icons.cloud_off_rounded;
      statusTitle = "離線模式下無法使用";
    } else if (_isCheckingSystem) {
      statusTextColor = colorScheme.bodyText;
      statusIcon = Icons.sync;
      statusTitle = "系統狀態檢查中";
    } else if (_isSystemOpen) {
      statusTextColor = colorScheme.isDark
          ? const Color(0xFF90CAF9)
          : colorScheme.primary;
      statusIcon = Icons.check_circle_rounded;
      statusTitle = "選課系統開放中";
    } else {
      DateTime? confirmEndTime = _getConfirmationEndTime();
      DateTime now = DateTime.now();
      if (confirmEndTime != null && now.isBefore(confirmEndTime)) {
        statusTextColor = colorScheme.isDark
            ? const Color(0xFFFFB74D)
            : Colors.orange[800]!;
        statusIcon = Icons.pending_rounded;
        statusTitle = "目前非選課時段";
        showStatusButton = true;
      } else {
        statusTextColor = colorScheme.subtitleText;
        statusIcon = Icons.do_not_disturb_on_rounded;
        statusTitle = "目前非選課時段";
      }
    }

    // 2. 計算異常處理狀態
    bool isExceptionActive =
        test || _activeItemKeys.any((key) => key.contains('異常'));

    Color exceptionTextColor = isOffline
        ? colorScheme.subtitleText
        : (isExceptionActive
              ? (colorScheme.isDark ? Colors.green[300]! : Colors.green[800]!)
              : colorScheme.subtitleText);
    IconData exceptionIcon = isOffline
        ? Icons.cloud_off_rounded
        : (isExceptionActive
              ? Icons.error_outline_rounded
              : Icons.radio_button_off_rounded);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: isLiquidGlass
          ? (glassCardDecoration(context, borderRadius: 16) ??
                BoxDecoration(
                  color: colorScheme.cardBackground,
                  borderRadius: BorderRadius.circular(16),
                ))
          : BoxDecoration(
              color: colorScheme.cardBackground,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: colorScheme.isDark
                      ? Colors.black38
                      : Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
              border: Border.all(color: colorScheme.borderColor, width: 0.8),
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 卡片標頭
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 12.0,
            ),
            child: Row(
              children: [
                Icon(
                  Icons.sensors_rounded,
                  color: colorScheme.primary,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  "選課即時狀態",
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primaryText,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // 第一區塊：選課狀態與操作
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 12.0,
            ),
            child: Row(
              children: [
                if (_isCheckingSystem)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.grey),
                    ),
                  )
                else
                  Icon(statusIcon, color: statusTextColor, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        isOffline ? "離線模式下無法使用" : statusTitle,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: statusTextColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isOffline ? "離線模式下無法使用" : _systemStatusMessage,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: colorScheme.subtitleText,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!_isCheckingSystem) ...[
                  const SizedBox(width: 8),
                  SizedBox(
                    height: 32,
                    child: ElevatedButton(
                      onPressed: !isOffline
                          ? () => _navigateToCourseSelection(enableQuery: true)
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isSystemOpen
                            ? colorScheme.primary
                            : (showStatusButton
                                  ? (colorScheme.isDark
                                        ? const Color(0xFFFFB74D)
                                        : Colors.orange[700]!)
                                  : colorScheme.primary),
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: colorScheme.isDark
                            ? Colors.grey[800]
                            : Colors.grey[300],
                        disabledForegroundColor: colorScheme.isDark
                            ? Colors.grey[600]
                            : Colors.grey[500],
                        elevation: 0,
                        shape: const StadiumBorder(),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                      ),
                      child: const Text(
                        "進入選課",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (_experimentalAbnormalEnabled) ...[
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0),
              child: Divider(height: 1),
            ),

            // 第二區塊：異常處理與操作
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 12.0,
              ),
              child: Row(
                children: [
                  Icon(exceptionIcon, color: exceptionTextColor, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          isOffline
                              ? "離線模式下無法使用"
                              : (isExceptionActive ? "目前為異常處理階段" : "非異常處理時段"),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: exceptionTextColor,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isOffline
                              ? "離線模式下無法使用"
                              : (isExceptionActive ? "請儘速提出申請" : "功能暫未開放"),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: colorScheme.subtitleText,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    height: 32,
                    child: OutlinedButton(
                      onPressed:
                          (isExceptionActive && !OfflineErrorHandler.isOffline)
                          ? () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const CourseExceptionHandlingPage(),
                                  settings: const RouteSettings(
                                    name: 'course_exception_handling',
                                  ),
                                ),
                              );
                            }
                          : null,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: isExceptionActive
                            ? exceptionTextColor
                            : colorScheme.subtitleText,
                        side: BorderSide(
                          color: isExceptionActive
                              ? exceptionTextColor
                              : colorScheme.borderColor,
                          width: 1,
                        ),
                        shape: const StadiumBorder(),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        disabledForegroundColor: colorScheme.subtitleText
                            .withValues(alpha: 0.5),
                      ),
                      child: const Text(
                        "異常處理",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ✅ 【修改】根據伺服器回傳狀態顯示 UI (加入異常處理判斷)
  Widget _buildActiveStatusRow() {
    final colorScheme = Theme.of(context).colorScheme;
    final isLiquidGlass = LayoutStyleNotifier.instance.isLiquidGlass;
    final bool isOffline = OfflineErrorHandler.isOffline;

    // 1. 基礎狀態判斷 (藍/橘/灰)
    Color primaryTextColor = colorScheme.bodyText;
    bool showStatusButton = false;

    if (isOffline) {
      primaryTextColor = colorScheme.subtitleText;
    } else if (_isCheckingSystem) {
      primaryTextColor = colorScheme.bodyText;
    } else if (_isSystemOpen) {
      primaryTextColor = colorScheme.isDark
          ? const Color(0xFF90CAF9)
          : colorScheme.primary;
    } else {
      DateTime? confirmEndTime = _getConfirmationEndTime();
      DateTime now = DateTime.now();
      if (confirmEndTime != null && now.isBefore(confirmEndTime)) {
        primaryTextColor = colorScheme.isDark
            ? const Color(0xFFFFB74D)
            : Colors.orange[800]!;
        _systemStatusMessage = "目前非選課時段";
        showStatusButton = true;
      } else {
        primaryTextColor = colorScheme.subtitleText;
      }
    }

    // 2. 異常處理狀態判斷 (綠/灰)
    bool isExceptionActive =
        test || _activeItemKeys.any((key) => key.contains('異常'));

    return Column(
      children: [
        // --- 第一部分：系統狀態列 (融入列表) ---
        Container(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
          decoration: BoxDecoration(
            color: isLiquidGlass
                ? Colors.transparent
                : colorScheme.cardBackground,
            border: Border(bottom: BorderSide(color: colorScheme.borderColor)),
          ),
          child: Row(
            children: [
              if (_isCheckingSystem && !isOffline)
                Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: primaryTextColor,
                    ),
                  ),
                ),
              Expanded(
                child: Text(
                  isOffline ? "離線模式下無法使用" : _systemStatusMessage,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: primaryTextColor,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              if (!_isCheckingSystem || isOffline)
                _buildActionButton(
                  "進入選課系統",
                  _isSystemOpen
                      ? colorScheme.primary
                      : (showStatusButton
                            ? (colorScheme.isDark
                                  ? const Color(0xFFFFB74D)
                                  : Colors.orange[700]!)
                            : colorScheme.primary),
                  !isOffline
                      ? () => _navigateToCourseSelection(enableQuery: true)
                      : null,
                ),
            ],
          ),
        ),

        // --- 第二部分：異常處理列 (融入列表) ---
        if (_experimentalAbnormalEnabled)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
            decoration: BoxDecoration(
              color: isLiquidGlass
                  ? Colors.transparent
                  : colorScheme.cardBackground,
              border: Border(
                bottom: BorderSide(color: colorScheme.borderColor),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    isOffline
                        ? "離線模式下無法使用"
                        : (isExceptionActive ? "目前為異常處理階段" : "非異常處理時段"),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: (isExceptionActive && !isOffline)
                          ? FontWeight.bold
                          : FontWeight.w600,
                      color: (isExceptionActive && !isOffline)
                          ? (colorScheme.isDark
                                ? Colors.green[300]
                                : Colors.green[800])
                          : colorScheme.subtitleText,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                _buildActionButton(
                  "前往異常處理",
                  (isExceptionActive && !isOffline)
                      ? (colorScheme.isDark
                            ? Colors.green[700]!
                            : Colors.green[600]!)
                      : Colors.transparent,
                  (isExceptionActive && !isOffline)
                      ? () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  const CourseExceptionHandlingPage(),
                              settings: const RouteSettings(
                                name: 'course_exception_handling',
                              ),
                            ),
                          );
                        }
                      : null,
                ),
              ],
            ),
          ),
      ],
    );
  }

  // 統一的按鈕小工具
  Widget _buildActionButton(String text, Color color, VoidCallback? onPressed) {
    final colorScheme = Theme.of(context).colorScheme;
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        disabledBackgroundColor: colorScheme.isDark
            ? Colors.grey[800]
            : Colors.grey[300],
        disabledForegroundColor: colorScheme.isDark
            ? Colors.grey[600]
            : Colors.grey[500],
        elevation: 0,
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        visualDensity: VisualDensity.compact,
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildCleanRow(
    MapEntry<String, dynamic> entry, {
    bool forceInactive = false,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final isLiquidGlass = LayoutStyleNotifier.instance.isLiquidGlass;
    final String title = entry.key;
    final Map<String, dynamic> content = entry.value is Map
        ? Map<String, dynamic>.from(entry.value)
        : {};

    String rawStart = content['開始時間'] ?? "";
    String rawEnd = content['結束時間'] ?? "";

    // 使用 DateTime 格式化，移除年份顯示
    String start = _formatDisplayDate(rawStart, _parseTwDate(rawStart));
    String end = _formatDisplayDate(rawEnd, _parseTwDate(rawEnd));

    bool hasEnd = end.trim().isNotEmpty;

    bool isActive = _activeItemKeys.contains(entry.key);
    final isWide = MediaQuery.of(context).size.width >= 800;

    return Container(
      padding: EdgeInsets.symmetric(vertical: 20, horizontal: isWide ? 24 : 12),
      decoration: BoxDecoration(
        color: isLiquidGlass ? Colors.transparent : colorScheme.cardBackground,
        border: Border(
          bottom: BorderSide(color: colorScheme.borderColor),
          left: BorderSide(
            color: isActive ? colorScheme.primary : Colors.transparent,
            width: 4,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: 6,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: isWide ? 16 : 14,
                      fontWeight: isActive ? FontWeight.bold : FontWeight.w600,
                      color: isActive
                          ? colorScheme.primary
                          : colorScheme.primaryText,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                if (isActive) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      "進行中",
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.primary,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(width: 12),

          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildTimeText(start, isActive, colorScheme),
                if (hasEnd) ...[
                  const SizedBox(height: 6),
                  _buildTimeText("~ $end", isActive, colorScheme),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeText(String text, bool isActive, ColorScheme colorScheme) {
    final isWide = MediaQuery.of(context).size.width >= 800;
    return Text(
      text,
      textAlign: TextAlign.right,
      style: TextStyle(
        fontSize: isWide ? 15 : 13,
        color: isActive ? colorScheme.primary : colorScheme.bodyText,
        fontWeight: FontWeight.w500,
        height: 1.1,
      ),
    );
  }

  Future<String?> _loginViaSSO2(String stuid, String password) async {
    final loginUri = Uri.parse("$_baseUrl/menu4/Studcheck_sso2.asp");
    String encryptedPass = Utils.base64md5(password);
    try {
      final response = await _client.post(
        loginUri,
        headers: {
          "Content-Type": "application/x-www-form-urlencoded",
          "User-Agent":
              "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
        },
        body: {"stuid": stuid.toUpperCase(), "SPassword": encryptedPass},
      );
      String? rawCookie = response.headers['set-cookie'];
      if (rawCookie != null && !response.body.contains("不符")) return rawCookie;
    } catch (e) {
      debugPrint("❌ [偵錯] Login Error: $e");
    }
    return null;
  }
}
