import 'package:flutter/material.dart';
import '../../services/course_selection_service.dart';
import '../../services/course_query_service.dart';
import '../../services/course_selection_submit_service.dart' as submit_service;
import '../../models/course_selection_models.dart'; // 引用刚刚建立的模型檔案
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:http/http.dart' as http; // ✅ 新增：用來發送課綱請求

class CourseQueryTab extends StatefulWidget {
  final List<CourseSelectionData> currentCourses; // 從父層傳入目前的課表，用來比對重複
  final VoidCallback onRequestRefresh; // 當送出成功後，通知父層重整

  const CourseQueryTab({
    Key? key,
    required this.currentCourses,
    required this.onRequestRefresh,
  }) : super(key: key);

  @override
  State<CourseQueryTab> createState() => _CourseQueryTabState();
}

// 使用 AutomaticKeepAliveClientMixin 保持切換分頁時狀態不消失
class _CourseQueryTabState extends State<CourseQueryTab> with AutomaticKeepAliveClientMixin {
  
  @override
  bool get wantKeepAlive => true;

  // 搜尋狀態
  bool _isQueryLoading = false;
  List<CourseJsonData> _searchResults = [];
  bool _hasSearched = false;
  bool _showEditListMode = false;

  final List<PendingAddCourse> _pendingAdds = []; 
  final List<PendingTransaction> _pendingItems = [];

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
    CourseQueryService.instance.getCourses().catchError((e) => print("背景載入失敗: $e"));
  }

  @override
  void dispose() {
    _crsNameCtrl.dispose();
    _teacherCtrl.dispose();
    _codeCtrl.dispose();
    _deptCtrl.dispose();
    for (var p in _pendingItems) {
      p.pointsController?.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // 必須呼叫
    // ✅ 每次畫面重建或切回時，順便檢查有沒有包裹(匯出資料)要領收
    _checkExportedCourses();
    return Column(
      children: [
        // 功能列
        Container(
          padding: const EdgeInsets.all(8),
          color: Colors.white,
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    setState(() => _showEditListMode = false);
                    _showSearchSheet();
                  },
                  icon: const Icon(Icons.search),
                  label: const Text("搜尋課程"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: !_showEditListMode ? Colors.blue[50] : Colors.grey[100],
                    foregroundColor: !_showEditListMode ? Colors.blue : Colors.grey,
                    elevation: 0,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    setState(() => _showEditListMode = true);
                  },
                  icon: const Icon(Icons.playlist_add_check),
                  label: Text("編輯選單 (${_pendingItems.length})"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _showEditListMode ? Colors.orange[50] : Colors.grey[100],
                    foregroundColor: _showEditListMode ? Colors.orange[800] : Colors.grey,
                    elevation: 0,
                    side: _pendingItems.isNotEmpty ? const BorderSide(color: Colors.orange, width: 1) : null,
                  ),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),

        Expanded(
          child: _showEditListMode ? _buildEditListMode() : _buildSearchResults(),
        ),
      ],
    );
  }

  // --- 搜尋結果 ---
  // --- 搜尋結果 (修改後：支援點擊展開) ---
  Widget _buildSearchResults() {
    if (_isQueryLoading) return const Center(child: CircularProgressIndicator());
    if (!_hasSearched) {
      return Center(child: Text("請點擊左上角「搜尋課程」開始", style: TextStyle(color: Colors.grey[400])));
    }
    if (_searchResults.isEmpty) return const Center(child: Text("找不到符合條件的課程"));

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final course = _searchResults[index];
        // 檢查是否已經在待加選清單中
        bool isAdded = _pendingAdds.any((p) => p.courseData.id == course.id) || 
                       _pendingItems.any((p) => p.id == course.id);

        return Card(
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 12),
          clipBehavior: Clip.antiAlias, // 讓展開動畫更滑順
          child: Theme(
            // 消除 ExpansionTile 上下預設的邊框線
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              // 標題：課名
              title: Text(
                course.name.split('\n')[0], 
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              // 副標題：老師 / 代號
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.person, size: 14, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(course.teacher, style: TextStyle(color: Colors.grey[800])),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          course.id, 
                          style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              // 右側按鈕：加選 (獨立運作，不會觸發展開)
              trailing: isAdded
                  ? const Icon(Icons.check_circle, color: Colors.green, size: 32)
                  : ElevatedButton(
                      onPressed: () => _addToPendingList(course),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        minimumSize: const Size(60, 32),
                      ),
                      child: const Text("加選"),
                    ),
              
              // --- 展開後的詳細內容 ---
              children: [
                const Divider(height: 1, thickness: 1, color: Colors.black12),
                Container(
                  color: Colors.blue[50]!.withOpacity(0.3), // 微微的背景色區分
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Column(
                    children: [
                      // 第一排資訊
                      Row(
                        children: [
                          Expanded(child: _buildDetailRow(Icons.school, "系所", course.department)),
                          Expanded(child: _buildDetailRow(Icons.grade, "學分", course.credit)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // 第二排資訊
                      Row(
                        children: [
                          Expanded(child: _buildDetailRow(Icons.class_, "班級", "${course.grade}年級 ${course.className}")),
                          Expanded(child: _buildDetailRow(Icons.room, "教室", _parseRoomLocation(course.room))),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // 時間表顯示
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text("上課時間表", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                      ),
                      const SizedBox(height: 8),
                      _buildTimeDisplay(course.classTime),

                      // ✅ 新增：評分方式區塊
                      const SizedBox(height: 16),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text("評分方式", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                      ),
                      const SizedBox(height: 8),
                      
                      // 使用 FutureBuilder 動態載入
                      Align(
                        alignment: Alignment.centerLeft,
                        child: FutureBuilder<List<String>>(
                          future: _getCourseEvaluation(course.id),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.waiting) {
                              return const Padding(
                                padding: EdgeInsets.all(8.0),
                                child: SizedBox(
                                  height: 20, width: 20, 
                                  child: CircularProgressIndicator(strokeWidth: 2)
                                ),
                              );
                            }
                            if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
                              return const Text("無法取得評分資料", style: TextStyle(color: Colors.grey, fontSize: 13));
                            }
                            // 渲染抓取到的評分清單
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: snapshot.data!.map((e) => Padding(
                                padding: const EdgeInsets.only(bottom: 6.0),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(Icons.check_circle_outline, size: 16, color: Colors.blue),
                                    const SizedBox(width: 6),
                                    Expanded(child: Text(e, style: const TextStyle(fontSize: 13, color: Colors.black87))),
                                  ],
                                ),
                              )).toList(),
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

  // --- 輔助方法 1: 顯示詳細資訊的小列 ---
  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: Colors.blueGrey),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
              Text(
                value, 
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
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
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.blue[100],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text("星期${days[i]}", style: TextStyle(color: Colors.blue[900], fontSize: 12, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 12),
                Text(
                  "第 ${times[i]} 節", 
                  style: const TextStyle(fontSize: 14, color: Colors.black87),
                ),
              ],
            ),
          ),
        );
      }
    }

    if (timeWidgets.isEmpty) {
      return const Text("無時間資訊", style: TextStyle(color: Colors.grey));
    }

    return Column(children: timeWidgets);
  }
  // --- 編輯清單 (購物車) ---
  Widget _buildEditListMode() {
    // 扣除掉「待退選」的，計算目前還在系統上的課程
    final activeExistingCourses = widget.currentCourses.where((c) {
      // 1. 如果已經在「待退選」清單中，就不顯示在已選列表
      if (_pendingItems.any((p) => p.id == c.code && p.type == TransactionType.drop)) {
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
            padding: const EdgeInsets.all(12),
            children: [
              // 1. 待送出清單
              if (_pendingItems.isNotEmpty) ...[
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8.0),
                  child: Text("待送出項目 (請確認後送出)", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.deepOrange)),
                ),
                ..._pendingItems.map((item) {
                  bool isAdd = item.type == TransactionType.add;
                  Color bgColor = isAdd ? Colors.orange[50]! : Colors.red[50]!;
                  Color borderColor = isAdd ? Colors.orange : Colors.red;
                  String tagText = isAdd ? "加選" : "退選";

                  return Card(
                    color: bgColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(color: borderColor.withOpacity(0.5), width: 1),
                    ),
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                margin: const EdgeInsets.only(top: 2),
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: borderColor,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(tagText, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(item.id, style: TextStyle(color: Colors.blueGrey[800], fontSize: 16, fontWeight: FontWeight.w900)),
                                    const SizedBox(height: 4),
                                    Text(item.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close, color: Colors.grey),
                                onPressed: () => _confirmRemovePendingItem(item),
                              )
                            ],
                          ),
                          if (isAdd && item.pointsController != null) ...[
                            const Divider(),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                const Padding(
                                  padding: EdgeInsets.only(top: 2),
                                  child: Text("點數/志願：", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                ),
                                const SizedBox(width: 8),
                                SizedBox(
                                  width: 70,
                                  height: 30,
                                  child: TextField(
                                    controller: item.pointsController,
                                    keyboardType: TextInputType.number,
                                    textAlign: TextAlign.center,
                                    textAlignVertical: TextAlignVertical.center,
                                    style: const TextStyle(fontSize: 14),
                                    decoration: const InputDecoration(
                                      isCollapsed: true,
                                      contentPadding: EdgeInsets.symmetric(vertical: 5),
                                      border: OutlineInputBorder(),
                                      hintText: "0",
                                      hintStyle: TextStyle(fontSize: 12, color: Colors.grey),
                                    ),
                                  ),
                                ),
                              ],
                            )
                          ],
                          if (!isAdd)
                            Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text("此課程將被退選", style: TextStyle(color: Colors.red[800], fontSize: 12)),
                            ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ],

              // 2. 已選課程
              if (activeExistingCourses.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8.0),
                  child: Text("目前已選課程", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                ),
                ...activeExistingCourses.map((course) {
                  Color statusColor = Colors.grey;
                  String displayStatus = course.status;

                  if (course.status.contains("選上")) {
                    statusColor = Colors.green;
                  } else if (course.status.contains("登記") || course.status.contains("加選")) {
                    statusColor = Colors.lightBlue;
                    displayStatus = "登記加選";
                  }

                  return Card(
                    color: Colors.white,
                    elevation: 1,
                    margin: const EdgeInsets.only(bottom: 8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: Row(
                        children: [
                          Container(width: 4, height: 40, color: statusColor),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(displayStatus, style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 13)),
                                    const SizedBox(width: 8),
                                    Text(course.code, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(course.name, style: const TextStyle(fontSize: 15)),
                              ],
                            ),
                          ),
                          TextButton(
                            onPressed: () => _confirmDropCourse(course),
                            style: TextButton.styleFrom(foregroundColor: Colors.red[300]),
                            child: const Text("退選"),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ]
            ],
          ),
        ),

        // 送出按鈕
        if (_pendingItems.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))],
            ),
            child: SafeArea(
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _submitSelection,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[800],
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text("送出 (${_pendingItems.length} 筆更動)", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ),
            ),
          )
      ],
    );
  }

  // --- 邏輯 Methods (加入, 搜尋, 送出) ---

  void _addToPendingList(CourseJsonData course) {
    if (_pendingItems.length >= 15) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("已達到選課清單上限 (15門)"), backgroundColor: Colors.red));
      return;
    }
    if (_pendingItems.any((p) => p.id == course.id)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("此課程已在編輯清單中")));
      return;
    }
    if (widget.currentCourses.any((c) => c.code == course.id)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("你已經選過這門課了")));
      return;
    }

    setState(() {
      final controller = TextEditingController();
      controller.addListener(() => _saveCart()); // 記得加監聽器
      _pendingItems.add(PendingTransaction(
        id: course.id,
        name: course.name.split('\n')[0],
        type: TransactionType.add,
        originalData: course,
        pointsController: TextEditingController(),
      ));
      _saveCart(); // ✅ 加入後存檔
    });
    
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("已加入加選：${course.name.split('\n')[0]}"), duration: const Duration(milliseconds: 800)));
  }

  void _confirmDropCourse(CourseSelectionData course) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("確認退選"),
        content: Text("確定要退選這門課嗎？\n\n${course.name}"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("取消")),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              final controller = TextEditingController();
              controller.addListener(() => _saveCart()); // 記得加監聽器
              setState(() {
                _pendingItems.add(PendingTransaction(
                  id: course.code,
                  name: course.name,
                  type: TransactionType.drop,
                  originalData: course,
                  pointsController: null,
                ));
                _saveCart(); // ✅ 加入後存檔
              });
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text("加入退選清單"),
          ),
        ],
      ),
    );
  }

  void _confirmRemovePendingItem(PendingTransaction item) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("移除項目"),
        content: Text("確定要取消「${item.type == TransactionType.add ? "加選" : "退選"}」此課程嗎？\n\n${item.name}"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("保留")),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _pendingItems.remove(item);
                
                item.pointsController?.dispose();
                _saveCart();
              });
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text("確定移除"),
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
              ...logs.map((l) => Text(l, style: TextStyle(color: l.startsWith("[退選]") ? Colors.red : Colors.blue[800], fontSize: 13, height: 1.5))),
              const SizedBox(height: 10),
              const Text("注意：送出過程可能需要幾秒鐘。", style: TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text("取消")),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              _processSubmission();
            },
            child: const Text("確定送出", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _processSubmission() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (loadingContext) => const Center(child: CircularProgressIndicator()),
    );

    try {
      List<submit_service.PendingTransaction> serviceItems = _pendingItems.map((uiItem) {
        return submit_service.PendingTransaction(
          id: uiItem.id,
          name: uiItem.name,
          type: uiItem.type == TransactionType.add 
              ? submit_service.TransactionType.add 
              : submit_service.TransactionType.drop,
          points: uiItem.pointsController?.text.trim() ?? "",
        );
      }).toList();

      final result = await submit_service.CourseSelectionSubmitService.instance.submitTransactions(serviceItems);

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
        for(var p in _pendingItems) p.pointsController?.dispose();
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
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("我知道了"))],
      ),
    );
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(children: [Icon(Icons.check_circle, color: Colors.green), SizedBox(width: 8), Text("請求已送出")]),
        content: const Text("加退選請求已成功送至系統。\n\n⚠️ 重要提示：\n系統狀態可能會有延遲，請務必稍後使用「電腦開啟學校網站」再次確認您的課表。"),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("好，我會確認"))],
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("❌ 送出失敗"),
        content: Text("發生錯誤：\n$message"),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("確定"))],
      ),
    );
  }

  // --- 搜尋條件 Sheet (省略部分 UI 程式碼，邏輯與原版相同，僅需確保呼叫 _performSearch) ---
  void _showSearchSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // 讓鍵盤彈出時不會遮擋
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.85,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              padding: EdgeInsets.only(
                left: 20, right: 20, top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Center(
                    child: Text("課程查詢條件", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 20),

                  // 1. 課名 & 老師
                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField("課程名稱", _crsNameCtrl),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildTextField("授課教師", _teacherCtrl),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // 2. 代號 & 系所 (取代 Degree Dropdown，因為 API 用 Dept Name 比較準)
                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField("課別代號 (T3)", _codeCtrl),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildTextField("開課系所", _deptCtrl, hint: "例如: 資工"),
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
                          value: _selectedGrade,
                          items: const [
                            DropdownMenuItem(value: null, child: Text("全部")),
                            DropdownMenuItem(value: "1", child: Text("一年級")),
                            DropdownMenuItem(value: "2", child: Text("二年級")),
                            DropdownMenuItem(value: "3", child: Text("三年級")),
                            DropdownMenuItem(value: "4", child: Text("四年級")),
                            DropdownMenuItem(value: "5", child: Text("五年級")),
                          ],
                          onChanged: (v) => _selectedGrade = v,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildDropdown(
                          label: "班級 (CLASS)",
                          value: _selectedClass,
                          items: const [
                            DropdownMenuItem(value: null, child: Text("全部")),
                            DropdownMenuItem(value: "0", child: Text("不分班")),
                            DropdownMenuItem(value: "1", child: Text("甲班")),
                            DropdownMenuItem(value: "2", child: Text("乙班")),
                            DropdownMenuItem(value: "5", child: Text("全英班")), // JSON 不一定有這個，視情況調整
                          ],
                          onChanged: (v) => _selectedClass = v,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // 4. 時間 (星期 & 節次)
                  const Text("上課時間", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: _buildDropdown(
                          label: "星期",
                          value: _selectedDay,
                          items: const [
                            DropdownMenuItem(value: null, child: Text("不限")),
                            DropdownMenuItem(value: "1", child: Text("星期一")),
                            DropdownMenuItem(value: "2", child: Text("星期二")),
                            DropdownMenuItem(value: "3", child: Text("星期三")),
                            DropdownMenuItem(value: "4", child: Text("星期四")),
                            DropdownMenuItem(value: "5", child: Text("星期五")),
                            DropdownMenuItem(value: "6", child: Text("星期六")),
                            DropdownMenuItem(value: "7", child: Text("星期日")),
                          ],
                          onChanged: (v) => _selectedDay = v,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildDropdown(
                          label: "節次",
                          value: _selectedPeriod,
                          items: _buildPeriodItems(),
                          onChanged: (v) => _selectedPeriod = v,
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
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text("開始查詢", style: TextStyle(fontSize: 18)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Center(
                    child: TextButton(
                      onPressed: _clearSearchFields,
                      child: const Text("重設條件", style: TextStyle(color: Colors.grey)),
                    ),
                  ),
                ],
              ),
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
    });
    try {
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
  
  Widget _buildDropdown({
    required String label,
    required String? value,
    required List<DropdownMenuItem<String>> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
        const SizedBox(height: 4),
        DropdownButtonFormField<String>(
          value: value,
          items: items,
          onChanged: (v) {
            // 需要在 StatefulBuilder 或 setState 中更新，但這裡是 BottomSheet
            // 因為用了 DraggableScrollableSheet 的 builder，通常建議用 StatefulBuilder 包裹
            // 簡化起見，直接依賴外部 setState 或 Dropdown 自身更新 (這裡用 onChanged callback 更新外部變數)
            onChanged(v);
          },
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            isDense: true,
          ),
        ),
      ],
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, {String? hint}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: hint,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            isDense: true,
          ),
        ),
      ],
    );
  }

  List<DropdownMenuItem<String>> _buildPeriodItems() {
    final List<Map<String, String>> periods = [
      {"val": "A", "label": "A (07:00)"},
      {"val": "1", "label": "1 (08:10)"},
      {"val": "2", "label": "2 (09:10)"},
      {"val": "3", "label": "3 (10:10)"},
      {"val": "4", "label": "4 (11:10)"},
      {"val": "B", "label": "B (12:10)"},
      {"val": "5", "label": "5 (13:10)"},
      {"val": "6", "label": "6 (14:10)"},
      {"val": "7", "label": "7 (15:10)"},
      {"val": "8", "label": "8 (16:10)"},
      {"val": "9", "label": "9 (17:10)"},
      {"val": "C", "label": "C (18:20)"},
    ];
    
    return [
      const DropdownMenuItem(value: null, child: Text("不限")),
      ...periods.map((p) => DropdownMenuItem(value: p['val'], child: Text(p['label']!))).toList(),
    ];
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
        if (_pendingItems.any((p) => p.id == id) || _pendingAdds.any((p) => p.courseData.id == id)) {
          duplicateCount++;
          continue;
        }
        // 2. 檢查是否已經選上或登記了 (正式課表)
        if (widget.currentCourses.any((c) => c.code == id)) {
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
          _pendingItems.add(PendingTransaction(
            id: course.id,
            name: course.name.split('\n')[0],
            type: TransactionType.add,
            originalData: course,
            pointsController: TextEditingController(),
          ));
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
              content: Text("已從助手匯入 $successCount 門課程至購物車" + (duplicateCount > 0 ? " (跳過 $duplicateCount 門重複課程)" : "")),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (e) {
      print("自動匯入失敗: $e");
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
      List<Map<String, dynamic>> cartData = _pendingItems.map((item) => {
        'id': item.id,
        'points': item.pointsController?.text ?? "",
      }).toList();
      await prefs.setString('saved_shopping_cart', jsonEncode(cartData));
    } catch (e) {
      print("儲存購物車失敗: $e");
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
        if (widget.currentCourses.any((c) => c.code == id)) continue;

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
            final controller = TextEditingController();
            controller.addListener(() => _saveCart()); // 記得加監聽器
            _pendingItems.add(PendingTransaction(
              id: course.id,
              name: course.name.split('\n')[0],
              type: TransactionType.add,
              originalData: course,
              pointsController: controller,
            ));
            _saveCart();
          });
        }
      }
    } catch (e) {
      print("讀取購物車失敗: $e");
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
    final sem = semStr.substring(3, 4);   // 最後一碼 (2)
    final url = Uri.parse('https://selcrs.nsysu.edu.tw/menu5/showoutline.asp?SYEAR=$syear&SEM=$sem&CrsDat=$courseId');

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


}



