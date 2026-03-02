import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/utils.dart'; // 確保你的 Utils 路徑正確

enum TransactionType { add, drop }

class PendingTransaction {
  final String id;
  final String name;
  final TransactionType type;
  final String points; 
  
  PendingTransaction({required this.id, required this.name, required this.type, required this.points});
}

class SubmitResult {
  final bool success;
  final String message;
  final List<FailedCourse> failures;

  SubmitResult({required this.success, required this.message, this.failures = const []});
}

class FailedCourse {
  final String courseId;
  final String courseName;
  final String reason;

  FailedCourse({required this.courseId, required this.courseName, required this.reason});
}

class CourseSelectionSubmitService {
  static final CourseSelectionSubmitService instance = CourseSelectionSubmitService._privateConstructor();
  CourseSelectionSubmitService._privateConstructor();

  final String _baseUrl = "https://selcrs.nsysu.edu.tw";
  final http.Client _client = http.Client();

  Future<SubmitResult> submitTransactions(List<PendingTransaction> items) async {
    final prefs = await SharedPreferences.getInstance();
    String studentId = (prefs.getString('username') ?? "").trim();
    String password = (prefs.getString('password') ?? "").trim();

    if (studentId.isEmpty || password.isEmpty) {
      return SubmitResult(success: false, message: "找不到帳號密碼資料");
    }

    List<PendingTransaction> dropList = items.where((i) => i.type == TransactionType.drop).toList();
    List<PendingTransaction> addList = items.where((i) => i.type == TransactionType.add).toList();

    List<FailedCourse> allFailures = [];
    
    try {
      // 1. 執行退選
      if (dropList.isNotEmpty) {
        String responseHtml = await _processBatch(studentId, password, dropList);
        allFailures.addAll(_parseFailureTable(responseHtml));
      }

      // 2. 執行加選
      if (addList.isNotEmpty) {
        // 退選完稍微緩衝一下，避免太快被擋
        if (dropList.isNotEmpty) await Future.delayed(const Duration(milliseconds: 500));
        
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
        return SubmitResult(
          success: true,
          message: "送出成功",
        );
      }

    } catch (e) {
      return SubmitResult(success: false, message: "連線或系統錯誤: $e");
    }
  }

  // [重點修改區塊]
  Future<String> _processBatch(String uid, String pwd, List<PendingTransaction> batchItems) async {
    // 1. 登入
    String? cookie = await _loginViaSSO2(uid, pwd);
    if (cookie == null) throw "登入失敗";

    // 2. 取得參數 (這裡是 Map)
    Map<String, String> finalParams = await _fetchSSFormParams(cookie);

    // 3. [關鍵修正] 組建 ssform 完整網址並執行 GET 請求
    // 這一步模擬瀏覽器「打開」選課表單，讓 Server 初始化 Session 變數 (如 Grade, Dept)
    String refererQuery = Uri(queryParameters: finalParams).query;
    final refererUrlStr = "$_baseUrl/menu4/addcourse/ssform.asp?$refererQuery";
    final refererUri = Uri.parse(refererUrlStr);

    print("🚀 正在初始化 Session (GET ssform): $refererUrlStr");
    
    await _client.get(
      refererUri,
      headers: {
        "Cookie": cookie,
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
      },
    );

    // 4. 準備 POST Payload
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

    // 5. 執行 POST
    final submitUrl = Uri.parse("$_baseUrl/menu4/addcourse/ssprs.asp");
    
    print("🚀 正在送出 POST 請求...");
    final response = await _client.post(
      submitUrl,
      headers: {
        "Cookie": cookie,
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
        "Content-Type": "application/x-www-form-urlencoded",
        "Referer": refererUrlStr, // 必須帶上剛剛 GET 過的網址
        "Origin": _baseUrl,
      },
      body: payload,
    );

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
    
    return body;
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
        RegExp cellRegex = RegExp(r"<td[^>]*>.*?<small>(.*?)<\/small>.*?<\/td>", caseSensitive: false);
        List<String> cells = cellRegex.allMatches(rowContent).map((m) => m.group(1) ?? "").toList();

        if (cells.length >= 6) {
          String action = cells[1];
          String id = cells[2];
          String name = cells[3];
          String remark = cells[5];

          // 排除表頭
          if (id != "課號" && (action.contains("加選") || action.contains("退選"))) {
            // 清理 HTML Tags
            remark = remark.replaceAll(RegExp(r"<[^>]*>"), " "); 
            
            failures.add(FailedCourse(
              courseId: id,
              courseName: name,
              reason: remark.trim(),
            ));
          }
        }
      }
    } catch (e) {
      print("解析 HTML 警告: $e");
    }

    return failures;
  }

  // 取得表單參數 (保持不變)
  Future<Map<String, String>> _fetchSSFormParams(String cookie) async {
    final headers = {
      "Cookie": cookie,
      "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
    };
    final mainFrameUrl = Uri.parse("$_baseUrl/menu4/main_frame.asp");
    final resFrame = await _client.get(mainFrameUrl, headers: headers);
    final frameBody = utf8.decode(resFrame.bodyBytes, allowMalformed: true);
    
    final studFunRegex = RegExp(r'src="Studfun\.asp\?([^"]+)"', caseSensitive: false);
    final studFunMatch = studFunRegex.firstMatch(frameBody);
    if (studFunMatch == null) throw "無法找到 Studfun 連結";
    
    String studFunQuery = studFunMatch.group(1)!;
    final studFunUrl = Uri.parse("$_baseUrl/menu4/Studfun.asp?$studFunQuery");
    
    final resStudFun = await _client.get(studFunUrl, headers: headers);
    final studFunBody = utf8.decode(resStudFun.bodyBytes, allowMalformed: true);
    
    final ssFormRegex = RegExp(r'''ssform\.asp\?([^"'\s>]+)''', caseSensitive: false);
    final ssFormMatch = ssFormRegex.firstMatch(studFunBody);
    
    if (ssFormMatch == null) {
        if (studFunBody.contains("querys.asp")) throw "目前非選課時間";
        throw "無法找到 ssform 參數 (可能需評鑑或非選課階段)";
    }
    
    String finalRawQuery = ssFormMatch.group(1)!;
    // 修正 HTML Entity
    finalRawQuery = finalRawQuery.replaceAll('&amp;', '&');
    
    return Uri.splitQueryString(finalRawQuery);
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
          "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
        },
        body: {"stuid": stuid.toUpperCase(), "SPassword": encryptedPass},
      );
      String? rawCookie = response.headers['set-cookie'];
      if (rawCookie != null && !response.body.contains("不符")) return rawCookie;
    } catch (e) { 
      print("Login Error: $e"); 
    }
    return null;
  }
}