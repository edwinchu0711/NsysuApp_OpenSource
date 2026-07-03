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
<<<<<<< HEAD
        final List<FileSystemEntity> entities = await googleFontsDir
            .list(recursive: true)
            .toList();
=======
        final List<FileSystemEntity> entities =
            await googleFontsDir.list(recursive: true).toList();
>>>>>>> cb0e69536426ceb2a943a1d70f3df893136211d7
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
<<<<<<< HEAD
        try {
          await googleFontsDir.delete(recursive: true);
        } catch (e) {
          // 若整資料夾刪除因個別檔案鎖定失敗，逐一刪除可刪除之檔案
          await for (var entity in googleFontsDir.list(recursive: true)) {
            try {
              if (entity is File) {
                await entity.delete();
              }
            } catch (_) {}
          }
        }
        debugPrint(
          'FontService: Successfully deleted google_fonts cache directory.',
        );
=======
        await googleFontsDir.delete(recursive: true);
        debugPrint('FontService: Successfully deleted google_fonts cache directory.');
>>>>>>> cb0e69536426ceb2a943a1d70f3df893136211d7
      }
    } catch (e) {
      debugPrint('FontService: Failed to delete google_fonts cache: $e');
    }
  }
}
