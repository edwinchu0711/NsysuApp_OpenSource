import 'package:flutter/material.dart';
import '../widgets/glass/glass_dialog.dart';
import 'offline_aware_http_client.dart';
import 'offline_mode_service.dart';

export 'offline_aware_http_client.dart' show OfflineDisabledException;

/// 離線模式錯誤統一處理器。
///
/// 所有 UI 層在 try-catch 中捕捉到 [OfflineDisabledException] 時,
/// 呼叫 [show] 顯示中央對話框,由 [showGlassDialog] 自動套用 liquid glass 樣式。
class OfflineErrorHandler {
  OfflineErrorHandler._();

  /// 顯示「離線模式不可用」中央對話框。
  ///
  /// 只對 [OfflineDisabledException] 反應;其他例外呼叫此方法為 no-op。
  static Future<void> show(BuildContext context, Object exception) async {
    if (exception is! OfflineDisabledException) return;
    if (!context.mounted) return;

    await showGlassDialog<void>(
      context: context,
      barrierDismissible: false,
      title: const Row(
        children: [
          Icon(Icons.cloud_off_rounded, color: Colors.amber),
          SizedBox(width: 8),
          Text('離線模式不可用'),
        ],
      ),
      content: const Text(
        '此功能需要網路連線。\n\n'
        '目前處於離線模式,無法存取網路資料。\n'
        '若要切換模式,請連接網路並重新開啟 App。',
      ),
      actions: [
        TextButton(
          child: const Text('確定'),
          onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
        ),
      ],
    );
  }

  /// 離線時跳對話框並回傳 true(呼叫端應 early-return);線上時回傳 false。
  ///
  /// 用於刷新按鈕 onPressed / onRefresh 開頭:
  /// ```dart
  /// Future<void> _handleRefresh() async {
  ///   if (await OfflineErrorHandler.handleRefresh(context)) return;
  ///   // ...原本的刷新邏輯...
  /// }
  /// ```
  ///
  /// 離線時呼叫此方法:
  /// - 不拋例外、不觸發任何網路呼叫
  /// - 跳「離線模式不可用」對話框(透過 [show])
  /// - 回傳 true 讓呼叫端 early-return,避免更新 `_dataFuture` / `_loadError`
  static Future<bool> handleRefresh(BuildContext context) async {
    if (!OfflineModeService.instance.isOffline) return false;
    if (!context.mounted) return true;
    await show(context, const OfflineDisabledException());
    return true;
  }

  /// 離線時回傳 true,線上時回傳 false。
  ///
  /// 用於 disable 按鈕:
  /// ```dart
  /// onPressed: (isExceptionActive && !OfflineErrorHandler.isOffline)
  ///     ? () {...}
  ///     : null,
  /// ```
  static bool get isOffline => OfflineModeService.instance.isOffline;
}