/*

This file contains code derived from the NSYSU Open Development Community project.

Original Copyright (c) 2024 NSYSU Open Development Community

Licensed under the MIT License.

*/
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../utils/utils.dart';
import '../theme/app_theme.dart';
import '../theme/layout_style_notifier.dart';
import '../widgets/glass/aurora_background.dart';
import '../widgets/glass/glass_card.dart';
import '../widgets/glass/glass_dialog.dart';
import 'main_menu_page.dart';
import 'initialization_page.dart';
import '../services/offline_mode_service.dart';
import '../services/storage_service.dart';
import '../services/session_service.dart';
import '../services/http_client_factory.dart';

bool _obscurePassword = true;

/// 依是否已初始化過，決定登入成功後直奔主頁或進入初始化頁。
Widget buildPostLoginDestination({
  required bool hasInitialized,
  required String cookies,
  required String userAgent,
}) {
  return hasInitialized
      ? MainMenuPage(cookies: cookies, userAgent: userAgent)
      : InitializationPage(cookies: cookies, userAgent: userAgent);
}

class LoginPage extends StatefulWidget {
  final bool isRelogin;
  LoginPage({this.isRelogin = false});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  String _result = "請輸入帳號密碼";
  bool _isLoading = false;
  bool _isAutoLoggingIn = false;

  @override
  void initState() {
    super.initState();
    _initSystem();
  }

  Future<void> _initSystem() async {
    await _loadCredentials();

    if (_usernameController.text.isNotEmpty &&
        _passwordController.text.isNotEmpty) {
      dynamic connectivityResult = await (Connectivity().checkConnectivity());
      bool isNone = (connectivityResult is List)
          ? connectivityResult.contains(ConnectivityResult.none)
          : connectivityResult == ConnectivityResult.none;

      if (isNone) {
        _showOfflineDialog();
      } else {
        _startLoginProcess();
      }
    }
  }

  void _showOfflineDialog() {
    showGlassDialog(
      context: context,
      barrierDismissible: false,
      title: const Row(
        children: [
          Icon(Icons.cloud_off_rounded, color: Colors.amber),
          SizedBox(width: 8),
          Text("離線模式預覽"),
        ],
      ),
      content: const Text(
        "目前偵測不到網路連線，無法登入伺服器。\n\n"
        "您仍可進入系統查看先前讀取過的快取資料。\n"
        "若要使用需要網路的功能，請連接網路並重新開啟 App。",
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context, rootNavigator: true).pop();
            setState(() {
              _result = "已取消離線登入";
              _isAutoLoggingIn = false;
              _isLoading = false;
            });
          },
          child: const Text("取消"),
        ),
        TextButton(
          onPressed: () {
            Navigator.of(context, rootNavigator: true).pop();
            _enterOfflineMode();
          },
          child: const Text(
            "確認進入",
            style: TextStyle(color: Colors.blue),
          ),
        ),
      ],
    );
  }

  void _enterOfflineMode() {
    // 設全域離線旗標，所有 service 的 http 呼叫會被攔截
    OfflineModeService.instance.enterOfflineMode();
    String userAgent = "Mozilla/5.0 (Offline Mode)";
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (context) =>
              MainMenuPage(cookies: "OFFLINE", userAgent: userAgent),
        ),
        (route) => false,
      );
    }
  }

  Future<void> _loadCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _usernameController.text = (prefs.getString('username') ?? "").trim();
      _passwordController.text = (prefs.getString('password') ?? "").trim();
      if (_usernameController.text.isNotEmpty) {
        _result = widget.isRelogin ? "連線逾時，重新登入中..." : "準備自動登入...";
      }
    });
  }

  Future<void> _saveCredentials() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();
    await StorageService.instance.saveCredentials(username, password);
  }

  Future<void> _startLoginProcess() async {
    // 離線模式:即使網路恢復也不允許聯網,必須重啟 App
    if (OfflineModeService.instance.isOffline) {
      _showOfflineDialog();
      return;
    }

    if (_usernameController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("請輸入學號和密碼"), duration: const Duration(seconds: 2)));
      return;
    }

    dynamic connectivityResult = await (Connectivity().checkConnectivity());
    bool isNone = (connectivityResult is List)
        ? connectivityResult.contains(ConnectivityResult.none)
        : connectivityResult == ConnectivityResult.none;

    if (isNone) {
      _showOfflineDialog();
      return;
    }

    setState(() {
      _isAutoLoggingIn = true;
      _isLoading = true;
      _result = "正在進行身分驗證...";
    });

    try {
      final String username = _usernameController.text.trim();
      final String password = _passwordController.text.trim();
      if (username.length < 9 || username.length > 11) {
        _handleLoginError("帳號或密碼錯誤");
        return;
      }
      final http.Client client = createHttpClient();

      try {
        final String base64md5Password = Utils.base64md5(password);
        final http.Request request =
            http.Request(
                'POST',
                Uri.parse(
                  'https://selcrs.nsysu.edu.tw/menu4/Studcheck_sso2.asp',
                ),
              )
              ..followRedirects = false
              ..headers['Content-Type'] = 'application/x-www-form-urlencoded'
              ..bodyFields = <String, String>{
                'stuid': username.toUpperCase(),
                'SPassword': base64md5Password,
              };

        final http.Response response = await http.Response.fromStream(
          await client.send(request).timeout(const Duration(seconds: 10)),
        );

        // 注意：學校伺服器的 Content-Type 不帶 charset，http 預設以 latin1 解碼會造成中文亂碼，
        // 導致「錯誤」等失敗訊息比對失敗（密碼錯誤卻判定登入成功）。改用 bodyBytes + utf8 解碼。
        String bodyText = utf8.decode(response.bodyBytes, allowMalformed: true);
        // debugPrint("bodyText: $bodyText");
        String? cookies = response.headers['set-cookie'];

        bool isFailureMessage =
            bodyText.contains("錯誤") || bodyText.contains("請重新輸入");
        // debugPrint("bodyText: $bodyText");
        if (cookies != null && cookies.isNotEmpty && !isFailureMessage) {
          String cookieString = cookies.split(';').first;

          if (response.statusCode == 302 || (response.statusCode == 200)) {
            if (bodyText.contains("請重新輸入")) {
              _handleLoginError("帳號或密碼錯誤");
              return;
            }
            _onLoginSuccess(cookieString);
          } else {
            _handleLoginError("帳號或密碼錯誤");
          }
        } else {
          _handleLoginError("帳號或密碼錯誤");
        }
      } finally {
        client.close();
      }
    } catch (e) {
      setState(() {
        _result = "❌ 連線錯誤";
        _isAutoLoggingIn = false;
        _isLoading = false;
      });
      if (_usernameController.text.isNotEmpty) _showOfflineDialog();
    }
  }

  void _onLoginSuccess(String cookieString) async {
    await _saveCredentials();

    // 記錄啟動（不等待，不影響登入流程）
    Utils.recordLaunch(_usernameController.text);

    // 同步快取至全域 SessionService
    SessionService.instance.setCookie(cookieString);

    String userAgent =
        "Mozilla/5.0 (Linux; Android 10; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.120 Mobile Safari/537.36";

    // 依是否已初始化過決定目的地
    final prefs = await SharedPreferences.getInstance();
    final bool hasInitialized = prefs.getBool('has_initialized') ?? false;
    final destination = buildPostLoginDestination(
      hasInitialized: hasInitialized,
      cookies: cookieString,
      userAgent: userAgent,
    );

    if (mounted) {
      setState(() {
        _result = "✅ 登入成功！";
        _isLoading = false;
      });

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => destination),
        (route) => false,
      );
    }
  }

  void _handleLoginError(String message) {
    setState(() {
      _result = "❌ $message";
      _isAutoLoggingIn = false;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final formContent = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.account_balance, size: 80, color: Colors.blueAccent),
        SizedBox(height: 20),
        Text(
          "NSYSU 校務系統",
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 10),
        Text(_result, style: TextStyle(color: colorScheme.bodyText)),
        SizedBox(height: 40),
        TextField(
          controller: _usernameController,
          decoration: InputDecoration(
            labelText: "學號",
            prefixIcon: Icon(Icons.person),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        SizedBox(height: 15),
        TextField(
          controller: _passwordController,
          obscureText: _obscurePassword,
          style: TextStyle(fontFamily: _obscurePassword ? '' : 'NotoSansTC'),
          decoration: InputDecoration(
            labelText: "密碼",
            prefixIcon: Icon(Icons.lock),
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword ? Icons.visibility : Icons.visibility_off,
                color: colorScheme.subtitleText,
              ),
              onPressed: () {
                setState(() {
                  _obscurePassword = !_obscurePassword;
                });
              },
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        SizedBox(height: 30),
        SizedBox(
          width: double.infinity,
          height: 55,
          child: ElevatedButton(
            onPressed: _isAutoLoggingIn ? null : _startLoginProcess,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueAccent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: _isAutoLoggingIn
                ? CircularProgressIndicator(color: Colors.white)
                : Text(
                    "登入系統",
                    style: TextStyle(fontSize: 18, color: Colors.white),
                  ),
          ),
        ),
      ],
    );

    if (LayoutStyleNotifier.instance.isLiquidGlass) {
      return Stack(
        children: [
          const AuroraBackground(),
          Scaffold(
            backgroundColor: Colors.transparent,
            body: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(30),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 450),
                  child: Container(
                    padding: const EdgeInsets.all(32),
                    decoration: glassCardDecoration(
                      context,
                      borderRadius: 24,
                    ),
                    child: formContent,
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    }

    return Scaffold(
      backgroundColor: colorScheme.pageBackground,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(30),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 450),
            child: formContent,
          ),
        ),
      ),
    );
  }
}
