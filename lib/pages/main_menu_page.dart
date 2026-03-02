/*

This file contains code derived from the NSYSU Open Development Community project.

Original Copyright (c) 2024 NSYSU Open Development Community

Licensed under the MIT License.

*/

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';


// 原有的頁面 Import
import 'score_result_page.dart';
import 'open_score_page.dart';
import 'captcha_auto_login_page.dart';
import 'course_schedule_page.dart';
import 'info_page.dart';
import 'calendar_page.dart'; // 加入這一行
import 'dart:async';
import 'dart:math'; // <--- 加入這行
import 'course_assistant/course_assistant_page.dart'; // ✅ 新增這行：選課助手頁面

// Service Import
import '../services/open_score_service.dart';
import '../services/historical_score_service.dart';
import '../services/course_service.dart';
import '../services/exam_task/elearn_task_HW_service.dart';
import '../services/elearn_bulletin_service.dart';
import '../services/version_service.dart';
import '../services/graduation_service.dart';
import '../services/cache_manager.dart';

// --- 新增的頁面 Import ---
import 'graduation_page.dart';
import 'announcement_page.dart';
import 'exam_task/exam_task_page.dart';

// --- 選單頁面 Import ---
import 'course_selection_schedule_page.dart';
import 'settings_page.dart';
import 'app_version_page.dart';
// TODO: 如果你有建立行事曆頁面，請記得 import，例如：
// import 'calendar_page.dart';

class MainMenuPage extends StatefulWidget {
  final String cookies;
  final String userAgent;

  const MainMenuPage({
    Key? key,
    required this.cookies,
    required this.userAgent,
  }) : super(key: key);

  @override
  State<MainMenuPage> createState() => _MainMenuPageState();
}

class _MainMenuPageState extends State<MainMenuPage> {
  bool _isFirstTimeLoading = false;
  bool _hasNewVersion = false;
  bool _isUpdateAlertEnabled = true;
  final ValueNotifier<double> _fakeProgressNotifier = ValueNotifier(0.0);

  // --- 新增：滑動控制器與箭頭顯示狀態 ---
  late ScrollController _scrollController;
  bool _showScrollArrow = true;

  @override
  void initState() {
    super.initState();
    
    // 初始化 ScrollController 並監聽
    _scrollController = ScrollController();
    _scrollController.addListener(_scrollListener);

    OpenScoreService.instance.statusMessageNotifier.addListener(_handleSessionExpiry);
    _checkAndStartTasks();
    _checkNewVersion();
    _loadSettings();
  }

  @override
  void dispose() {
    // 記得銷毀 Controller
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    
    OpenScoreService.instance.statusMessageNotifier.removeListener(_handleSessionExpiry);
    super.dispose();
  }

  Future<void> _runRealisticLoading() async {
    // 1. 【起步】先停在 0% 延遲 1 秒
    _fakeProgressNotifier.value = 0.0;
    await Future.delayed(const Duration(milliseconds: 1700));
    
    double currentProgress = 0.0;
    Random rng = Random();

    // 2. 【中間】模擬不穩定的讀取過程 (目標約 4.5 秒跑完)
    // 我們用 while 迴圈慢慢加，直到 1.0
    while (currentProgress < 1.0) {
      if (!mounted) return;

      // 隨機決定這次加多少進度 (模擬有時候載入多，有時候載入少)
      // 80% 機率加一點點 (0.005 ~ 0.03)
      // 20% 機率突然衝刺 (0.05 ~ 0.15)
      double increment = 0.0;
      if (rng.nextDouble() > 0.8) {
        increment = 0.05 + rng.nextDouble() * 0.06; // 大跳躍
      } else {
        increment = 0.005 + rng.nextDouble() * 0.016; // 慢慢爬
      }

      currentProgress += increment;
      
      // 限制不要超過 1.0
      if (currentProgress >= 1.0) {
        currentProgress = 1.0;
      }

      // 更新 UI
      _fakeProgressNotifier.value = currentProgress;

      // 隨機決定這次停頓多久 (模擬網路延遲)
      // 範圍 50ms ~ 200ms 之間跳動
      int delayMs = 50 + rng.nextInt(150); 
      
      // 如果進度接近 90%~99%，故意卡久一點 (模擬最後處理)
      if (currentProgress > 0.9 && currentProgress < 1.0) {
        delayMs += 130; 
      }

      await Future.delayed(Duration(milliseconds: delayMs));
    }

    // 3. 【結尾】到達 100% 後，再延遲 1 秒
    await Future.delayed(const Duration(milliseconds: 2200));

    // 時間到！進入主頁
    if (mounted) {
      setState(() {
        _isFirstTimeLoading = false;
      });
    }
  }
  // --- 新增：滑動監聽邏輯 ---
  void _scrollListener() {
    // 當滑動距離超過 20 像素時，隱藏箭頭
    if (_scrollController.offset > 20 && _showScrollArrow) {
      setState(() {
        _showScrollArrow = false;
      });
    } else if (_scrollController.offset <= 20 && !_showScrollArrow) {
      // 如果回到頂部，重新顯示箭頭 (可選，看你喜好)
      setState(() {
        _showScrollArrow = true;
      });
    }
  }

  void _showElearnMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                const SizedBox(height: 15),
                const Text(
                  "網路大學",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 15),
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Colors.redAccent,
                    child: Icon(Icons.campaign_rounded, color: Colors.white),
                  ),
                  title: const Text("網大公告", style: TextStyle(fontSize: 16)),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () {
                    Navigator.pop(ctx);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const AnnouncementPage()),
                    );
                  },
                ),
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Colors.indigo,
                    child: Icon(Icons.task_rounded, color: Colors.white),
                  ),
                  title: const Text("作業與考試", style: TextStyle(fontSize: 16)),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () {
                    Navigator.pop(ctx);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const ExamTaskPage()),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
  
  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _isUpdateAlertEnabled = prefs.getBool('is_update_alert_enabled') ?? true;
      });
    }
  }

  Future<void> _checkNewVersion() async {
    try {
      final result = await VersionService().checkVersionStatus();
      if (mounted && result.hasNewStable) {
        setState(() {
          _hasNewVersion = true;
        });
      }
    } catch (e) {
      print("版本檢查失敗: $e");
    }
  }

  Future<void> _checkAndStartTasks() async {
    final prefs = await SharedPreferences.getInstance();
    bool hasCourseCache = prefs.containsKey('cached_courses');

    if (!hasCourseCache) {
      // --- 初始化模式 ---
      final prefs = await SharedPreferences.getInstance();
      prefs.setBool('is_preview_rank_enabled', true); // 預先設定預覽名次為開啟，讓使用者第一次進來就能看到這個功能 (可選)
      setState(() {
        _isFirstTimeLoading = true;
      });

      // 1. 背景默默跑任務 (不管它何時好，也不管失敗)
      _startBackgroundTask().then((_) {
        print("背景任務完成");
      }).catchError((e) {
        print("背景任務異常(忽略): $e");
      });

      // 2. 前台跑擬真的 6.5秒 動畫，UI 聽這個的
      await _runRealisticLoading();

    } else {
      // --- 一般模式 (非第一次) ---
      _startBackgroundTask();
    }
  }
  
  
  Future<void> _startBackgroundTask() async {
    try {
      await CourseService.instance.refreshAndCache();
      if (_isScoreReleaseSeason()) {
        await OpenScoreService.instance.fetchOpenScores();
      }
      await HistoricalScoreService.instance.fetchAllData();
    } catch (e) {
      print("❌ 背景抓取發生錯誤: $e");
    }
  }

  bool _isScoreReleaseSeason() {
    DateTime now = DateTime.now();
    int month = now.month;
    int day = now.day;
    bool isWinter = (month == 12 && day >= 15) || (month == 1 && day <= 15);
    bool isSummer = (month == 5 && day >= 15) || (month == 6 && day <= 15);
    return isWinter || isSummer;
  }

  void _handleSessionExpiry() {
    final msg = OpenScoreService.instance.statusMessageNotifier.value;
    if (msg == "Session失效" || msg == "Session Timeout") {
      _navigateToLogin(isRelogin: true);
    }
  }

  void _navigateToLogin({bool isRelogin = false}) {
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => CaptchaAutoLoginPage(isRelogin: isRelogin),
      ),
    );
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      CourseService.instance.clearCache(),
      OpenScoreService.instance.clearCache(),
      HistoricalScoreService.instance.clearCache(),
      ElearnService.instance.clearAllCache(),
      ElearnBulletinService.instance.clearCache(),
      GraduationService.instance.clearCache(),
    ]);

    await prefs.clear();

    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => CaptchaAutoLoginPage()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          CustomScrollView(
            controller: _scrollController,
            slivers: [
              // 1. 可隱藏的 AppBar
              SliverAppBar(
                title: const Text("校務通功能選單"),
                centerTitle: true,
                floating: true, 
                snap: true,     
                pinned: false,  
                actions: [
                  PopupMenuButton<String>(
                    icon: (_hasNewVersion && _isUpdateAlertEnabled)
                        ? const Icon(Icons.error_rounded, color: Colors.red, size: 28)
                        : const Icon(Icons.more_vert),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    onSelected: (value) async {
                      switch (value) {
                        case 'settings':
                          await Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const SettingsPage()),
                          );
                          if (mounted) _loadSettings();
                          break;
                        case 'app_version':
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const AppVersionPage()),
                          );
                          break;
                        case 'clear_cache':
                          _showClearCacheDialog();
                          break;
                        case 'info':
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const InfoPage()),
                          );
                          break;
                        case 'logout':
                          _showLogoutDialog();
                          break;
                      }
                    },
                    itemBuilder: (BuildContext context) => [
                      const PopupMenuItem(
                        value: 'settings',
                        height: 40,
                        child: ListTile(
                          dense: true,
                          leading: Icon(Icons.settings_rounded, color: Colors.blueGrey),
                          title: Text('設定'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      PopupMenuItem(
                        value: 'app_version',
                        height: 40,
                        child: ListTile(
                          dense: true,
                          leading: Icon(
                            _hasNewVersion ? Icons.system_update : Icons.verified_user_rounded,
                            color: _hasNewVersion ? Colors.red : Colors.green,
                          ),
                          title: Text(
                            _hasNewVersion ? '更新APP' : 'App版本',
                            style: TextStyle(
                              color: _hasNewVersion ? Colors.red : null,
                              fontWeight: _hasNewVersion ? FontWeight.bold : null,
                            ),
                          ),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'clear_cache',
                        height: 40,
                        child: ListTile(
                          dense: true,
                          leading: Icon(Icons.delete_sweep_outlined, color: Colors.orange),
                          title: Text('清除暫存檔案'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'info',
                        height: 40,
                        child: ListTile(
                          dense: true,
                          leading: Icon(Icons.info_outline, color: Colors.blue),
                          title: Text('使用說明'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'logout',
                        height: 40,
                        child: ListTile(
                          dense: true,
                          leading: Icon(Icons.logout, color: Colors.red),
                          title: Text('登出系統'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              // 2. 歡迎區塊
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.1),
                          spreadRadius: 2,
                          blurRadius: 5,
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("歡迎使用", style: TextStyle(fontSize: 16, color: Colors.grey[600])),
                        const SizedBox(height: 5),
                        Text(
                          "學生服務系統",
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[800],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // 3. 功能按鈕網格
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10),
                sliver: SliverGrid.count(
                  crossAxisCount: 2,
                  crossAxisSpacing: 15,
                  mainAxisSpacing: 15,
                  children: [
                    // 1. 學期成績
                    _buildMenuButton(
                      context,
                      icon: Icons.school_rounded,
                      label: "學期成績查詢",
                      color: Colors.blue,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ScoreResultPage(cookies: widget.cookies),
                        ),
                      ),
                    ),
                    // 2. 開放成績
                    _buildMenuButton(
                      context,
                      icon: Icons.assignment_turned_in_rounded,
                      label: "開放成績查詢",
                      color: Colors.teal,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => OpenScorePage(
                            cookies: widget.cookies,
                            userAgent: widget.userAgent,
                          ),
                        ),
                      ),
                    ),
                    // 3. 課表查詢
                    _buildMenuButton(
                      context,
                      icon: Icons.calendar_month_rounded,
                      label: "課表查詢",
                      color: Colors.orange,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const CourseSchedulePage()),
                      ),
                    ),
                    // 4. 畢業檢核
                    _buildMenuButton(
                      context,
                      icon: Icons.fact_check_rounded,
                      label: "畢業檢核",
                      color: Colors.purple,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const GraduationPage()),
                      ),
                    ),
                    // 5. 選課助手 (新增)
                    _buildMenuButton(
                      context,
                      icon: Icons.assistant_rounded,
                      label: "選課助手",
                      color: Colors.lightBlue,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const CourseAssistantPage()),
                      ),
                    ),
                    // 6. 選課系統
                    _buildMenuButton(
                      context,
                      icon: Icons.date_range_rounded,
                      label: "選課系統",
                      color: const Color.fromARGB(255, 255, 29, 13),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const CourseSelectionSchedulePage()),
                      ),
                    ),
                    
                    // 7. 網路大學 (整合公告與考試)
                    _buildMenuButton(
                      context,
                      icon: Icons.laptop_chromebook_rounded,
                      label: "網路大學",
                      color: const Color.fromARGB(255, 65, 211, 133),
                      onTap: () => _showElearnMenu(context),
                    ),
                    // 8. 行事曆
                    _buildMenuButton(
                      context,
                      icon: Icons.event_note_rounded,
                      label: "行事曆",
                      color: const Color.fromARGB(255, 228, 55, 113),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const CalendarPage()),
                      ),
                    ),
                  ],
                ),
              ),
              
              // 底部留白
              const SliverToBoxAdapter(
                child: SizedBox(height: 60), 
              ),
            ],
          ),

          // 下滑提示箭頭
          Positioned(
            bottom: 20,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 300),
                opacity: _showScrollArrow ? 1.0 : 0.0,
                child: Column(
                  children: [
                    Text(
                      "更多功能",
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        shadows: const [
                          Shadow(color: Colors.white, blurRadius: 5)
                        ]
                      ),
                    ),
                    Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: Colors.blue[800]?.withOpacity(0.8),
                      size: 36,
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          // 載入中的遮罩
          if (_isFirstTimeLoading)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.85),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        "系統初始化中",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          decoration: TextDecoration.none
                        ),
                      ),
                      const SizedBox(height: 40),
                      ValueListenableBuilder<double>(
                        valueListenable: _fakeProgressNotifier, 
                        builder: (context, progress, _) {
                          int percent = (progress * 100).toInt();
                          return Column(
                            children: [
                              Text(
                                "$percent%",
                                style: const TextStyle(
                                  color: Colors.blueAccent,
                                  fontSize: 32,
                                  fontWeight: FontWeight.w900,
                                  decoration: TextDecoration.none
                                ),
                              ),
                              const SizedBox(height: 25),
                              SizedBox(
                                width: 220,
                                height: 10,
                                child: LinearProgressIndicator(
                                  value: progress,
                                  backgroundColor: Colors.white10,
                                  color: Colors.blueAccent,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
  // 按鈕組件保持不變
  Widget _buildMenuButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(15),
      elevation: 2,
      child: InkWell(
        borderRadius: BorderRadius.circular(15),
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 35, color: color),
            ),
            const SizedBox(height: 15),
            Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  // Dialog 相關函數保持不變...
  void _showLogoutDialog() {
     showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text("確認登出"),
        content: const Text("確定要登出並清除所有個人紀錄嗎？下次登入將重新初始化。"),
        actions: [
          TextButton(
            child: const Text("取消"),
            onPressed: () => Navigator.pop(ctx),
          ),
          TextButton(
            child: const Text("登出", style: TextStyle(color: Colors.red)),
            onPressed: () {
              Navigator.pop(ctx);
              _logout();
            },
          ),
        ],
      ),
    );
  }

  void _showClearCacheDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.cleaning_services, color: Colors.orange),
            SizedBox(width: 8),
            Text("清除暫存"),
          ],
        ),
        content: const Text("這將會刪除所有下載過的 PDF 、附件檔案與部分快取，但不會登出帳號。確定要執行嗎？"),
        actions: [
          TextButton(
            child: const Text("取消"),
            onPressed: () => Navigator.pop(ctx),
          ),
          TextButton(
            child: const Text("確定清除", style: TextStyle(color: Colors.orange)),
            onPressed: () async {
              Navigator.pop(ctx); 
              
              try {
                await Future.wait([
                  AppCacheManager.performCacheCleanup(), 
                  AppCacheManager.clearAllServiceCache(), 
                ]);

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("檔案和部分快取已清除")),
                  );
                  _checkAndStartTasks(); 
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("清理失敗: $e"), backgroundColor: Colors.red),
                  );
                }
              }
            },
          ),
        ],
      ),
    );
  }
}