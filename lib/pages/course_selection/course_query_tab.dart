import 'package:flutter/material.dart';
import '../../services/course_selection_service.dart';
import '../../services/course_query_service.dart';
import '../../services/course_selection_submit_service.dart' as submit_service;
import '../../models/course_selection_models.dart'; // 引用刚刚建立的模型檔案
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:http/http.dart' as http; // ✅ 新增：用來發送課綱請求
import '../../theme/app_theme.dart';
import 'package:flutter/services.dart';
import '../../widgets/glass_dropdown.dart';

class CourseQueryTab extends StatefulWidget {
  final List<CourseSelectionData> currentCourses; // 從父層傳入目前的課表，用來比對重複
  final VoidCallback onRequestRefresh; // 當送出成功後，通知父層重整
  final bool isCompact;

  const CourseQueryTab({
    super.key,
    required this.currentCourses,
    required this.onRequestRefresh,
    this.isCompact = false,
  });

  @override
  State<CourseQueryTab> createState() => _CourseQueryTabState();
}

// 使用 AutomaticKeepAliveClientMixin 保持切換分頁時狀態不消失
class _CourseQueryTabState extends State<CourseQueryTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  // 搜尋狀態
  bool _isQueryLoading = false;
  List<CourseJsonData> _searchResults = [];
  bool _hasSearched = false;
  bool _showEditListMode = false;
  bool _showInlineSearchPanel = false;
  final GlobalKey _inlineSearchPanelKey = GlobalKey();

  final List<PendingAddCourse> _pendingAdds = [];
  final List<PendingTransaction> _pendingItems = [];

  // 匯入選課行內狀態
  bool _showImportMode = false;
  final TextEditingController _importTextCtrl = TextEditingController();
  bool _isImporting = false;

  List<String> _semesterOptions = [];
  Map<String, String> _semesterDisplayMap = {};
  String? _selectedSemester;
  bool _isSemesterLoading = true;

  Future<void> _loadSemesters() async {
    try {
      final data = await CourseQueryService.instance.getSemesters();
      final latest = data['latest'] as String;
      final history = data['history'] as Map<String, dynamic>;

      final List<String> sems = history.keys.map((e) => e.toString()).toList();
      if (!sems.contains(latest)) {
        sems.add(latest);
      }

      sems.sort((a, b) => b.compareTo(a));

      final Map<String, String> displayMap = {};
      for (var sem in sems) {
        if (sem.length == 4) {
          final syear = sem.substring(0, 3);
          final sterm = sem.substring(3, 4);
          displayMap[sem] = "$syear-$sterm";
        } else {
          displayMap[sem] = sem;
        }
      }

      if (mounted) {
        setState(() {
          _semesterOptions = sems;
          _semesterDisplayMap = displayMap;
          _selectedSemester = latest;
          _isSemesterLoading = false;
        });
      }
    } catch (e) {
      debugPrint("載入學期清單失敗: $e");
      if (mounted) {
        setState(() {
          _isSemesterLoading = false;
        });
      }
    }
  }

  // 搜尋控制項
  final TextEditingController _crsNameCtrl = TextEditingController();
  final TextEditingController _teacherCtrl = TextEditingController();
  final TextEditingController _codeCtrl = TextEditingController();
  final TextEditingController _deptCtrl = TextEditingController();
  String? _selectedGrade;
  String? _selectedClass;
  String? _selectedDay;
  String? _selectedPeriod;

  @override
  void initState() {
    super.initState();
    // 預先載入搜尋用的 JSON
    _loadCartFromPrefs();
    _loadSemesters();
    CourseQueryService.instance.getCourses().catchError((e) {
      debugPrint("背景載入失敗: $e");
      return <CourseJsonData>[];
    });
  }

  @override
  void dispose() {
    _crsNameCtrl.dispose();
    _teacherCtrl.dispose();
    _codeCtrl.dispose();
    _deptCtrl.dispose();
    _importTextCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // 必須呼叫
    // ✅ 每次畫面重建或切回時，順便檢查有沒有包裹(匯出資料)要領收
    _checkExportedCourses();
    final colorScheme = Theme.of(context).colorScheme;
    final isWide = MediaQuery.of(context).size.width >= 800;
    final isKeyboardActive = MediaQuery.of(context).viewInsets.bottom > 0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxHeight = constraints.maxHeight;
        final maxWidth = constraints.maxWidth;
        final showScrollablePanelOnly =
            isWide &&
            _showInlineSearchPanel &&
            !_showEditListMode &&
            !_showImportMode &&
            ((maxHeight < 450) || isKeyboardActive);
        // 當可用寬度小於 340px 時，按鈕只顯示 icon，避免文字換行與右側溢出
        final iconOnly = maxWidth < 340;

        final bool isSearchActive =
            !_showEditListMode &&
            !_showImportMode &&
            (!isWide || _showInlineSearchPanel);

        return Column(
          children: [
            // 功能列 - 調整為 12px 對齊的外邊距
            Padding(
              padding: EdgeInsets.fromLTRB(
                12,
                12,
                12,
                widget.isCompact ? 4 : 8,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Tooltip(
                      message: iconOnly ? "搜尋課程" : "",
                      child: ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _showEditListMode = false;
                            _showImportMode = false;
                            if (isWide) {
                              _showInlineSearchPanel = !_showInlineSearchPanel;
                            } else {
                              _showSearchSheet();
                            }
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isSearchActive
                              ? colorScheme.primaryContainer
                              : colorScheme.subtleBackground,
                          foregroundColor: isSearchActive
                              ? colorScheme.primary
                              : colorScheme.subtitleText,
                          elevation: 0,
                          padding: iconOnly
                              ? const EdgeInsets.symmetric(
                                  horizontal: 0,
                                  vertical: 12,
                                )
                              : const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 12,
                                ),
                        ),
                        child: iconOnly
                            ? const Icon(Icons.search, size: 20)
                            : const FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.search, size: 18),
                                    SizedBox(width: 6),
                                    Text("搜尋課程"),
                                  ],
                                ),
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Tooltip(
                      message: iconOnly ? "匯入選課" : "",
                      child: ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _showImportMode = !_showImportMode;
                            _showEditListMode = false;
                            _showInlineSearchPanel = false;
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _showImportMode
                              ? colorScheme.primaryContainer
                              : colorScheme.subtleBackground,
                          foregroundColor: _showImportMode
                              ? colorScheme.primary
                              : colorScheme.subtitleText,
                          elevation: 0,
                          padding: iconOnly
                              ? const EdgeInsets.symmetric(
                                  horizontal: 0,
                                  vertical: 12,
                                )
                              : const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 12,
                                ),
                        ),
                        child: iconOnly
                            ? const Icon(Icons.download, size: 20)
                            : const FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.download, size: 18),
                                    SizedBox(width: 6),
                                    Text("匯入選課"),
                                  ],
                                ),
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Tooltip(
                      message: iconOnly ? "編輯選單 (${_pendingItems.length})" : "",
                      child: ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _showEditListMode = !_showEditListMode;
                            _showImportMode = false;
                            _showInlineSearchPanel = false;
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _showEditListMode
                              ? colorScheme.warningContainer
                              : colorScheme.subtleBackground,
                          foregroundColor: _showEditListMode
                              ? (colorScheme.isDark
                                    ? const Color(0xFFFFB74D)
                                    : Colors.orange[800])
                              : colorScheme.subtitleText,
                          elevation: 0,
                          padding: iconOnly
                              ? const EdgeInsets.symmetric(
                                  horizontal: 0,
                                  vertical: 12,
                                )
                              : const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 12,
                                ),
                          side: _pendingItems.isNotEmpty
                              ? BorderSide(
                                  color: colorScheme.isDark
                                      ? const Color(0xFFFFB74D)
                                      : Colors.orange,
                                  width: 1,
                                )
                              : null,
                        ),
                        child: iconOnly
                            ? Badge(
                                label: _pendingItems.isNotEmpty
                                    ? Text("${_pendingItems.length}")
                                    : null,
                                isLabelVisible: _pendingItems.isNotEmpty,
                                child: const Icon(
                                  Icons.playlist_add_check,
                                  size: 20,
                                ),
                              )
                            : FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.playlist_add_check,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 6),
                                    Text("編輯選單 (${_pendingItems.length})"),
                                  ],
                                ),
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: colorScheme.borderColor),

            if (showScrollablePanelOnly)
              Expanded(
                child: SingleChildScrollView(child: _buildInlineSearchPanel()),
              )
            else ...[
              // 行內查詢面板
              if (isWide &&
                  _showInlineSearchPanel &&
                  !_showEditListMode &&
                  !_showImportMode)
                _buildInlineSearchPanel(),

              Expanded(
                child: _showImportMode
                    ? _buildImportView()
                    : (_showEditListMode
                          ? _buildEditListMode()
                          : _buildSearchResults()),
              ),
            ],
          ],
        );
      },
    );
  }

  // --- 實作行內查詢面板 ---
  Widget _buildInlineSearchPanel() {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      key: _inlineSearchPanelKey,
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.borderColor),
        boxShadow: [
          BoxShadow(
            color: colorScheme.isDark
                ? Colors.black12
                : Colors.grey.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "課程查詢條件",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: colorScheme.primaryText,
                ),
              ),
              GestureDetector(
                onTap: () {
                  setState(() {
                    _showInlineSearchPanel = false;
                  });
                },
                child: Icon(
                  Icons.close,
                  size: 18,
                  color: colorScheme.subtitleText,
                ),
              ),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: _isSemesterLoading
                    ? const Center(
                        child: SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : _buildDropdown(
                        label: "學期",
                        value: _selectedSemester ?? "",
                        items: _semesterOptions,
                        displayMap: _semesterDisplayMap,
                        onChanged: (v) => setState(() => _selectedSemester = v),
                      ),
              ),
              const SizedBox(width: 8),
              Expanded(child: _buildTextField("課程名稱", _crsNameCtrl)),
            ],
          ),
          const SizedBox(height: 8),

          Row(
            children: [
              Expanded(child: _buildTextField("授課教師", _teacherCtrl)),
              const SizedBox(width: 8),
              Expanded(
                child: _buildTextField("開課系所", _deptCtrl, hint: "例如: 資工"),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // 3. 年級 & 班級
          Row(
            children: [
              Expanded(
                child: _buildDropdown(
                  label: "年級",
                  value: _selectedGrade ?? "",
                  items: const ["", "1", "2", "3", "4", "5"],
                  displayMap: const {
                    "": "全部",
                    "1": "一年級",
                    "2": "二年級",
                    "3": "三年級",
                    "4": "四年級",
                    "5": "五年級",
                  },
                  onChanged: (v) => setState(
                    () => _selectedGrade = (v == null || v.isEmpty) ? null : v,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildDropdown(
                  label: "班級",
                  value: _selectedClass ?? "",
                  items: const ["", "0", "1", "2", "5"],
                  displayMap: const {
                    "": "全部",
                    "0": "不分班",
                    "1": "甲班",
                    "2": "乙班",
                    "5": "全英班",
                  },
                  onChanged: (v) => setState(
                    () => _selectedClass = (v == null || v.isEmpty) ? null : v,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // 4. 星期 & 節次
          Row(
            children: [
              Expanded(
                child: _buildDropdown(
                  label: "星期",
                  value: _selectedDay ?? "",
                  items: const ["", "1", "2", "3", "4", "5", "6", "7"],
                  displayMap: const {
                    "": "不限",
                    "1": "星期一",
                    "2": "星期二",
                    "3": "星期三",
                    "4": "星期四",
                    "5": "星期五",
                    "6": "星期六",
                    "7": "星期日",
                  },
                  onChanged: (v) => setState(
                    () => _selectedDay = (v == null || v.isEmpty) ? null : v,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildDropdown(
                  label: "節次",
                  value: _selectedPeriod ?? "",
                  items: const [
                    "",
                    "A",
                    "1",
                    "2",
                    "3",
                    "4",
                    "B",
                    "5",
                    "6",
                    "7",
                    "8",
                    "9",
                    "C",
                  ],
                  displayMap: const {
                    "": "不限",
                    "A": "A (07:00)",
                    "1": "1 (08:10)",
                    "2": "2 (09:10)",
                    "3": "3 (10:10)",
                    "4": "4 (11:10)",
                    "B": "B (12:10)",
                    "5": "5 (13:10)",
                    "6": "6 (14:10)",
                    "7": "7 (15:10)",
                    "8": "8 (16:10)",
                    "9": "9 (17:10)",
                    "C": "C (18:20)",
                  },
                  onChanged: (v) => setState(
                    () => _selectedPeriod = (v == null || v.isEmpty) ? null : v,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 5. 按鈕列
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () {
                  _crsNameCtrl.clear();
                  _teacherCtrl.clear();
                  _codeCtrl.clear();
                  _deptCtrl.clear();
                  setState(() {
                    _selectedGrade = null;
                    _selectedClass = null;
                    _selectedDay = null;
                    _selectedPeriod = null;
                  });
                },
                child: Text(
                  "重設",
                  style: TextStyle(
                    color: colorScheme.subtitleText,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _showInlineSearchPanel = false;
                  });
                  _performSearch();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                  minimumSize: const Size(60, 32),
                ),
                child: const Text(
                  "開始查詢",
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- 搜尋結果 (支援緊湊模式與 12px 側邊距對齊) ---
  Widget _buildSearchResults() {
    final colorScheme = Theme.of(context).colorScheme;
    if (_isQueryLoading)
      return const Center(child: CircularProgressIndicator());
    if (!_hasSearched) {
      return Center(
        child: Text(
          "請點擊「搜尋課程」開始",
          style: TextStyle(color: colorScheme.subtitleText),
        ),
      );
    }
    if (_searchResults.isEmpty) return const Center(child: Text("找不到符合條件的課程"));

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final course = _searchResults[index];
        // 檢查是否已經在待加選清單中，或已經是正式課表裡的已選/登記課程
        bool isAdded =
            _pendingAdds.any((p) => p.courseData.id == course.id) ||
            _pendingItems.any((p) => p.id == course.id) ||
            _isCourseAlreadySelected(course.id);

        return Card(
          elevation: 2,
          margin: EdgeInsets.only(bottom: widget.isCompact ? 8 : 12),
          clipBehavior: Clip.antiAlias, // 讓展開動畫更滑順
          child: Theme(
            // 消除 ExpansionTile 上下預設的邊框線
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: widget.isCompact
                  ? const EdgeInsets.symmetric(horizontal: 12, vertical: 4)
                  : const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              // 標題：課名
              title: Text(
                course.name.split('\n')[0],
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: widget.isCompact ? 14 : 16,
                  color: colorScheme.primaryText,
                ),
              ),
              // 副標題：老師 / 代號
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.person,
                        size: widget.isCompact ? 12 : 14,
                        color: colorScheme.subtitleText,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          course.teacher,
                          style: TextStyle(
                            color: colorScheme.bodyText,
                            fontSize: widget.isCompact ? 12 : 13,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      SizedBox(width: widget.isCompact ? 8 : 12),
                      Container(
                        padding: widget.isCompact
                            ? const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 1,
                              )
                            : const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                        decoration: BoxDecoration(
                          color: colorScheme.secondaryCardBackground,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          course.id,
                          style: TextStyle(
                            fontSize: widget.isCompact ? 11 : 12,
                            color: colorScheme.subtitleText,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              // 右側按鈕：加選 (獨立運作，不會觸發展開)
              trailing: isAdded
                  ? Icon(
                      Icons.check_circle,
                      color: Colors.green,
                      size: widget.isCompact ? 28 : 32,
                    )
                  : ElevatedButton(
                      onPressed: () => _addToPendingList(course),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colorScheme.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: widget.isCompact
                            ? const EdgeInsets.symmetric(horizontal: 8)
                            : const EdgeInsets.symmetric(horizontal: 12),
                        minimumSize: widget.isCompact
                            ? const Size(50, 28)
                            : const Size(60, 32),
                      ),
                      child: Text(
                        "加選",
                        style: TextStyle(fontSize: widget.isCompact ? 12 : 14),
                      ),
                    ),

              // --- 展開後的詳細內容 ---
              children: [
                Divider(
                  height: 1,
                  thickness: 1,
                  color: colorScheme.borderColor,
                ),
                Container(
                  color: colorScheme.isDark
                      ? colorScheme.secondaryCardBackground
                      : Colors.blue[50]!.withOpacity(0.3), // 微微的背景色區分
                  padding: widget.isCompact
                      ? const EdgeInsets.symmetric(horizontal: 12, vertical: 10)
                      : const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 16,
                        ),
                  child: Column(
                    children: [
                      // 第一排資訊
                      Row(
                        children: [
                          Expanded(
                            child: _buildDetailRow(
                              Icons.school,
                              "系所",
                              course.department,
                            ),
                          ),
                          Expanded(
                            child: _buildDetailRow(
                              Icons.grade,
                              "學分",
                              course.credit,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: widget.isCompact ? 8 : 12),
                      // 第二排資訊
                      Row(
                        children: [
                          Expanded(
                            child: _buildDetailRow(
                              Icons.class_,
                              "班級",
                              "${course.grade}年級 ${course.className}",
                            ),
                          ),
                          Expanded(
                            child: _buildDetailRow(
                              Icons.room,
                              "教室",
                              _parseRoomLocation(course.room),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: widget.isCompact ? 12 : 16),
                      // 時間表顯示
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          "上課時間表",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.subtitleText,
                            fontSize: widget.isCompact ? 12 : 13,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildTimeDisplay(course.classTime),

                      // ✅ 評分方式區塊
                      SizedBox(height: widget.isCompact ? 12 : 16),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          "評分方式",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.subtitleText,
                            fontSize: widget.isCompact ? 12 : 13,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),

                      // 使用 FutureBuilder 動態載入
                      Align(
                        alignment: Alignment.centerLeft,
                        child: FutureBuilder<List<String>>(
                          future: _getCourseEvaluation(course.id),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const Padding(
                                padding: EdgeInsets.all(8.0),
                                child: SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              );
                            }
                            if (snapshot.hasError ||
                                !snapshot.hasData ||
                                snapshot.data!.isEmpty) {
                              return Text(
                                "無法取得評分資料",
                                style: TextStyle(
                                  color: colorScheme.subtitleText,
                                  fontSize: 13,
                                ),
                              );
                            }
                            // 渲染抓取到的評分清單
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: snapshot.data!
                                  .map(
                                    (e) => Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 6.0,
                                      ),
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Text(
                                              e,
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: colorScheme.primaryText,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  )
                                  .toList(),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // --- 輔劇方法 1: 顯示詳細資訊的小列 ---
  Widget _buildDetailRow(IconData icon, String label, String value) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: colorScheme.subtitleText),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 11, color: colorScheme.subtitleText),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: colorScheme.primaryText,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // --- 輔助方法 2: 視覺化時間表 ---
  Widget _buildTimeDisplay(List<String> times) {
    final colorScheme = Theme.of(context).colorScheme;
    final days = ["一", "二", "三", "四", "五", "六", "日"];
    List<Widget> timeWidgets = [];

    for (int i = 0; i < times.length && i < 7; i++) {
      if (times[i].isNotEmpty) {
        timeWidgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.isDark
                        ? const Color(0xFF1E2D4A)
                        : Colors.blue[100],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    "星期${days[i]}",
                    style: TextStyle(
                      color: colorScheme.isDark
                          ? const Color(0xFF90CAF9)
                          : Colors.blue[900],
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  "第 ${times[i]} 節",
                  style: TextStyle(
                    fontSize: 14,
                    color: colorScheme.primaryText,
                  ),
                ),
              ],
            ),
          ),
        );
      }
    }

    if (timeWidgets.isEmpty) {
      return Text("無時間資訊", style: TextStyle(color: colorScheme.subtitleText));
    }

    return Column(children: timeWidgets);
  }

  // --- 編輯清單 (購物車) ---
  Widget _buildEditListMode() {
    final colorScheme = Theme.of(context).colorScheme;
    // 扣除掉「待退選」的，計算目前還在系統上的課程
    final activeExistingCourses = widget.currentCourses.where((c) {
      // 1. 如果已經在「待退選」清單中，就不顯示在已選列表
      if (_pendingItems.any(
        (p) => p.id == c.courseNo && p.type == TransactionType.drop,
      )) {
        return false;
      }

      // 2. 狀態過濾：只顯示符合特定關鍵字的狀態
      // 邏輯：如果包含 "選上" (含已選上)、 "登記" 或 "加選"，則保留；否則隱藏。
      bool isSelected = (c.status.contains("選上")) && !c.status.contains("未選上");
      bool isRegistered = c.status.contains("登記") || c.status.contains("加選");

      return isSelected || isRegistered;
    }).toList();

    int totalCount = activeExistingCourses.length + _pendingItems.length;
    if (totalCount == 0) return const Center(child: Text("清單是空的"));

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            children: [
              // 1. 待送出清單
              if (_pendingItems.isNotEmpty) ...[
                Padding(
                  padding: EdgeInsets.symmetric(
                    vertical: widget.isCompact ? 4.0 : 8.0,
                  ),
                  child: Text(
                    "待送出項目 (請確認後送出)",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: widget.isCompact ? 13 : 14,
                      color: colorScheme.isDark
                          ? const Color(0xFFFFA726)
                          : Colors.deepOrange,
                    ),
                  ),
                ),
                ..._pendingItems.map((item) {
                  bool isAdd = item.type == TransactionType.add;
                  Color mainColor = isAdd ? Colors.orange : Colors.red;
                  Color lightColor = isAdd
                      ? const Color(0xFFFFB74D)
                      : const Color(0xFFEF5350);
                  String tagText = isAdd ? "加選" : "退選";

                  return Card(
                    color: colorScheme.cardBackground,
                    elevation: 1,
                    margin: EdgeInsets.only(bottom: widget.isCompact ? 8 : 10),
                    clipBehavior: Clip.antiAlias,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: colorScheme.borderColor,
                        width: 1,
                      ),
                    ),
                    child: IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // 左側漸層色條
                          Container(
                            width: 6,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [lightColor, mainColor],
                              ),
                            ),
                          ),
                          // 主體
                          Expanded(
                            child: Padding(
                              padding: EdgeInsets.fromLTRB(
                                widget.isCompact ? 10 : 14,
                                widget.isCompact ? 9 : 11,
                                widget.isCompact ? 4 : 6,
                                widget.isCompact ? 9 : 11,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      // 課名 + 標籤 + 課號
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              item.name,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: widget.isCompact
                                                    ? 14
                                                    : 15,
                                                fontWeight: FontWeight.bold,
                                                color: colorScheme.primaryText,
                                              ),
                                            ),
                                            const SizedBox(height: 3),
                                            Row(
                                              children: [
                                                Container(
                                                  padding: EdgeInsets.symmetric(
                                                    horizontal: widget.isCompact
                                                        ? 6
                                                        : 7,
                                                    vertical: 1.5,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: mainColor,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          999,
                                                        ),
                                                  ),
                                                  child: Text(
                                                    tagText,
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 10,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 6),
                                                Flexible(
                                                  child: Text(
                                                    item.id,
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: TextStyle(
                                                      fontSize: 11.5,
                                                      color: colorScheme
                                                          .subtitleText,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      // 志願輸入 (僅加選)
                                      if (isAdd &&
                                          item.pointsController != null) ...[
                                        const SizedBox(width: 8),
                                        Column(
                                          mainAxisSize: MainAxisSize.min,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.center,
                                          children: [
                                            SizedBox(
                                              width: widget.isCompact ? 48 : 54,
                                              height: widget.isCompact
                                                  ? 26
                                                  : 28,
                                              child: TextField(
                                                controller:
                                                    item.pointsController,
                                                keyboardType:
                                                    TextInputType.number,
                                                textAlign: TextAlign.center,
                                                textAlignVertical:
                                                    TextAlignVertical.center,
                                                style: TextStyle(
                                                  fontSize: widget.isCompact
                                                      ? 12
                                                      : 13,
                                                  fontWeight: FontWeight.bold,
                                                  color: mainColor,
                                                ),
                                                decoration: InputDecoration(
                                                  isCollapsed: true,
                                                  contentPadding:
                                                      EdgeInsets.symmetric(
                                                        vertical:
                                                            widget.isCompact
                                                            ? 5
                                                            : 6,
                                                      ),
                                                  enabledBorder:
                                                      OutlineInputBorder(
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              8,
                                                            ),
                                                        borderSide: BorderSide(
                                                          color: colorScheme
                                                              .borderColor,
                                                        ),
                                                      ),
                                                  focusedBorder:
                                                      OutlineInputBorder(
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              8,
                                                            ),
                                                        borderSide: BorderSide(
                                                          color: mainColor,
                                                          width: 1.5,
                                                        ),
                                                      ),
                                                  hintText: "0",
                                                  hintStyle: TextStyle(
                                                    fontSize: widget.isCompact
                                                        ? 11
                                                        : 12,
                                                    color: colorScheme
                                                        .subtitleText,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(height: 3),
                                            Text(
                                              "志願/點數",
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: colorScheme.subtitleText,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ],
                                  ),
                                  if (!isAdd)
                                    Padding(
                                      padding: EdgeInsets.only(
                                        top: widget.isCompact ? 6 : 8,
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.warning_amber_rounded,
                                            size: widget.isCompact ? 13 : 14,
                                            color: colorScheme.isDark
                                                ? Colors.red[300]
                                                : Colors.red[700],
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            "此課程將被退選",
                                            style: TextStyle(
                                              color: colorScheme.isDark
                                                  ? Colors.red[300]
                                                  : Colors.red[700],
                                              fontSize: widget.isCompact
                                                  ? 11
                                                  : 12,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                          // 移除鈕
                          Align(
                            alignment: Alignment.center,
                            child: TextButton(
                              onPressed: () => _confirmRemovePendingItem(item),
                              style: TextButton.styleFrom(
                                foregroundColor: colorScheme.subtitleText,
                                padding: EdgeInsets.symmetric(
                                  horizontal: widget.isCompact ? 8 : 10,
                                  vertical: 6,
                                ),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: Text(
                                "移除",
                                style: TextStyle(
                                  fontSize: widget.isCompact ? 12 : 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ],

              // 2. 已選課程
              if (activeExistingCourses.isNotEmpty) ...[
                SizedBox(height: widget.isCompact ? 8 : 16),
                Padding(
                  padding: EdgeInsets.symmetric(
                    vertical: widget.isCompact ? 4.0 : 8.0,
                  ),
                  child: Text(
                    "目前已選課程",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: widget.isCompact ? 13 : 14,
                      color: colorScheme.subtitleText,
                    ),
                  ),
                ),
                ...activeExistingCourses.map((course) {
                  Color statusColor = Colors.grey;
                  String displayStatus = course.status;

                  if (course.status.contains("選上")) {
                    statusColor = Colors.green;
                  } else if (course.status.contains("登記") ||
                      course.status.contains("加選")) {
                    statusColor = Colors.lightBlue;
                    displayStatus = "登記加選";
                  }

                  return Card(
                    color: colorScheme.cardBackground,
                    elevation: 1,
                    margin: EdgeInsets.only(bottom: widget.isCompact ? 6 : 8),
                    child: Padding(
                      padding: widget.isCompact
                          ? const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 6,
                            )
                          : const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                      child: Row(
                        children: [
                          Container(
                            width: 4,
                            height: widget.isCompact ? 30 : 40,
                            color: statusColor,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      displayStatus,
                                      style: TextStyle(
                                        color: statusColor,
                                        fontWeight: FontWeight.bold,
                                        fontSize: widget.isCompact ? 12 : 13,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      course.courseNo,
                                      style: TextStyle(
                                        color: colorScheme.subtitleText,
                                        fontSize: widget.isCompact ? 11 : 12,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  course.name,
                                  style: TextStyle(
                                    fontSize: widget.isCompact ? 13 : 15,
                                    color: colorScheme.primaryText,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          TextButton(
                            onPressed: () => _confirmDropCourse(course),
                            style: TextButton.styleFrom(
                              foregroundColor: colorScheme.isDark
                                  ? Colors.red[300]
                                  : Colors.red[600],
                              padding: widget.isCompact
                                  ? EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    )
                                  : null,
                              minimumSize: widget.isCompact
                                  ? const Size(40, 30)
                                  : null,
                            ),
                            child: Text(
                              "退選",
                              style: TextStyle(
                                fontSize: widget.isCompact ? 12 : 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ],
            ],
          ),
        ),

        // 送出按鈕
        if (_pendingItems.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colorScheme.cardBackground,
              boxShadow: [
                BoxShadow(
                  color: colorScheme.isDark
                      ? Colors.black38
                      : Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: SafeArea(
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _submitSelection,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorScheme.isDark
                        ? colorScheme.primary
                        : Colors.blue[800],
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    "送出 (${_pendingItems.length} 筆更動)",
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  // --- 邏輯 Methods (加入, 搜尋, 送出) ---

  // 檢查課程是否已經在正式課表中（已選上或登記加選），
  // 用來避免使用者把已選/已登記的課程再次加入待加選清單，造成「課程加選第兩次」。
  // 比對邏輯與 _buildEditListMode 的 activeExistingCourses 一致。
  bool _isCourseAlreadySelected(String courseId) {
    return widget.currentCourses.any((c) {
      if (c.courseNo != courseId) return false;
      bool isSelected = c.status.contains("選上") && !c.status.contains("未選上");
      bool isRegistered = c.status.contains("登記") || c.status.contains("加選");
      return isSelected || isRegistered;
    });
  }

  void _addToPendingList(CourseJsonData course) {
    if (_pendingItems.length >= 15) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("已達到選課清單上限 (15門)"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    // 檢查是否重複
    if (_pendingItems.any((item) => item.id == course.id)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("已在選單中"), backgroundColor: Colors.orange),
      );
      return;
    }

    // 檢查是否已經在正式課表中（已選上或登記加選），避免重複加選造成「課程加選第兩次」
    if (_isCourseAlreadySelected(course.id)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("此課程已選上或登記加選，無法重複加選"),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      final controller = TextEditingController();
      controller.addListener(() => _saveCart()); // 當點數修改時存檔
      _pendingItems.add(
        PendingTransaction(
          id: course.id,
          name: course.name.split('\n')[0],
          type: TransactionType.add,
          originalData: course,
          pointsController: controller,
        ),
      );
      _saveCart();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("已加入待送出清單：${course.name.split('\n')[0]}"),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _confirmRemovePendingItem(PendingTransaction item) {
    // 加選項目移除前需使用者確認，避免誤刪已填好的志願/點數
    if (item.type == TransactionType.add) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("確認移除"),
          content: Text("確定要將「${item.name}」從待加選清單中移除嗎？"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("取消"),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _removePendingItem(item);
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text("移除"),
            ),
          ],
        ),
      );
    } else {
      _removePendingItem(item);
    }
  }

  void _removePendingItem(PendingTransaction item) {
    setState(() {
      _pendingItems.remove(item);
      item.pointsController?.dispose();
      _saveCart();
    });
  }

  void _confirmDropCourse(CourseSelectionData course) {
    // 檢查是否已經在退選中
    if (_pendingItems.any((item) => item.id == course.code)) {
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("確認退選項目"),
        content: Text("您確定要將「${course.name}」加入退選名單嗎？\n(將在點擊送出後一併送至選課系統)"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("取消"),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _pendingItems.add(
                  PendingTransaction(
                    id: course.courseNo,
                    name: course.name,
                    type: TransactionType.drop,
                  ),
                );
                _saveCart();
              });
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text("加入退選名單"),
          ),
        ],
      ),
    );
  }

  void _submitSelection() {
    List<String> logs = _pendingItems.map((item) {
      if (item.type == TransactionType.add) {
        String pts = item.pointsController?.text.trim() ?? "";
        return "[加選] ${item.name} (點數/志願: ${pts.isEmpty ? '0' : pts})";
      } else {
        return "[退選] ${item.name}";
      }
    }).toList();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text("確認送出選課結果"),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("即將執行 ${logs.length} 項操作：\n"),
              ...logs.map(
                (l) => Text(
                  l,
                  style: TextStyle(
                    color: l.startsWith("[退選]") ? Colors.red : Colors.blue[800],
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                "注意：送出過程可能需要幾秒鐘。",
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text("取消"),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              _processSubmission();
            },
            child: const Text(
              "確定送出",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _processSubmission() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (loadingContext) =>
          const Center(child: CircularProgressIndicator()),
    );

    try {
      List<submit_service.PendingTransaction> serviceItems = _pendingItems.map((
        uiItem,
      ) {
        return submit_service.PendingTransaction(
          id: uiItem.id,
          name: uiItem.name,
          type: uiItem.type == TransactionType.add
              ? submit_service.TransactionType.add
              : submit_service.TransactionType.drop,
          points: uiItem.pointsController?.text.trim() ?? "",
        );
      }).toList();

      final result = await submit_service.CourseSelectionSubmitService.instance
          .submitTransactions(serviceItems);

      if (!mounted) return;
      Navigator.pop(context); // 關閉 Loading

      if (result.success == false && result.failures.isNotEmpty) {
        _showFailureDialog(result.failures);
      } else if (result.success == true) {
        _showSuccessDialog();
      } else {
        _showErrorDialog(result.message);
      }

      setState(() {
        for (var p in _pendingItems) p.pointsController?.dispose();
        _pendingItems.clear();
        _showEditListMode = false;
        _saveCart(); // ✅ 送出成功清空後，存檔把快取也清空
      });

      // 通知父層重整課表
      widget.onRequestRefresh();
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      _showErrorDialog(e.toString());
    }
  }

  // --- Dialog Helpers ---
  void _showFailureDialog(List<submit_service.FailedCourse> failures) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("⚠️ 加退選部分失敗", style: TextStyle(color: Colors.red)),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: failures.length,
            itemBuilder: (context, index) {
              final f = failures[index];
              return ListTile(
                leading: const Icon(Icons.error_outline, color: Colors.red),
                title: Text(f.courseName),
                subtitle: Text("原因：${f.reason}"),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("我知道了"),
          ),
        ],
      ),
    );
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 8),
            Text("請求已送出"),
          ],
        ),
        content: const Text(
          "加退選請求已成功送至系統。\n\n⚠️ 重要提示：\n系統狀態可能會有延遲，請務必稍後使用「電腦開啟學校網站」再次確認您的課表。",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("好，我會確認"),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("❌ 送出失敗"),
        content: Text("發生錯誤：\n$message"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("確定"),
          ),
        ],
      ),
    );
  }

  // --- 搜尋條件 Sheet (省略部分 UI 程式碼，邏輯與原版相同，僅需確保呼叫 _performSearch) ---
  void _showSearchSheet() {
    final colorScheme = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // 讓鍵盤彈出時不會遮擋
      backgroundColor: colorScheme.cardBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            void updateState(VoidCallback fn) {
              setModalState(fn);
              setState(fn);
            }

            return DraggableScrollableSheet(
              initialChildSize: 0.85,
              minChildSize: 0.5,
              maxChildSize: 0.95,
              expand: false,
              builder: (context, scrollController) {
                return SingleChildScrollView(
                  controller: scrollController,
                  padding: EdgeInsets.only(
                    left: 20,
                    right: 20,
                    top: 20,
                    bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Text(
                          "課程查詢條件",
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: colorScheme.primaryText,
                              ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      Row(
                        children: [
                          Expanded(
                            child: _isSemesterLoading
                                ? const Center(
                                    child: SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    ),
                                  )
                                : _buildDropdown(
                                    label: "學期",
                                    value: _selectedSemester ?? "",
                                    items: _semesterOptions,
                                    displayMap: _semesterDisplayMap,
                                    onChanged: (v) => updateState(
                                      () => _selectedSemester = v,
                                    ),
                                  ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildTextField("課程名稱", _crsNameCtrl),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField("授課教師", _teacherCtrl),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildTextField(
                              "開課系所",
                              _deptCtrl,
                              hint: "例如: 資工",
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // 3. 年級 & 班級
                      Row(
                        children: [
                          Expanded(
                            child: _buildDropdown(
                              label: "年級 (D2)",
                              value: _selectedGrade ?? "",
                              items: const ["", "1", "2", "3", "4", "5"],
                              displayMap: const {
                                "": "全部",
                                "1": "一年級",
                                "2": "二年級",
                                "3": "三年級",
                                "4": "四年級",
                                "5": "五年級",
                              },
                              onChanged: (v) => updateState(
                                () => _selectedGrade = (v == null || v.isEmpty)
                                    ? null
                                    : v,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildDropdown(
                              label: "班級 (CLASS)",
                              value: _selectedClass ?? "",
                              items: const ["", "0", "1", "2", "5"],
                              displayMap: const {
                                "": "全部",
                                "0": "不分班",
                                "1": "甲班",
                                "2": "乙班",
                                "5": "全英班",
                              },
                              onChanged: (v) => updateState(
                                () => _selectedClass = (v == null || v.isEmpty)
                                    ? null
                                    : v,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // 4. 時間 (星期 & 節次)
                      Text(
                        "上課時間",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.subtitleText,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                            child: _buildDropdown(
                              label: "星期",
                              value: _selectedDay ?? "",
                              items: const [
                                "",
                                "1",
                                "2",
                                "3",
                                "4",
                                "5",
                                "6",
                                "7",
                              ],
                              displayMap: const {
                                "": "不限",
                                "1": "星期一",
                                "2": "星期二",
                                "3": "星期三",
                                "4": "星期四",
                                "5": "星期五",
                                "6": "星期六",
                                "7": "星期日",
                              },
                              onChanged: (v) => updateState(
                                () => _selectedDay = (v == null || v.isEmpty)
                                    ? null
                                    : v,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildDropdown(
                              label: "節次",
                              value: _selectedPeriod ?? "",
                              items: const [
                                "",
                                "A",
                                "1",
                                "2",
                                "3",
                                "4",
                                "B",
                                "5",
                                "6",
                                "7",
                                "8",
                                "9",
                                "C",
                              ],
                              displayMap: const {
                                "": "不限",
                                "A": "A (07:00)",
                                "1": "1 (08:10)",
                                "2": "2 (09:10)",
                                "3": "3 (10:10)",
                                "4": "4 (11:10)",
                                "B": "B (12:10)",
                                "5": "5 (13:10)",
                                "6": "6 (14:10)",
                                "7": "7 (15:10)",
                                "8": "8 (16:10)",
                                "9": "9 (17:10)",
                                "C": "C (18:20)",
                              },
                              onChanged: (v) => updateState(
                                () => _selectedPeriod = (v == null || v.isEmpty)
                                    ? null
                                    : v,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 30),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context); // 關閉 Sheet
                            _performSearch();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: colorScheme.primary,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text(
                            "開始查詢",
                            style: TextStyle(fontSize: 18),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Center(
                        child: TextButton(
                          onPressed: () {
                            updateState(() {
                              _crsNameCtrl.clear();
                              _teacherCtrl.clear();
                              _codeCtrl.clear();
                              _deptCtrl.clear();
                              _selectedGrade = null;
                              _selectedClass = null;
                              _selectedDay = null;
                              _selectedPeriod = null;
                            });
                            Navigator.pop(context);
                          },
                          child: Text(
                            "重設條件",
                            style: TextStyle(color: colorScheme.subtitleText),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Future<void> _performSearch() async {
    setState(() {
      _isQueryLoading = true;
      _hasSearched = true;
      _showImportMode = false;
      _showEditListMode = false;
    });
    try {
      // 確保資料已經透過 API 下載完畢 (配合學期選擇)
      await CourseQueryService.instance.getCourses(semester: _selectedSemester);

      String? classText;
      if (_selectedClass == "0") classText = "不分班";
      if (_selectedClass == "1") classText = "甲班";
      if (_selectedClass == "2") classText = "乙班";

      final results = CourseQueryService.instance.search(
        keyword: _crsNameCtrl.text.trim(),
        teacher: _teacherCtrl.text.trim(),
        code: _codeCtrl.text.trim(),
        grade: _selectedGrade,
        classType: classText,
        day: _selectedDay,
        period: _selectedPeriod,
        dept: _deptCtrl.text.trim(),
      );

      setState(() {
        _searchResults = results;
        _isQueryLoading = false;
      });
    } catch (e) {
      setState(() => _isQueryLoading = false);
    }
  }

  void _clearSearchFields() {
    _crsNameCtrl.clear();
    _teacherCtrl.clear();
    _codeCtrl.clear();
    _deptCtrl.clear();
    setState(() {
      _selectedGrade = null;
      _selectedClass = null;
      _selectedDay = null;
      _selectedPeriod = null;
    });
    Navigator.pop(context);
  }

  // 使用 GlassSingleSelectDropdown 的統一下拉選單建構器
  Widget _buildDropdown({
    required String label,
    required String value,
    required List<String> items,
    Map<String, String>? displayMap,
    required ValueChanged<String?> onChanged,
  }) {
    return GlassSingleSelectDropdown(
      label: label,
      items: items,
      value: value,
      displayMap: displayMap,
      onChanged: onChanged,
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller, {
    String? hint,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.bold,
            fontSize: 12,
            color: colorScheme.subtitleText,
          ),
        ),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: colorScheme.primaryText),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: colorScheme.subtitleText),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 8,
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            isDense: true,
            filled: true,
            fillColor: colorScheme.subtleBackground,
          ),
        ),
      ],
    );
  }

  // --- 輔助方法: 處理教室字串 (只顯示括號內容) ---
  String _parseRoomLocation(String rawRoom) {
    if (rawRoom.isEmpty) return "不明";

    // 使用正則表達式抓取 ( ) 或 （ ） 裡面的內容
    // 支援半形 () 與全形 （）
    final RegExp regex = RegExp(r'[(\uff08]([^)\uff09]*)[)\uff09]');
    final match = regex.firstMatch(rawRoom);

    if (match != null) {
      String content = match.group(1)?.trim() ?? "";
      // 如果括號內有東西，就回傳內容；如果是空的 (例如 "()")，就回傳不明
      return content.isNotEmpty ? content : "不明";
    }

    // 如果完全沒有括號
    return "不明";
  }

  bool _isCheckingExport = false; // 防止重複觸發檢查

  // ✅ 新增：自動檢查並匯入助手傳來的課程
  Future<void> _checkExportedCourses() async {
    if (_isCheckingExport) return;
    _isCheckingExport = true;

    try {
      final prefs = await SharedPreferences.getInstance();
      List<String>? exportedIds = prefs.getStringList('exported_course_ids');

      // 如果沒有需要匯入的資料，直接結束
      if (exportedIds == null || exportedIds.isEmpty) {
        _isCheckingExport = false;
        return;
      }

      // 💡 立即移除 Key，確保同一批資料絕對不會被匯入第二次
      await prefs.remove('exported_course_ids');

      // 確保搜尋用的課程總表已經載入
      await CourseQueryService.instance.getCourses();

      int successCount = 0;
      int duplicateCount = 0;

      for (String id in exportedIds) {
        // 1. 檢查是否已經在購物車裡 (包含待加選、待退選)
        if (_pendingItems.any((p) => p.id == id) ||
            _pendingAdds.any((p) => p.courseData.id == id)) {
          duplicateCount++;
          continue;
        }
        // 2. 檢查是否已經選上或登記了 (正式課表)
        if (widget.currentCourses.any((c) => c.courseNo == id)) {
          duplicateCount++;
          continue;
        }

        // 3. 搜尋這門課的詳細資料
        final results = CourseQueryService.instance.search(code: id);
        if (results.isNotEmpty) {
          final course = results.first;
          final controller = TextEditingController();
          // ✅ 加上監聽器，打字時自動存檔
          controller.addListener(() {
            _saveCart();
          });
          // 加入購物車 (編輯選單)
          _pendingItems.add(
            PendingTransaction(
              id: course.id,
              name: course.name.split('\n')[0],
              type: TransactionType.add,
              originalData: course,
              pointsController: controller,
            ),
          );
          successCount++;
        }
      }

      // 如果有匯入任何東西，觸發畫面重繪並顯示提示
      if (successCount > 0 || duplicateCount > 0) {
        if (mounted) {
          setState(() {
            _showEditListMode = true; // 自動幫使用者切換到「編輯選單」分頁讓他看
          });
          _saveCart();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                "已從助手匯入 $successCount 門課程至購物車" +
                    (duplicateCount > 0 ? " (跳過 $duplicateCount 門重複課程)" : ""),
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint("自動匯入失敗: $e");
    } finally {
      _isCheckingExport = false;
    }
  }

  // ✅ 儲存購物車到快取
  // ✅ 儲存購物車到快取
  Future<void> _saveCart() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // 使用 ?.text ?? "" 來避免 pointsController 為 null 時發生錯誤
      List<Map<String, dynamic>> cartData = _pendingItems
          .map(
            (item) => {
              'id': item.id,
              'points': item.pointsController?.text ?? "",
            },
          )
          .toList();
      await prefs.setString('saved_shopping_cart', jsonEncode(cartData));
    } catch (e) {
      debugPrint("儲存購物車失敗: $e");
    }
  }

  // ✅ 從快取讀取購物車
  Future<void> _loadCartFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? jsonStr = prefs.getString('saved_shopping_cart');
      if (jsonStr == null || jsonStr.isEmpty) return;

      List<dynamic> decoded = jsonDecode(jsonStr);
      await CourseQueryService.instance.getCourses(); // 確保課程總表已載入以便搜尋

      for (var data in decoded) {
        String id = data['id'];
        String points = data['points'] ?? "";

        // 避免重複加入
        if (_pendingItems.any((item) => item.id == id)) continue;
        if (widget.currentCourses.any((c) => c.courseNo == id)) continue;

        // 透過 ID 找回這門課的詳細資料
        final results = CourseQueryService.instance.search(code: id);
        if (results.isNotEmpty) {
          final course = results.first;

          final controller = TextEditingController(text: points);
          // 當使用者修改點數時，自動觸發儲存，這樣才不會漏存點數
          controller.addListener(() {
            _saveCart();
          });

          setState(() {
            _pendingItems.add(
              PendingTransaction(
                id: course.id,
                name: course.name.split('\n')[0],
                type: TransactionType.add,
                originalData: course,
                pointsController: controller,
              ),
            );
            _saveCart();
          });
        }
      }
    } catch (e) {
      debugPrint("讀取購物車失敗: $e");
    }
  }

  // ✅ 新增：用來快取已經抓過的評分資料，避免重複請求
  final Map<String, List<String>> _evaluationCache = {};

  // ✅ 新增：抓取並解析課綱評分方式
  Future<List<String>> _getCourseEvaluation(String courseId) async {
    // 1. 如果已經抓過，直接回傳快取
    if (_evaluationCache.containsKey(courseId)) {
      return _evaluationCache[courseId]!;
    }

    final semStr = CourseQueryService.instance.currentSemester;
    if (semStr.length != 4) return ["無法取得學期資訊"];

    final syear = semStr.substring(0, 3); // 前三碼 (114)
    final sem = semStr.substring(3, 4); // 最後一碼 (2)
    final url = Uri.parse(
      'https://selcrs.nsysu.edu.tw/menu5/showoutline.asp?SYEAR=$syear&SEM=$sem&CrsDat=$courseId',
    );

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        // ⚠️ 注意：中山舊系統通常是 Big5 編碼。如果遇到純中文亂碼，可能需要引入 cp950 套件。
        // 這裡先用 allowMalformed: true 避免報錯，英文與數字能正常顯示
        String html = utf8.decode(response.bodyBytes, allowMalformed: true);

        // 利用正規表達式抓取 <span id=SS4_X1>項目</span>：<span id=SS4_X2>比例</span>
        final RegExp exp = RegExp(
          r'SS4_\d+1[^>]*>([^<]*)</span>[^<]*<span[^>]*SS4_\d+2[^>]*>([^<]*)</span>',
          caseSensitive: false,
        );

        final matches = exp.allMatches(html);
        List<String> evals = [];
        int index = 1;

        for (var match in matches) {
          // group(1) 會對應第一個 ([^<]*) -> 項目
          String item = match.group(1)?.trim() ?? "";
          // group(2) 會對應第二個 ([^<]*) -> 比例
          String pct = match.group(2)?.trim() ?? "";

          if (item.isNotEmpty) {
            evals.add('$index. $item：${pct.isNotEmpty ? pct : "0"}%');
            index++;
          }
        }

        if (evals.isEmpty) evals.add("尚無評分方式資料");

        _evaluationCache[courseId] = evals; // 存入快取
        return evals;
      }
    } catch (e) {
      return ["載入失敗，請稍後再試"];
    }
    return ["查無資料"];
  }

  // --- 實作行內「匯入選課」功能與 UI ---

  Widget _buildImportView() {
    final colorScheme = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline, color: colorScheme.primary),
                    const SizedBox(width: 8),
                    Text(
                      "匯入說明",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  "請至「中山選課小幫手網頁版」匯出加選課程，將產生的完整 JavaScript 程式碼複製並貼在下方欄位中。",
                  style: TextStyle(color: colorScheme.onPrimaryContainer),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (_isSemesterLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0),
              child: Center(
                child: SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else if (_semesterOptions.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: GlassSingleSelectDropdown(
                label: "選擇學期",
                value: _selectedSemester ?? "",
                items: _semesterOptions,
                displayMap: _semesterDisplayMap,
                onChanged: (v) {
                  setState(() {
                    _selectedSemester = v;
                  });
                },
              ),
            ),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "程式碼內容：",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.primaryText,
                ),
              ),
              TextButton.icon(
                onPressed: _pasteFromClipboard,
                icon: const Icon(Icons.paste, size: 18),
                label: const Text("剪貼簿貼上"),
                style: TextButton.styleFrom(
                  foregroundColor: colorScheme.primary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
              ),
            ],
          ),
          TextField(
            controller: _importTextCtrl,
            maxLines: 10,
            minLines: 5,
            textAlignVertical: TextAlignVertical.top,
            style: TextStyle(color: colorScheme.primaryText),
            decoration: InputDecoration(
              hintText: "貼上從選課小幫手複製的程式碼...",
              hintStyle: TextStyle(color: colorScheme.subtitleText),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              filled: true,
              fillColor: colorScheme.subtleBackground,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _isImporting ? null : _processImport,
              icon: _isImporting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.download),
              label: Text(
                _isImporting ? "正在搜尋並匯入..." : "開始匯入",
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: colorScheme.primary,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pasteFromClipboard() async {
    ClipboardData? data = await Clipboard.getData(Clipboard.kTextPlain);

    if (data != null && data.text != null && data.text!.isNotEmpty) {
      setState(() {
        _importTextCtrl.text = data.text!;
      });
    } else {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("剪貼簿內沒有文字！")));
      }
    }
  }

  Future<void> _processImport() async {
    final String input = _importTextCtrl.text;
    if (input.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("請先貼上程式碼！")));
      return;
    }

    setState(() => _isImporting = true);

    try {
      // 1. 利用 Regex 擷取 exportClass 後面的 JSON 陣列
      final regex = RegExp(r'exportClass\s*=\s*(\[.*?\]);', dotAll: true);
      final match = regex.firstMatch(input);

      if (match == null) {
        throw FormatException("找不到有效的 exportClass 資料，請確認貼上的程式碼是否正確。");
      }

      String jsonString = match.group(1)!;
      List<dynamic> parsedJson = jsonDecode(jsonString);

      // 取出所有要匯入的課號
      List<String> idsToImport = parsedJson
          .map((e) => e['id'].toString())
          .toList();

      int successCount = 0;
      int skipCount = 0;
      List<String> failIds = [];

      // 2. 確保資料已經載入
      await CourseQueryService.instance.getCourses(semester: _selectedSemester);

      for (String id in idsToImport) {
        // 如果已經在購物車或已選課表裡就跳過
        bool inCart = _pendingItems.any((item) => item.id == id);
        bool inSelectedTable = widget.currentCourses.any(
          (c) => c.courseNo == id,
        );

        if (inCart || inSelectedTable) {
          skipCount++;
          continue;
        }

        // 搜尋課程代碼
        List<CourseJsonData> results = CourseQueryService.instance.search(
          code: id,
        );

        if (results.isNotEmpty) {
          final course = results.first;
          final controller = TextEditingController();
          controller.addListener(() => _saveCart());

          setState(() {
            _pendingItems.add(
              PendingTransaction(
                id: course.id,
                name: course.name.split('\n')[0],
                type: TransactionType.add,
                originalData: course,
                pointsController: controller,
              ),
            );
          });
          successCount++;
        } else {
          failIds.add(id);
        }
      }

      // 3. 儲存購物車到快取
      if (successCount > 0) {
        await _saveCart();
      }

      // 4. 顯示結果並返回
      if (mounted) {
        _showImportResultDialog(successCount, skipCount, failIds);
      }
    } catch (e) {
      if (mounted) {
        final colorScheme = Theme.of(context).colorScheme;
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: colorScheme.cardBackground,
            title: Text(
              "匯入失敗",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: colorScheme.primaryText,
              ),
            ),
            content: Text(
              e.toString(),
              style: TextStyle(color: colorScheme.bodyText),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text("確定", style: TextStyle(color: colorScheme.primary)),
              ),
            ],
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
  }

  void _showImportResultDialog(int success, int skip, List<String> fails) {
    final colorScheme = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: colorScheme.cardBackground,
        title: Text(
          "匯入結果",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: colorScheme.primaryText,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "✅ 成功匯入選課系統: $success 筆",
              style: TextStyle(color: colorScheme.bodyText),
            ),
            if (skip > 0)
              Text(
                "⏭️ 已存在跳過: $skip 筆",
                style: TextStyle(color: colorScheme.bodyText),
              ),
            if (fails.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Text(
                "❌ 找不到課程:",
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                fails.join(", "),
                style: const TextStyle(color: Colors.red, fontSize: 13),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // 關閉 Dialog
              setState(() {
                _importTextCtrl.clear();
                _showImportMode = false;
                _showEditListMode = true; // 自動切換到編輯選單
              });
            },
            child: Text(
              "確定",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: colorScheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
