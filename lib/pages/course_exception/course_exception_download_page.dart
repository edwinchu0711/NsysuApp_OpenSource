// course_exception_download_page.dart

import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../../utils/utils.dart';

class AbnormalWebViewPage extends StatefulWidget {
  final Map<String, String> postData;
  final String stuid;
  final String password;

  const AbnormalWebViewPage({
    Key? key, 
    required this.postData, 
    required this.stuid, 
    required this.password
  }) : super(key: key);

  @override
  State<AbnormalWebViewPage> createState() => _AbnormalWebViewPageState();
}

class _AbnormalWebViewPageState extends State<AbnormalWebViewPage> {
  InAppWebViewController? webViewController;
  int _processStep = 0; 
  bool _isLoading = true;
  String _statusMessage = "正在連線系統...";

  final String loginUrl = "https://selcrs.nsysu.edu.tw/menu4/Studcheck_sso2.asp";
  final String mainFrameUrl = "https://selcrs.nsysu.edu.tw/menu4/main_frame.asp";
  final String submitUrl = "https://selcrs.nsysu.edu.tw/menu4/query/abnormal.asp";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("申請流程"), centerTitle: true),
      body: Stack(
        children: [
          SizedBox(
            height: 1, // 保持隱藏
            child: InAppWebView(
              initialUrlRequest: URLRequest(
                url: WebUri(loginUrl),
                method: 'POST',
                body: Uint8List.fromList(utf8.encode(
                  "stuid=${widget.stuid.toUpperCase()}&SPassword=${Utils.base64md5(widget.password)}"
                )),
                headers: {
                  'Content-Type': 'application/x-www-form-urlencoded',
                  'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
                },
              ),
              onWebViewCreated: (controller) => webViewController = controller,
              // 加入錯誤偵測
              onReceivedError: (controller, request, error) {
                print("🌐 WebView Error: ${error.description}");
              },
              onLoadStop: (controller, url) async {
                String urlString = url.toString();
                print("📍 目前停留頁面: $urlString (Step: $_processStep)");

                // --- 步驟 0: 登入結果判定 ---
                if (_processStep == 0) {
                  String? html = await controller.getHtml();
                  
                  if (html != null && html.contains("不符")) {
                    setState(() { _isLoading = false; _statusMessage = "登入失敗：帳號或密碼錯誤"; });
                    return;
                  }

                  // 只要 URL 變了，或是 HTML 內出現登出字眼，就算登入成功
                  if (urlString.contains("menu.asp") || urlString.contains("main") || (html?.contains("登出") ?? false)) {
                    print("✅ 登入成功，準備進入主框架");
                    _processStep = 1;
                    setState(() => _statusMessage = "初始化環境中...");
                    await controller.loadUrl(urlRequest: URLRequest(url: WebUri(mainFrameUrl)));
                    return;
                  }
                }

                // --- 步驟 1: 主框架載入後提交表單 ---
                if (_processStep == 1 && urlString.contains("main_frame.asp")) {
                  print("🚀 已抵達主框架，準備 POST 申請資料");
                  _processStep = 2;
                  setState(() => _statusMessage = "正在送出申請表單...");
                  _performPostSubmit(controller);
                  return;
                }

                // --- 步驟 2: 處理最終結果 ---
                if (_processStep == 2 && urlString.contains("abnormal.asp")) {
                  print("🎯 已抵達結果頁面");
                  _processStep = 3;
                  await _finalizeProcess(controller);
                }
              },
            ),
          ),
          _buildOverlayUI(),
        ],
      ),
    );
  }

  Future<void> _performPostSubmit(InAppWebViewController controller) async {
    String postFields = widget.postData.entries
        .map((e) => "${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}")
        .join('&');

    await controller.postUrl(
      url: WebUri(submitUrl),
      postData: Uint8List.fromList(utf8.encode(postFields)),
    );
  }

  Future<void> _finalizeProcess(InAppWebViewController controller) async {
    String? bodyText = await controller.evaluateJavascript(source: "document.body.innerText");
    await controller.evaluateJavascript(source: "document.querySelectorAll('input[type=\"button\"]').forEach(btn => btn.style.display='none');");

    setState(() {
      _isLoading = false;
      if (bodyText != null && (bodyText.contains("成功") || bodyText.contains("完成"))) {
        _statusMessage = "申請已成功送出！";
      } else {
        _statusMessage = "流程處理完畢";
      }
    });
  }

  Widget _buildOverlayUI() {
    return Container(
      color: Colors.white,
      width: double.infinity,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (_isLoading) ...[
            const CircularProgressIndicator(),
            const SizedBox(height: 20),
            Text(_statusMessage, style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 10),
            // 加入強制跳轉按鈕，以防自動判定失效
            TextButton(
              onPressed: () => _forceSubmit(),
              child: const Text("點此強制送出 (若卡住超過5秒)", style: TextStyle(color: Colors.grey)),
            )
          ] else ...[
            Icon(
              _statusMessage.contains("失敗") ? Icons.error_outline : Icons.check_circle_outline,
              color: _statusMessage.contains("失敗") ? Colors.red : Colors.green, size: 80,
            ),
            const SizedBox(height: 16),
            Text(_statusMessage, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 40),
            if (!_statusMessage.contains("失敗"))
              ElevatedButton.icon(
                onPressed: () => webViewController?.printCurrentPage(),
                icon: const Icon(Icons.print),
                label: const Text("列印結果或下載PDF"),
                style: ElevatedButton.styleFrom(minimumSize: const Size(200, 50)),
              ),
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("返回")),
          ],
        ],
      ),
    );
  }

  // 強制執行下一步的保險手段
  void _forceSubmit() {
    if (webViewController != null) {
      if (_processStep == 0) {
         _processStep = 1;
         webViewController!.loadUrl(urlRequest: URLRequest(url: WebUri(mainFrameUrl)));
      } else if (_processStep == 1) {
         _processStep = 2;
         _performPostSubmit(webViewController!);
      }
    }
  }
}