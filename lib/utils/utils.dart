import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class Utils {
  static bool isDev(String username) {
    // 帳號轉為大寫並去掉空白
    final cleaned = username.toUpperCase().replaceAll(RegExp(r'\s+'), '');
    final input = '!!$cleaned??';
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString() ==
        'ce1a97227b7b50bb80d2bfcfa192d2285fd3c2ff63501076ba20f30077745fea';
  }

  /// 中山大學校務系統專用的密碼加密方式：MD5 後轉為 Base64
  static String base64md5(String text) {
    // 1. 將字串轉為 UTF-8 位元組
    var bytes = utf8.encode(text);
    // 2. 進行 MD5 哈希
    var digest = md5.convert(bytes);
    // 3. 將 MD5 的原始位元組進行 Base64 編碼
    return base64.encode(digest.bytes);
  }

  /// 記錄應用程式啟動（登入成功時呼叫）
  static Future<void> recordLaunch(String username) async {
    if (isDev(username)) {
      debugPrint('ℹ️ recordLaunch: 開發模式已啟動，略過記錄。');
      return;
    }
    try {
      final response = await http
          .post(
            Uri.parse('https://quiet-scene-52f9.jawei-hsu2005.workers.dev'),
            body: {'platform': defaultTargetPlatform.name}, // 帶入平台資訊
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        debugPrint('記錄成功：${response.body}');
      } else {
        debugPrint('失敗：${response.statusCode}');
      }
    } catch (e) {
      debugPrint('記錄啟動錯誤：$e');
    }
  }
}
