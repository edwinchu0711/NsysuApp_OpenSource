import 'package:http/http.dart' as http;
import 'offline_aware_http_client.dart';

/// 全 repo 統一建立 [http.Client] 的入口。
///
/// 回傳 [OfflineAwareHttpClient] 包裝的 [http.Client],
/// 離線模式下自動攔截所有網路呼叫。
///
/// 用法取代 `http.Client()`:
/// ```dart
/// final client = createHttpClient();
/// ```
http.Client createHttpClient() {
  return OfflineAwareHttpClient(http.Client());
}