import 'package:flutter/material.dart';
import 'dart:convert';
import '../models/program_model.dart';
import 'storage_service.dart';
import 'http_client_factory.dart';

class ProgramService {
  static final ProgramService instance = ProgramService._internal();
  ProgramService._internal();

  static const String CACHE_KEY = 'program_rules_v1';
  static const String UPDATE_TIME_KEY = 'program_rules_last_update_time';
  static const String RULES_URL =
      'https://edwinchu0711.github.io/CourseSelectionDateUpdate/program/rules/rules.json';

  final ValueNotifier<List<ProgramRule>> programsNotifier = ValueNotifier([]);
  final ValueNotifier<bool> isLoadingNotifier = ValueNotifier(false);
  final ValueNotifier<String> statusNotifier = ValueNotifier('');

  Future<void> loadFromCache() async {
    // 規則不存硬碟，清除舊版硬碟快取（若有）
    try {
      await StorageService.instance.remove(CACHE_KEY);
      await StorageService.instance.remove(UPDATE_TIME_KEY);
    } catch (_) {}
  }

  Future<void> fetchPrograms() async {
    if (isLoadingNotifier.value) return;
    isLoadingNotifier.value = true;
    statusNotifier.value = '正在載入學程資料...';

    try {
      final client = createHttpClient();
      final response = await client.get(Uri.parse(RULES_URL));
      client.close();
      if (response.statusCode != 200) {
        statusNotifier.value = '載入失敗';
        return;
      }

      final decoded = jsonDecode(response.body) as List<dynamic>;
      programsNotifier.value = decoded
          .map((e) =>
              ProgramRule.fromJson(e as Map<String, dynamic>))
          .toList();
      statusNotifier.value = '載入完成';
    } catch (e) {
      statusNotifier.value = '載入失敗';
      debugPrint('ProgramService Error: $e');
    } finally {
      isLoadingNotifier.value = false;
    }
  }

  Future<DateTime?> getLastUpdateTime() async {
    return null;
  }
}