import 'dart:convert';
import 'package:crypto/crypto.dart';

class Utils {
  /// 中山大學校務系統專用的密碼加密方式：MD5 後轉為 Base64
  static String base64md5(String text) {
    // 1. 將字串轉為 UTF-8 位元組
    var bytes = utf8.encode(text);
    // 2. 進行 MD5 哈希
    var digest = md5.convert(bytes);
    // 3. 將 MD5 的原始位元組進行 Base64 編碼
    return base64.encode(digest.bytes);
  }
}