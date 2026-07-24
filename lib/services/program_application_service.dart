import 'dart:convert';
import 'dart:isolate';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as parser;
import 'package:html/dom.dart' as dom;
import '../models/program_model.dart';
import 'storage_service.dart';
import 'http_client_factory.dart';

class ProgramApplicationService {
  static final ProgramApplicationService instance =
      ProgramApplicationService._internal();
  ProgramApplicationService._internal();

  static const String CACHE_KEY = 'applied_programs_cache';
  static const String BASE_URL = 'https://stuapp-oaa.nsysu.edu.tw/stuapprep';

  final http.Client _client = createHttpClient();

  final ValueNotifier<List<AppliedProgram>> appliedProgramsNotifier =
      ValueNotifier([]);
  final ValueNotifier<bool> isLoadingNotifier = ValueNotifier(false);
  final ValueNotifier<String> statusMessageNotifier = ValueNotifier('');

  Future<void> loadFromCache() async {
    try {
      final jsonStr = await StorageService.instance.read(CACHE_KEY);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final decoded = jsonDecode(jsonStr) as List<dynamic>;
        appliedProgramsNotifier.value =
            decoded
                .map((e) => AppliedProgram.fromJson(e as Map<String, dynamic>))
                .toList();
        debugPrint(
            'ProgramApplicationService: Loaded ${appliedProgramsNotifier.value.length} applied programs from cache');
      }
    } catch (e) {
      debugPrint('ProgramApplicationService: loadFromCache error: $e');
    }
  }

  Future<void> _saveToCache() async {
    try {
      final encoded = jsonEncode(
          appliedProgramsNotifier.value.map((e) => e.toJson()).toList());
      await StorageService.instance.save(CACHE_KEY, encoded);
    } catch (e) {
      debugPrint('ProgramApplicationService: saveToCache error: $e');
    }
  }

  Future<void> fetchAppliedPrograms() async {
    if (isLoadingNotifier.value) return;
    isLoadingNotifier.value = true;
    statusMessageNotifier.value = '正在登入學程申請系統...';

    try {
      final credentials = await StorageService.instance.getCredentials();
      final username = (credentials['username'] ?? '').trim();
      final password = (credentials['password'] ?? '').trim();

      if (username.isEmpty || password.isEmpty) {
        statusMessageNotifier.value = '找不到帳號密碼，請先在設定中填寫';
        isLoadingNotifier.value = false;
        return;
      }

      // Step 1: Login
      final loginResult = await _login(username, password);
      if (loginResult == null) {
        statusMessageNotifier.value = '登入失敗，請檢查帳號密碼';
        isLoadingNotifier.value = false;
        return;
      }

      final cookies = loginResult;

      // Step 2: Fetch applied programs page
      statusMessageNotifier.value = '正在取得申請學程資料...';
      final programs = await _fetchProgramsPage(cookies);

      if (programs == null) {
        statusMessageNotifier.value = '取得學程資料失敗';
        isLoadingNotifier.value = false;
        return;
      }

      appliedProgramsNotifier.value = programs;
      if (programs.isEmpty) {
        statusMessageNotifier.value = '尚無申請學程資料';
      } else {
        statusMessageNotifier.value = '已載入 ${programs.length} 個申請學程';
      }
      await _saveToCache();
    } catch (e) {
      debugPrint('ProgramApplicationService: fetchAppliedPrograms error: $e');
      statusMessageNotifier.value = '發生錯誤：$e';
    } finally {
      isLoadingNotifier.value = false;
    }
  }

  Future<String?> _login(String username, String password) async {
    final loginUrl = Uri.parse('$BASE_URL/loginchk.asp');

    try {
      final request = http.Request('POST', loginUrl);
      request.followRedirects = false;
      request.headers['Content-Type'] = 'application/x-www-form-urlencoded';
      request.headers['User-Agent'] =
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36';
      request.headers['Origin'] = 'https://stuapp-oaa.nsysu.edu.tw';
      request.headers['Referer'] =
          'https://stuapp-oaa.nsysu.edu.tw/stuapprep/studentApplication.asp';
      request.bodyFields = {
        'selForm': 'g3',
        'user_id': username,
        'password': password,
        'submit': '登入 Login in',
      };

      final streamedResponse = await _client.send(request);
      final response = await http.Response.fromStream(streamedResponse);

      debugPrint(
          'ProgramApplicationService: Login status ${response.statusCode}');

      // Extract cookies from response
      String? rawCookie = response.headers['set-cookie'];

      // Follow redirect if needed (302)
      if (rawCookie == null &&
          (response.statusCode == 301 ||
              response.statusCode == 302 ||
              response.statusCode == 303 ||
              response.statusCode == 307)) {
        final location = response.headers['location'];
        if (location != null) {
          final redirectUri = Uri.parse(location).hasScheme
              ? Uri.parse(location)
              : loginUrl.resolve(location);
          debugPrint(
              'ProgramApplicationService: Following redirect to $redirectUri');
          try {
            final redirectResponse = await _client.get(
              redirectUri,
              headers: {
                'User-Agent':
                    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
              },
            );
            rawCookie = redirectResponse.headers['set-cookie'];
          } catch (e) {
            debugPrint(
                'ProgramApplicationService: Redirect follow failed: $e');
          }
        }
      }

      if (rawCookie == null) {
        debugPrint('ProgramApplicationService: No cookies received');
        return null;
      }

      // Check if login was successful (page should not contain error indicators)
      if (response.body.contains('不符') || response.body.contains('錯誤')) {
        debugPrint(
            'ProgramApplicationService: Login failed (wrong credentials)');
        return null;
      }

      debugPrint('ProgramApplicationService: Login successful');
      return _buildCookieString(rawCookie);
    } catch (e) {
      debugPrint('ProgramApplicationService: Login error: $e');
      return null;
    }
  }

  Future<List<AppliedProgram>?> _fetchProgramsPage(String cookies) async {
    final url = Uri.parse('$BASE_URL/appliForm_G3.asp');

    try {
      final response = await _client.get(url, headers: {
        'Cookie': cookies,
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        'Referer': '$BASE_URL/studentApplication.asp',
      });

      if (response.statusCode != 200) {
        debugPrint(
            'ProgramApplicationService: Fetch programs page failed: ${response.statusCode}');
        return null;
      }

      // Try UTF-8 first, fall back to raw bytes
      String htmlContent;
      try {
        htmlContent = utf8.decode(response.bodyBytes);
      } catch (_) {
        htmlContent = response.body;
      }

      return await Isolate.run(() => _parseAppliedPrograms(htmlContent));
    } catch (e) {
      debugPrint('ProgramApplicationService: Fetch programs error: $e');
      return null;
    }
  }

  static List<AppliedProgram>? _parseAppliedPrograms(String html) {
    final document = parser.parse(html);

    // Find the table containing "已核准修習學程"
    dom.Element? targetTable;
    for (final table in document.getElementsByTagName('table')) {
      if (table.text.contains('已核准修習學程') ||
          table.text.contains('核准修習')) {
        targetTable = table;
        break;
      }
    }

    if (targetTable == null) {
      debugPrint(
          'ProgramApplicationService: No applied programs table found');
      return [];
    }

    final results = <AppliedProgram>[];
    final rows = targetTable.getElementsByTagName('tr');

    for (int i = 0; i < rows.length; i++) {
      final cells = rows[i].getElementsByTagName('td');
      // Skip header rows
      if (cells.isEmpty || cells.length < 3) continue;

      // Skip if first cell looks like a header
      final firstCellText = cells[0].text.trim();
      if (firstCellText.contains('序號') || firstCellText.contains('學程名稱')) {
        continue;
      }

      // Extract data: columns are typically 序號, 學程名稱, 核准學年度學期, 取得證書學年度學期
      final programName = cells.length > 1 ? cells[1].text.trim() : '';
      final applicationSemester = cells.length > 2 ? cells[2].text.trim() : '';
      final certificateSemester = cells.length > 3 ? cells[3].text.trim() : '';

      if (programName.isEmpty) continue;

      // Parse the semester string
      final parsed = _parseSemesterFromText(applicationSemester);
      final appAcademicYear = parsed?.$1 ?? 0;
      final appSemester = parsed?.$2 ?? 0;

      results.add(AppliedProgram(
        programName: programName,
        applicationSemester: applicationSemester,
        certificateSemester:
            certificateSemester.isNotEmpty ? certificateSemester : null,
        appAcademicYear: appAcademicYear,
        appSemester: appSemester,
      ));
    }

    debugPrint(
        'ProgramApplicationService: Parsed ${results.length} applied programs');
    for (final p in results) {
      debugPrint('   - ${p.programName} (${p.applicationSemester})');
    }

    return results;
  }

  static (int, int)? _parseSemesterFromText(String text) {
    // Handle formats like "113 學年度 第 1 學期", "113學年度第1學期", "113-1"
    final regex = RegExp(r'(\d{2,3})\s*學年度\s*第?\s*(\d)\s*學期');
    final match = regex.firstMatch(text);
    if (match != null) {
      final year = int.tryParse(match.group(1) ?? '');
      final sem = int.tryParse(match.group(2) ?? '');
      if (year != null && sem != null) return (year, sem);
    }

    // Fallback: try "113-1" format
    final dashRegex = RegExp(r'(\d{2,3})-(\d)');
    final dashMatch = dashRegex.firstMatch(text);
    if (dashMatch != null) {
      final year = int.tryParse(dashMatch.group(1) ?? '');
      final sem = int.tryParse(dashMatch.group(2) ?? '');
      if (year != null && sem != null) return (year, sem);
    }

    return null;
  }

  String _buildCookieString(String rawCookie) {
    // Parse Set-Cookie header and build a simple cookie string
    final cookies = <String, String>{};
    for (final part in rawCookie.split(',')) {
      final segments = part.split(';');
      for (final seg in segments) {
        final trimmed = seg.trim();
        if (trimmed.isEmpty) continue;
        final eqIndex = trimmed.indexOf('=');
        if (eqIndex > 0) {
          final key = trimmed.substring(0, eqIndex).trim();
          final value = trimmed.substring(eqIndex + 1).trim();
          if (!{
            'path',
            'domain',
            'expires',
            'max-age',
            'httponly',
            'secure'
          }.contains(key.toLowerCase())) {
            cookies[key] = value;
          }
        }
      }
    }
    return cookies.entries.map((e) => '${e.key}=${e.value}').join('; ');
  }
}