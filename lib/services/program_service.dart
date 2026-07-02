import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/program_model.dart';
import 'storage_service.dart';

class ProgramService {
  static final ProgramService instance = ProgramService._internal();
  ProgramService._internal();

  static const String CACHE_KEY = 'program_rules_v1';
  static const String RULES_URL =
      'https://edwinchu0711.github.io/CourseSelectionDateUpdate/program/rules/rules.json';

  final ValueNotifier<List<ProgramRule>> programsNotifier = ValueNotifier([]);
  final ValueNotifier<bool> isLoadingNotifier = ValueNotifier(false);
  final ValueNotifier<String> statusNotifier = ValueNotifier('');

  Future<void> loadFromCache() async {
    try {
      final jsonStr = await StorageService.instance.read(CACHE_KEY);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final decoded = jsonDecode(jsonStr) as List<dynamic>;
        programsNotifier.value = decoded
            .map((e) =>
                ProgramRule.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      debugPrint('ProgramService: loadFromCache error: $e');
    }
  }

  Future<void> fetchPrograms() async {
    if (isLoadingNotifier.value) return;
    isLoadingNotifier.value = true;
    statusNotifier.value = '正在載入學程資料...';

    try {
      final response = await http.get(Uri.parse(RULES_URL));
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
      await _saveToCache(response.body);
    } catch (e) {
      statusNotifier.value = '載入失敗';
      debugPrint('ProgramService Error: $e');
    } finally {
      isLoadingNotifier.value = false;
    }
  }

  Future<void> _saveToCache(String rawJson) async {
    try {
      await StorageService.instance.save(CACHE_KEY, rawJson);
    } catch (e) {
      debugPrint('ProgramService: saveToCache error: $e');
    }
  }
}