import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../utils/utils.dart';
import 'storage_service.dart';
import 'http_client_factory.dart';

class LoginPasswordErrorException implements Exception {
  final String message;
  LoginPasswordErrorException(this.message);
  @override
  String toString() => message;
}

class ScoreSessionService {
  static final ScoreSessionService historicalInstance =
      ScoreSessionService._internal();
  static final ScoreSessionService openInstance =
      ScoreSessionService._internal();

  static ScoreSessionService get instance => historicalInstance;

  ScoreSessionService._internal();

  final http.Client _client = createHttpClient();

  String? _cachedCookie;
  DateTime? _cookieTime;
  Future<String?>? _loginFuture;

  // 10分鐘的過期限制
  static const Duration _sessionDuration = Duration(minutes: 10);

  /// 獲取有效的成績系統 Session Cookie。
  /// 已停用快取機制，每次調用皆強制執行登入流程以取得全新 Cookie。
  Future<String?> getCookie({bool forceRefresh = false}) async {
    // 防止多重併發登入請求，若目前已有登入在進行中，則共用該 Future
    if (_loginFuture != null) {
      debugPrint("🔑 [ScoreSessionService] 偵測到已有登入請求進行中，合併併發請求");
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
      final String username = (credentials['username'] ?? "").trim();
      final String password = (credentials['password'] ?? "").trim();

      if (username.isEmpty || password.isEmpty) {
        debugPrint("🔑 [ScoreSessionService] 登入失敗：安全儲存中找不到帳號或密碼");
        return null;
      }

      // debugPrint("🔑 [ScoreSessionService] 開始向成績系統 SSO2 進行自動身分驗證");
      final loginUrl = Uri.parse(
        "https://selcrs.nsysu.edu.tw/scoreqry/sco_query_prs_sso2.asp",
      );
      final String base64md5Password = Utils.base64md5(password);

      final response = await _client
          .post(
            loginUrl,
            headers: {
              "Content-Type": "application/x-www-form-urlencoded",
              "User-Agent":
                  "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
            },
            body: {
              'SID': username.toUpperCase(),
              'PASSWD': base64md5Password,
              'ACTION': '0',
              'INTYPE': '1',
            },
          )
          .timeout(const Duration(seconds: 15));

      final bodyText = response.body;
      if (bodyText.contains(
            '&#30331;&#37636;&#23494;&#30908;&#37679;&#35492;&#65292;&#28961;&#27861;&#20351;&#29992;&#35531;&#37325;&#26032;&#30331;&#37636;&#65281;',
          ) ||
          bodyText.contains('登錄密碼錯誤，無法使用請重新登錄！')) {
        throw LoginPasswordErrorException("登錄密碼錯誤");
      }

      String? rawCookie = response.headers['set-cookie'];
      bool isLoginFailed = bodyText.contains("不符") || bodyText.contains("錯誤");

      if (rawCookie != null && !isLoginFailed) {
        // 登入成功後直接進行一次暖機請求，確保 Session 在伺服器端完全就緒
        try {
          await _client
              .get(
                Uri.parse(
                  "https://selcrs.nsysu.edu.tw/scoreqry/sco_query_prs_sso2.asp",
                ),
                headers: {"Cookie": rawCookie, "User-Agent": "Mozilla/5.0"},
              )
              .timeout(const Duration(seconds: 5));
        } catch (e) {
          debugPrint("🔑 [ScoreSessionService] 暖機請求發生異常 (非致命): $e");
        }

        _cachedCookie = rawCookie;
        _cookieTime = DateTime.now();
        // debugPrint("🔑 [ScoreSessionService] 登入成功，Cookie 已快取。時間: $_cookieTime");
        return rawCookie;
      } else {
        debugPrint("🔑 [ScoreSessionService] 登入失敗：帳密不符或網頁回應異常");
      }
    } on LoginPasswordErrorException {
      rethrow;
    } catch (e) {
      debugPrint("🔑 [ScoreSessionService] 登入發生例外狀況: $e");
    }
    return null;
  }

  /// 手動設定 Cookie
  void setCookie(String cookie) {
    _cachedCookie = cookie;
    _cookieTime = DateTime.now();
    // debugPrint("🔑 [ScoreSessionService] 已手動設定 Cookie 且記錄時間為: $_cookieTime");
  }

  /// 標記目前快取的 Cookie 失效
  void invalidateCookie() {
    // debugPrint("🔑 [ScoreSessionService] 標記目前快取 Cookie 失效 (設定為 null)");
    _cachedCookie = null;
    _cookieTime = null;
  }
}
