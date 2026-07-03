import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../utils/utils.dart';

class CourseExceptionService {
  static const String _userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36';

  /// 執行完整的登入與申請流程，並回傳結果 HTML 檔案的路徑
  static Future<String> submitException({
    required String stuid,
    required String password,
    required Map<String, String> postData,
  }) async {
    final client = http.Client();
    final Map<String, String> sessionCookies = {};

    try {
      final loginUrl = Uri.parse("https://selcrs.nsysu.edu.tw/menu4/Studcheck_sso2.asp");
      final mainFrameUrl = Uri.parse("https://selcrs.nsysu.edu.tw/menu4/main_frame.asp");
      final submitUrl = Uri.parse("https://selcrs.nsysu.edu.tw/menu4/query/abnormal.asp");

      // ====== 步驟 1: 登入 ======
      final loginResponse = await client.post(
        loginUrl,
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'User-Agent': _userAgent,
        },
        body: {
          'stuid': stuid.toUpperCase(),
          'SPassword': Utils.base64md5(password),
        },
      ).timeout(const Duration(seconds: 15));

      if (loginResponse.body.contains("不符")) {
        throw Exception("登入失敗：帳號或密碼錯誤");
      }

      // 儲存 Cookie
      _updateCookies(sessionCookies, loginResponse.headers);

      // ====== 步驟 2: 初始化 Session (存取主框架) ======
      final mainFrameResponse = await client.get(
        mainFrameUrl,
        headers: {
          'User-Agent': _userAgent,
          'Cookie': _formatCookies(sessionCookies),
        },
      ).timeout(const Duration(seconds: 15));

      _updateCookies(sessionCookies, mainFrameResponse.headers);

      // ====== 步驟 3: 提交申請資料 ======
      // 使用 x-www-form-urlencoded 格式編碼 postData
      final submitBody = postData.entries
          .map((e) => "${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}")
          .join('&');

      final submitResponse = await client.post(
        submitUrl,
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'User-Agent': _userAgent,
          'Cookie': _formatCookies(sessionCookies),
        },
        body: utf8.encode(submitBody),
      ).timeout(const Duration(seconds: 20));

      final htmlResult = submitResponse.body;
      if (!htmlResult.contains("成功") && !htmlResult.contains("完成")) {
        throw Exception("申請提交未成功，請確認校務系統狀態");
      }

      // ====== 步驟 4: 清理並將結果 HTML 寫入本地暫存 ======
      final cleanedHtml = _cleanHtml(htmlResult);

      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/abnormal_apply_receipt.html');
      await file.writeAsString(cleanedHtml, encoding: utf8);

      return file.path;
    } finally {
      client.close();
    }
  }

  /// 靜態移除與注入 JS 隱藏包含「列印」字樣的元素
  static String _cleanHtml(String html) {
    // 1. 靜態正則移除帶有「列印」字樣的 input 按鈕或 button 按鈕
    String cleaned = html.replaceAll(
      RegExp("<input[^>]*value=[\"'][^\"']*列印[^\"']*[\"'][^>]*>", caseSensitive: false),
      '',
    );
    cleaned = cleaned.replaceAll(
      RegExp(r'<button[^>]*>[^<]*列印[^<]*</button>', caseSensitive: false),
      '',
    );
    
    // 2. 注入自適應的 JS，在網頁載入時動態尋找並隱藏所有與「列印」相關的按鈕、超連結
    final jsInject = """
<script>
  document.addEventListener("DOMContentLoaded", function() {
    var elements = document.querySelectorAll('input, button, a');
    elements.forEach(function(el) {
      var hasPrintText = false;
      if (el.value && el.value.indexOf('列印') !== -1) {
        hasPrintText = true;
      } else if (el.innerText && el.innerText.indexOf('列印') !== -1) {
        hasPrintText = true;
      } else if (el.textContent && el.textContent.indexOf('列印') !== -1) {
        hasPrintText = true;
      }
      
      if (hasPrintText) {
        el.style.display = 'none';
      }
    });
  });
</script>
""";
    return cleaned + jsInject;
  }

  // 解析 Response 中的 Set-Cookie 並更新至 cookie map
  static void _updateCookies(Map<String, String> cookies, Map<String, String> headers) {
    final setCookie = headers['set-cookie'];
    if (setCookie == null) return;

    // 處理多個 Cookie
    final parts = setCookie.split(',');
    for (var part in parts) {
      final cookiePair = part.split(';').first.trim();
      final eqIdx = cookiePair.indexOf('=');
      if (eqIdx != -1) {
        final name = cookiePair.substring(0, eqIdx);
        final value = cookiePair.substring(eqIdx + 1);
        cookies[name] = value;
      }
    }
  }

  // 格式化為 Request 所需的 Cookie 字串
  static String _formatCookies(Map<String, String> cookies) {
    return cookies.entries.map((e) => "${e.key}=${e.value}").join('; ');
  }
}
