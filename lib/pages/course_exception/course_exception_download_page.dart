// course_exception_download_page.dart

import 'package:flutter/material.dart';
<<<<<<< HEAD
import 'package:open_filex/open_filex.dart';
import '../../theme/app_theme.dart';
import '../../services/course_exception_service.dart';
=======
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../../utils/utils.dart';
import '../../theme/app_theme.dart';
>>>>>>> cb0e69536426ceb2a943a1d70f3df893136211d7

class AbnormalWebViewPage extends StatefulWidget {
  final Map<String, String> postData;
  final String stuid;
  final String password;

  const AbnormalWebViewPage({
    Key? key,
    required this.postData,
    required this.stuid,
    required this.password,
  }) : super(key: key);

  @override
  State<AbnormalWebViewPage> createState() => _AbnormalWebViewPageState();
}

class _AbnormalWebViewPageState extends State<AbnormalWebViewPage> {
<<<<<<< HEAD
=======
  InAppWebViewController? webViewController;
  int _processStep = 0;
>>>>>>> cb0e69536426ceb2a943a1d70f3df893136211d7
  bool _isLoading = true;
  String _statusMessage = "正在連線系統...";
  String? _localHtmlPath;

<<<<<<< HEAD
  @override
  void initState() {
    super.initState();
    _startProcess();
  }

  Future<void> _startProcess() async {
    try {
      setState(() {
        _isLoading = true;
        _statusMessage = "正在登入並送出申請表單...";
      });

      final path = await CourseExceptionService.submitException(
        stuid: widget.stuid,
        password: widget.password,
        postData: widget.postData,
      );

      setState(() {
        _isLoading = false;
        _localHtmlPath = path;
        _statusMessage = "申請已成功送出！";
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = "處理失敗：${e.toString().replaceFirst('Exception: ', '')}";
      });
    }
  }
=======
  final String loginUrl =
      "https://selcrs.nsysu.edu.tw/menu4/Studcheck_sso2.asp";
  final String mainFrameUrl =
      "https://selcrs.nsysu.edu.tw/menu4/main_frame.asp";
  final String submitUrl =
      "https://selcrs.nsysu.edu.tw/menu4/query/abnormal.asp";
>>>>>>> cb0e69536426ceb2a943a1d70f3df893136211d7

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text("申請流程"),
        centerTitle: true,
        backgroundColor: colorScheme.cardBackground,
        foregroundColor: colorScheme.primaryText,
        elevation: 0.5,
<<<<<<< HEAD
=======
      ),
      backgroundColor: colorScheme.pageBackground,
      body: Stack(
        children: [
          SizedBox(
            height: 1, // 保持隱藏
            child: InAppWebView(
              initialUrlRequest: URLRequest(
                url: WebUri(loginUrl),
                method: 'POST',
                body: Uint8List.fromList(
                  utf8.encode(
                    "stuid=${widget.stuid.toUpperCase()}&SPassword=${Utils.base64md5(widget.password)}",
                  ),
                ),
                headers: {
                  'Content-Type': 'application/x-www-form-urlencoded',
                  'User-Agent':
                      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
                },
              ),
              onWebViewCreated: (controller) => webViewController = controller,
              // 加入錯誤偵測
              onReceivedError: (controller, request, error) {
                debugPrint("🌐 WebView Error: ${error.description}");
              },
              onLoadStop: (controller, url) async {
                String urlString = url.toString();
                debugPrint("📍 目前停留頁面: $urlString (Step: $_processStep)");

                // --- 步驟 0: 登入結果判定 ---
                if (_processStep == 0) {
                  String? html = await controller.getHtml();

                  if (html != null && html.contains("不符")) {
                    setState(() {
                      _isLoading = false;
                      _statusMessage = "登入失敗：帳號或密碼錯誤";
                    });
                    return;
                  }

                  // 只要 URL 變了，或是 HTML 內出現登出字眼，就算登入成功
                  if (urlString.contains("menu.asp") ||
                      urlString.contains("main") ||
                      (html?.contains("登出") ?? false)) {
                    // debugPrint("✅ 登入成功，準備進入主框架");
                    _processStep = 1;
                    setState(() => _statusMessage = "初始化環境中...");
                    await controller.loadUrl(
                      urlRequest: URLRequest(url: WebUri(mainFrameUrl)),
                    );
                    return;
                  }
                }

                // --- 步驟 1: 主框架載入後提交表單 ---
                if (_processStep == 1 && urlString.contains("main_frame.asp")) {
                  debugPrint("🚀 已抵達主框架，準備 POST 申請資料");
                  _processStep = 2;
                  setState(() => _statusMessage = "正在送出申請表單...");
                  _performPostSubmit(controller);
                  return;
                }

                // --- 步驟 2: 處理最終結果 ---
                if (_processStep == 2 && urlString.contains("abnormal.asp")) {
                  debugPrint("🎯 已抵達結果頁面");
                  _processStep = 3;
                  await _finalizeProcess(controller);
                }
              },
            ),
          ),
          _buildOverlayUI(),
        ],
>>>>>>> cb0e69536426ceb2a943a1d70f3df893136211d7
      ),
      backgroundColor: colorScheme.pageBackground,
      body: _buildOverlayUI(),
    );
  }

<<<<<<< HEAD
=======
  Future<void> _performPostSubmit(InAppWebViewController controller) async {
    String postFields = widget.postData.entries
        .map(
          (e) =>
              "${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}",
        )
        .join('&');

    await controller.postUrl(
      url: WebUri(submitUrl),
      postData: Uint8List.fromList(utf8.encode(postFields)),
    );
  }

  Future<void> _finalizeProcess(InAppWebViewController controller) async {
    String? bodyText = await controller.evaluateJavascript(
      source: "document.body.innerText",
    );
    await controller.evaluateJavascript(
      source:
          "document.querySelectorAll('input[type=\"button\"]').forEach(btn => btn.style.display='none');",
    );

    setState(() {
      _isLoading = false;
      if (bodyText != null &&
          (bodyText.contains("成功") || bodyText.contains("完成"))) {
        _statusMessage = "申請已成功送出！";
      } else {
        _statusMessage = "流程處理完畢";
      }
    });
  }

>>>>>>> cb0e69536426ceb2a943a1d70f3df893136211d7
  Widget _buildOverlayUI() {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      color: colorScheme.pageBackground,
      width: double.infinity,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (_isLoading) ...[
            CircularProgressIndicator(color: colorScheme.primary),
            const SizedBox(height: 20),
            Text(
              _statusMessage,
              style: TextStyle(
                fontSize: 16,
                color: colorScheme.primaryText,
                fontWeight: FontWeight.w500,
              ),
            ),
<<<<<<< HEAD
=======
            const SizedBox(height: 10),
            // 加入強制跳轉按鈕，以防自動判定失效
            TextButton(
              onPressed: () => _forceSubmit(),
              child: Text(
                "點此強制送出 (若卡住超過5秒)",
                style: TextStyle(color: colorScheme.subtitleText),
              ),
            ),
>>>>>>> cb0e69536426ceb2a943a1d70f3df893136211d7
          ] else ...[
            Icon(
              _statusMessage.contains("失敗")
                  ? Icons.error_outline
                  : Icons.check_circle_outline,
              color: _statusMessage.contains("失敗") ? Colors.red : Colors.green,
              size: 80,
            ),
            const SizedBox(height: 16),
<<<<<<< HEAD
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                _statusMessage,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.primaryText,
                ),
              ),
            ),
            const SizedBox(height: 40),
            if (!_statusMessage.contains("失敗") && _localHtmlPath != null)
              ElevatedButton.icon(
                onPressed: () => OpenFilex.open(_localHtmlPath!),
                icon: const Icon(Icons.open_in_new),
                label: const Text("檢視收執聯或列印/下載PDF"),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(220, 50),
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
              ),
=======
            Text(
              _statusMessage,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: colorScheme.primaryText,
              ),
            ),
            const SizedBox(height: 40),
            if (!_statusMessage.contains("失敗"))
              ElevatedButton.icon(
                onPressed: () => webViewController?.printCurrentPage(),
                icon: const Icon(Icons.print),
                label: const Text("列印結果或下載PDF"),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(200, 50),
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
              ),
>>>>>>> cb0e69536426ceb2a943a1d70f3df893136211d7
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("返回", style: TextStyle(color: colorScheme.primary)),
            ),
          ],
        ],
      ),
    );
  }
<<<<<<< HEAD
=======

  // 強制執行下一步的保險手段
  void _forceSubmit() {
    if (webViewController != null) {
      if (_processStep == 0) {
        _processStep = 1;
        webViewController!.loadUrl(
          urlRequest: URLRequest(url: WebUri(mainFrameUrl)),
        );
      } else if (_processStep == 1) {
        _processStep = 2;
        _performPostSubmit(webViewController!);
      }
    }
  }
>>>>>>> cb0e69536426ceb2a943a1d70f3df893136211d7
}
