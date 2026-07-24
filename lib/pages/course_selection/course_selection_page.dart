// 檔案名稱：course_selection_page.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/course_selection_service.dart';
import '../../services/offline_error_handler.dart';
import 'course_status_tab.dart';
import 'course_query_tab.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass/glass_page_scaffold.dart';
import '../../widgets/glass/glass_dialog.dart';

class CourseSelectionPage extends StatefulWidget {
  // 控制是否開啟查詢/加退選功能
  final bool enableQuery;

  const CourseSelectionPage({
    super.key,
    this.enableQuery = true, // 預設為 true (正常模式)
  });

  @override
  State<CourseSelectionPage> createState() => _CourseSelectionPageState();
}

class _CourseSelectionPageState extends State<CourseSelectionPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // 共享狀態
  bool _isLoading = true;
  String _message = "資料讀取中...";
  List<CourseSelectionData> _myCourses = [];
  bool _isSystemClosed = false;

  @override
  void initState() {
    super.initState();
    // 如果 enableQuery 為 false，Tab 長度只有 1，否則為 2
    _tabController = TabController(
      length: widget.enableQuery ? 2 : 1,
      vsync: this,
    );
    _loadMyCourses();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      // 【修改】只有在「非唯讀模式」(enableQuery為true) 時，才跳出免責聲明
      if (widget.enableQuery) {
        _showDisclaimerDialog();
        _checkAndSwitchToQueryTab();
      }
    });
  }

  Future<void> _checkAndSwitchToQueryTab() async {
    if (!widget.enableQuery) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final exportedIds = prefs.getStringList('exported_course_ids');
      if (exportedIds != null && exportedIds.isNotEmpty) {
        // 切換到第二個分頁 (課程查詢/加退選)
        _tabController.animateTo(1);
      }
    } catch (e) {
      debugPrint("檢查匯出課程失敗: $e");
    }
  }

  Future<void> _loadMyCourses() async {
    setState(() {
      _isLoading = true;
      _message = "正在登入選課系統...";
      _isSystemClosed = false;
    });

    try {
      final result = await CourseSelectionService.instance
          .fetchSelectionResult();
      if (!mounted) return;
      final SelectionState state = result['state'];
      final List<CourseSelectionData> data = result['data'];

      if (state == SelectionState.closed) {
        // 如果是唯讀模式 (enableQuery=false)，即使系統回傳 closed 我們也顯示抓到的資料(如果有的話)
        setState(() {
          _isSystemClosed = true;
          _isLoading = false;
        });
      } else if (state == SelectionState.needConfirmation) {
        setState(() {
          _isLoading = false;
        });
      } else {
        setState(() {
          _myCourses = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (e is OfflineDisabledException) {
        if (mounted) await OfflineErrorHandler.show(context, e);
        if (mounted) setState(() => _isLoading = false);
        return;
      }
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _message = "發生錯誤：$e";
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;

        if (width < 800) {
          // Mobile Layout (Keep exact existing layout)
          return GlassPageScaffold(
            appBar: AppBar(
              title: Text(widget.enableQuery ? "選課系統" : "目前選課狀態"),
              centerTitle: true,
              bottom: widget.enableQuery
                  ? TabBar(
                      controller: _tabController,
                      labelColor: colorScheme.primary,
                      unselectedLabelColor: colorScheme.subtitleText,
                      indicatorColor: colorScheme.primary,
                      tabs: const [
                        Tab(text: "目前選課情況"),
                        Tab(text: "課程查詢/加退選"),
                      ],
                    )
                  : null,
            ),
            body: widget.enableQuery
                ? TabBarView(
                    controller: _tabController,
                    children: [
                      _buildStatusTab(showPreviewButton: true),
                      CourseQueryTab(
                        currentCourses: _myCourses,
                        onRequestRefresh: _loadMyCourses,
                      ),
                    ],
                  )
                : _buildStatusTab(showPreviewButton: true),
          );
        } else if (width < 1100) {
          // Medium Layout: Split into two parts: Left is "目前選課狀態", Right is "課程查詢/加退選"
          return GlassPageScaffold(
            appBar: AppBar(
              title: Text(widget.enableQuery ? "選課系統" : "目前選課狀態"),
              centerTitle: true,
              elevation: 0,
              scrolledUnderElevation: 0,
              shape: Border(
                bottom: BorderSide(color: colorScheme.borderColor, width: 1.0),
              ),
            ),
            body: widget.enableQuery
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Left: 目前選課狀態
                      Expanded(
                        flex: 45,
                        child: _buildStatusTab(
                          showPreviewButton: true,
                          isCompact: true,
                        ),
                      ),
                      VerticalDivider(
                        width: 1,
                        thickness: 1.0,
                        color: colorScheme.borderColor,
                      ),
                      // Right: 課程查詢/加退選
                      Expanded(
                        flex: 55,
                        child: CourseQueryTab(
                          currentCourses: _myCourses,
                          onRequestRefresh: _loadMyCourses,
                          isCompact: true,
                        ),
                      ),
                    ],
                  )
                : Center(
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 800),
                      child: _buildStatusTab(
                        showPreviewButton: true,
                        isCompact: true,
                      ),
                    ),
                  ),
          );
        } else {
          // Wide Layout: Left: "目前選課狀態", Middle: "課表預覽", Right: "課程查詢/加退選"
          return GlassPageScaffold(
            appBar: AppBar(
              title: Text(widget.enableQuery ? "選課系統" : "目前選課狀態"),
              centerTitle: true,
              elevation: 0,
              scrolledUnderElevation: 0,
              shape: Border(
                bottom: BorderSide(color: colorScheme.borderColor, width: 1.0),
              ),
            ),
            body: widget.enableQuery
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Left: 目前選課狀態 (hide button since preview is in middle)
                      Expanded(
                        flex: 25,
                        child: _buildStatusTab(
                          showPreviewButton: false,
                          isCompact: true,
                        ),
                      ),
                      VerticalDivider(
                        width: 1,
                        thickness: 1.0,
                        color: colorScheme.borderColor,
                      ),
                      // Middle: 課表預覽
                      Expanded(
                        flex: 35,
                        child: Container(
                          color: colorScheme.cardBackground,
                          child: CoursePreviewWidget(courses: _myCourses),
                        ),
                      ),
                      VerticalDivider(
                        width: 1,
                        thickness: 1.0,
                        color: colorScheme.borderColor,
                      ),
                      // Right: 課程查詢/加退選
                      Expanded(
                        flex: 40,
                        child: CourseQueryTab(
                          currentCourses: _myCourses,
                          onRequestRefresh: _loadMyCourses,
                          isCompact: true,
                        ),
                      ),
                    ],
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Read-only Wide layout: split screen between status list and timetable preview
                      Expanded(
                        flex: 40,
                        child: _buildStatusTab(
                          showPreviewButton: false,
                          isCompact: true,
                        ),
                      ),
                      VerticalDivider(
                        width: 1,
                        thickness: 1.0,
                        color: colorScheme.borderColor,
                      ),
                      Expanded(
                        flex: 60,
                        child: Container(
                          color: colorScheme.cardBackground,
                          child: CoursePreviewWidget(courses: _myCourses),
                        ),
                      ),
                    ],
                  ),
          );
        }
      },
    );
  }

  Widget _buildStatusTab({
    bool showPreviewButton = true,
    bool isCompact = false,
  }) {
    return CourseStatusTab(
      isLoading: _isLoading,
      message: _message,
      isSystemClosed: _isSystemClosed,
      courses: _myCourses,
      onRefresh: _loadMyCourses,
      showPreviewButton: showPreviewButton,
      isCompact: isCompact,
    );
  }

  void _showDisclaimerDialog() {
    final colorScheme = Theme.of(context).colorScheme;
    showGlassDialog(
      context: context,
      barrierDismissible: false,
      title: Row(
        children: [
          const SizedBox(width: 10),
          Text(
            "免責聲明",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: colorScheme.primaryText,
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "本功能僅為提供手機選課之便利，請勿過度依賴。",
              style: TextStyle(fontSize: 16, color: colorScheme.primaryText),
            ),
            const SizedBox(height: 16),
            const Text(
              "⚠️ 請務必再次確認",
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
            ),
            const SizedBox(height: 8),
            Text(
              "選完課之後，請一定要前往「學校官網」確認無誤。\n\n若是這邊操作的結果和最終學校系統收到的結果不一致，開發者不負擔任何責任。\n\n因此，請務必進行二次檢查。",
              style: TextStyle(height: 1.5, color: colorScheme.bodyText),
            ),
          ],
        ),
      ),
      actions: [
        Builder(
          builder: (dialogCtx) => ElevatedButton(
            onPressed: () => Navigator.pop(dialogCtx),
            style: ElevatedButton.styleFrom(
              backgroundColor: colorScheme.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text("我了解，我會去官網檢查"),
          ),
        ),
      ],
    );
  }
}
