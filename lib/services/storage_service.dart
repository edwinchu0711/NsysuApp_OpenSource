import 'dart:async';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

class StorageService {
  static final StorageService instance = StorageService._internal();
  StorageService._internal();

  final _secureStorage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  final Completer<void> _initCompleter = Completer<void>();
  bool _isInitializing = false;

  /// [初始化並遷移資料]
  Future<void> init() async {
    _isInitializing = true;
    // 執行遷移 (SharedPreferences -> SecureStorage)
    // 舊版帳密存在 SharedPreferences，需搬移到 SecureStorage
    try {
      final prefs = await SharedPreferences.getInstance();

      // 避免每次啟動重複執行耗時的安全存儲寫入
      final bool hasMigrated =
          prefs.getBool('has_migrated_to_secure_storage') ?? false;

      if (!hasMigrated) {
        // 遷移帳號 (但不刪除以保持 legacy 相容性)
        if (prefs.containsKey('username')) {
          String? oldUser = prefs.getString('username');
          if (oldUser != null) {
            await _secureStorage.write(key: 'username', value: oldUser);
          }
        }

        // 遷移密碼 (但不刪除以保持 legacy 相容性)
        if (prefs.containsKey('password')) {
          String? oldPass = prefs.getString('password');
          if (oldPass != null) {
            await _secureStorage.write(key: 'password', value: oldPass);
          }
        }

        // 遷移 AI API keys (contains sensitive apiKey fields)
        if (prefs.containsKey('ai_configs')) {
          String? oldConfigs = prefs.getString('ai_configs');
          if (oldConfigs != null) {
            await _secureStorage.write(key: 'ai_configs', value: oldConfigs);
          }
          await prefs.remove('ai_configs');
        }
        if (prefs.containsKey('embedding_config')) {
          String? oldEmbedding = prefs.getString('embedding_config');
          if (oldEmbedding != null) {
            await _secureStorage.write(
              key: 'embedding_config',
              value: oldEmbedding,
            );
          }
          await prefs.remove('embedding_config');
        }

        // 設定已遷移標記
        await prefs.setBool('has_migrated_to_secure_storage', true);
        // debugPrint("🔐 StorageService: 成功完成首次安全存儲遷移");
      } else {
        // debugPrint("🔐 StorageService: 已完成遷移，跳過重複安全存儲寫入");
      }
    } catch (e) {
      debugPrint("⚠️ StorageService: 遷移失敗: $e");
    }

    if (!_initCompleter.isCompleted) {
      _initCompleter.complete();
    }
    // debugPrint("🔐 StorageService: 初始化與遷移完成");
  }

  Future<void> _ensureInit() async {
    if (!_initCompleter.isCompleted) {
      if (!_isInitializing) {
        _isInitializing = true;
        await init();
      } else {
        await _initCompleter.future;
      }
    }
  }

  // --- 帳密存取 ---
  Future<void> saveCredentials(String username, String password) async {
    await _ensureInit();
    await _secureStorage.write(key: 'username', value: username);
    await _secureStorage.write(key: 'password', value: password);

    // 同時儲存至 SharedPreferences 以保持相容性，免得舊有 Service 讀取失敗
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('username', username);
      await prefs.setString('password', password);
    } catch (e) {
      debugPrint("❌ StorageService: 同步至 SharedPreferences 失敗: $e");
    }
  }

  Future<Map<String, String?>> getCredentials() async {
    await _ensureInit();
    String? username;
    String? password;
    try {
      username = await _secureStorage.read(key: 'username');
    } catch (e) {
      debugPrint("❌ StorageService: 讀取 'username' 發生錯誤: $e");
      try {
        await _secureStorage.delete(key: 'username');
      } catch (_) {}
    }
    try {
      password = await _secureStorage.read(key: 'password');
    } catch (e) {
      debugPrint("❌ StorageService: 讀取 'password' 發生錯誤: $e");
      try {
        await _secureStorage.delete(key: 'password');
      } catch (_) {}
    }

    // 雙向防呆與復原機制：
    // 1. 如果 SharedPreferences 有資料但 SecureStorage 沒有，寫回 SecureStorage (自動修復受影響的現有用戶)
    // 2. 如果 SecureStorage 有資料但 SharedPreferences 沒有，寫回 SharedPreferences 以保證 legacy 相容
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? prefsUser = prefs.getString('username')?.trim();
      final String? prefsPass = prefs.getString('password')?.trim();

      if (username == null && prefsUser != null && prefsUser.isNotEmpty) {
        username = prefsUser;
        await _secureStorage.write(key: 'username', value: username);
        // debugPrint("🔐 StorageService: 已自動復原 username 至安全存儲");
      }
      if (password == null && prefsPass != null && prefsPass.isNotEmpty) {
        password = prefsPass;
        await _secureStorage.write(key: 'password', value: password);
        // debugPrint("🔐 StorageService: 已自動復原 password 至安全存儲");
      }

      if (username != null && prefs.getString('username') != username) {
        await prefs.setString('username', username);
      }
      if (password != null && prefs.getString('password') != password) {
        await prefs.setString('password', password);
      }
    } catch (e) {
      debugPrint("❌ StorageService: 雙向同步失敗: $e");
    }

    return {'username': username, 'password': password};
  }

  Future<void> clearAll() async {
    await _secureStorage.deleteAll();
    final prefs = await SharedPreferences.getInstance();

    // 備份偏好設定，避免被 clear() 刪除
    final String? appThemeMode = prefs.getString('app_theme_mode');
    final String? appFontFamily = prefs.getString('app_font_family');
    final String? mainMenuLayoutStyle = prefs.getString(
      'main_menu_layout_style',
    );
    final bool? allowLandscapeMode = prefs.getBool('allow_landscape_mode');
    final bool? isPreviewRankEnabled = prefs.getBool('is_preview_rank_enabled');
    final int? previewRankMode = prefs.getInt('preview_rank_mode');
    final bool? hasMigratedToSecureStorage = prefs.getBool(
      'has_migrated_to_secure_storage',
    );

    await prefs.clear();

    // 還原偏好設定
    if (appThemeMode != null)
      await prefs.setString('app_theme_mode', appThemeMode);
    if (appFontFamily != null)
      await prefs.setString('app_font_family', appFontFamily);
    if (mainMenuLayoutStyle != null)
      await prefs.setString('main_menu_layout_style', mainMenuLayoutStyle);
    if (allowLandscapeMode != null)
      await prefs.setBool('allow_landscape_mode', allowLandscapeMode);
    if (isPreviewRankEnabled != null)
      await prefs.setBool('is_preview_rank_enabled', isPreviewRankEnabled);
    if (previewRankMode != null)
      await prefs.setInt('preview_rank_mode', previewRankMode);
    if (hasMigratedToSecureStorage != null)
      await prefs.setBool(
        'has_migrated_to_secure_storage',
        hasMigratedToSecureStorage,
      );
  }

  Future<String?> read(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(key);
    // if (value != null) {
    //   debugPrint("📂 StorageService: 讀取快取 [$key] (${value.length} 字元)");
    // } else {
    //   debugPrint("ℹ️ StorageService: 找不到快取 [$key]");
    // }
    return value;
  }

  /// [純文字儲存]
  Future<void> save(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    bool success = await prefs.setString(key, value);
    if (success) {
      // debugPrint("💾 StorageService: 成功儲存 [$key] (${value.length} 字元)");
    } else {
      debugPrint("❌ StorageService: 儲存失敗 [$key]");
    }
  }

  /// [Session Cookie 存取]
  Future<void> saveSession(String cookies) async {
    await save('session_cookies_plain_v1', cookies);
  }

  Future<String?> getSession() async {
    return await read('session_cookies_plain_v1');
  }

  Future<void> remove(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(key);
  }

  // --- Secure storage for sensitive data (API keys etc.) ---
  Future<void> saveSecure(String key, String value) async {
    await _ensureInit();
    await _secureStorage.write(key: key, value: value);
  }

  Future<String?> readSecure(String key) async {
    await _ensureInit();
    try {
      return await _secureStorage.read(key: key);
    } catch (e) {
      debugPrint("❌ StorageService: 讀取 '$key' 發生錯誤: $e");
      try {
        await _secureStorage.delete(key: key);
      } catch (_) {}
      return null;
    }
  }

  Future<void> removeSecure(String key) async {
    await _ensureInit();
    await _secureStorage.delete(key: key);
  }
}
