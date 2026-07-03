import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'course_service.dart';
import 'open_score_service.dart';
import 'historical_score_service.dart';
import 'exam_task/elearn_task_HW_service.dart';
import 'elearn_bulletin_service.dart';
import 'graduation_service.dart';
import 'font_service.dart';
import '../theme/font_notifier.dart';

class AppCacheManager {
  static const String _versionKey = 'last_installed_version';

  /// 檢查版本並清理快取
  static Future<void> checkAndCleanCache() async {
    final prefs = await SharedPreferences.getInstance();
    final packageInfo = await PackageInfo.fromPlatform();

    String currentVersion = packageInfo.version; // 例如 "1.0.5"
    String? lastVersion = prefs.getString(_versionKey);

    if (lastVersion != null && lastVersion != currentVersion) {
      // 版本不同，執行清理
      debugPrint("偵測到版本更新：$lastVersion -> $currentVersion，正在清理舊快取...");
      await performCacheCleanup();
    }

    // 更新版本紀錄
    await prefs.setString(_versionKey, currentVersion);
  }

  /// 遞迴刪除下載目錄與臨時目錄下所有檔案及子資料夾
  static Future<void> performCacheCleanup() async {
    try {
      final directory = await getTemporaryDirectory();

      if (await directory.exists()) {
<<<<<<< HEAD
        // 遞迴刪除檔案
        await for (var entity in directory.list(
          recursive: true,
          followLinks: false,
        )) {
          try {
            if (entity is File) {
              await entity.delete();
            }
          } catch (e) {
            debugPrint("刪除檔案失敗: ${entity.path}, $e");
          }
        }

        // 清理留下的空資料夾
        await for (var entity in directory.list(
          recursive: true,
          followLinks: false,
        )) {
          try {
            if (entity is Directory && (await entity.list().isEmpty)) {
              await entity.delete();
            }
          } catch (_) {}
        }
=======
        // 列出所有檔案並刪除
        await for (var entity in directory.list(
          recursive: false,
          followLinks: false,
        )) {
          if (entity is File) {
            await entity.delete();
          }
        }
>>>>>>> cb0e69536426ceb2a943a1d70f3df893136211d7
        debugPrint("快取清理完成");
      }
    } catch (e) {
      debugPrint("清理快取發生錯誤: $e");
    }
  }

  static Future<void> clearAllServiceCache() async {
    final futures = <Future<void>>[
      // CourseService.instance.clearCache(),
      OpenScoreService.instance.clearCache(),
      HistoricalScoreService.instance.clearCache(),
      ElearnService.instance.clearAllCache(),
      ElearnBulletinService.instance.clearCache(),
      GraduationService.instance.clearCache(),
    ];

    // 若目前使用的是系統預設字體，一併清理字體檔快取
    if (FontNotifier.instance.value != 'NotoSansTC') {
      futures.add(FontService.instance.deleteFontCache());
    }

    await Future.wait(futures);
  }
}
