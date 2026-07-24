import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/utils.dart'; // 確保你的 Utils 路徑正確
import 'storage_service.dart';
import 'package:flutter/foundation.dart';
import 'http_client_factory.dart';

enum TransactionType { add, drop }

class PendingTransaction {
  final String id;
  final String name;
  final TransactionType type;
  final String points;

  PendingTransaction({
    required this.id,
    required this.name,
    required this.type,
    required this.points,
  });
}

class SubmitResult {
  final bool success;
  final String message;
  final List<FailedCourse> failures;

  SubmitResult({
    required this.success,
    required this.message,
    this.failures = const [],
  });
}

class FailedCourse {
  final String courseId;
  final String courseName;
  final String reason;

  FailedCourse({
    required this.courseId,
    required this.courseName,
    required this.reason,
  });
}

class _SSFormParamsResult {
  final Map<String, String> params;
  final bool isStage5;

  _SSFormParamsResult({required this.params, required this.isStage5});
}

class CourseSelectionSubmitService {
  static final CourseSelectionSubmitService instance =
      CourseSelectionSubmitService._privateConstructor();
  CourseSelectionSubmitService._privateConstructor();

  final String _baseUrl = "https://selcrs.nsysu.edu.tw";
  final http.Client _client = createHttpClient();

  String? lastResponseHtml;

  Future<SubmitResult> submitTransactions(
    List<PendingTransaction> items,
  ) async {
    final credentials = await StorageService.instance.getCredentials();
    String studentId = (credentials['username'] ?? "").trim();
    String password = (credentials['password'] ?? "").trim();

    if (studentId.isEmpty || password.isEmpty) {
      return SubmitResult(success: false, message: "找不到帳號密碼資料");
    }

    List<PendingTransaction> dropList = items
        .where((i) => i.type == TransactionType.drop)
        .toList();
    List<PendingTransaction> addList = items
        .where((i) => i.type == TransactionType.add)
        .toList();

    List<FailedCourse> allFailures = [];

    try {
      // 1. 執行退選
      if (dropList.isNotEmpty) {
        String responseHtml = await _processBatch(
          studentId,
          password,
          dropList,
        );
        allFailures.addAll(_parseFailureTable(responseHtml));
      }

      // 2. 執行加選
      if (addList.isNotEmpty) {
        // 退選完稍微緩衝一下，避免太快被擋
        if (dropList.isNotEmpty)
          await Future.delayed(const Duration(milliseconds: 500));

        String responseHtml = await _processBatch(studentId, password, addList);
        allFailures.addAll(_parseFailureTable(responseHtml));
      }

      if (allFailures.isNotEmpty) {
        return SubmitResult(
          success: false,
          message: "部分課程加退選失敗",
          failures: allFailures,
        );
      } else {
        return SubmitResult(success: true, message: "送出成功");
      }
    } catch (e) {
      return SubmitResult(success: false, message: "連線或系統錯誤: $e");
    }
  }

  // [重點修改區塊]
  Future<String> _processBatch(
    String uid,
    String pwd,
    List<PendingTransaction> batchItems,
  ) async {
    // 1. 登入
    String? cookie = await _loginViaSSO2(uid, pwd);
    if (cookie == null) throw "登入失敗";

    Map<String, String> finalParams = {};
    String refererUrlStr = "";
    Uri refererUri;
    Uri submitUrl;
    http.Response? response;

    bool success = false;
    String lastError = "";

    // 嘗試 1: 預設選課流程
    try {
      _SSFormParamsResult formResult = await _fetchSSFormParams(cookie);
      finalParams = formResult.params;
      bool isStage5 = formResult.isStage5;

      String refererQuery = Uri(queryParameters: finalParams).query;
      refererUrlStr = isStage5
          ? "$_baseUrl/menu4/addcourse/stage5/saddstage5.asp?$refererQuery"
          : "$_baseUrl/menu4/addcourse/ssform.asp?$refererQuery";
      refererUri = Uri.parse(refererUrlStr);

      submitUrl = isStage5
          ? Uri.parse("$_baseUrl/menu4/addcourse/stage5/saddstage5prs.asp")
          : Uri.parse("$_baseUrl/menu4/addcourse/ssprs.asp");

      response = await _executeSubmitFlow(
        cookie,
        refererUri,
        submitUrl,
        finalParams,
        batchItems,
      );
      success = true;
    } catch (e) {
      if (e.toString().contains("目前非選課時間")) {
        rethrow;
      }
      lastError = e.toString();
      debugPrint("⚠️ 預設選課流程失敗 ($e)，嘗試使用遠端備用網址...");
    }

    // 嘗試 2: 備用網址流程
    if (!success) {
      try {
        final backup = await _fetchBackupUrls();
        if (backup == null) {
          throw "無法取得備用網址。原錯誤: $lastError";
        }

        refererUrlStr = backup['GET_link']!;

        // 若備用網址本身沒帶 ?，且我們前面成功解析了參數，則主動補上
        if (!refererUrlStr.contains('?') && finalParams.isNotEmpty) {
          String query = Uri(queryParameters: finalParams).query;
          if (query.isNotEmpty) {
            refererUrlStr = "$refererUrlStr?$query";
          }
        }

        refererUri = Uri.parse(refererUrlStr);
        submitUrl = Uri.parse(backup['POST_link']!);

        // 若備用網址本身就有帶 Query 參數，也將其合併進 finalParams 中（供 POST payload 使用）
        if (refererUri.hasQuery) {
          finalParams.addAll(refererUri.queryParameters);
        }

        response = await _executeSubmitFlow(
          cookie,
          refererUri,
          submitUrl,
          finalParams,
          batchItems,
        );
        success = true;
      } catch (e) {
        throw "選課失敗 (預設錯誤: $lastError, 備用錯誤: $e)";
      }
    }

    if (response == null) {
      throw "未收到伺服器回應";
    }

    // 處理回應編碼 (Big5 轉 UTF-8 的簡易處理，若亂碼嚴重可能需要 fast_gbk)
    // 這裡假設 server 回傳大部分是 big5，但 Dart utf8.decode 配合 allowMalformed 可以硬解部分
    String body = "";
    try {
      body = utf8.decode(response.bodyBytes, allowMalformed: true);
    } catch (e) {
      // 如果真的很慘，就直接用 ASCII 顯示 (通常不會發生)
      body = response.body;
    }

    if (response.statusCode != 200) {
      throw "伺服器回應錯誤 (Code: ${response.statusCode})";
    }

    lastResponseHtml = body;

    return body;
  }

  Future<http.Response> _executeSubmitFlow(
    String cookie,
    Uri refererUri,
    Uri submitUrl,
    Map<String, String> finalParams,
    List<PendingTransaction> batchItems,
  ) async {
    debugPrint("🚀 正在初始化 Session (GET Form): $refererUri");
    await _client.get(
      refererUri,
      headers: {
        "Cookie": cookie,
        "User-Agent":
            "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
      },
    );

    // 準備 POST Payload
    Map<String, String> payload = {};
    payload.addAll(finalParams);
    payload["send"] = "提交";
    payload["step"] = "2";
    payload["MAX_ADD"] = "15";

    for (int i = 1; i <= 15; i++) {
      String keyD = "D$i";
      String keyC = "C$i";
      String keyT = "T$i";

      if (i <= batchItems.length) {
        final item = batchItems[i - 1];
        payload[keyD] = (item.type == TransactionType.add) ? "+" : "-";
        payload[keyC] = item.id;
        payload[keyT] = (item.type == TransactionType.add) ? item.points : "";
      } else {
        payload[keyD] = "N";
        payload[keyC] = "";
        payload[keyT] = "";
      }
    }

    debugPrint("🚀 正在送出 POST 請求: $submitUrl");
    final response = await _client.post(
      submitUrl,
      headers: {
        "Cookie": cookie,
        "User-Agent":
            "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
        "Content-Type": "application/x-www-form-urlencoded",
        "Referer": refererUri.toString(),
        "Origin": _baseUrl,
      },
      body: payload,
    );

    return response;
  }

  Future<Map<String, String>?> _fetchBackupUrls() async {
    const backupJsonUrl =
        "https://edwinchu0711.github.io/CourseSelectionDateUpdate/course-selection/backup_url.json";
    try {
      debugPrint("📡 正在獲取備用網址 JSON: $backupJsonUrl");
      final response = await _client.get(Uri.parse(backupJsonUrl));
      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        if (data is Map &&
            data.containsKey('GET_link') &&
            data.containsKey('POST_link')) {
          String getLink = data['GET_link'].toString().trim();
          String postLink = data['POST_link'].toString().trim();

          // 確保網址開頭補齊 _baseUrl
          String formatUrl(String link) {
            if (link.startsWith("http://") || link.startsWith("https://")) {
              return link;
            }
            if (link.startsWith("/")) {
              return "$_baseUrl$link";
            }
            return "$_baseUrl/menu4/addcourse/$link";
          }

          return {
            'GET_link': formatUrl(getLink),
            'POST_link': formatUrl(postLink),
          };
        }
      }
    } catch (e) {
      debugPrint("⚠️ 無法獲取備用網址: $e");
    }
    return null;
  }

  // 解析失敗清單 (保持不變，或根據實際 HTML 調整)
  List<FailedCourse> _parseFailureTable(String html) {
    List<FailedCourse> failures = [];

    // 簡單關鍵字檢查，如果沒有這個詞，通常代表全部成功或系統錯誤
    if (!html.contains("加退選失敗課程清單")) return failures;

    try {
      // 尋找 Table Row
      RegExp rowRegex = RegExp(r"<tr>(.*?)<\/tr>", caseSensitive: false);
      Iterable<Match> rowMatches = rowRegex.allMatches(html);

      for (var row in rowMatches) {
        String rowContent = row.group(1) ?? "";

        // 尋找 Cell: <td>...<small>Content</small>...</td>
        // 注意：有些系統可能沒有 small 標籤，Regex 可能需要根據實際 HTML 微調
        RegExp cellRegex = RegExp(
          r"<td[^>]*>.*?<small>(.*?)<\/small>.*?<\/td>",
          caseSensitive: false,
        );
        List<String> cells = cellRegex
            .allMatches(rowContent)
            .map((m) => m.group(1) ?? "")
            .toList();

        if (cells.length >= 6) {
          String action = cells[1];
          String id = cells[2];
          String name = cells[3];
          String remark = cells[5];

          // 排除表頭
          if (id != "課號" && (action.contains("加選") || action.contains("退選"))) {
            // 清理 HTML Tags
            remark = remark.replaceAll(RegExp(r"<[^>]*>"), " ");

            failures.add(
              FailedCourse(
                courseId: id,
                courseName: name,
                reason: remark.trim(),
              ),
            );
          }
        }
      }
    } catch (e) {
      debugPrint("解析 HTML 警告: $e");
    }

    return failures;
  }

  // 取得表單參數
  Future<_SSFormParamsResult> _fetchSSFormParams(String cookie) async {
    final headers = {
      "Cookie": cookie,
      "User-Agent":
          "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
    };
    final mainFrameUrl = Uri.parse("$_baseUrl/menu4/main_frame.asp");
    final resFrame = await _client.get(mainFrameUrl, headers: headers);
    final frameBody = utf8.decode(resFrame.bodyBytes, allowMalformed: true);

    final studFunRegex = RegExp(
      r'src="Studfun\.asp\?([^"]+)"',
      caseSensitive: false,
    );
    final studFunMatch = studFunRegex.firstMatch(frameBody);
    if (studFunMatch == null) throw "無法找到 Studfun 連結";

    String studFunQuery = studFunMatch.group(1)!;
    final studFunUrl = Uri.parse("$_baseUrl/menu4/Studfun.asp?$studFunQuery");

    final resStudFun = await _client.get(studFunUrl, headers: headers);
    final studFunBody = utf8.decode(resStudFun.bodyBytes, allowMalformed: true);

    final ssFormRegex = RegExp(
      r'''ssform\.asp\?([^"'\s>]+)''',
      caseSensitive: false,
    );
    final ssFormMatch = ssFormRegex.firstMatch(studFunBody);

    bool isStage5 = false;
    Match? activeMatch = ssFormMatch;

    if (activeMatch == null) {
      final stage5Regex = RegExp(
        r'''saddstage5\.asp\?([^"'\s>]+)''',
        caseSensitive: false,
      );
      final stage5Match = stage5Regex.firstMatch(studFunBody);
      if (stage5Match != null) {
        activeMatch = stage5Match;
        isStage5 = true;
      }
    }

    if (activeMatch == null) {
      if (studFunBody.contains("querys.asp")) throw "目前非選課時間";
      throw "無法找到 ssform 參數 (可能需評鑑或非選課階段)";
    }

    String finalRawQuery = activeMatch.group(1)!;
    // 修正 HTML Entity
    finalRawQuery = finalRawQuery.replaceAll('&amp;', '&');

    final params = Uri.splitQueryString(finalRawQuery);
    return _SSFormParamsResult(params: params, isStage5: isStage5);
  }

  Future<String?> _loginViaSSO2(String stuid, String password) async {
    final loginUri = Uri.parse("$_baseUrl/menu4/Studcheck_sso2.asp");
    // 假設 Utils.base64md5 已經實作
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
      debugPrint("Login Error: $e");
    }
    return null;
  }
}
