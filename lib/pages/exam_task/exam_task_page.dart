import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart'; // 需引入
import '../../services/exam_task/elearn_task_HW_service.dart';
import 'task_detail_pages.dart';

class ExamTaskPage extends StatefulWidget {
  const ExamTaskPage({Key? key}) : super(key: key);

  @override
  State<ExamTaskPage> createState() => _ExamTaskPageState();
}

class _ExamTaskPageState extends State<ExamTaskPage> {
  List<ElearnTask> _allTasks = [];
  List<ElearnTask> _displayedTasks = [];
  bool _isLoading = true;
  String _statusMessage = "";

  // 篩選條件
  String _selectedSemester = ""; 
  String _selectedCourse = "所有課程"; 
  List<String> _semesterOptions = [];
  List<String> _courseOptions = ["所有課程"];
  final Set<String> _selectedStatusFilters = {};

  @override
  void initState() {
    super.initState();
    _semesterOptions = _generateSemesters();
    if (_semesterOptions.isNotEmpty) {
      _selectedSemester = _semesterOptions.first;
    }
    // 執行初始化檢查 (讀快取 + 檢查時間)
    _initData();
  }

  Future<void> _initData() async {
    // 1. 永遠先嘗試載入快取，讓使用者有東西看
    var cached = await ElearnService.instance.loadCachedTasks();
    if (cached.isNotEmpty) {
      if (mounted) {
        setState(() {
          _allTasks = cached;
          _updateCourseOptions();
          _applyFilterAndSort();
          // 先別急著關掉 loading，等下決定要不要聯網
        });
      }
    }

    // 2. 檢查時間決定是否聯網
    final prefs = await SharedPreferences.getInstance();
    final int? lastTs = prefs.getInt('last_elearn_fetch_time');
    bool shouldRefresh = true;

    if (lastTs != null && cached.isNotEmpty) {
      final DateTime lastTime = DateTime.fromMillisecondsSinceEpoch(lastTs);
      final int diff = DateTime.now().difference(lastTime).inMinutes;
      
      if (diff < 3) {
        shouldRefresh = false;
        print("⏳ 距離上次更新僅 $diff 分鐘，跳過自動刷新，使用快取資料。");
        if (mounted) {
          setState(() {
            _isLoading = false; // 停止轉圈
            _statusMessage = "";
          });
        }
      }
    }

    // 3. 如果需要刷新 (超過3分鐘 或 沒快取)，則聯網
    if (shouldRefresh) {
      _fetchFromNetwork();
    }
  }

  List<String> _generateSemesters() {
    List<String> options = [];
    DateTime now = DateTime.now();
    int currentYear = now.year - 1911;
    int month = now.month;

    int startYear;
    int semesterType; 

    if (month >= 9 || month <= 1) {
      startYear = (month >= 9) ? currentYear : (currentYear - 1);
      semesterType = 1;
    } else {
      startYear = currentYear - 1;
      semesterType = 2;
    }

    for (int i = 0; i < 8; i++) {
      if (startYear < 114) break; // 避免出現不合理的學年
      options.add("$startYear-$semesterType");
      if (semesterType == 1) {
        startYear -= 1;
        semesterType = 2;
      } else {
        semesterType = 1;
      }
    }
    
    if (!options.contains("114-1")) {
       options.insert(0, "114-1");
       if (_selectedSemester.isEmpty) _selectedSemester = "114-1";
    }

    return options;
  }

  Future<void> _fetchFromNetwork() async {
    print("🚀 開始重新加載(全部list)...");
    setState(() { 
      _isLoading = true; 
      _statusMessage = "讀取中..."; 
    });

    try {
      var tasks = await ElearnService.instance.fetchTasks(_selectedSemester);
      
      // 成功後記錄時間
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('last_elearn_fetch_time', DateTime.now().millisecondsSinceEpoch);

      if (mounted) {
        setState(() {
          _allTasks = tasks;
          _updateCourseOptions();
          _applyFilterAndSort();
          _isLoading = false;
          _statusMessage = "";
        });
      }
    } catch (e) {
      print("Error: $e");
      if (mounted) {
        setState(() { _isLoading = false; _statusMessage = "更新失敗"; });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("更新失敗: $e")));
      }
    }
  }

  void _updateCourseOptions() {
    Set<String> courses = {"所有課程"};
    for (var t in _allTasks) {
      courses.add(t.courseName);
    }
    _courseOptions = courses.toList();
    if (!_courseOptions.contains(_selectedCourse)) {
      _selectedCourse = "所有課程";
    }
  }

  void _applyFilterAndSort() {
    List<ElearnTask> temp = List.from(_allTasks);

    // 1. 課程篩選
    if (_selectedCourse != "所有課程") {
      temp = temp.where((t) => t.courseName == _selectedCourse).toList();
    }

    // 2. 狀態篩選 (多選邏輯)
    if (_selectedStatusFilters.isNotEmpty) {
      temp = temp.where((t) {
      // 狀態判斷
      bool statusMatch = false;
      if (!_selectedStatusFilters.any((f) => ["未完成", "已完成", "忽略"].contains(f))) {
        statusMatch = true; // 如果沒選任何狀態篩選，預設全過
      } else {
        if (_selectedStatusFilters.contains("未完成") && !t.isSubmitted && !t.isIgnored) statusMatch = true;
        if (_selectedStatusFilters.contains("已完成") && t.isSubmitted) statusMatch = true;
        if (_selectedStatusFilters.contains("忽略") && t.isIgnored) statusMatch = true;
      }

      // 類型判斷
      bool typeMatch = false;
      if (!_selectedStatusFilters.any((f) => ["測驗", "作業"].contains(f))) {
        typeMatch = true; // 如果沒選任何類型篩選，預設全過
      } else {
        if (_selectedStatusFilters.contains("測驗") && t.type == "測驗") typeMatch = true;
        if (_selectedStatusFilters.contains("作業") && t.type == "作業") typeMatch = true;
      }

      return statusMatch && typeMatch;
      }).toList();
    }

    // 3. 排序 (時間由未來到過去)
    temp.sort((a, b) {
      DateTime timeA = a.endTime ?? DateTime(1900);
      DateTime timeB = b.endTime ?? DateTime(1900);
      return timeB.compareTo(timeA); 
    });

    setState(() {
      _displayedTasks = temp;
    });
  }

  void _openDetail(ElearnTask task) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => task.type == "測驗" 
            ? ExamDetailPage(
                examId: task.id, 
                title: task.title, 
                isIgnored: task.isIgnored,
                isSubmitted: task.isSubmitted,
              )
            : HomeworkDetailPage(
                homeworkId: task.id, 
                title: task.title, 
                isIgnored: task.isIgnored,
                isSubmitted: task.isSubmitted,
              ),
      ),
    );

    // 如果從詳情頁回來且有變動 (例如改變了忽略狀態)
    if (result == true) {
      // 這裡直接重新讀取快取即可，因為 Service 裡的 toggleIgnore 已經更新了快取
      // 不需要重新聯網，除非您希望強制同步
      _initData(); 
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("作業與考試"),
        centerTitle: true,
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        actions: [
          _isLoading 
            ? const Padding(
                padding: EdgeInsets.only(right: 16.0),
                child: SizedBox(
                  width: 20, height: 20,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                ),
              )
            : IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _fetchFromNetwork, // 手動按按鈕，強制刷新 (忽略3分鐘限制)
              )
        ],
      ),
      body: Column(
        children: [
          // --- 篩選區 ---
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            color: Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 12),
                // 第一排：學期 與 課程
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: DropdownButtonFormField<String>(
                        value: _selectedSemester,
                        decoration: InputDecoration(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          labelText: "學期",
                        ),
                        items: _semesterOptions.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                        onChanged: _isLoading ? null : (val) {
                          if (val != null) {
                            setState(() => _selectedSemester = val);
                            _fetchFromNetwork(); // 切換學期時強制刷新
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 3,
                      child: DropdownButtonFormField<String>(
                        value: _selectedCourse,
                        isExpanded: true,
                        decoration: InputDecoration(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          labelText: "課程篩選",
                        ),
                        items: _courseOptions.map((c) => DropdownMenuItem(
                          value: c, 
                          child: Text(c, overflow: TextOverflow.ellipsis)
                        )).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              _selectedCourse = val;
                              _applyFilterAndSort();
                            });
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _buildStatusChip("未完成")),
                    const SizedBox(width: 4),
                    Expanded(child: _buildStatusChip("已完成")),
                    const SizedBox(width: 4),
                    Expanded(child: _buildStatusChip("忽略")),
                    const SizedBox(width: 4),
                    Expanded(child: _buildStatusChip("測驗")),
                    const SizedBox(width: 4),
                    Expanded(child: _buildStatusChip("作業")),
                  ],
                ),
              ],
            ),
          ),
          
          // --- 列表區 ---
          if (_isLoading && _displayedTasks.isEmpty)
             Expanded(child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const Text("讀取資料中..."), const SizedBox(height: 10), const CircularProgressIndicator()]))),

          if (!_isLoading || _displayedTasks.isNotEmpty)
            Expanded(
              child: Container(
                color: Colors.grey[100],
                child: _displayedTasks.isEmpty
                  ? Center(child: Text("此學期沒有符合條件的任務", style: TextStyle(color: Colors.grey[600])))
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: _displayedTasks.length,
                      itemBuilder: (context, index) {
                        return _buildTaskCard(_displayedTasks[index]);
                      },
                    ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String label) {
    bool isSelected = _selectedStatusFilters.contains(label);
    return FilterChip(
      label: Center( // 確保文字置中
      child: Text(
        label, 
        style: TextStyle(
          fontSize: 11, // 稍微縮小字體以適應寬度
          color: isSelected ? Colors.indigo : Colors.black87,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        )
      )
    ),
    selected: isSelected,
    onSelected: (bool selected) {
      setState(() {
        if (selected) {
          _selectedStatusFilters.add(label);
        } else {
          _selectedStatusFilters.remove(label);
        }
        _applyFilterAndSort();
      });
    },
      // 壓縮尺寸的關鍵設定
    showCheckmark: false, // 移除選取時的打勾符號
    visualDensity: VisualDensity.compact, // 緊湊佈局
    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap, // 縮小點擊區域至標籤大小
    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0), 
    
    selectedColor: Colors.indigo.withOpacity(0.2),
    checkmarkColor: Colors.indigo,
    labelStyle: TextStyle(
      color: isSelected ? Colors.indigo : Colors.black87,
      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      fontSize: 12, // 再次確保字體較小
    ),
      backgroundColor: Colors.grey[100],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: isSelected ? Colors.indigo : Colors.grey[300]!),
      ),
    );
  }

  Widget _buildTaskCard(ElearnTask task) {
    final dateFormat = DateFormat('yyyy/MM/dd HH:mm');
    bool isOverdue = task.endTime != null && task.endTime!.isBefore(DateTime.now()) && !task.isSubmitted;
    
    Color statusColor;
    String statusText;
    
    if (task.isIgnored) {
      statusColor = Colors.blue;
      statusText = "已忽略";
    } else if (task.isSubmitted) {
      statusColor = Colors.green;
      statusText = task.statusRaw;
    } else if (isOverdue) {
      statusColor = Colors.red;
      statusText = task.statusRaw;
    } else {
      statusColor = Colors.orange;
      statusText = task.statusRaw;
    }

    IconData typeIcon = task.type == "作業" ? Icons.assignment_outlined : Icons.quiz_outlined;
    Color typeColor = task.type == "作業" ? Colors.blueAccent : Colors.purpleAccent;

    return Card(
    margin: const EdgeInsets.only(bottom: 12),
    elevation: 2,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    child: InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => _openDetail(task),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 第一排：課程名稱與類型標籤
            Row(
              children: [
                Expanded(child: Text(task.courseName, style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis)),
                _buildTypeBadge(task), // 顯示「作業」或「測驗」的小標籤
              ],
            ),
            const SizedBox(height: 8),
            // 第二排：標題與分數
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: Text(task.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87))),
                if (task.score != null) _buildScoreBadge(task.score!), // 顯示分數
              ],
            ),
            const SizedBox(height: 12),
            Divider(height: 1, color: Colors.grey[200]),
            const SizedBox(height: 10),
            // 第三排：時間 (左) 與 狀態 (右)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween, // 關鍵：左右分開
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // 左下角：時間
                Row(
                  children: [
                    Icon(Icons.access_time, size: 14, color: Colors.grey[500]),
                    const SizedBox(width: 4),
                    Text(task.endTime != null ? dateFormat.format(task.endTime!) : "無期限", 
                         style: TextStyle(fontSize: 13, color: Colors.grey[700])),
                  ],
                ),
                // 右下角：狀態標籤
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: statusColor.withOpacity(0.3))
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(task.isIgnored ? Icons.visibility_off : (task.isSubmitted ? Icons.check_circle : Icons.circle_outlined), 
                           size: 14, color: statusColor),
                      const SizedBox(width: 4),
                      Text(statusText, style: TextStyle(fontSize: 12, color: statusColor, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

// 輔助方法：類型小標籤 (測驗/作業)
Widget _buildTypeBadge(ElearnTask task) {
  Color typeColor = task.type == "作業" ? Colors.blueAccent : Colors.purpleAccent;
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(color: typeColor.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
    child: Text(task.type, style: TextStyle(fontSize: 10, color: typeColor, fontWeight: FontWeight.bold)),
  );
}

// 輔助方法：分數小方塊
Widget _buildScoreBadge(double score) {
  return Container(
    margin: const EdgeInsets.only(left: 8),
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(
      color: Colors.amber.shade50,
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: Colors.amber.shade200),
    ),
    child: Column(
      children: [
        Text("SCORE", style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.amber.shade800)),
        Text("$score", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.amber.shade900)),
      ],
    ),
  );
}}