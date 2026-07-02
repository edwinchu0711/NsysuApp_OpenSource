import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'storage_service.dart';

class DeptOption {
  final String code;
  final String displayName;

  DeptOption({required this.code, required this.displayName});
}

class DepartmentService {
  static final DepartmentService instance = DepartmentService._internal();
  DepartmentService._internal();

  static const String CACHE_KEY = 'nsysu_dept_list_v1';
  final String _url =
      'https://selcrs.nsysu.edu.tw/menu1/CourseQuery.asp?HIS=1&eng=0';

  final ValueNotifier<List<DeptOption>> departmentsNotifier = ValueNotifier([]);
  final ValueNotifier<bool> isLoadingNotifier = ValueNotifier(false);
  final ValueNotifier<String> statusNotifier = ValueNotifier('');

  Future<void> loadFromCache() async {
    try {
      final jsonStr = await StorageService.instance.read(CACHE_KEY);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final decoded = jsonDecode(jsonStr) as List<dynamic>;
        departmentsNotifier.value = decoded
            .map((e) => DeptOption(
                  code: e['code'] ?? '',
                  displayName: e['displayName'] ?? '',
                ))
            .toList();
      }
    } catch (e) {
      debugPrint('DepartmentService: loadFromCache error: $e');
    }
  }

  Future<void> fetchDepartments() async {
    if (isLoadingNotifier.value) return;
    isLoadingNotifier.value = true;
    statusNotifier.value = '正在載入科系列表...';

    try {
      final response = await http.get(Uri.parse(_url));
      if (response.statusCode != 200) {
        statusNotifier.value = '載入失敗';
        return;
      }

      final html = utf8.decode(response.bodyBytes, allowMalformed: true);
      final departments = _parseDepartments(html);
      departmentsNotifier.value = departments;
      statusNotifier.value = '載入完成，共 ${departments.length} 個科系';
      await _saveToCache();
    } catch (e) {
      statusNotifier.value = '載入失敗';
      debugPrint('DepartmentService Error: $e');
    } finally {
      isLoadingNotifier.value = false;
    }
  }

  List<DeptOption> _parseDepartments(String html) {
    final selectRegex = RegExp(
        r'<select[^>]*name="D1"[^>]*>(.*?)</select>',
        dotAll: true);
    final selectMatch = selectRegex.firstMatch(html);
    if (selectMatch == null) return [];

    final selectContent = selectMatch.group(1)!;
    final optionRegex =
        RegExp(r'<option[^>]*value="([^"]*)"[^>]*>([^<]*)</option>');
    final options = optionRegex.allMatches(selectContent);

    final result = <DeptOption>[];
    for (final match in options) {
      final code = match.group(1) ?? '';
      final rawName = match.group(2) ?? '';
      if (code.isEmpty) continue;

      // Filter: only keep B or M prefix
      if (!code.startsWith('B') && !code.startsWith('M')) continue;

      // Process display name
      String displayName = rawName.trim();

      // Remove first 4 characters if they don't contain Chinese
      if (displayName.length > 4) {
        final prefix = displayName.substring(0, 4);
        final hasChinese =
            prefix.codeUnits.any((c) => c > 0x4E00 && c < 0x9FFF);
        if (!hasChinese) {
          displayName = displayName.substring(4).trim();
        }
      }

      // Remove trailing parentheses: （全）, (碩), （學）, etc.
      displayName =
          displayName.replaceAll(RegExp(r'[（(][^）)]*[）)]\s*$'), '').trim();

      if (displayName.isNotEmpty) {
        result.add(DeptOption(code: code, displayName: displayName));
      }
    }
    return result;
  }

  Future<void> _saveToCache() async {
    try {
      final encoded = jsonEncode(departmentsNotifier.value
          .map((d) => {'code': d.code, 'displayName': d.displayName})
          .toList());
      await StorageService.instance.save(CACHE_KEY, encoded);
    } catch (e) {
      debugPrint('DepartmentService: saveToCache error: $e');
    }
  }

  List<DeptOption> search(String query) {
    if (query.isEmpty) return departmentsNotifier.value;
    final lower = query.toLowerCase();
    return departmentsNotifier.value
        .where((d) =>
            d.displayName.toLowerCase().contains(lower) ||
            d.code.toLowerCase().contains(lower))
        .toList();
  }
}