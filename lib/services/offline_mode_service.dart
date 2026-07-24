import 'package:flutter/foundation.dart';

/// 離線模式全域旗標。
///
/// 一旦進入離線模式,整個 App 生命週期內禁止所有網路呼叫。
/// 旗標只存活於記憶體(static 欄位),**不持久化**:
/// App 重啟後自動重置為 false,符合「必須重啟 App 才能退出離線模式」的需求。
///
/// 設定點:`LoginPage._enterOfflineMode` 呼叫 `enterOfflineMode()`。
/// 重置點:App 進程結束(重啟)。
class OfflineModeService {
  OfflineModeService._();
  static final OfflineModeService instance = OfflineModeService._();

  final ValueNotifier<bool> _notifier = ValueNotifier<bool>(false);

  /// 目前是否處於離線模式。
  bool get isOffline => _notifier.value;

  /// 給 UI 監聽旗標變化(例如想對離線/線上切換做反應)。
  ValueListenable<bool> get isOfflineListenable => _notifier;

  /// 進入離線模式。由登入頁 `_enterOfflineMode` 呼叫。
  void enterOfflineMode() {
    _notifier.value = true;
  }

  /// 退出離線模式。僅測試用;正式流程靠 App 重啟自然重置。
  void exitOfflineMode() {
    _notifier.value = false;
  }

  /// dispose notifier(單例通常不呼叫,測試清理用)
  void dispose() {
    _notifier.dispose();
  }
}