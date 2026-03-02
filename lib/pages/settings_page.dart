import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({Key? key}) : super(key: key);

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _isUpdateAlertEnabled = true;
  bool _isPreviewRankEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  // 載入偏好設定
  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isUpdateAlertEnabled = prefs.getBool('is_update_alert_enabled') ?? true;
      _isPreviewRankEnabled = prefs.getBool('is_preview_rank_enabled') ?? false;
    });
  }

  // 切換預覽名次
  Future<void> _togglePreviewRank(bool value) async {
    setState(() => _isPreviewRankEnabled = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_preview_rank_enabled', value);
    
    if (value) {
      _showSnackBar("已開啟預覽名次功能，下一次查詢成績時生效");
    }
  }

  // 切換更新警示
  Future<void> _toggleUpdateAlert(bool value) async {
    setState(() => _isUpdateAlertEnabled = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_update_alert_enabled', value);
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
            child: Text(
              "功能設定", 
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey)
            ),
          ),
          
          // 預覽名次開關
          SwitchListTile(
            title: const Text("預覽名次"),
            subtitle: const Text("從其他系統抓取尚未正式公布的名次 (查詢時間會變長)"),
            secondary: const Icon(Icons.preview_rounded, color: Colors.pinkAccent),
            value: _isPreviewRankEnabled,
            onChanged: _togglePreviewRank,
          ),

          // 更新警示開關
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