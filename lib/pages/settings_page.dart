import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
// 請確認這個 import 路徑是正確的
import 'package:permission_handler/permission_handler.dart'; // 1. 引入套件
import '../services/notification_service.dart'; 

class SettingsPage extends StatefulWidget {
  const SettingsPage({Key? key}) : super(key: key);

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _isCourseReminderEnabled = false;
  bool _isUpdateAlertEnabled = true;
  // ★★★ 新增：預覽名次開關 ★★★
  bool _isPreviewRankEnabled = false; 

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isCourseReminderEnabled = prefs.getBool('is_course_reminder_enabled') ?? false;
      _isUpdateAlertEnabled = prefs.getBool('is_update_alert_enabled') ?? true;
      // 讀取預覽設定
      _isPreviewRankEnabled = prefs.getBool('is_preview_rank_enabled') ?? false;
    });
  }

  Future<void> _toggleCourseReminder(bool value) async {
    // 如果使用者試圖「開啟」
    if (value) {
      var status = await Permission.notification.status;
      
      if (status.isDenied || status.isPermanentlyDenied) {
        // 請求權限
        status = await Permission.notification.request();
        
        // 如果使用者還是拒絕，或者之前已經永久拒絕
        if (status.isPermanentlyDenied || status.isDenied) {
          _showPermissionDialog(); // 彈出對話框引導去設定頁
          return; // 中斷執行，不切換開關
        }
      }
    }

    // --- 以下為原本的邏輯 ---
    setState(() {
      _isCourseReminderEnabled = value;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final notiService = NotificationService();

      await Future.wait([
        notiService.toggleNotification(value),
        prefs.setBool('is_course_reminder_enabled', value),
      ]);

      if (mounted) {
        _showSnackBar(value ? "已開啟提醒，將接收來自雲端的選課通知" : "已關閉提醒");
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isCourseReminderEnabled = !value);
        _showSnackBar("設定失敗，請檢查網路連線", isError: true);
      }
    }
  }

  // 新增：權限引導對話框
  void _showPermissionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("需要通知權限"),
        content: const Text("目前通知權限已關閉，請至系統設定中開啟，以接收選課提醒。"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("取消"),
          ),
          TextButton(
            onPressed: () {
              openAppSettings(); // 開啟手機的 App 設定頁面
              Navigator.pop(context);
            },
            child: const Text("前往設定"),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleUpdateAlert(bool value) async {
    setState(() => _isUpdateAlertEnabled = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_update_alert_enabled', value);
  }

  // ★★★ 新增：切換預覽名次 ★★★
  Future<void> _togglePreviewRank(bool value) async {
    setState(() => _isPreviewRankEnabled = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_preview_rank_enabled', value);
    
    if (value) {
      _showSnackBar("已開啟預覽名次功能，下次查詢成績時生效");
    }
  }
  
  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("設定"),
        centerTitle: true,
      ),
      body: ListView(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 20, 16, 10),
            child: Text("通知設定", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey)),
          ),
          SwitchListTile(
            title: const Text("選課提醒"),
            subtitle: const Text("接收由系統自動發送的即時選課通知"),
            secondary: const Icon(Icons.notifications_active_rounded, color: Colors.blueAccent),
            value: _isCourseReminderEnabled,
            onChanged: _toggleCourseReminder,
          ),
          
          const Divider(),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 20, 16, 10),
            child: Text("功能設定", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey)),
          ),
           // ★★★ 新增 UI：預覽名次 ★★★
          SwitchListTile(
            title: const Text("預覽名次"),
            subtitle: const Text("從其他系統抓取尚未正式公布的名次 (查詢時間會變長)"),
            secondary: const Icon(Icons.preview_rounded, color: Colors.pinkAccent),
            value: _isPreviewRankEnabled,
            onChanged: _togglePreviewRank,
          ),
          SwitchListTile(
            title: const Text("更新警示"),
            subtitle: const Text("當有新版本時，在首頁右上角顯示紅色提示"),
            secondary: const Icon(Icons.system_update_rounded, color: Colors.orange),
            value: _isUpdateAlertEnabled,
            onChanged: _toggleUpdateAlert,
          ),
          const Divider(),
        ],
      ),
    );
  }
}