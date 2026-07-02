import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';

class FontService {
  static final FontService instance = FontService._();
  FontService._();

  /// 觸發下載與預載 Noto Sans TC 字型
  Future<void> preloadFont() async {
    try {
      // 使用 google_fonts 的 API 強制觸發預載
      await GoogleFonts.pendingFonts([GoogleFonts.notoSansTc()]);
      debugPrint('FontService: Noto Sans TC preloaded successfully.');
    } catch (e) {
      debugPrint('FontService: Failed to preload Noto Sans TC font: $e');
      rethrow;
    }
  }

  /// 檢查是否已下載/快取 Noto Sans TC
  Future<bool> isFontDownloaded() async {
    try {
      final supportDir = await getApplicationSupportDirectory();
      final googleFontsDir = Directory('${supportDir.path}/google_fonts');
      if (await googleFontsDir.exists()) {
        final List<FileSystemEntity> entities =
            await googleFontsDir.list(recursive: true).toList();
        for (var entity in entities) {
          if (entity is File &&
              (entity.path.endsWith('.ttf') || entity.path.endsWith('.otf'))) {
            return true;
          }
        }
      }
    } catch (e) {
      debugPrint('FontService: Error checking font download status: $e');
    }
    return false;
  }

  /// 刪除 google_fonts 快取以節省空間
  Future<void> deleteFontCache() async {
    try {
      final supportDir = await getApplicationSupportDirectory();
      final googleFontsDir = Directory('${supportDir.path}/google_fonts');
      if (await googleFontsDir.exists()) {
        await googleFontsDir.delete(recursive: true);
        debugPrint('FontService: Successfully deleted google_fonts cache directory.');
      }
    } catch (e) {
      debugPrint('FontService: Failed to delete google_fonts cache: $e');
    }
  }
}
