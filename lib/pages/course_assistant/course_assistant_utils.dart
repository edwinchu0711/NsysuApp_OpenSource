// 選課助手純函式工具（不依賴 BuildContext / State）

import 'package:flutter/material.dart';

import '../../models/course_model.dart';
import 'course_assistant_constants.dart';

/// 課程在 SharedPreferences 的 key（依課表 ID 區分）
String getCourseKey(String scheduleId) {
  return scheduleId == 'default'
      ? 'assistant_courses'
      : 'assistant_courses_$scheduleId';
}

/// 自訂行程在 SharedPreferences 的 key（依課表 ID 區分）
String getEventKey(String scheduleId) {
  return scheduleId == 'default'
      ? 'custom_events'
      : 'custom_events_$scheduleId';
}

/// 計算中英文字數 (中文字算 1，英數字算 0.5)
double calculateTextLength(String text) {
  double length = 0.0;
  for (var rune in text.runes) {
    // 簡單判斷：ASCII 範圍內的字元 (英數字/半形符號) 算 0.5，其他算 1
    if (rune <= 128) {
      length += 0.5;
    } else {
      length += 1.0;
    }
  }
  return length;
}

String formatSemester(String? sem) {
  if (sem == null || sem.isEmpty) return "";
  if (sem.length >= 4) {
    final year = sem.substring(0, sem.length - 1);
    final term = sem.substring(sem.length - 1);
    return "$year-$term";
  }
  return sem;
}

String normalizeCode(String code) {
  String s = code
      .replaceAll(RegExp(r'&nbsp;?', caseSensitive: false), '')
      .replaceAll(RegExp(r'<[^>]*>'), '')
      .replaceAll(RegExp(r'\s+'), '')
      .toUpperCase();

  // 將全形英文字母、數字轉換為半形
  final buffer = StringBuffer();
  for (int i = 0; i < s.length; i++) {
    int char = s.codeUnitAt(i);
    if (char >= 0xFF01 && char <= 0xFF5E) {
      buffer.writeCharCode(char - 0xFEE0);
    } else if (char == 0x3000) {
      buffer.writeCharCode(0x0020);
    } else {
      buffer.writeCharCode(char);
    }
  }
  return buffer.toString();
}

bool matchCourseCodeExact(String apiId, String schoolCode) {
  return normalizeCode(apiId) == normalizeCode(schoolCode);
}

bool matchCourseCodeFuzzy(String apiId, String schoolCode) {
  final normApi = normalizeCode(apiId);
  final normSchool = normalizeCode(schoolCode);
  if (normApi.isEmpty || normSchool.isEmpty) return false;
  return normApi.contains(normSchool) || normSchool.contains(normApi);
}

Map<String, String> splitCourseName(String fullName) {
  final cleanName = fullName.split('\n')[0];
  final String chinesePart = keepUntilLastChinese(cleanName).trim();
  if (chinesePart.isEmpty) {
    return {"chinese": cleanName, "english": ""};
  }
  final String englishPart = cleanName.substring(chinesePart.length).trim();
  return {"chinese": chinesePart, "english": englishPart};
}

/// 保留到最後一個中文字（含其後配對的括號）
String keepUntilLastChinese(String input) {
  final RegExp chineseRegex = RegExp(r'[一-龥]');
  final Iterable<Match> matches = chineseRegex.allMatches(input);
  if (matches.isEmpty) return input.split('\n')[0];
  int lastIndex = matches.last.end;
  String prefix = input.substring(0, lastIndex);

  // Count unmatched open parentheses in prefix
  int standardOpen = 0;
  int fullwidthOpen = 0;
  for (int i = 0; i < prefix.length; i++) {
    String char = prefix[i];
    if (char == '(') {
      standardOpen++;
    } else if (char == '（') {
      fullwidthOpen++;
    } else if (char == ')') {
      if (standardOpen > 0) standardOpen--;
    } else if (char == '）') {
      if (fullwidthOpen > 0) fullwidthOpen--;
    }
  }

  // Scan remaining string to find matching closing parentheses
  String suffix = "";
  for (int i = lastIndex; i < input.length; i++) {
    if (standardOpen == 0 && fullwidthOpen == 0) {
      break;
    }
    String char = input[i];
    suffix += char;
    if (char == ')') {
      if (standardOpen > 0) standardOpen--;
    } else if (char == '）') {
      if (fullwidthOpen > 0) fullwidthOpen--;
    }
  }

  return prefix + suffix;
}

/// 從 location 字串中取出括號內的內容
String extractLocation(String raw) {
  final regex = RegExp(r'[\(（](.*?)[\)）]');
  final match = regex.firstMatch(raw);
  return match?.group(1) ?? raw;
}

String formatCourseTimeWithRange(Course c) {
  if (c.parsedTimes.isEmpty) return "";
  Map<int, List<String>> dayGroups = {};
  for (var t in c.parsedTimes) {
    if (!dayGroups.containsKey(t.day)) dayGroups[t.day] = [];
    dayGroups[t.day]!.add(t.period);
  }
  List<String> results = [];
  List<int> sortedDays = dayGroups.keys.toList()..sort();

  for (var d in sortedDays) {
    List<String> periods = dayGroups[d]!;
    periods.removeWhere((p) => p.contains("&nbsp") || p.trim().isEmpty);
    if (periods.isEmpty) continue;
    periods.sort((a, b) => kPeriods.indexOf(a).compareTo(kPeriods.indexOf(b)));

    String dayName = "星期${kFullWeekDays[d - 1]}";
    String periodStr = periods.join(", ");

    String timeRange = "";
    if (kTimeRangeMap.isNotEmpty) {
      String? startT = kTimeRangeMap[periods.first]?[0];
      String? endT = kTimeRangeMap[periods.last]?[1];
      if (startT != null && endT != null) {
        timeRange = " ($startT - $endT)";
      }
    }
    results.add("$dayName ($periodStr節)$timeRange");
  }
  return results.join("\n");
}

Color getCourseColor(String name, {String? id}) {
  final colors = [
    Colors.blue[700]!, // 藍
    Colors.orange[800]!, // 橘
    Colors.purple[600]!, // 紫
    Colors.teal[700]!, // 藍綠
    Colors.pink[500]!, // 粉紅      // 金黃
    Colors.indigo[600]!, // 靛藍
    Colors.deepOrange[600]!, // 橘紅
    Colors.cyan[700]!, // 青
    Colors.red[700]!, // 紅
    Colors.deepPurple[600]!, // 深紫
    Colors.green[700]!, // 正綠
  ];

  // 組合 key 並取絕對值雜湊
  final String key = id != null ? name + id : name;
  final int hash = key.hashCode.abs();

  return colors[hash % colors.length];
}

/// 計算總學分字串（原 _getTotalCredits）
String getTotalCredits(List<Course> courses) {
  double total = 0.0;
  for (var c in courses) {
    double? cred = double.tryParse(c.credits);
    if (cred != null) total += cred;
  }
  return total.toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '');
}
