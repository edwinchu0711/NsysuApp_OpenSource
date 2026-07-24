/*

This file contains code derived from the NSYSU Open Development Community project.

Original Copyright (c) 2024 NSYSU Open Development Community

Licensed under the MIT License.

*/

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import '../theme/layout_style_notifier.dart';
import '../widgets/glass/aurora_background.dart';
import '../widgets/glass/glass_dialog.dart';

// 原有的頁面 Import
import 'score_result_page.dart';
import 'open_score_page.dart';
import 'login_page.dart';
import 'course_schedule_page.dart';
import 'info_page.dart';
import 'calendar_page.dart';
import 'dart:async';
import 'course_assistant/course_assistant_page.dart';

// Service Import
import '../services/open_score_service.dart';
import '../services/historical_score_service.dart';
import '../services/course_service.dart';
import '../services/exam_task/elearn_task_HW_service.dart';
import '../services/elearn_bulletin_service.dart';
import '../services/version_service.dart';
import '../services/graduation_service.dart';
import '../services/cache_manager.dart';
import '../services/offline_mode_service.dart';

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

// --- 新增分頁佈局與資料模型 Import ---
import 'main_menu/menu_item_model.dart';
import 'main_menu/layouts/default_list_layout.dart';
import 'main_menu/layouts/grid_layout.dart';
import 'main_menu/layouts/bento_layout.dart';
import 'main_menu/layouts/liquid_glass_layout.dart';

class MainMenuPage extends StatefulWidget {
  final String cookies;
  final String userAgent;

  const MainMenuPage({Key? key, required this.cookies, required this.userAgent})
    : super(key: key);

  @override
  State<MainMenuPage> createState() => _MainMenuPageState();
}

class _MainMenuPageState extends State<MainMenuPage> {
  bool _hasNewVersion = false;
  bool _isUpdateAlertEnabled = true;
  String _layoutStyle = 'default';

  // 快取 menuItems：當 layout 未變化時重複使用同一 list，避免每次
  // LayoutStyleNotifier 觸發重建時都重新建構 14 個 MainMenuItem（其 onTap 閉包
  // 會捕獲 context，使 identity 變化向下傳播到 _GlassMenuButton）。
  List<MainMenuItem> _menuItems = const [];

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
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();

    OpenScoreService.instance.statusMessageNotifier.removeListener(
      _handleSessionExpiry,
    );
    super.dispose();
  }

  void _updateScrollArrowState() {
    if (!mounted) return;
    if (_scrollController.hasClients) {
      final maxScroll = _scrollController.position.maxScrollExtent;
      final currentOffset = _scrollController.offset;
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
        _layoutStyle = LayoutStyleNotifier.instance.value;
        _menuItems = _buildMenuItems(_layoutStyle);
      });
    }
  }

  Future<void> _checkNewVersion() async {
    if (OfflineModeService.instance.isOffline) return;
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
    // 離線模式：完全跳過背景任務，避免一進主選單就聯網
    if (OfflineModeService.instance.isOffline) {
      debugPrint("📴 離線模式：跳過背景任務");
      return;
    }
    // 初始化已由 InitializationPage 負責；此處僅做靜默背景刷新。
    _startBackgroundTask()
        .then((_) => debugPrint("背景任務完成"))
        .catchError((e) => debugPrint("背景任務異常(忽略): $e"));
  }

  Future<void> _startBackgroundTask() async {
    final courseFuture = () async {
      await Future.delayed(const Duration(milliseconds: 500));
      try {
        await CourseService.instance.refreshAndCache();
      } catch (e) {
        debugPrint("❌ 背景抓取課程資料發生錯誤: $e");
      }
    }();

    final openScoreFuture = () async {
      await Future.delayed(const Duration(milliseconds: 300));
      try {
        if (_isScoreReleaseSeason()) {
          await OpenScoreService.instance.fetchOpenScores();
        }
      } catch (e) {
        debugPrint("❌ 背景抓取開放成績資料發生錯誤: $e");
      }
    }();

    final historicalScoreFuture = () async {
      await Future.delayed(const Duration(milliseconds: 300));
      try {
        await HistoricalScoreService.instance.fetchAllData();
      } catch (e) {
        debugPrint("❌ 背景抓取歷年成績資料發生錯誤: $e");
      }
    }();

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
    // 離線模式：不處理 session expiry，避免誤觸發重新登入流程
    if (OfflineModeService.instance.isOffline) return;
    final msg = OpenScoreService.instance.statusMessageNotifier.value;
    if (msg == "Session失效" || msg == "Session Timeout") {
      _navigateToLogin(isRelogin: true);
    }
  }

  void _navigateToLogin({bool isRelogin = false}) {
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => LoginPage(isRelogin: isRelogin)),
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
      MaterialPageRoute(builder: (context) => LoginPage()),
      (route) => false,
    );
  }

  /// 建構 menuItems list。內容與原本 build 內 inline 的 list 完全相同（同一份
  /// 14 個 MainMenuItem 的定義），抽出成為 method 後可在 layout 未變化時
  /// 快取重用，避免每次 LayoutStyleNotifier 觸發 rebuild 都重新建構。
  List<MainMenuItem> _buildMenuItems(String layoutStyle) {
    return <MainMenuItem>[
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
      if (layoutStyle == 'grid' || layoutStyle == 'liquid_glass') ...[
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

    // 透過 ValueListenableBuilder 訂閱 LayoutStyleNotifier，
    // 使 layout 切換時（包含在設定頁中即時切換）立即重建主頁面，
    // liquid glass 底部導覽列因此能即時出現/消失。
    return ValueListenableBuilder<String>(
      valueListenable: LayoutStyleNotifier.instance,
      builder: (context, layoutStyle, _) {
        // memo 化：僅在 (a) 首次 build（_menuItems 為空）或 (b) layout 變化時
        // 才重建 menuItems；layout 未變化（其他 setState 或 notifier 重發同值）
        // 時重用同一 list，避免向下傳播 identity 變化至 _GlassMenuButton。
        if (_menuItems.isEmpty || _layoutStyle != layoutStyle) {
          _layoutStyle = layoutStyle;
          _menuItems = _buildMenuItems(layoutStyle);
        }
        final List<MainMenuItem> menuItems = _menuItems;

        Widget body;
        if (layoutStyle == 'liquid_glass') {
          body = MainMenuLiquidGlassLayout(
            menuItems: menuItems,
            hasNewVersion: _hasNewVersion,
            onShowClearCache: _showClearCacheDialog,
            onShowLogout: _showLogoutDialog,
            onLoadSettings: _loadSettings,
          );
        } else {
          Widget sliverLayout;
          if (layoutStyle == 'bento' || layoutStyle == 'aurora') {
            sliverLayout = MainMenuBentoLayout(
              menuItems: menuItems,
              horizontalPadding: horizontalPadding,
              isTablet: isTablet,
              isWideScreen: isWideScreen,
              isAurora: layoutStyle == 'aurora',
            );
          } else if (layoutStyle == 'grid') {
            sliverLayout = MainMenuGridLayout(
              menuItems: menuItems,
              horizontalPadding: horizontalPadding,
              isTablet: isTablet,
              isWideScreen: isWideScreen,
            );
          } else {
            sliverLayout = MainMenuDefaultListLayout(
              menuItems: menuItems,
              horizontalPadding: horizontalPadding,
              isTablet: isTablet,
              isWideScreen: isWideScreen,
              layoutStyle: layoutStyle,
            );
          }

          body = Stack(
            children: [
              if (layoutStyle == 'aurora') const AuroraBackground(),
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
                    backgroundColor: (_isScrolled && layoutStyle != 'aurora')
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
                                  color: endColor.withValues(alpha: 0.45),
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
                                          color: Colors.white.withValues(alpha: 0.8),
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
                                    color: Colors.white.withValues(alpha: 0.25),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),

                  // 3. 功能選單
                  sliverLayout,

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
                              color: colorScheme.accentBlue.withValues(alpha: 0.8),
                              size: 36,
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
            ],
          );
        }

        return Scaffold(
          drawer: layoutStyle == 'liquid_glass' ? null : _buildDrawer(context),
          body: body,
        );
      },
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
                          color: colorScheme.accentBlue.withValues(alpha: 0.1),
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

  void _showLogoutDialog() {
    showGlassDialog(
      context: context,
      title: const Row(
        children: [
          Icon(Icons.logout, color: Colors.red),
          SizedBox(width: 8),
          Text("確認登出"),
        ],
      ),
      content: const Text("確定要登出並清除所有個人紀錄嗎？下次登入將重新初始化。"),
      actions: [
        TextButton(
          child: const Text("取消"),
          onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
        ),
        TextButton(
          child: const Text("登出", style: TextStyle(color: Colors.red)),
          onPressed: () {
            Navigator.of(context, rootNavigator: true).pop();
            _logout();
          },
        ),
      ],
    );
  }

  void _showClearCacheDialog() {
    showGlassDialog(
      context: context,
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
          onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
        ),
        TextButton(
          child: const Text("確定清除", style: TextStyle(color: Colors.orange)),
          onPressed: () async {
            Navigator.of(context, rootNavigator: true).pop();

            try {
              await Future.wait([
                AppCacheManager.performCacheCleanup(),
                AppCacheManager.clearAllServiceCache(),
              ]);

              if (mounted) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text("檔案和部分快取已清除"), duration: const Duration(seconds: 2)));
                _checkAndStartTasks();
              }
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text("清理失敗: $e"),
                    backgroundColor: Colors.red,
                    duration: const Duration(seconds: 2),),
                );
              }
            }
          },
        ),
      ],
    );
  }
}
