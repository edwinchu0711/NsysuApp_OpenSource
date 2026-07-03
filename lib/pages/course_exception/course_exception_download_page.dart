// course_exception_download_page.dart

import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import '../../theme/app_theme.dart';
import '../../services/course_exception_service.dart';

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
  bool _isLoading = true;
  String _statusMessage = "正在連線系統...";
  String? _localHtmlPath;

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
      ),
      backgroundColor: colorScheme.pageBackground,
      body: _buildOverlayUI(),
    );
  }

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
          ] else ...[
            Icon(
              _statusMessage.contains("失敗")
                  ? Icons.error_outline
                  : Icons.check_circle_outline,
              color: _statusMessage.contains("失敗") ? Colors.red : Colors.green,
              size: 80,
            ),
            const SizedBox(height: 16),
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
}
