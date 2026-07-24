import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../utils/utils.dart';
import 'storage_service.dart';
import 'historical_score_service.dart';
import 'http_client_factory.dart';

class CourseSelectionRawData {
  final String dept;
  final String courseNo;
  CourseSelectionRawData({required this.dept, required this.courseNo});
}

class CourseHistoryResult {
  final String semester;
  final String department;
  final String courseNo;
  final String courseName;
  final String credits;
  final String score;
  final bool passed;

  CourseHistoryResult({
    required this.semester,
    required this.department,
    required this.courseNo,
    required this.courseName,
    required this.credits,
    required this.score,
    required this.passed,
  });

  Map<String, dynamic> toJson() => {
    'semester': semester,
    'department': department,
    'courseNo': courseNo,
    'courseName': courseName,
    'credits': credits,
    'score': score,
    'passed': passed,
  };

  factory CourseHistoryResult.fromJson(Map<String, dynamic> json) =>
      CourseHistoryResult(
        semester: json['semester'] ?? '',
        department: json['department'] ?? '',
        courseNo: json['courseNo'] ?? '',
        courseName: json['courseName'] ?? '',
        credits: json['credits'] ?? '',
        score: json['score'] ?? '',
        passed: json['passed'] ?? false,
      );
}

/// 歷年修課系所與課程進度對照同步服務
class CourseHistorySyncService {
  static final CourseHistorySyncService instance =
      CourseHistorySyncService._internal();
  CourseHistorySyncService._internal();

  static const String TOGGLE_KEY = 'is_ai_course_history_enabled';
  static const String DATA_KEY = 'ai_course_history_data';

  final String _baseUrl = "https://selcrs.nsysu.edu.tw";
  final http.Client _client = createHttpClient();

  final ValueNotifier<List<CourseHistoryResult>> resultsNotifier =
      ValueNotifier([]);
  final ValueNotifier<bool> isLoadingNotifier = ValueNotifier(false);
  final ValueNotifier<String> statusMessageNotifier = ValueNotifier("");

  Future<void> loadFromCache() async {
    try {
      String? jsonStr = await StorageService.instance.read(DATA_KEY);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        List<dynamic> decoded = jsonDecode(jsonStr);
        resultsNotifier.value = decoded
            .map((e) => CourseHistoryResult.fromJson(e))
            .toList();
      }
    } catch (e) {
      debugPrint("CourseHistorySyncService: 讀取快取失敗: $e");
    }
  }

  Future<bool> checkIfSyncNeeded() async {
    try {
      // 1. 檢查是否在 1 小時內已經同步過
      final String? lastSyncStr = await StorageService.instance.read(
        'ai_course_history_last_sync_time',
      );
      if (lastSyncStr != null) {
        final int? lastSyncMs = int.tryParse(lastSyncStr);
        if (lastSyncMs != null) {
          final DateTime lastSync = DateTime.fromMillisecondsSinceEpoch(
            lastSyncMs,
          );
          if (DateTime.now().difference(lastSync).inHours < 1) {
            return false;
          }
        }
      }

      String? histJson = await StorageService.instance.read(
        HistoricalScoreService.CACHE_KEY,
      );
      if (histJson == null || histJson.isEmpty) {
        return false;
      }

      Map<String, dynamic> histDecoded = jsonDecode(histJson);
      Set<String> histCourses = {};
      for (var semKey in histDecoded.keys) {
        var semData = histDecoded[semKey];
        if (semData is Map && semData['courses'] is List) {
          for (var course in semData['courses']) {
            if (course is Map && course['id'] != null) {
              histCourses.add("${semKey}_${course['id']}");
            }
          }
        }
      }

      Set<String> currentCourses = resultsNotifier.value
          .map((r) => "${r.semester}_${r.courseNo}")
          .toSet();

      for (var courseKey in histCourses) {
        if (!currentCourses.contains(courseKey)) {
          return true;
        }
      }

      if (histCourses.length != currentCourses.length) {
        return true;
      }
    } catch (e) {
      debugPrint("CourseHistorySyncService: checkIfSyncNeeded error: $e");
    }
    return false;
  }

  Future<void> _saveToCache() async {
    try {
      String encoded = jsonEncode(
        resultsNotifier.value.map((e) => e.toJson()).toList(),
      );
      await StorageService.instance.save(DATA_KEY, encoded);
    } catch (e) {
      debugPrint("CourseHistorySyncService: 儲存快取失敗: $e");
    }
  }

  Future<void> fetchCourseHistory() async {
    if (isLoadingNotifier.value) {
      return;
    }
    isLoadingNotifier.value = true;
    statusMessageNotifier.value = "正在載入歷年成績資料...";

    try {
      String? jsonStr = await StorageService.instance.read(
        HistoricalScoreService.CACHE_KEY,
      );
      if (jsonStr == null || jsonStr.isEmpty) {
        await HistoricalScoreService.instance.fetchAllData();
        jsonStr = await StorageService.instance.read(
          HistoricalScoreService.CACHE_KEY,
        );
        if (jsonStr == null || jsonStr.isEmpty) {
          statusMessageNotifier.value = "找不到歷年成績資料，請先同步成績";
          return;
        }
      }

      Map<String, dynamic> decoded = jsonDecode(jsonStr);

      // 建立已知的科目-開課系所快取對照表 (Key: "semester_courseNo", Value: department)
      Map<String, String> knownDepts = {
        for (var r in resultsNotifier.value)
          "${r.semester}_${r.courseNo}": r.department,
      };

      // 檢查哪些學期有「尚未解析出開課科系」的課程
      List<String> semestersNeedingNetwork = [];
      for (var originalKey in decoded.keys) {
        var semesterData = decoded[originalKey];
        if (semesterData is Map && semesterData['courses'] is List) {
          for (var courseJson in semesterData['courses']) {
            if (courseJson is Map && courseJson['id'] != null) {
              String courseNo = courseJson['id'];
              if (!knownDepts.containsKey("${originalKey}_$courseNo")) {
                semestersNeedingNetwork.add(originalKey);
                break;
              }
            }
          }
        }
      }

      List<CourseHistoryResult> allResults = [];

      // 若所有課程均已在快取中擁有開課科系對照，免去網路登入選課系統，直接極速解析
      if (semestersNeedingNetwork.isEmpty) {
        for (var originalKey in decoded.keys) {
          var semesterData = decoded[originalKey];
          if (semesterData is Map && semesterData['courses'] is List) {
            for (var courseJson in semesterData['courses']) {
              if (courseJson is Map && courseJson['id'] != null) {
                String courseNo = courseJson['id'];
                String dept = knownDepts["${originalKey}_$courseNo"] ?? '';
                String score = courseJson['score'] ?? '';
                String credits = courseJson['credits'] ?? '';
                allResults.add(
                  CourseHistoryResult(
                    semester: originalKey,
                    department: dept,
                    courseNo: courseNo,
                    courseName: courseJson['name'] ?? '',
                    credits: credits,
                    score: score,
                    passed: _isPassed(score),
                  ),
                );
              }
            }
          }
        }
        resultsNotifier.value = allResults;
        statusMessageNotifier.value = "同步完成，共 ${allResults.length} 筆課程 (快取)";
        await _saveToCache();
        isLoadingNotifier.value = false;
        return;
      }

      final credentials = await StorageService.instance.getCredentials();
      String studentId = (credentials['username'] ?? '').trim();
      String password = (credentials['password'] ?? '').trim();
      if (studentId.isEmpty || password.isEmpty) {
        statusMessageNotifier.value = "找不到帳號密碼";
        return;
      }

      statusMessageNotifier.value = "正在登入...";
      String? cookie = await _loginViaSSO2(studentId, password);
      if (cookie == null) {
        statusMessageNotifier.value = "登入失敗，請檢查帳號密碼";
        return;
      }

      String userAgent =
          "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36";
      String stuact = studentId.substring(0, 1);
      int total = semestersNeedingNetwork.length;
      Map<String, List<CourseSelectionRawData>> fetchedSemestersData = {};

      for (int i = 0; i < semestersNeedingNetwork.length; i++) {
        String originalKey = semestersNeedingNetwork[i];
        String yrsm = originalKey.replaceAll('-', '');
        statusMessageNotifier.value =
            "正在查詢 $originalKey 選課資料 (${i + 1}/$total)...";

        List<CourseSelectionRawData> selectedCourses =
            await _fetchSelectionData(
              cookie,
              userAgent,
              studentId,
              stuact,
              yrsm,
            );
        fetchedSemestersData[originalKey] = selectedCourses;

        await Future.delayed(const Duration(milliseconds: 150));
      }

      // 整合所有學期（已快取科系者直接代入，新學期由網路獲取資料整合）
      for (var originalKey in decoded.keys) {
        var semesterData = decoded[originalKey];
        if (semesterData is Map && semesterData['courses'] is List) {
          List<dynamic> historicalCourses = semesterData['courses'];

          if (fetchedSemestersData.containsKey(originalKey)) {
            var selectedCourses = fetchedSemestersData[originalKey]!;
            for (var rawData in selectedCourses) {
              for (var courseJson in historicalCourses) {
                if (courseJson is Map && courseJson['id'] == rawData.courseNo) {
                  String score = courseJson['score'] ?? '';
                  String credits = courseJson['credits'] ?? '';
                  allResults.add(
                    CourseHistoryResult(
                      semester: originalKey,
                      department: rawData.dept,
                      courseNo: rawData.courseNo,
                      courseName: courseJson['name'] ?? '',
                      credits: credits,
                      score: score,
                      passed: _isPassed(score),
                    ),
                  );
                  break;
                }
              }
            }
          } else {
            // 從 knownDepts 快取解析科系
            for (var courseJson in historicalCourses) {
              if (courseJson is Map && courseJson['id'] != null) {
                String courseNo = courseJson['id'];
                String dept = knownDepts["${originalKey}_$courseNo"] ?? '';
                String score = courseJson['score'] ?? '';
                String credits = courseJson['credits'] ?? '';
                allResults.add(
                  CourseHistoryResult(
                    semester: originalKey,
                    department: dept,
                    courseNo: courseNo,
                    courseName: courseJson['name'] ?? '',
                    credits: credits,
                    score: score,
                    passed: _isPassed(score),
                  ),
                );
              }
            }
          }
        }
      }

      resultsNotifier.value = allResults;
      statusMessageNotifier.value = "同步完成，共 ${allResults.length} 筆課程";
      await _saveToCache();

      // 儲存成功同步的時間戳記
      await StorageService.instance.save(
        'ai_course_history_last_sync_time',
        DateTime.now().millisecondsSinceEpoch.toString(),
      );
    } catch (e) {
      statusMessageNotifier.value = "同步發生異常";
      debugPrint("CourseHistorySyncService Error: $e");
    } finally {
      isLoadingNotifier.value = false;
    }
  }

  Future<String?> _loginViaSSO2(String stuid, String password) async {
    final loginUri = Uri.parse("$_baseUrl/menu4/Studcheck_sso2.asp");
    String encryptedPass = Utils.base64md5(password);
    try {
      final response = await _client
          .post(
            loginUri,
            headers: {
              "Content-Type": "application/x-www-form-urlencoded",
              "User-Agent":
                  "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
            },
            body: {"stuid": stuid.toUpperCase(), "SPassword": encryptedPass},
          )
          .timeout(const Duration(seconds: 10));

      String? rawCookie = response.headers['set-cookie'];
      if (rawCookie != null && !response.body.contains("不符")) {
        return rawCookie;
      }
    } catch (e) {
      debugPrint("CourseHistorySyncService Login Error: $e");
    }
    return null;
  }

  Future<List<CourseSelectionRawData>> _fetchSelectionData(
    String cookies,
    String userAgent,
    String stuid,
    String stuact,
    String yrsm,
  ) async {
    final uri = Uri.parse("$_baseUrl/menu4/query/stu_slt_data.asp");
    String big5Submit = "%BD%54%A9%77%B0%65%A5%58";
    String body = "stuact=$stuact&YRSM=$yrsm&Stuid=$stuid&B1=$big5Submit";
    try {
      final response = await _client
          .post(
            uri,
            headers: {
              "Cookie": cookies,
              "User-Agent": userAgent,
              "Content-Type": "application/x-www-form-urlencoded",
              "Referer": "$_baseUrl/menu4/query/stu_slt_up.asp",
            },
            body: body,
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        String htmlContent = utf8.decode(
          response.bodyBytes,
          allowMalformed: true,
        );
        if (htmlContent.contains("科目名稱")) {
          return _parseSelectionHtml(htmlContent);
        }
      }
    } catch (e) {
      debugPrint("CourseHistorySyncService Fetch $yrsm Error: $e");
    }
    return [];
  }

  List<CourseSelectionRawData> _parseSelectionHtml(String html) {
    final rowRegex = RegExp(r'</tr>', caseSensitive: false);
    List<String> sections = html.split(rowRegex);
    final tdRegex = RegExp(
      r'<td[^>]*>(.*?)</td>',
      caseSensitive: false,
      dotAll: true,
    );
    final tagRegex = RegExp(r'<[^>]+>');

    String strip(String s) => s
        .replaceAll(tagRegex, ' ')
        .replaceAll('&nbsp;', '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    List<CourseSelectionRawData> results = [];
    for (var section in sections) {
      if (!section.contains(">選上<") || section.contains("選上否")) continue;

      var matches = tdRegex.allMatches(section);
      var cells = matches.map((m) => m.group(1) ?? "").toList();
      if (cells.length < 10) continue;

      String cell0 = strip(cells[0]);
      if (cell0.contains("選上與否")) continue;

      results.add(
        CourseSelectionRawData(
          dept: strip(cells[1]),
          courseNo: strip(cells[2]),
        ),
      );
    }
    return results;
  }

  bool _isPassed(String score) {
    String s = score.toUpperCase();
    return s.contains('A') ||
        s.contains('B') ||
        s.contains('C') ||
        s.contains('P');
  }
}
