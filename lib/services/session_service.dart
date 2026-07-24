import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../utils/utils.dart';
import 'storage_service.dart';
import 'http_client_factory.dart';

class SessionTimeoutException implements Exception {
  final String message;
  const SessionTimeoutException([
    this.message = "Session has timed out or is invalid",
  ]);

  @override
  String toString() => "SessionTimeoutException: $message";
}

class SessionService {
  static final SessionService instance = SessionService._internal();
  SessionService._internal();

  final String _baseUrl = "https://selcrs.nsysu.edu.tw";
  final http.Client _client = createHttpClient();

  String? _cachedCookie;
  DateTime? _cookieTime;
  Future<String?>? _loginFuture;

  // 15分鐘的過期限制

  /// 獲取有效的 Session Cookie。
  /// 已停用快取機制，每次調用皆強制執行登入流程以取得全新 Cookie。
  Future<String?> getCookie({bool forceRefresh = false}) async {
    // 防止多重併發登入請求，若目前已有登入在進行中，則共用該 Future
    if (_loginFuture != null) {
      debugPrint("🔑 [SessionService] 偵測到已有登入請求進行中，合併併發請求");
      return _loginFuture;
    }

    _loginFuture = _performLogin();
    try {
      final cookie = await _loginFuture;
      return cookie;
    } finally {
      _loginFuture = null;
    }
  }

  /// 執行實際登入
  Future<String?> _performLogin() async {
    try {
      final credentials = await StorageService.instance.getCredentials();
      final String studentId = (credentials['username'] ?? "").trim();
      final String password = (credentials['password'] ?? "").trim();

      if (studentId.isEmpty || password.isEmpty) {
        debugPrint("🔑 [SessionService] 登入失敗：安全儲存中找不到帳號或密碼");
        return null;
      }

      debugPrint("🔑 [SessionService] 開始向 SSO2 進行自動身分驗證");
      final loginUri = Uri.parse("$_baseUrl/menu4/Studcheck_sso2.asp");
      final String encryptedPass = Utils.base64md5(password);

      final response = await _client.post(
        loginUri,
        headers: {
          "Content-Type": "application/x-www-form-urlencoded",
          "User-Agent":
              "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
        },
        body: {"stuid": studentId.toUpperCase(), "SPassword": encryptedPass},
      );

      final String? rawCookie = response.headers['set-cookie'];
      if (rawCookie != null && !response.body.contains("不符")) {
        _cachedCookie = rawCookie;
        _cookieTime = DateTime.now();
        debugPrint("🔑 [SessionService] 自動登入成功，Cookie 已快取。時間: $_cookieTime");
        return rawCookie;
      } else {
        debugPrint("🔑 [SessionService] 登入失敗：帳密錯誤或網頁回應異常");
      }
    } catch (e) {
      debugPrint("🔑 [SessionService] 登入發生例外狀況: $e");
    }
    return null;
  }

  /// 手動設定 Cookie (例如在登入頁面手動登入成功後)
  void setCookie(String cookie) {
    _cachedCookie = cookie;
    _cookieTime = DateTime.now();
    debugPrint("🔑 [SessionService] 已手動設定 Cookie 且記錄時間為: $_cookieTime");
  }

  /// 標記目前快取的 Cookie 失效
  void invalidateCookie() {
    debugPrint("🔑 [SessionService] 標記目前快取 Cookie 失效 (設定為 null)");
    _cachedCookie = null;
    _cookieTime = null;
  }
}
