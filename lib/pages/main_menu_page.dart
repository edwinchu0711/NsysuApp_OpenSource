/*

This file contains code derived from the NSYSU Open Development Community project.

Original Copyright (c) 2024 NSYSU Open Development Community

Licensed under the MIT License.

*/

import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';

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
import 'score_tracking_page.dart';
import 'course_progress_page.dart';
import 'settings_page.dart';
import 'app_version_page.dart';
import 'bus/bus_list_page.dart';
import 'about_developer_page.dart';

// --- 首頁選單資料模型 ---
class MainMenuItem {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final String section;
  final WidgetBuilder? pageBuilder;
  final VoidCallback onTap;

  MainMenuItem({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.section,
    this.pageBuilder,
    required this.onTap,
  });
}

class MainMenuPage extends StatefulWidget {
  final String cookies;
  final String userAgent;

  const MainMenuPage({Key? key, required this.cookies, required this.userAgent})
    : super(key: key);

  @override
  State<MainMenuPage> createState() => _MainMenuPageState();
}

class _MainMenuPageState extends State<MainMenuPage> {
  bool _isFirstTimeLoading = false;
  bool _hasNewVersion = false;
  bool _isUpdateAlertEnabled = true;
  String _layoutStyle = 'default';
  final ValueNotifier<double> _fakeProgressNotifier = ValueNotifier(0.0);

  // --- 新增：滑動控制器與箭頭顯示狀態 ---
  late ScrollController _scrollController;
  bool _showScrollArrow = false;
  bool _isScrolled = false;

  @override
  void initState() {
    super.initState();

    // 初始化 ScrollController 並監聽
    _scrollController = ScrollController();
    _scrollController.addListener(_scrollListener);

    OpenScoreService.instance.statusMessageNotifier.addListener(
      _handleSessionExpiry,
    );
    _checkAndStartTasks();
    _checkNewVersion();
    _loadSettings();
  }

  @override
  void dispose() {
    // 記得銷毀 Controller
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();

    OpenScoreService.instance.statusMessageNotifier.removeListener(
      _handleSessionExpiry,
    );
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

  // --- 新增：滑動監聽邏輯與狀態更新 ---
  void _updateScrollArrowState() {
    if (!mounted) return;
    if (_scrollController.hasClients) {
      final maxScroll = _scrollController.position.maxScrollExtent;
      final currentOffset = _scrollController.offset;
      // 只有當最大可滾動範圍大於 10 像素（代表確實有空間可滾動），
      // 且使用者尚未滾動到接近底部（大於 maxScroll - 20）時，才顯示提示箭頭
      final bool shouldShow =
          maxScroll > 10.0 && currentOffset < (maxScroll - 20.0);
      if (_showScrollArrow != shouldShow) {
        setState(() {
          _showScrollArrow = shouldShow;
        });
      }
    } else {
      if (_showScrollArrow) {
        setState(() {
          _showScrollArrow = false;
        });
      }
    }
  }

  void _scrollListener() {
    _updateScrollArrowState();
    if (_scrollController.hasClients) {
      final bool isScrolledNow = _scrollController.offset > 0.0;
      if (_isScrolled != isScrolledNow) {
        setState(() {
          _isScrolled = isScrolledNow;
        });
      }
    }
  }

  void _showElearnMenu(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final screenWidth = MediaQuery.of(context).size.width;
    final isWideScreen = screenWidth >= 900;

    showModalBottomSheet(
      context: context,
      backgroundColor: colorScheme.cardBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      constraints: isWideScreen ? const BoxConstraints(maxWidth: 480) : null,
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
                    color: colorScheme.borderColor,
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
                      MaterialPageRoute(
                        builder: (context) => const AnnouncementPage(),
                      ),
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
                      MaterialPageRoute(
                        builder: (context) => const ExamTaskPage(),
                      ),
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
        _isUpdateAlertEnabled =
            prefs.getBool('is_update_alert_enabled') ?? true;
        _layoutStyle = prefs.getString('main_menu_layout_style') ?? 'default';
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
      debugPrint("版本檢查失敗: $e");
    }
  }

  Future<void> _checkAndStartTasks() async {
    final prefs = await SharedPreferences.getInstance();
    bool hasCourseCache = prefs.containsKey('cached_courses');

    if (!hasCourseCache) {
      // --- 初始化模式 ---
      prefs.setInt(
        'preview_rank_mode',
        2,
      ); // 預先設定預覽名次為部分期間開啟 (預設選項 2)
      prefs.setBool(
        'is_preview_rank_enabled',
        true,
      ); // 預先設定預覽名次為開啟，讓使用者第一次進來就能看到這個功能 (可選)
      setState(() {
        _isFirstTimeLoading = true;
      });

      // 1. 背景默默跑任務 (不管它何時好，也不管失敗)
      _startBackgroundTask(isFirstTime: true)
          .then((_) {
            debugPrint("背景任務完成");
          })
          .catchError((e) {
            debugPrint("背景任務異常(忽略): $e");
          });

      // 2. 前台跑擬真的 6.5秒 動畫，UI 聽這個的
      await _runRealisticLoading();
    } else {
      // --- 一般模式 (非第一次) ---
      _startBackgroundTask(isFirstTime: false);
    }
  }

  Future<void> _startBackgroundTask({bool isFirstTime = false}) async {
    // 任務 1：課表與課程資料（延遲 0.5 秒後執行）
    final courseFuture = () async {
      await Future.delayed(const Duration(milliseconds: 500));
      try {
        await CourseService.instance.refreshAndCache();
      } catch (e) {
        debugPrint("❌ 背景抓取課程資料發生錯誤: $e");
      }
    }();

    // 任務 2：開放成績資料（延遲 0.3 秒後執行，且獨立與其他任務並行）
    final openScoreFuture = () async {
      await Future.delayed(const Duration(milliseconds: 300));
      try {
        if (isFirstTime || _isScoreReleaseSeason()) {
          await OpenScoreService.instance.fetchOpenScores();
        }
      } catch (e) {
        debugPrint("❌ 背景抓取開放成績資料發生錯誤: $e");
      }
    }();

    // 任務 3：歷年成績資料（延遲 0.3 秒後執行，且獨立與其他任務並行）
    final historicalScoreFuture = () async {
      await Future.delayed(const Duration(milliseconds: 300));
      try {
        await HistoricalScoreService.instance.fetchAllData();
      } catch (e) {
        debugPrint("❌ 背景抓取歷年成績資料發生錯誤: $e");
      }
    }();

    // 同時等待這三組非同步流程完成
    await Future.wait([courseFuture, openScoreFuture, historicalScoreFuture]);
  }

  bool _isScoreReleaseSeason() {
    DateTime now = DateTime.now();
    int month = now.month;
    int day = now.day;
    bool isWinter = (month == 12 && day >= 15) || (month == 1 && day <= 25);
    bool isSummer = (month == 5 && day >= 15) || (month == 6 && day <= 25);
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

    // 備份偏好設定，避免被 clear() 刪除
    final String? appThemeMode = prefs.getString('app_theme_mode');
    final String? appFontFamily = prefs.getString('app_font_family');
    final String? mainMenuLayoutStyle = prefs.getString(
      'main_menu_layout_style',
    );
    final bool? allowLandscapeMode = prefs.getBool('allow_landscape_mode');
    final bool? isPreviewRankEnabled = prefs.getBool('is_preview_rank_enabled');
    final int? previewRankMode = prefs.getInt('preview_rank_mode');
    final bool? hasMigratedToSecureStorage = prefs.getBool(
      'has_migrated_to_secure_storage',
    );

    await prefs.clear();

    // 還原偏好設定
    if (appThemeMode != null)
      await prefs.setString('app_theme_mode', appThemeMode);
    if (appFontFamily != null)
      await prefs.setString('app_font_family', appFontFamily);
    if (mainMenuLayoutStyle != null)
      await prefs.setString('main_menu_layout_style', mainMenuLayoutStyle);
    if (allowLandscapeMode != null)
      await prefs.setBool('allow_landscape_mode', allowLandscapeMode);
    if (isPreviewRankEnabled != null)
      await prefs.setBool('is_preview_rank_enabled', isPreviewRankEnabled);
    if (previewRankMode != null)
      await prefs.setInt('preview_rank_mode', previewRankMode);
    if (hasMigratedToSecureStorage != null)
      await prefs.setBool(
        'has_migrated_to_secure_storage',
        hasMigratedToSecureStorage,
      );

    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => CaptchaAutoLoginPage()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth >= 600;
    final isWideScreen = screenWidth >= 900;
    final double horizontalPadding = screenWidth > 1020
        ? (screenWidth - 1020) / 2 + 20.0
        : 20.0;

    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _updateScrollArrowState(),
    );

    final List<MainMenuItem> menuItems = [
      MainMenuItem(
        icon: Icons.school_rounded,
        label: "學期成績查詢",
        subtitle: "查詢歷年與當期之學期成績",
        color: Colors.blue,
        section: "成績與進度",
        pageBuilder: (context) => const ScoreResultPage(),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const ScoreResultPage()),
        ),
      ),
      MainMenuItem(
        icon: Icons.assignment_turned_in_rounded,
        label: "開放成績查詢",
        subtitle: "查詢教師已登錄之開放成績",
        color: Colors.teal,
        section: "成績與進度",
        pageBuilder: (context) => const OpenScorePage(),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const OpenScorePage()),
        ),
      ),
      MainMenuItem(
        icon: Icons.fact_check_rounded,
        label: "畢業檢核",
        subtitle: "大三以上限定",
        color: Colors.purple,
        section: "成績與進度",
        pageBuilder: (context) => const GraduationPage(),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const GraduationPage()),
        ),
      ),
      MainMenuItem(
        icon: Icons.school_outlined,
        label: "學程進度",
        subtitle: "查詢各學程領域之修課進度",
        color: Colors.cyan,
        section: "成績與進度",
        pageBuilder: (context) => const CourseProgressPage(),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const CourseProgressPage()),
        ),
      ),
      MainMenuItem(
        icon: Icons.calculate_rounded,
        label: "分數試算",
        subtitle: "試算與模擬學分權重",
        color: Colors.amber,
        section: "成績與進度",
        pageBuilder: (context) => const ScoreTrackingPage(),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const ScoreTrackingPage()),
        ),
      ),
      MainMenuItem(
        icon: Icons.calendar_month_rounded,
        label: "課表查詢",
        subtitle: "查看個人上課時間與地點",
        color: Colors.orange,
        section: "課表與選課",
        pageBuilder: (context) => const CourseSchedulePage(),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const CourseSchedulePage()),
        ),
      ),
      MainMenuItem(
        icon: Icons.assistant_rounded,
        label: "選課助手",
        subtitle: "篩選與模擬排課管理",
        color: Colors.lightBlue,
        section: "課表與選課",
        pageBuilder: (context) => const CourseAssistantPage(),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const CourseAssistantPage()),
        ),
      ),
      MainMenuItem(
        icon: Icons.date_range_rounded,
        label: "選課系統",
        subtitle: "進行加選、退選與志願登記",
        color: const Color.fromARGB(255, 255, 29, 13),
        section: "課表與選課",
        pageBuilder: (context) => const CourseSelectionSchedulePage(),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const CourseSelectionSchedulePage(),
          ),
        ),
      ),
      if (_layoutStyle == 'grid') ...[
        MainMenuItem(
          icon: Icons.campaign_rounded,
          label: "網大公告",
          subtitle: "掌握網大公告資訊",
          color: Colors.redAccent,
          section: "學習與校園",
          pageBuilder: (context) => const AnnouncementPage(),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AnnouncementPage()),
          ),
        ),
        MainMenuItem(
          icon: Icons.task_rounded,
          label: "作業與考試",
          subtitle: "掌握課程作業與考試資訊",
          color: Colors.indigo,
          section: "學習與校園",
          pageBuilder: (context) => const ExamTaskPage(),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const ExamTaskPage()),
          ),
        ),
      ] else ...[
        MainMenuItem(
          icon: Icons.laptop_chromebook_rounded,
          label: "網路大學",
          subtitle: "掌握網大公告、作業與考試資訊",
          color: const Color.fromARGB(255, 65, 211, 133),
          section: "學習與校園",
          onTap: () => _showElearnMenu(context),
        ),
      ],
      MainMenuItem(
        icon: Icons.directions_bus_rounded,
        label: "校園公車",
        subtitle: "查詢校園公車路線與到站時間",
        color: Colors.green,
        section: "學習與校園",
        pageBuilder: (context) => const BusListPage(),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const BusListPage()),
        ),
      ),
      MainMenuItem(
        icon: Icons.event_note_rounded,
        label: "行事曆",
        subtitle: "查詢校曆重要活動與學術日程",
        color: const Color.fromARGB(255, 228, 55, 113),
        section: "學習與校園",
        pageBuilder: (context) => const CalendarPage(),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const CalendarPage()),
        ),
      ),
    ];

    return Scaffold(
      drawer: _buildDrawer(context),
      body: Stack(
        children: [
          if (_layoutStyle == 'aurora') _buildAuroraBackground(context),
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
                backgroundColor: (_isScrolled && _layoutStyle != 'aurora')
                    ? Theme.of(context).scaffoldBackgroundColor
                    : Colors.transparent,
                elevation: 0,
              ),

              // 2. 歡迎區塊
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.only(
                    left: horizontalPadding,
                    right: horizontalPadding,
                    top: 12.0,
                    bottom: 2.0,
                  ),
                  child: Builder(
                    builder: (context) {
                      final Color startColor = const Color(0xFF1565C0);
                      final Color endColor = const Color(0xFF1976D2);
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16.0,
                          vertical: 12.0,
                        ),
                        width: double.infinity,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [startColor, endColor],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(15),
                          boxShadow: [
                            BoxShadow(
                              color: endColor.withOpacity(0.45),
                              spreadRadius: 3,
                              blurRadius: 12,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "歡迎使用",
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.white.withOpacity(0.8),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  const Text(
                                    "學生服務系統",
                                    style: TextStyle(
                                      fontSize: 21,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (isTablet)
                              Icon(
                                Icons.school_rounded,
                                size: 44,
                                color: Colors.white.withOpacity(0.25),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),

              // 3. 功能選單 (條狀、格狀或 Bento)
              (_layoutStyle == 'bento' || _layoutStyle == 'aurora')
                  ? _buildBentoLayout(
                      context,
                      menuItems,
                      horizontalPadding,
                      isTablet,
                      isWideScreen,
                    )
                  : (_layoutStyle == 'grid'
                        ? SliverPadding(
                            padding: EdgeInsets.symmetric(
                              horizontal: horizontalPadding,
                              vertical: 16.0,
                            ),
                            sliver: SliverGrid(
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: isWideScreen
                                        ? 4
                                        : (isTablet ? 3 : 2),
                                    mainAxisSpacing: 12,
                                    crossAxisSpacing: 12,
                                    childAspectRatio: isWideScreen
                                        ? 1.25
                                        : (isTablet ? 1.2 : 1.15),
                                  ),
                              delegate: SliverChildBuilderDelegate((
                                context,
                                index,
                              ) {
                                final item = menuItems[index];
                                return _buildGridMenuButton(context, item);
                              }, childCount: menuItems.length),
                            ),
                          )
                        : (isTablet
                              ? SliverPadding(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: horizontalPadding,
                                    vertical: 10,
                                  ),
                                  sliver: SliverToBoxAdapter(
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        if (isWideScreen) ...[
                                          // 3 欄式儀表板 (寬螢幕/橫向平板)
                                          Expanded(
                                            child: _buildSectionColumn(
                                              context,
                                              "成績與進度",
                                              Icons.analytics_rounded,
                                              menuItems,
                                              isFirst: true,
                                            ),
                                          ),
                                          const SizedBox(width: 20),
                                          Expanded(
                                            child: _buildSectionColumn(
                                              context,
                                              "課表與選課",
                                              Icons.menu_book_rounded,
                                              menuItems,
                                              isFirst: true,
                                            ),
                                          ),
                                          const SizedBox(width: 20),
                                          Expanded(
                                            child: _buildSectionColumn(
                                              context,
                                              "學習與校園",
                                              Icons.campaign_rounded,
                                              menuItems,
                                              isFirst: true,
                                            ),
                                          ),
                                        ] else ...[
                                          // 2 欄式儀表板 (直向平板)
                                          Expanded(
                                            child: _buildSectionColumn(
                                              context,
                                              "成績與進度",
                                              Icons.analytics_rounded,
                                              menuItems,
                                              isFirst: true,
                                            ),
                                          ),
                                          const SizedBox(width: 20),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                _buildSectionColumn(
                                                  context,
                                                  "課表與選課",
                                                  Icons.menu_book_rounded,
                                                  menuItems,
                                                  isFirst: true,
                                                ),
                                                const SizedBox(height: 10),
                                                _buildSectionColumn(
                                                  context,
                                                  "學習與校園",
                                                  Icons.campaign_rounded,
                                                  menuItems,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                )
                              : SliverPadding(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: horizontalPadding,
                                    vertical: 10,
                                  ),
                                  sliver: SliverList(
                                    delegate: SliverChildListDelegate([
                                      _buildSectionHeader(
                                        context,
                                        "成績與進度",
                                        Icons.analytics_rounded,
                                        isFirst: true,
                                      ),
                                      ...menuItems
                                          .where(
                                            (item) => item.section == "成績與進度",
                                          )
                                          .map(
                                            (item) => _buildBarMenuButton(
                                              context,
                                              icon: item.icon,
                                              label: item.label,
                                              subtitle: item.subtitle,
                                              color: item.color,
                                              onTap: item.onTap,
                                            ),
                                          ),
                                      _buildSectionHeader(
                                        context,
                                        "課表與選課",
                                        Icons.menu_book_rounded,
                                      ),
                                      ...menuItems
                                          .where(
                                            (item) => item.section == "課表與選課",
                                          )
                                          .map(
                                            (item) => _buildBarMenuButton(
                                              context,
                                              icon: item.icon,
                                              label: item.label,
                                              subtitle: item.subtitle,
                                              color: item.color,
                                              onTap: item.onTap,
                                            ),
                                          ),
                                      _buildSectionHeader(
                                        context,
                                        "學習與校園",
                                        Icons.campaign_rounded,
                                      ),
                                      ...menuItems
                                          .where(
                                            (item) => item.section == "學習與校園",
                                          )
                                          .map(
                                            (item) => _buildBarMenuButton(
                                              context,
                                              icon: item.icon,
                                              label: item.label,
                                              subtitle: item.subtitle,
                                              color: item.color,
                                              onTap: item.onTap,
                                            ),
                                          ),
                                    ]),
                                  ),
                                ))),

              // 底部留白
              const SliverToBoxAdapter(child: SizedBox(height: 60)),
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
                child: Builder(
                  builder: (context) {
                    final colorScheme = Theme.of(context).colorScheme;
                    return Column(
                      children: [
                        Text(
                          "更多功能",
                          style: TextStyle(
                            color: colorScheme.subtitleText,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: colorScheme.accentBlue.withOpacity(0.8),
                          size: 36,
                        ),
                      ],
                    );
                  },
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
                          decoration: TextDecoration.none,
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
                                  decoration: TextDecoration.none,
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

  Widget _buildAuroraBackground(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;

    final colors = isDark
        ? [
            const Color(0xFF0C0E14),
            const Color(0xFF0F1A30),
            const Color(0xFF1B0F30),
            const Color(0xFF0C0E14),
          ]
        : [
            const Color(0xFFE8F0FE),
            const Color(0xFFF3E5F5),
            const Color(0xFFE0F7FA),
            const Color(0xFFE8F0FE),
          ];

    return Positioned.fill(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: colors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          children: [
            // 左上角青色發光暈染
            Positioned(
              top: -140,
              left: -140,
              child: Container(
                width: 450,
                height: 450,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      (isDark
                              ? const Color(0xFF00E5FF)
                              : const Color(0xFF80DEEA))
                          .withOpacity(isDark ? 0.35 : 0.38),
                      (isDark
                              ? const Color(0xFF00E5FF)
                              : const Color(0xFF80DEEA))
                          .withOpacity(0.12),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.4, 1.0],
                  ),
                ),
              ),
            ),
            // 右下角洋紅/紫色發光暈染
            Positioned(
              bottom: 80,
              right: -120,
              child: Container(
                width: 480,
                height: 480,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      (isDark
                              ? const Color(0xFFD500F9)
                              : const Color(0xFFF3E5F5))
                          .withOpacity(isDark ? 0.28 : 0.34),
                      (isDark
                              ? const Color(0xFFD500F9)
                              : const Color(0xFFF3E5F5))
                          .withOpacity(0.10),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.4, 1.0],
                  ),
                ),
              ),
            ),
            // 中間右側天藍色發光暈染
            Positioned(
              top: 300,
              right: 20,
              child: Container(
                width: 320,
                height: 320,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      (isDark
                              ? const Color(0xFF2979FF)
                              : const Color(0xFFBBDEFB))
                          .withOpacity(isDark ? 0.26 : 0.30),
                      (isDark
                              ? const Color(0xFF2979FF)
                              : const Color(0xFFBBDEFB))
                          .withOpacity(0.08),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.4, 1.0],
                  ),
                ),
              ),
            ),
            // 單通道全域高階模糊層：將背景色彩完美融合成流體極光，並預模糊下方景深
            Positioned.fill(
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 45.0, sigmaY: 45.0),
                child: Container(color: Colors.transparent),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 複合分類整欄組件（平板/寬螢幕排版用）
  Widget _buildSectionColumn(
    BuildContext context,
    String sectionName,
    IconData icon,
    List<MainMenuItem> menuItems, {
    bool isFirst = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(context, sectionName, icon, isFirst: isFirst),
        ...menuItems
            .where((item) => item.section == sectionName)
            .map(
              (item) => _buildBarMenuButton(
                context,
                icon: item.icon,
                label: item.label,
                subtitle: item.subtitle,
                color: item.color,
                onTap: item.onTap,
              ),
            ),
      ],
    );
  }

  // 條狀選單分類標題組件
  Widget _buildSectionHeader(
    BuildContext context,
    String title,
    IconData icon, {
    bool isFirst = false,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.only(
        top: isFirst ? 10.0 : 24.0,
        bottom: 12.0,
        left: 4.0,
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: colorScheme.accentBlue),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: colorScheme.accentBlue,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  // 條狀按鈕組件
  Widget _buildBarMenuButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final isCompact = _layoutStyle == 'compact';

    return Container(
      margin: EdgeInsets.symmetric(vertical: isCompact ? 4.0 : 6.0),
      decoration: BoxDecoration(
        color: colorScheme.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.borderColor, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: isCompact ? 8.0 : 14.0,
            ),
            child: Row(
              children: [
                // 圖標背景圓角框
                Container(
                  padding: EdgeInsets.all(isCompact ? 8 : 12),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, size: isCompact ? 22 : 26, color: color),
                ),
                const SizedBox(width: 16),
                // 標題與說明文字
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: isCompact ? 15 : 16,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.primaryText,
                        ),
                      ),
                      if (!isCompact) ...[
                        const SizedBox(height: 3),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.subtitleText,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                // 箭頭
                Icon(
                  Icons.chevron_right_rounded,
                  color: colorScheme.subtitleText.withOpacity(0.7),
                  size: isCompact ? 20 : 24,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 格狀按鈕組件 (一排兩個正方形框框格式)
  Widget _buildGridMenuButton(BuildContext context, MainMenuItem item) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.cardBackground,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colorScheme.borderColor, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: item.onTap,
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // 圖標背景圓形框
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: item.color.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(item.icon, size: 28, color: item.color),
                ),
                const SizedBox(height: 12),
                // 標題
                Text(
                  item.label,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primaryText,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Bento Box 佈局核心方法
  Widget _buildBentoLayout(
    BuildContext context,
    List<MainMenuItem> menuItems,
    double horizontalPadding,
    bool isTablet,
    bool isWideScreen,
  ) {
    // A helper to safely find an item by label
    MainMenuItem? getItem(String label) {
      try {
        return menuItems.firstWhere((item) => item.label == label);
      } catch (_) {
        return null;
      }
    }

    final scoreQuery = getItem("學期成績查詢");
    final openScore = getItem("開放成績查詢");
    final scoreTracking = getItem("分數試算");
    final schedule = getItem("課表查詢");
    final assistant = getItem("選課助手");
    final selection = getItem("選課系統");
    final elearn = getItem("網路大學");
    final progress = getItem("學程進度");
    final graduation = getItem("畢業檢核");
    final bus = getItem("校園公車");
    final calendar = getItem("行事曆");

    if (isTablet || isWideScreen) {
      // 3欄式 Bento 佈局 (平板與寬螢幕)
      return SliverPadding(
        padding: EdgeInsets.symmetric(
          horizontal: horizontalPadding,
          vertical: 16.0,
        ),
        sliver: SliverToBoxAdapter(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 第一欄
              Expanded(
                child: Column(
                  children: [
                    if (scoreQuery != null)
                      _BentoTile(item: scoreQuery, isTall: true, height: 228),
                    const SizedBox(height: 12),
                    if (openScore != null)
                      _BentoTile(item: openScore, height: 120),
                    const SizedBox(height: 12),
                    if (graduation != null)
                      _BentoTile(item: graduation, height: 120),
                  ],
                ),
              ),
              const SizedBox(width: 16),

              // 第二欄
              Expanded(
                child: Column(
                  children: [
                    if (schedule != null)
                      _BentoTile(item: schedule, isTall: true, height: 228),
                    const SizedBox(height: 12),
                    if (assistant != null)
                      _BentoTile(item: assistant, height: 120),
                    const SizedBox(height: 12),
                    if (selection != null)
                      _BentoTile(item: selection, height: 120),
                  ],
                ),
              ),
              const SizedBox(width: 16),

              // 第三欄
              Expanded(
                child: Column(
                  children: [
                    if (elearn != null)
                      _BentoTile(item: elearn, isTall: true, height: 228),
                    const SizedBox(height: 12),
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (progress != null)
                            Expanded(
                              child: _BentoTile(item: progress, height: 120),
                            ),
                          const SizedBox(width: 12),
                          if (scoreTracking != null)
                            Expanded(
                              child: _BentoTile(
                                item: scoreTracking,
                                height: 120,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (bus != null)
                            Expanded(child: _BentoTile(item: bus, height: 120)),
                          const SizedBox(width: 12),
                          if (calendar != null)
                            Expanded(
                              child: _BentoTile(item: calendar, height: 120),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    // 雙欄非對稱 Bento 佈局 (手機端)
    return SliverPadding(
      padding: EdgeInsets.symmetric(
        horizontal: horizontalPadding,
        vertical: 12.0,
      ),
      sliver: SliverList(
        delegate: SliverChildListDelegate([
          // 區塊一：成績焦點 (不對稱設計)
          SizedBox(
            height: 252,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (scoreQuery != null)
                  Expanded(
                    child: _BentoTile(
                      item: scoreQuery,
                      isTall: true,
                      height: 252,
                    ),
                  ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    children: [
                      if (openScore != null)
                        _BentoTile(item: openScore, height: 120),
                      const SizedBox(height: 12),
                      if (scoreTracking != null)
                        _BentoTile(item: scoreTracking, height: 120),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // 區塊二：今日課表 (單張大寬卡)
          if (schedule != null)
            _BentoTile(item: schedule, isWide: true, height: 100),
          const SizedBox(height: 12),

          // 區塊三：選課核心 (雙欄並排)
          Row(
            children: [
              if (assistant != null)
                Expanded(child: _BentoTile(item: assistant, height: 120)),
              const SizedBox(width: 12),
              if (selection != null)
                Expanded(child: _BentoTile(item: selection, height: 120)),
            ],
          ),
          const SizedBox(height: 12),

          // 區塊四：網路大學 (單張大寬卡)
          if (elearn != null)
            _BentoTile(item: elearn, isWide: true, height: 100),
          const SizedBox(height: 12),

          // 區塊五：學歷與畢業追蹤 (雙欄並排)
          Row(
            children: [
              if (progress != null)
                Expanded(child: _BentoTile(item: progress, height: 120)),
              const SizedBox(width: 12),
              if (graduation != null)
                Expanded(child: _BentoTile(item: graduation, height: 120)),
            ],
          ),
          const SizedBox(height: 12),

          // 區塊六：生活與校園便利 (雙欄並排)
          Row(
            children: [
              if (bus != null)
                Expanded(child: _BentoTile(item: bus, height: 120)),
              const SizedBox(width: 12),
              if (calendar != null)
                Expanded(child: _BentoTile(item: calendar, height: 120)),
            ],
          ),
        ]),
      ),
    );
  }

  // 左側彈出式選單 (Drawer)
  Widget _buildDrawer(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Drawer(
      backgroundColor: colorScheme.cardBackground,
      child: SafeArea(
        child: Column(
          children: [
            // Drawer Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24.0),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: colorScheme.borderColor),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: colorScheme.accentBlue.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.account_balance_rounded,
                          color: colorScheme.accentBlue,
                          size: 32,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "學生服務系統",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: colorScheme.primaryText,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "中山大學校務行動助理",
                              style: TextStyle(
                                fontSize: 12,
                                color: colorScheme.subtitleText,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Drawer Menu List Items
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 8,
                ),
                children: [
                  ListTile(
                    visualDensity: const VisualDensity(vertical: -2.0),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    leading: const Icon(
                      Icons.settings_rounded,
                      color: Colors.blueGrey,
                    ),
                    title: const Text('設定'),
                    trailing: const Icon(Icons.chevron_right_rounded, size: 20),
                    onTap: () async {
                      Navigator.pop(context); // 關閉側邊欄
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const SettingsPage(),
                        ),
                      );
                      if (mounted) _loadSettings();
                    },
                  ),
                  const SizedBox(height: 2),
                  ListTile(
                    visualDensity: const VisualDensity(vertical: -2.0),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    leading: Icon(
                      _hasNewVersion
                          ? Icons.system_update
                          : Icons.verified_user_rounded,
                      color: _hasNewVersion ? Colors.red : Colors.green,
                    ),
                    title: Text(
                      _hasNewVersion ? '更新APP' : 'App版本',
                      style: TextStyle(
                        color: _hasNewVersion ? Colors.red : null,
                        fontWeight: _hasNewVersion ? FontWeight.bold : null,
                      ),
                    ),
                    trailing: _hasNewVersion
                        ? Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Text(
                              "NEW",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          )
                        : const Icon(Icons.chevron_right_rounded, size: 20),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const AppVersionPage(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 2),
                  ListTile(
                    visualDensity: const VisualDensity(vertical: -2.0),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    leading: const Icon(
                      Icons.delete_sweep_outlined,
                      color: Colors.orange,
                    ),
                    title: const Text('清除暫存檔案'),
                    trailing: const Icon(Icons.chevron_right_rounded, size: 20),
                    onTap: () {
                      Navigator.pop(context);
                      _showClearCacheDialog();
                    },
                  ),
                  const SizedBox(height: 2),
                  ListTile(
                    visualDensity: const VisualDensity(vertical: -2.0),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    leading: const Icon(Icons.info_outline, color: Colors.blue),
                    title: const Text('使用說明'),
                    trailing: const Icon(Icons.chevron_right_rounded, size: 20),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const InfoPage(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 2),
                  ListTile(
                    visualDensity: const VisualDensity(vertical: -2.0),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    leading: const Icon(Icons.code_rounded, color: Colors.teal),
                    title: const Text('關於開發者'),
                    trailing: const Icon(Icons.chevron_right_rounded, size: 20),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const AboutDeveloperPage(),
                        ),
                      );
                    },
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(
                      vertical: 4.0,
                      horizontal: 16.0,
                    ),
                    child: Divider(),
                  ),
                  ListTile(
                    visualDensity: const VisualDensity(vertical: -2.0),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    leading: const Icon(Icons.logout, color: Colors.red),
                    title: const Text(
                      '登出系統',
                      style: TextStyle(color: Colors.red),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      _showLogoutDialog();
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),
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
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text("檔案和部分快取已清除")));
                  _checkAndStartTasks();
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text("清理失敗: $e"),
                      backgroundColor: Colors.red,
                    ),
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

// Bento Box 專用微光漸層卡片組件 (Bento Tile)
// ─────────────────────────────────────────────
class _BentoTile extends StatefulWidget {
  final MainMenuItem item;
  final bool isWide;
  final bool isTall;
  final double? height;

  const _BentoTile({
    super.key,
    required this.item,
    this.isWide = false,
    this.isTall = false,
    this.height,
  });

  @override
  State<_BentoTile> createState() => _BentoTileState();
}

class _BentoTileState extends State<_BentoTile>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _isGlowing = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.96,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final item = widget.item;

    final parentState = context.findAncestorStateOfType<_MainMenuPageState>();
    final isGlassmorphic = parentState?._layoutStyle == 'aurora';

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTapDown: (_) {
          setState(() {
            _isGlowing = true;
          });
          _controller.forward();
        },
        onTapUp: (_) {
          _controller.reverse();

          if (mounted) {
            setState(() {
              _isGlowing = false;
            });
          }

          if (item.pageBuilder != null && mounted) {
            final RenderBox renderBox = context.findRenderObject() as RenderBox;
            final Offset position = renderBox.localToGlobal(Offset.zero);
            final Size size = renderBox.size;
            final rect = Rect.fromLTWH(
              position.dx,
              position.dy,
              size.width,
              size.height,
            );

            Navigator.push(
              context,
              BentoPageRoute(
                builder: item.pageBuilder!,
                startRect: rect,
                startBorderRadius: 22.0,
                accentColor: item.color,
              ),
            );
          } else {
            item.onTap();
          }
        },
        onTapCancel: () {
          setState(() {
            _isGlowing = false;
          });
          _controller.reverse();
        },
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: Container(
            height: widget.height,
            decoration: BoxDecoration(
              color: isGlassmorphic
                  ? colorScheme.cardBackground.withOpacity(
                      colorScheme.brightness == Brightness.dark ? 0.30 : 0.50,
                    )
                  : colorScheme.cardBackground,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: isGlassmorphic
                    ? item.color.withOpacity(
                        colorScheme.brightness == Brightness.dark ? 0.4 : 0.3,
                      )
                    : item.color.withOpacity(
                        colorScheme.brightness == Brightness.dark ? 0.25 : 0.18,
                      ),
                width: isGlassmorphic ? 1.5 : 1.2,
              ),
              gradient: isGlassmorphic
                  ? LinearGradient(
                      colors: colorScheme.brightness == Brightness.dark
                          ? [
                              item.color.withOpacity(0.18),
                              item.color.withOpacity(0.04),
                            ]
                          : [
                              item.color.withOpacity(0.24),
                              item.color.withOpacity(0.08),
                            ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : LinearGradient(
                      colors: colorScheme.brightness == Brightness.dark
                          ? [
                              item.color.withOpacity(0.08),
                              item.color.withOpacity(0.01),
                            ]
                          : [
                              item.color.withOpacity(0.12),
                              item.color.withOpacity(0.02),
                            ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
              boxShadow: [
                BoxShadow(
                  color: _isGlowing
                      ? item.color.withOpacity(
                          colorScheme.brightness == Brightness.dark
                              ? 0.85
                              : 0.70,
                        )
                      : (isGlassmorphic
                            ? item.color.withOpacity(
                                colorScheme.brightness == Brightness.dark
                                    ? 0.15
                                    : 0.1,
                              )
                            : item.color.withOpacity(0.06)),
                  spreadRadius: _isGlowing ? 6 : (isGlassmorphic ? 2 : 1),
                  blurRadius: _isGlowing ? 26 : (isGlassmorphic ? 16 : 10),
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: Stack(
                children: [
                  Positioned(
                    right: -20,
                    top: widget.isWide ? 10 : -20, // 寬卡片時將裝飾圓圈垂直置中，完美契合右側箭頭
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: item.color.withOpacity(0.05),
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.all(
                      widget.isWide ? 16.0 : (widget.isTall ? 14.0 : 12.0),
                    ),
                    child: widget.isWide
                        ? Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: item.color.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Icon(
                                  item.icon,
                                  size: 28,
                                  color: item.color,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      item.label,
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: colorScheme.primaryText,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      item.subtitle,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: colorScheme.subtitleText,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.chevron_right_rounded,
                                color: item.color.withOpacity(
                                  0.5,
                                ), // 改為統一使用功能的主題半透明色，與右上斜箭頭視覺一致
                              ),
                            ],
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Container(
                                    padding: EdgeInsets.all(
                                      widget.isTall ? 10 : 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: item.color.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Icon(
                                      item.icon,
                                      size: 22,
                                      color: item.color,
                                    ),
                                  ),
                                  Icon(
                                    Icons.arrow_outward_rounded,
                                    size: 16,
                                    color: item.color.withOpacity(0.5),
                                  ),
                                ],
                              ),
                              SizedBox(height: widget.isTall ? 12 : 6),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.label,
                                    style: TextStyle(
                                      fontSize: widget.isTall ? 14 : 13,
                                      fontWeight: FontWeight.bold,
                                      color: colorScheme.primaryText,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    item.subtitle,
                                    style: TextStyle(
                                      fontSize: widget.isTall ? 10.5 : 9.5,
                                      color: colorScheme.subtitleText,
                                    ),
                                    maxLines: widget.isTall ? 2 : 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ],
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Bento 專用絲滑原地放大與內容淡入轉場路由 (BentoPageRoute)
// ─────────────────────────────────────────────
class BentoPageRoute<T> extends PageRouteBuilder<T> {
  final WidgetBuilder builder;
  final Rect startRect;
  final double startBorderRadius;
  final Color accentColor;

  BentoPageRoute({
    required this.builder,
    required this.startRect,
    required this.startBorderRadius,
    required this.accentColor,
  }) : super(
         pageBuilder: (context, animation, secondaryAnimation) =>
             builder(context),
         transitionDuration: const Duration(milliseconds: 400),
         reverseTransitionDuration: const Duration(milliseconds: 350),
         transitionsBuilder: (context, animation, secondaryAnimation, child) {
           final curvedAnimation = CurvedAnimation(
             parent: animation,
             curve: Curves.easeInOutCubic,
           );

           // 效能優化：在最外層只讀取一次螢幕尺寸與主題，避免在 AnimatedBuilder 的每一影格重複進行 InheritedWidget 查找
           final mediaQuery = MediaQuery.of(context);
           final screenWidth = mediaQuery.size.width;
           final screenHeight = mediaQuery.size.height;
           final theme = Theme.of(context);
           final startBgColor = accentColor.withOpacity(0.12);
           final endBgColor = theme.scaffoldBackgroundColor;

           return Stack(
             children: [
               AnimatedBuilder(
                 animation: curvedAnimation,
                 builder: (context, _) {
                   final progress = curvedAnimation.value;

                   final currentRect = Rect.lerp(
                     startRect,
                     Rect.fromLTWH(0, 0, screenWidth, screenHeight),
                     progress,
                   )!;

                   final currentRadius = ui.lerpDouble(
                     startBorderRadius,
                     0.0,
                     progress,
                   )!;

                   final currentBgColor = Color.lerp(
                     startBgColor,
                     endBgColor,
                     progress,
                   )!;

                   // 內容淡入時間控制：當放大進行到後半段 (例如進度 > 40%) 時才開始淡入
                   final contentOpacity = Interval(
                     0.4,
                     1.0,
                     curve: Curves.easeOut,
                   ).transform(progress);

                   return Positioned.fromRect(
                     rect: currentRect,
                     child: Container(
                       decoration: BoxDecoration(
                         color: currentBgColor,
                         borderRadius: BorderRadius.circular(currentRadius),
                         boxShadow: [
                           BoxShadow(
                             color: accentColor.withOpacity(
                               ui.lerpDouble(0.15, 0.0, progress)!,
                             ),
                             spreadRadius: ui.lerpDouble(2.0, 0.0, progress)!,
                             blurRadius: ui.lerpDouble(16.0, 0.0, progress)!,
                           ),
                         ],
                       ),
                       child: ClipRRect(
                         borderRadius: BorderRadius.circular(currentRadius),
                         child: Opacity(
                           opacity: contentOpacity,
                           child: progress > 0.35
                               ? child
                               : const SizedBox.shrink(),
                         ),
                       ),
                     ),
                   );
                 },
               ),
             ],
           );
         },
       );
}
