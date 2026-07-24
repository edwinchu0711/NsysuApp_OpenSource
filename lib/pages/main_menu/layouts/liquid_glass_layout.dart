import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart' hide GlassCard;

import '../../../theme/app_theme.dart';
import '../menu_item_model.dart';
import '../../../services/course_service.dart';
import '../../../models/course_model.dart';
import '../../../widgets/glass/aurora_background.dart';
import '../../../widgets/glass/glass_card.dart';
import '../../../services/historical_score_service.dart';
import '../../../services/graduation_service.dart';
import '../../../models/graduation_model.dart';
import '../../../theme/layout_style_notifier.dart';

// 頁面 imports for navigation within the layout
import '../../info_page.dart';
import '../../settings_page.dart';
import '../../app_version_page.dart';
import '../../about_developer_page.dart';
import '../../course_assistant/course_assistant_utils.dart';

class MainMenuLiquidGlassLayout extends StatefulWidget {
  final List<MainMenuItem> menuItems;
  final bool hasNewVersion;
  final VoidCallback onShowClearCache;
  final VoidCallback onShowLogout;
  final VoidCallback onLoadSettings;

  const MainMenuLiquidGlassLayout({
    Key? key,
    required this.menuItems,
    required this.hasNewVersion,
    required this.onShowClearCache,
    required this.onShowLogout,
    required this.onLoadSettings,
  }) : super(key: key);

  @override
  State<MainMenuLiquidGlassLayout> createState() =>
      _MainMenuLiquidGlassLayoutState();
}

class _MainMenuLiquidGlassLayoutState extends State<MainMenuLiquidGlassLayout> {
  int _selectedIndex = 0;
  int _oldSelectedIndex = 0;
  int _selectedDay = DateTime.now().weekday > 5 ? 1 : DateTime.now().weekday;

  // 巢狀 Navigator：首頁為 4 個分頁，子頁面疊於其上；導覽列恆存於最上層。
  final GlobalKey<NavigatorState> _nestedNavKey = GlobalKey<NavigatorState>();
  // 巢狀 Navigator 最上層為彈窗 / popup 時，暫停導覽列回應，避免被誤點。
  bool _modalOpen = false;
  bool _hideNavBar = false;
  late final _ModalRouteObserver _modalObserver = _ModalRouteObserver(this);

  // 為接下來的 PageView 遷移預備的 controller；initialPage 對齊 _selectedIndex（預設 0）。
  late final PageController _pageController;

  // 寬螢幕下用來提供畢業進度資料的 Future。Hoist 至 state field 使其 identity 跨
  // rebuild 穩定，避免 FutureBuilder 在每次父層 setState 時重新訂閱（PageView 使
  // 本 tab 常駐不 dispose，故 future 必須穩定）。懶初始化：首次寬螢幕 build 時才建立。
  Future<GraduationData?>? _gradDataFuture;

  final List<String> _periodsOrder = [
    'A',
    '1',
    '2',
    '3',
    '4',
    'B',
    '5',
    '6',
    '7',
    '8',
    '9',
    'C',
    'D',
    'E',
    'F',
  ];

  final Map<String, String> _timeRangeMap = {
    'A': '07:00 - 07:50',
    '1': '08:10 - 09:00',
    '2': '09:10 - 10:00',
    '3': '10:10 - 11:00',
    '4': '11:10 - 12:00',
    'B': '12:10 - 13:00',
    '5': '13:10 - 14:00',
    '6': '14:10 - 15:00',
    '7': '15:10 - 16:00',
    '8': '16:10 - 17:00',
    '9': '17:10 - 18:00',
    'C': '18:20 - 19:10',
    'D': '19:15 - 20:05',
    'E': '20:10 - 21:00',
    'F': '21:05 - 21:55',
  };

  /// 點擊導覽列任一項：若身在子頁面則先返回首頁，再由 PageController 平滑切換到對應分頁。
  void _onNavTap(int index) {
    final nav = _nestedNavKey.currentState;
    final bool wasSubPage = nav != null && nav.canPop();
    if (wasSubPage) {
      nav.popUntil((route) => route.isFirst);
    }
    if (index == _selectedIndex) return;
    _oldSelectedIndex = _selectedIndex;
    _selectedIndex = index;
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
    setState(() {});
  }

  /// 將子頁面推入巢狀 Navigator（使導覽列持續顯示於其上）。
  Future<void> _pushSubPageBuilder(WidgetBuilder builder) async {
    final nav = _nestedNavKey.currentState;
    if (nav == null) return;
    await nav.push(MaterialPageRoute(builder: builder));
  }

  /// 供 [_ModalRouteObserver] 回報最上層路由是否為彈窗，以暫停/恢復導覽列回應。
  void _onModalChanged(bool open) {
    if (!mounted || _modalOpen == open) return;
    setState(() => _modalOpen = open);
  }

  void _onHideNavBarChanged(bool hide) {
    if (!mounted || _hideNavBar == hide) return;
    setState(() => _hideNavBar = hide);
  }

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _selectedIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 底部導覽列以「透明玻璃」浮於最上層；內容（含子頁面）鋪滿整個螢幕並從導覽列
    // 下方滑過，因此導覽列的玻璃效果能折射其下方的滑動內容。
    return PopScope(
      canPop: false, // 攔截系統返回鍵以優先處理巢狀 Navigator 的 pop
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final NavigatorState? nestedNav = _nestedNavKey.currentState;
        if (nestedNav != null && nestedNav.canPop()) {
          nestedNav.pop();
        } else {
          // 如果巢狀 Navigator 沒有可以 pop 的子頁面，則 pop 外層 Navigator
          if (context.mounted) {
            Navigator.of(context).pop(result);
          }
        }
      },
      child: Scaffold(
        extendBody: true,
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            // 1. 流體極光背景（填滿整個螢幕，透出玻璃質感）
            const AuroraBackground(),

            // 2. 頁面內容（巢狀 Navigator：首頁為 4 個分頁，子頁面疊於其上）鋪滿整個螢幕，
            //    內容會滑到導覽列下方。
            Positioned.fill(
              child: Navigator(
                key: _nestedNavKey,
                observers: [_modalObserver],
                onGenerateRoute: (settings) => MaterialPageRoute(
                  builder: (context) => _buildHome(),
                  settings: settings,
                ),
              ),
            ),

            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: RepaintBoundary(
                child: ValueListenableBuilder<bool>(
                  valueListenable: LayoutStyleNotifier.hideNavBarNotifier,
                  builder: (context, globalHide, _) {
                    if (_hideNavBar || globalHide) return const SizedBox.shrink();
                    return IgnorePointer(
                      ignoring: _modalOpen,
                      child: _buildBottomNavBar(),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 巢狀 Navigator 的首頁：標題列 + 4 個分頁的 PageView。
  Widget _buildHome() {
    // Filter items based on original categorizations
    final gradesItems = widget.menuItems
        .where((item) => item.section == "成績與進度")
        .toList();
    final scheduleItems = widget.menuItems
        .where((item) => item.section == "課表與選課")
        .toList();
    final campusItems = widget.menuItems
        .where((item) => item.section == "學習與校園")
        .toList();

    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          // 標題列
          _buildAppBar(),

          // 滾動內容 (透過 PageView 進行左右滑動切換；分頁常駐不重建)
          Expanded(
            child: ClipRect(
              child: RepaintBoundary(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  children: <Widget>[
                    _buildGradesTab(gradesItems),
                    _buildScheduleTab(scheduleItems),
                    _buildTabContent(campusItems),
                    _buildMenuTab(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    final colorScheme = Theme.of(context).colorScheme;
    String title = "學生服務系統";
    if (_selectedIndex == 0) title = "成績與進度";
    if (_selectedIndex == 1) title = "課表與選課";
    if (_selectedIndex == 2) title = "學習與校園";
    if (_selectedIndex == 3) title = "功能設定選單";

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: colorScheme.primaryText,
              letterSpacing: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabContent(List<MainMenuItem> items) {
    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 100),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 14.0),
          child: _GlassMenuButton(item: item, navKey: _nestedNavKey),
        );
      },
    );
  }

  Widget _buildGradesTab(List<MainMenuItem> items) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth >= 700;

    // Hoist: only wide screens need gradData. Initialize once lazily so
    // FutureBuilder doesn't re-subscribe on every parent setState (PageView
    // keeps this tab alive permanently, so the future must be stable).
    if (isWide) {
      _gradDataFuture ??=
          GraduationService.instance.fetchGraduationData(forceRefresh: false);
    }

    return FutureBuilder<GraduationData?>(
      future: isWide ? _gradDataFuture : null,
      builder: (context, gradSnapshot) {
        final gradData = gradSnapshot.data;
        final hasGradData = gradData != null && gradData.minCredits > 0;

        return ValueListenableBuilder<Map<String, List<CourseScore>>>(
          valueListenable: HistoricalScoreService.instance.coursesNotifier,
          builder: (context, coursesMap, _) {
            final keys = coursesMap.keys.toList()
              ..sort((a, b) => b.compareTo(a));
            final latestSemesterKey = keys.isNotEmpty ? keys.first : null;

            // summaryNotifier / previewRanksNotifier 的訂閱與 wide/narrow 的
            // Row/Column 佈局判斷都移到 [_GradesTabHeader] 內（Task 5 已完成）。
            // 外層不再訂閱 summaryNotifier，所以這些 notifier 的更新只會 rebuild
            // header，不會牽動整個 ListView。
            Widget? statsHeader;
            if (latestSemesterKey != null) {
              statsHeader = _GradesTabHeader(
                latestSemesterKey: latestSemesterKey,
                gradData: hasGradData ? gradData : null,
              );
            }

            return ListView.builder(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 100),
              itemCount: items.length + (statsHeader != null ? 1 : 0),
              itemBuilder: (context, index) {
                if (statsHeader != null) {
                  if (index == 0) {
                    return statsHeader;
                  }
                  final item = items[index - 1];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 14.0),
                    child: _GlassMenuButton(
                      item: item,
                      navKey: _nestedNavKey,
                    ),
                  );
                } else {
                  final item = items[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 14.0),
                    child: _GlassMenuButton(
                      item: item,
                      navKey: _nestedNavKey,
                    ),
                  );
                }
              },
            );
          },
        );
      },
    );
  }

  Widget _buildScheduleTab(List<MainMenuItem> scheduleItems) {
    final colorScheme = Theme.of(context).colorScheme;
    // 窄螢幕下才套用「隱藏英文 / 只顯示教室 / 第A節~第B節」的調整
    final isNarrow = MediaQuery.of(context).size.width < 700;

    return ValueListenableBuilder<Map<String, List<Course>>>(
      valueListenable: CourseService.instance.allCoursesNotifier,
      builder: (context, allCourses, _) {
        List<Course> todayCourses = [];
        String semesterLabel = "";

        if (allCourses.isNotEmpty) {
          final sortedSemesters = allCourses.keys.toList()
            ..sort((a, b) => b.compareTo(a));
          final latestSemester = sortedSemesters.first;
          semesterLabel =
              "${latestSemester.substring(0, 3)}學年度 第${latestSemester.substring(3)}學期";

          final courses = allCourses[latestSemester] ?? [];
          for (var course in courses) {
            final hasTodayClass = course.parsedTimes.any(
              (time) => time.day == _selectedDay,
            );
            if (hasTodayClass) {
              todayCourses.add(course);
            }
          }

          // 排序當日課程按節次先後
          todayCourses.sort((a, b) {
            final aPeriod = a.parsedTimes
                .firstWhere((t) => t.day == _selectedDay)
                .period;
            final bPeriod = b.parsedTimes
                .firstWhere((t) => t.day == _selectedDay)
                .period;
            final aIdx = _periodsOrder.indexOf(aPeriod);
            final bIdx = _periodsOrder.indexOf(bPeriod);
            return aIdx.compareTo(bIdx);
          });
        }

        return ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 100),
          children: [
            // 週一到週五的快速選擇 Tabs
            _buildDaySelector(),
            const SizedBox(height: 16),

            // 課表內容玻璃卡片區塊
            GlassCard(
              borderRadius: 22,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.calendar_today_rounded,
                              color: colorScheme.primary,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              "星期${['', '一', '二', '三', '四', '五', '六', '日'][_selectedDay]}課表",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: colorScheme.primaryText,
                              ),
                            ),
                          ],
                        ),
                        if (semesterLabel.isNotEmpty)
                          Text(
                            semesterLabel,
                            style: TextStyle(
                              fontSize: 11,
                              color: colorScheme.subtitleText,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (todayCourses.isEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 32.0),
                          child: Column(
                            children: [
                              Icon(
                                Icons.spa_rounded,
                                color: colorScheme.subtitleText.withValues(alpha: 
                                  0.3,
                                ),
                                size: 48,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                "當天沒有排課喔，好好放鬆吧！",
                                style: TextStyle(
                                  color: colorScheme.subtitleText,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        padding: const EdgeInsets.only(bottom: 8),
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: todayCourses.length,
                        separatorBuilder: (context, index) =>
                            const Divider(color: Colors.white10, height: 24),
                        itemBuilder: (context, index) {
                          final course = todayCourses[index];
                          // 該課程在當天的所有節次（依節次順序排序）
                          final dayPeriods = course.parsedTimes
                              .where((t) => t.day == _selectedDay)
                              .map((t) => t.period)
                              .toList();
                          dayPeriods.sort(
                            (a, b) => _periodsOrder
                                .indexOf(a)
                                .compareTo(_periodsOrder.indexOf(b)),
                          );
                          final period = dayPeriods.isNotEmpty
                              ? dayPeriods.first
                              : '';
                          final lastPeriod = dayPeriods.isNotEmpty
                              ? dayPeriods.last
                              : '';
                          final timeRange = _timeRangeMap[period] ?? "時間未排定";

                          // 窄螢幕：節次顯示為兩行區間「第A節\n~第B節」
                          final bool isRange =
                              isNarrow &&
                              dayPeriods.length > 1 &&
                              period != lastPeriod;
                          final String periodLabel = isRange
                              ? "第 $period 節\n|\n第 $lastPeriod 節"
                              : "第 $period 節";

                          // 窄螢幕：課程名稱隱藏英文、地點只顯示()內教室
                          final String displayName = isNarrow
                              ? keepUntilLastChinese(course.name)
                              : course.name;
                          final String rawLocation = isNarrow
                              ? extractLocation(course.location)
                              : course.location;
                          // 地點沒有資料（含抽取後為空）一律顯示「未定」
                          final String locationText =
                              (course.location.isEmpty ||
                                  rawLocation.trim().isEmpty)
                              ? "未定"
                              : rawLocation;

                          return IntrinsicHeight(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // 左側時間與節次
                                Container(
                                  width: 80,
                                  padding: EdgeInsets.symmetric(
                                    horizontal: isNarrow ? 4 : 8,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: colorScheme.primary.withValues(alpha: 
                                      0.12,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Column(
                                    // 區間（多節）時頂端對齊，讓藍字與右邊課名對齊；
                                    // 單節時置中，藍色區塊視覺平衡。
                                    mainAxisAlignment: (dayPeriods.length > 1)
                                        ? MainAxisAlignment.start
                                        : MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        periodLabel,
                                        style: TextStyle(
                                          fontSize: isNarrow ? 12 : 13,
                                          fontWeight: FontWeight.bold,
                                          color: colorScheme.primary,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                      // 寬螢幕保留時間；窄螢幕只留節次藍字
                                      if (!isNarrow) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          timeRange.replaceAll(" - ", "\n"),
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: colorScheme.subtitleText,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 16),
                                // 右側課程詳細
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 6,
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          displayName,
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.bold,
                                            color: colorScheme.primaryText,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 6),
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.location_on_outlined,
                                              size: 13,
                                              color: colorScheme.subtitleText,
                                            ),
                                            const SizedBox(width: 4),
                                            Expanded(
                                              child: Text(
                                                locationText,
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color:
                                                      colorScheme.subtitleText,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Icon(
                                              Icons.person_outline_rounded,
                                              size: 13,
                                              color: colorScheme.subtitleText,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              course.professor,
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: colorScheme.subtitleText,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // 功能選單標題
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 12),
              child: Row(
                children: [
                  Icon(
                    Icons.widgets_outlined,
                    size: 18,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    "選課工具與查詢",
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),

            // 選課功能列表
            ...scheduleItems.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: _GlassMenuButton(item: item, navKey: _nestedNavKey),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDaySelector() {
    final colorScheme = Theme.of(context).colorScheme;
    final days = ["一", "二", "三", "四", "五"];

    return GlassCard(
      borderRadius: 16,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: List.generate(5, (index) {
            final dayIndex = index + 1;
            final isSelected = _selectedDay == dayIndex;
            return Expanded(
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedDay = dayIndex;
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? colorScheme.primary.withValues(alpha: 0.16)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected
                          ? colorScheme.primary.withValues(alpha: 0.3)
                          : Colors.transparent,
                      width: 1,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      "週${days[index]}",
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: isSelected
                            ? colorScheme.primary
                            : colorScheme.primaryText.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildMenuTab() {
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 100),
      children: [
        // 1. 已依需求移除原本的 _buildInfoCard() 學生服務系統資訊卡

        // 2. 選單項目列表
        _buildMenuActionTile(
          icon: Icons.settings_rounded,
          color: Colors.blueGrey,
          label: "設定",
          onTap: () async {
            await _pushSubPageBuilder((_) => const SettingsPage());
            widget.onLoadSettings();
          },
        ),
        const SizedBox(height: 12),
        _buildMenuActionTile(
          icon: widget.hasNewVersion
              ? Icons.system_update
              : Icons.verified_user_rounded,
          color: widget.hasNewVersion ? Colors.red : Colors.green,
          label: widget.hasNewVersion ? "更新APP" : "App版本",
          trailingText: widget.hasNewVersion ? "NEW" : null,
          onTap: () {
            _pushSubPageBuilder((_) => const AppVersionPage());
          },
        ),
        const SizedBox(height: 12),
        _buildMenuActionTile(
          icon: Icons.delete_sweep_outlined,
          color: Colors.orange,
          label: "清除暫存檔案",
          onTap: widget.onShowClearCache,
        ),
        const SizedBox(height: 12),
        _buildMenuActionTile(
          icon: Icons.info_outline,
          color: Colors.blue,
          label: "使用說明",
          onTap: () {
            _pushSubPageBuilder((_) => const InfoPage());
          },
        ),
        const SizedBox(height: 12),
        _buildMenuActionTile(
          icon: Icons.code_rounded,
          color: Colors.teal,
          label: "關於開發者",
          onTap: () {
            _pushSubPageBuilder((_) => const AboutDeveloperPage());
          },
        ),
        const SizedBox(height: 20),
        const Divider(color: Colors.white12, height: 1),
        const SizedBox(height: 20),
        _buildMenuActionTile(
          icon: Icons.logout,
          color: Colors.red,
          label: "登出系統",
          isDestructive: true,
          onTap: widget.onShowLogout,
        ),
      ],
    );
  }

  Widget _buildMenuActionTile({
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
    String? trailingText,
    bool isDestructive = false,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return GlassCard(
      borderRadius: 16,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 22, color: color),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: isDestructive ? Colors.red : colorScheme.primaryText,
                  ),
                ),
              ),
              if (trailingText != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    trailingText,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                )
              else
                Icon(
                  Icons.chevron_right_rounded,
                  color: colorScheme.subtitleText.withValues(alpha: 0.5),
                  size: 22,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNavBar() {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Bottom bar item definition
    final navbarItems = [
      _NavbarItem(Icons.school_outlined, Icons.school, "成績"),
      _NavbarItem(Icons.calendar_month_outlined, Icons.calendar_month, "課表選課"),
      _NavbarItem(Icons.campaign_outlined, Icons.campaign, "校園"),
      _NavbarItem(Icons.widgets_outlined, Icons.widgets, "選單"),
    ];

    final borderRadiusVal = 28.0;
    final glassBgColor = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.white.withValues(alpha: 0.35);

    final glassBorder = Border.all(
      color: isDark
          ? Colors.white.withValues(alpha: 0.12)
          : Colors.white.withValues(alpha: 0.35),
      width: 1.0,
    );

    final glassShadows = isDark
        ? [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ]
        : [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ];

    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth >= 600;

    Widget navBar = SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(20, 0, 20, 18),
      child: AdaptiveGlass(
        quality: GlassQuality.premium,
        shape: LiquidRoundedSuperellipse(borderRadius: borderRadiusVal),
        settings: LiquidGlassSettings(
          blur: 1,
          glassColor: glassBgColor,
          refractiveIndex: 1.05,
          thickness: 45,
          chromaticAberration: 0.02,
          lightIntensity: 0.5,
          specularSharpness: GlassSpecularSharpness.sharp,
          shadow: glassShadows,
          visibility: 1,
        ),
        child: Container(
          height: 64,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            border: glassBorder,
            borderRadius: BorderRadius.circular(borderRadiusVal),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final totalWidth = constraints.maxWidth;
              final tabWidth = totalWidth / navbarItems.length;

              return Stack(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: List.generate(navbarItems.length, (index) {
                      final item = navbarItems[index];
                      final active = _selectedIndex == index;
                      return Expanded(
                        child: _LiquidGlassNavItem(
                          item: item,
                          active: active,
                          activeColor: colorScheme.primary,
                          dimColor: colorScheme.primaryText.withValues(
                            alpha: 0.55,
                          ),
                          onTap: () => _onNavTap(index),
                        ),
                      );
                    }),
                  ),
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 320),
                    curve: Curves.easeOutBack,
                    left: _selectedIndex * tabWidth,
                    width: tabWidth,
                    top: 0,
                    bottom: 0,
                    child: IgnorePointer(
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          color: colorScheme.primary.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: colorScheme.primary.withValues(alpha: 0.3),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: colorScheme.primary.withValues(alpha: 0.1),
                              blurRadius: 6,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );

    if (isWide) {
      navBar = Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: navBar,
        ),
      );
    }

    return navBar;
  }
}

class _NavbarItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;

  _NavbarItem(this.icon, this.activeIcon, this.label);
}

/// 流體玻璃導覽列單項：點擊「按下但尚未放開」時給予豐富回饋——
/// 液態擠壓（橫向微脹、縱向壓縮）、圖示後方的柔光暈、以及圖示/標籤顏色
/// 朝主色趨亮；放開時以 easeOutBack 彈回。僅用於 liquid glass 底部導覽列。
class _LiquidGlassNavItem extends StatefulWidget {
  final _NavbarItem item;
  final bool active;
  final Color activeColor;
  final Color dimColor;
  final VoidCallback onTap;

  const _LiquidGlassNavItem({
    required this.item,
    required this.active,
    required this.activeColor,
    required this.dimColor,
    required this.onTap,
  });

  @override
  State<_LiquidGlassNavItem> createState() => _LiquidGlassNavItemState();
}

class _LiquidGlassNavItemState extends State<_LiquidGlassNavItem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _press;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 160),
      reverseDuration: const Duration(milliseconds: 380),
    );
    _press = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeIn,
      reverseCurve: Curves.easeOutBack,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDown() => _controller.forward();

  void _onUp() {
    _controller.reverse();
    widget.onTap();
  }

  void _onCancel() => _controller.reverse();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _onDown(),
      onTapUp: (_) => _onUp(),
      onTapCancel: _onCancel,
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: _press,
        builder: (context, _) {
          final p = _press.value;
          // 按下進度 0..1（彈回時 easeOutBack 可能略為越界，clamp 顏色避免負值）
          final haloAlpha = (0.16 * p).clamp(0.0, 1.0);
          final glowAlpha = (0.30 * p).clamp(0.0, 1.0);
          final colorT = widget.active ? 1.0 : (0.60 * p).clamp(0.0, 1.0);
          final iconColor = Color.lerp(
            widget.dimColor,
            widget.activeColor,
            colorT,
          )!;

          return Container(
            height: 48,
            color: Colors.transparent,
            child: Center(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // 按下時浮現的液態光暈（柔焦擴散）
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: widget.activeColor.withValues(alpha: haloAlpha),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: p > 0
                          ? [
                              BoxShadow(
                                color: widget.activeColor.withValues(
                                  alpha: glowAlpha,
                                ),
                                blurRadius: 10 + 8 * p,
                                spreadRadius: 1 + 2 * p,
                              ),
                            ]
                          : null,
                    ),
                  ),
                  // 活躍狀態的縮放過渡（保留原本行為）
                  AnimatedScale(
                    scale: widget.active ? 1.12 : 1.0,
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOut,
                    child: Transform.scale(
                      scaleX: 1 + 0.06 * p,
                      scaleY: 1 - 0.16 * p,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            widget.active
                                ? widget.item.activeIcon
                                : widget.item.icon,
                            color: iconColor,
                            size: 20,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.item.label,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: widget.active
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: iconColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// 觀察巢狀 Navigator 最上層路由是否為彈窗（PopupRoute），
/// 據此暫停/恢復底部導覽列的回應，避免在彈窗後被誤點。
/// （showGlassDialog 因 useRootNavigator: true 會直接覆蓋導覽列，不需依賴此處。）
class _ModalRouteObserver extends NavigatorObserver {
  final _MainMenuLiquidGlassLayoutState state;

  _ModalRouteObserver(this.state);

  void _update(Route? top) {
    // PopupRoute 涵蓋 dialog 與 modal bottom sheet（皆非 opaque，只覆蓋內容區）。
    state._onModalChanged(top is PopupRoute);

    final String? routeName = top?.settings.name;
    final bool hideNavBar =
        routeName == 'initialization_page' ||
        routeName == 'assistant_add_course' ||
        routeName == 'assistant_import' ||
        routeName == 'assistant_export' ||
        routeName == 'course_exception_handling' ||
        routeName == 'course_exception_download';
    state._onHideNavBarChanged(hideNavBar);
  }

  @override
  void didPush(Route route, Route? previousRoute) => _update(route);

  @override
  void didPop(Route route, Route? previousRoute) => _update(previousRoute);

  @override
  void didRemove(Route route, Route? previousRoute) => _update(previousRoute);

  @override
  void didReplace({Route? newRoute, Route? oldRoute}) => _update(newRoute);
}

// Custom glass list item menu button that matches bento tile behavior but styled as a sleek glass card
class _GlassMenuButton extends StatefulWidget {
  final MainMenuItem item;
  // 巢狀 Navigator 的 key：liquid glass 模式下子頁面推入此 Navigator，使導覽列恆存於其上。
  final GlobalKey<NavigatorState>? navKey;

  const _GlassMenuButton({Key? key, required this.item, this.navKey})
    : super(key: key);

  @override
  State<_GlassMenuButton> createState() => _GlassMenuButtonState();
}

class _GlassMenuButtonState extends State<_GlassMenuButton>
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
      end: 0.97,
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

          // liquid glass：優先以 pageBuilder 推入巢狀 Navigator，讓導覽列恆存；
          // 否則退回項目原本的 onTap（推入 root Navigator）。
          final nav = widget.navKey?.currentState;
          if (nav != null && item.pageBuilder != null) {
            nav.push(MaterialPageRoute(builder: item.pageBuilder!));
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
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: _isGlowing
                      ? item.color.withValues(alpha: 0.3)
                      : Colors.transparent,
                  spreadRadius: _isGlowing ? 2 : 0,
                  blurRadius: _isGlowing ? 12 : 0,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: GlassCard(
              borderRadius: 20,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 14.0,
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: item.color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(item.icon, size: 24, color: item.color),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.label,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: colorScheme.primaryText,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            item.subtitle,
                            style: TextStyle(
                              fontSize: 12,
                              color: colorScheme.subtitleText,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: item.color.withValues(alpha: 0.7),
                      size: 24,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 成績 tab 上方獨立的 header：最新學期摘要 + 畢業進度。
///
/// 獨立成為單一 widget 後，只訂閱 [HistoricalScoreService.summaryNotifier] 與
/// [HistoricalScoreService.previewRanksNotifier]，當這些 notifier 觸發時只重 build
/// 此 header，不會牽動外層課程 ListView。
/// `latestSemesterKey` 與 `gradData` 由外層 [_buildGradesTab] 傳入（後者依寬度與
/// coursesNotifier 是否有該學期 fetch gradData）。
class _GradesTabHeader extends StatefulWidget {
  final String latestSemesterKey;
  final GraduationData? gradData;

  const _GradesTabHeader({
    required this.latestSemesterKey,
    this.gradData,
  });

  @override
  State<_GradesTabHeader> createState() => _GradesTabHeaderState();
}

class _GradesTabHeaderState extends State<_GradesTabHeader> {
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: HistoricalScoreService.instance.isLoadingNotifier,
      builder: (context, isLoading, _) {
        return ValueListenableBuilder<Map<String, ScoreSummary>>(
          valueListenable: HistoricalScoreService.instance.summaryNotifier,
          builder: (context, summaryMap, _) {
            return ValueListenableBuilder<Map<String, Map<String, String>>>(
              valueListenable:
                  HistoricalScoreService.instance.previewRanksNotifier,
              builder: (context, previewMap, _) {
                final coursesMap =
                    HistoricalScoreService.instance.coursesNotifier.value;
                final courses = coursesMap[widget.latestSemesterKey] ?? [];
                final officialSummary =
                    summaryMap[widget.latestSemesterKey] ?? ScoreSummary();
                final previewData = previewMap[widget.latestSemesterKey];

                bool hasValidValue(String? value) {
                  return value != null && value.isNotEmpty && value != "-";
                }

                ScoreSummary finalSummary;
                bool isOfficialValid = hasValidValue(officialSummary.average);
                bool isPreviewRank = false;

                if (isOfficialValid) {
                  finalSummary = officialSummary;
                  if (!hasValidValue(finalSummary.rank) &&
                      previewData != null &&
                      hasValidValue(previewData['rank'])) {
                    finalSummary.rank = previewData['rank']!;
                    finalSummary.classSize = previewData['classSize'] ?? "-";
                    isPreviewRank = true;
                  }
                } else {
                  ScoreSummary calculated =
                      _calculateSemesterSummary(courses);
                  bool hasPreviewRank = previewData != null &&
                      hasValidValue(previewData['rank']);
                  if (hasPreviewRank) {
                    finalSummary = ScoreSummary(
                      creditsTaken: calculated.creditsTaken,
                      creditsEarned: calculated.creditsEarned,
                      average: calculated.average,
                      rank: previewData['rank']!,
                      classSize: previewData['classSize'] ?? "-",
                    );
                    isPreviewRank = true;
                  } else {
                    finalSummary = calculated;
                  }
                }

                if (!hasValidValue(finalSummary.rank)) {
                  finalSummary.rank = "--";
                  finalSummary.classSize = "--";
                }

                final screenWidth = MediaQuery.of(context).size.width;
                final isWide = screenWidth >= 700;
                final hasGradData =
                    widget.gradData != null && widget.gradData!.minCredits > 0;

                final scoreCard = _buildLatestSemesterScoreSummaryCard(
                  semesterKey: widget.latestSemesterKey,
                  summary: finalSummary,
                  isUpdating: isLoading,
                  isPreviewRank: isPreviewRank,
                );

                if (isWide && hasGradData) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 20.0),
                    child: IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(child: scoreCard),
                          const SizedBox(width: 14),
                          Expanded(
                            child: _buildGraduationProgressCard(widget.gradData!),
                          ),
                        ],
                      ),
                    ),
                  );
                } else {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        scoreCard,
                        if (hasGradData) ...[
                          const SizedBox(height: 14),
                          _buildGraduationProgressCard(widget.gradData!),
                        ],
                      ],
                    ),
                  );
                }
              },
            );
          },
        );
      },
    );
  }

  // 從 _MainMenuLiquidGlassLayoutState 搬過來的 5 個方法：
  // _buildLatestSemesterScoreSummaryCard
  // _buildMiniSummaryItem
  // _buildGraduationProgressCard
  // _calculateSemesterSummary
  // _formatAverage
  // 均只使用參數與 context，未引用任何 _MainMenuLiquidGlassLayoutState 欄位。
  Widget _buildLatestSemesterScoreSummaryCard({
    required String semesterKey,
    required ScoreSummary summary,
    bool isUpdating = false,
    bool isPreviewRank = false,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final parts = semesterKey.split('-');
    final semesterName = parts.length == 2
        ? "${parts[0]}學年度 第${parts[1]}學期"
        : semesterKey;

    final themeColor = colorScheme.isDark
        ? Colors.teal[200]!
        : Colors.teal[800]!;

    return GlassCard(
      borderRadius: 20,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.analytics_outlined, color: themeColor, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "$semesterName",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.primaryText,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isUpdating) ...[
                  const SizedBox(width: 6),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.8,
                          color: themeColor,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        "更新中...",
                        style: TextStyle(
                          fontSize: 11,
                          color: themeColor.withValues(alpha: 0.85),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ] else if (isPreviewRank) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: themeColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: themeColor.withValues(alpha: 0.3),
                        width: 0.8,
                      ),
                    ),
                    child: Text(
                      "預覽名次",
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: themeColor,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildMiniSummaryItem("修習學分", summary.creditsTaken),
                _buildMiniSummaryItem("實得學分", summary.creditsEarned),
                _buildMiniSummaryItem(
                  "平均分數",
                  _formatAverage(summary.average),
                  isHighlight: true,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: colorScheme.isDark
                    ? Colors.black.withValues(alpha: 0.2)
                    : Colors.white.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "班名次",
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.subtitleText,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    "${summary.rank} / ${summary.classSize}",
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.primaryText,
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

  Widget _buildMiniSummaryItem(
    String label,
    String value, {
    bool isHighlight = false,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 11, color: colorScheme.subtitleText),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: isHighlight ? 15 : 13,
            fontWeight: FontWeight.bold,
            color: isHighlight
                ? (colorScheme.isDark ? Colors.teal[200] : colorScheme.primary)
                : colorScheme.primaryText,
          ),
        ),
      ],
    );
  }

  Widget _buildGraduationProgressCard(GraduationData gradData) {
    final colorScheme = Theme.of(context).colorScheme;
    final double completionRate = gradData.minCredits > 0
        ? (gradData.currentCredits / gradData.minCredits).clamp(0.0, 1.0)
        : 0.0;

    final themeColor = colorScheme.isDark
        ? Colors.purple[200]!
        : Colors.purple[800]!;

    return GlassCard(
      borderRadius: 20,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.fact_check_rounded, color: themeColor, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "畢業學分進度",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.primaryText,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "累計學分 / 畢業門檻",
                      style: TextStyle(
                        fontSize: 11,
                        color: colorScheme.subtitleText,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "${gradData.currentCredits} / ${gradData.minCredits}",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.primaryText,
                      ),
                    ),
                  ],
                ),
                Text(
                  "${(completionRate * 100).toStringAsFixed(0)}%",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: themeColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: completionRate,
                backgroundColor: colorScheme.isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.05),
                valueColor: AlwaysStoppedAnimation<Color>(themeColor),
                minHeight: 6,
              ),
            ),
          ],
        ),
      ),
    );
  }

  ScoreSummary _calculateSemesterSummary(List<CourseScore> courses) {
    double totalWeightedPoints = 0;
    double gpaCredits = 0;
    double creditsTaken = 0;
    double creditsEarned = 0;

    final Map<String, double> gradePoints = {
      "A+": 4.3,
      "A": 4.0,
      "A-": 3.7,
      "B+": 3.3,
      "B": 3.0,
      "B-": 2.7,
      "C+": 2.3,
      "C": 2.0,
      "C-": 1.7,
      "D": 1.0,
      "E": 0.0,
      "F": 0.0,
      "X": 0.0,
    };

    for (var course in courses) {
      double credit = double.tryParse(course.credits) ?? 0;
      String score = course.score.trim();

      if (score.contains("抵免")) continue;
      creditsTaken += credit;

      if (score != "E" && score != "F" && score != "X" && score != "") {
        creditsEarned += credit;
      }

      if (score != "(P)" && gradePoints.containsKey(score)) {
        gpaCredits += credit;
        totalWeightedPoints += (credit * gradePoints[score]!);
      }
    }

    double avg = gpaCredits > 0 ? (totalWeightedPoints / gpaCredits) : 0.0;

    return ScoreSummary(
      creditsTaken: creditsTaken.toInt().toString(),
      creditsEarned: creditsEarned.toInt().toString(),
      average: avg == 0.0 ? "0" : avg.toStringAsFixed(2),
      rank: "--",
      classSize: "--",
    );
  }

  String _formatAverage(String? val) {
    if (val == null || val.isEmpty || val == "-") return "-";
    return val;
  }
}
