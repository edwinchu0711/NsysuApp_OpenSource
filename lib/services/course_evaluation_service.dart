import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

/// 課程配分方式服務
/// 從選課系統大網抓取課程評分方式，支援任意學年學期查詢
class CourseEvaluationService {
  static final CourseEvaluationService instance = CourseEvaluationService._();
  CourseEvaluationService._();

  // 快取：key = "{year}-{semester}-{courseId}"
  final Map<String, List<String>> _cache = {};

  /// 抓取課程評分方式
  ///
  /// [year] 學年，例如 "114"
  /// [semester] 學期，例如 "1", "2", "3"
  /// [courseId] 課程代碼
  /// [sessionCookie] 可選的登入 session cookie
  Future<List<String>> fetchEvaluation({
    required String year,
    required String semester,
    required String courseId,
    String? sessionCookie,
  }) async {
    final cacheKey = '$year-$semester-$courseId';
    if (_cache.containsKey(cacheKey)) {
      return _cache[cacheKey]!;
    }

    final url = Uri.parse(
      'https://selcrs.nsysu.edu.tw/menu5/showoutline.asp?SYEAR=$year&SEM=$semester&CrsDat=$courseId',
    );

    try {
      final response = await http.get(
        url,
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
          if (sessionCookie != null && sessionCookie.isNotEmpty)
            'Cookie': sessionCookie,
        },
      );

      if (response.statusCode == 200) {
        String html = utf8.decode(response.bodyBytes, allowMalformed: true);

        // 分別抓項目名稱 (SS4_*1) 和百分比 (SS4_*2)，按索引配對
        final nameExp = RegExp(
          r'<span[^>]*id="?SS4_(\d+)1"?[^>]*>([^<]*)</span>',
          caseSensitive: false,
        );
        final pctExp = RegExp(
          r'<span[^>]*id="?SS4_(\d+)2"?[^>]*>([^<]*)</span>',
          caseSensitive: false,
        );

        Map<String, String> names = {};
        for (var m in nameExp.allMatches(html)) {
          String idx = m.group(1) ?? "";
          String name = m.group(2)?.trim() ?? "";
          if (idx.isNotEmpty && name.isNotEmpty) {
            names[idx] = name;
          }
        }

        Map<String, String> pcts = {};
        for (var m in pctExp.allMatches(html)) {
          String idx = m.group(1) ?? "";
          String pct = m.group(2)?.trim() ?? "";
          if (idx.isNotEmpty && pct.isNotEmpty) {
            pcts[idx] = pct;
          }
        }

        debugPrint(
          '[CourseEvaluationService] 抓到名稱: ${names.length} 個, 百分比: ${pcts.length} 個',
        );

        List<String> evals = [];
        int index = 1;

        // 按名稱的索引排序，找對應的百分比
        var sortedKeys = names.keys.toList()
          ..sort((a, b) => int.parse(a).compareTo(int.parse(b)));
        for (var key in sortedKeys) {
          String name = names[key]!;
          String pct = pcts[key] ?? "0";
          // 如果百分比為空，也顯示為 0%
          if (pct.isEmpty) pct = "0";
          evals.add('$index. $name：$pct%');
          index++;
        }

        if (evals.isEmpty) evals.add("尚無評分方式資料");
        _cache[cacheKey] = evals;
        return evals;
      }
    } catch (e) {
      debugPrint('[CourseEvaluationService] Error: $e');
      return ["載入失敗"];
    }
    return ["查無資料"];
  }

  /// 解析評分項目為結構化資料
  ///
  /// 回傳 `List<Map<String, dynamic>>`，每個項目包含:
  /// - name: 項目名稱
  /// - weight: 權重百分比 (double)
  Future<List<Map<String, dynamic>>> fetchStructuredEvaluation({
    required String year,
    required String semester,
    required String courseId,
    String? sessionCookie,
  }) async {
    final rawList = await fetchEvaluation(
      year: year,
      semester: semester,
      courseId: courseId,
      sessionCookie: sessionCookie,
    );

    List<Map<String, dynamic>> structured = [];
    for (var item in rawList) {
      // 解析格式: "1. 期中考：30%"
      final match = RegExp(
        r'^(\d+)\.\s*(.+?)\s*：\s*(\d+(?:\.\d+)?)\s*%$',
      ).firstMatch(item);
      if (match != null) {
        structured.add({
          'name': match.group(2)!.trim(),
          'weight': double.tryParse(match.group(3)!) ?? 0.0,
        });
      }
    }
    return structured;
  }

  /// 清除特定快取
  void clearCache(String year, String semester, String courseId) {
    final cacheKey = '$year-$semester-$courseId';
    _cache.remove(cacheKey);
  }

  /// 清除所有快取
  void clearAllCache() {
    _cache.clear();
  }
}