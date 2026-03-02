// 檔案名稱：course_selection_page.dart
import 'package:flutter/material.dart';
import '../../services/course_selection_service.dart';
import 'course_status_tab.dart';
import 'course_query_tab.dart';
import '../../models/course_selection_models.dart';

class CourseSelectionPage extends StatefulWidget {
  // 控制是否開啟查詢/加退選功能
  final bool enableQuery;

  const CourseSelectionPage({
    Key? key, 
    this.enableQuery = true // 預設為 true (正常模式)
  }) : super(key: key);

  @override
  State<CourseSelectionPage> createState() => _CourseSelectionPageState();
}

class _CourseSelectionPageState extends State<CourseSelectionPage> with SingleTickerProviderStateMixin {
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
    _tabController = TabController(length: widget.enableQuery ? 2 : 1, vsync: this);
    _loadMyCourses();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      // 【修改】只有在「非唯讀模式」(enableQuery為true) 時，才跳出免責聲明
      if (widget.enableQuery) {
        _showDisclaimerDialog();
      }
    });
  }

  Future<void> _loadMyCourses() async {
    setState(() {
      _isLoading = true;
      _message = "正在登入選課系統...";
      _isSystemClosed = false;
    });

    try {
      final result = await CourseSelectionService.instance.fetchSelectionResult();
      final SelectionState state = result['state'];
      final List<CourseSelectionData> data = result['data'];

      if (state == SelectionState.closed) {
        // 如果是唯讀模式 (enableQuery=false)，即使系統回傳 closed 我們也顯示抓到的資料(如果有的話)
        setState(() { _isSystemClosed = true; _isLoading = false; });
      } else if (state == SelectionState.needConfirmation) {
        setState(() { _isLoading = false; });
      } else {
        setState(() { _myCourses = data; _isLoading = false; });
      }
    } catch (e) {
      setState(() { _isLoading = false; _message = "發生錯誤：$e"; });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // 如果是唯讀模式，標題改一下比較清楚
        title: Text(widget.enableQuery ? "選課系統" : "目前選課狀態"),
        centerTitle: true,
        // 如果 enableQuery 為 false，就不顯示 TabBar
        bottom: widget.enableQuery 
            ? TabBar(
                controller: _tabController,
                labelColor: Colors.blue[800],
                unselectedLabelColor: Colors.grey,
                indicatorColor: Colors.blue,
                tabs: const [
                  Tab(text: "目前選課情況"),
                  Tab(text: "課程查詢/加退選"),
                ],
              )
            : null,
      ),
      // 如果 enableQuery 為 false，直接顯示 StatusTab，不使用 TabBarView
      body: widget.enableQuery
          ? TabBarView(
              controller: _tabController,
              children: [
                _buildStatusTab(), 
                CourseQueryTab(
                  currentCourses: _myCourses,
                  onRequestRefresh: _loadMyCourses,
                ),
              ],
            )
          : _buildStatusTab(), // 唯讀模式只顯示這個
    );
  }

  Widget _buildStatusTab() {
    return CourseStatusTab(
      isLoading: _isLoading,
      message: _message,
      isSystemClosed: _isSystemClosed,
      courses: _myCourses,
      onRefresh: _loadMyCourses,
    );
  }

  void _showDisclaimerDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(children: [SizedBox(width: 10), Text("免責聲明")]),
        content: const SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("本功能僅為提供手機選課之便利，請勿過度依賴。", style: TextStyle(fontSize: 16)),
              SizedBox(height: 16),
              Text("⚠️ 請務必再次確認", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
              SizedBox(height: 8),
              Text("選完課之後，請一定要前往「學校官網」確認無誤。\n\n若是這邊操作的結果和最終學校系統收到的結果不一致，開發者不負擔任何責任。\n\n因此，請務必進行二次檢查。", style: TextStyle(height: 1.5)),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[800], foregroundColor: Colors.white),
            child: const Text("我了解，我會去官網檢查"),
          ),
        ],
      ),
    );
  }
}