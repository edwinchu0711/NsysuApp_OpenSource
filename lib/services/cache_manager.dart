import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'course_service.dart';
import 'open_score_service.dart';
import 'historical_score_service.dart';
import 'exam_task/elearn_task_HW_service.dart';
import 'elearn_bulletin_service.dart';
import 'graduation_service.dart';

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
      print("偵測到版本更新：$lastVersion -> $currentVersion，正在清理舊快取...");
      await performCacheCleanup();
    }

    // 更新版本紀錄
    await prefs.setString(_versionKey, currentVersion);
  }

  /// 刪除下載目錄下所有檔案
  static Future<void> performCacheCleanup() async {
    try {
      // 假設你的 ElearnBulletinService 是存在 TemporaryDirectory
      final directory = await getTemporaryDirectory();
      
      if (await directory.exists()) {
        // 列出所有檔案並刪除
        await for (var entity in directory.list(recursive: false, followLinks: false)) {
          if (entity is File) {
            await entity.delete();
          }
        }
        print("快取清理完成");
      }


    } catch (e) {
      print("清理快取發生錯誤: $e");
    }
  }
  static Future<void> clearAllServiceCache() async {
    await Future.wait([
      // CourseService.instance.clearCache(),
      OpenScoreService.instance.clearCache(),
      HistoricalScoreService.instance.clearCache(),
      ElearnService.instance.clearAllCache(),
      ElearnBulletinService.instance.clearCache(),
      GraduationService.instance.clearCache(),
    ]);
  }
}