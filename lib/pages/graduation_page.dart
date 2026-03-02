import 'package:flutter/material.dart';
import '../models/graduation_model.dart';
import '../services/graduation_service.dart';

class GraduationPage extends StatefulWidget {
  const GraduationPage({Key? key}) : super(key: key);

  @override
  State<GraduationPage> createState() => _GraduationPageState();
}

class _GraduationPageState extends State<GraduationPage> {
  // 使用 nullable future
  late Future<GraduationData?> _dataFuture;
  bool _isRefreshing = false; // 新增：控制刷新狀態

  @override
  void initState() {
    super.initState();
    // 第一次載入，允許使用快取 (forceRefresh: false)
    _dataFuture = GraduationService.instance.fetchGraduationData(forceRefresh: false);
  }

  Future<void> _handleRefresh() async {
    if (_isRefreshing) return;

    setState(() {
      _isRefreshing = true;
      // 觸發重新抓取資料 (強制刷新)
      _dataFuture = GraduationService.instance.fetchGraduationData(forceRefresh: true);
    });

    try {

      await _dataFuture;
    } catch (e) {
      // 錯誤處理 (視需求加入)
      debugPrint("Refresh error: $e");
    } finally {
      // 確保在 Widget 還存在時更新狀態
      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
      }
    }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("畢業檢核"),
        centerTitle: true,
        backgroundColor: const Color.fromARGB(213, 239, 195, 255),
        actions: [
          // 右上角按鈕區域
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: _isRefreshing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.black54, // 或根據您的 AppBar 主題調整顏色
                    ),
                  )
                : IconButton(
                    icon: const Icon(Icons.refresh),
                    tooltip: '重新整理',
                    onPressed: _handleRefresh,
                  ),
          ),
        ],
      ),
      // 移除 RefreshIndicator，直接放 FutureBuilder
      body: FutureBuilder<GraduationData?>(
        future: _dataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text("正在連線教務處資料庫..."),
                ],
              ),
            );
          } else if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
                    const SizedBox(height: 16),
                    Text("讀取失敗：\n${snapshot.error}", textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _handleRefresh,
                      child: const Text("重試"),
                    )
                  ],
                ),
              ),
            );
          } else if (!snapshot.hasData || snapshot.data == null) {
            return const Center(child: Text("無法取得資料，請檢查網路或帳號狀態"));
          }

          // 確定有資料
          final data = snapshot.data!;
          return RefreshIndicator(
            onRefresh: _handleRefresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                
                const SizedBox(height: 16),
                _buildCreditProgress(data),
                const SizedBox(height: 16),
                
                // 只有當有缺修時才顯示
                if (data.missingRequiredCourses.isNotEmpty) ...[
                  _buildMissingRequiredCard(data),
                  const SizedBox(height: 16),
                ],

                _buildGenEdCard(data),
                const SizedBox(height: 16),
                _buildElectivesCard(data),
                
                const SizedBox(height: 30),
                Center(
                  child: Text(
                    "最後更新時間：${data.checkTime}",
                    style: TextStyle(color: Colors.grey[400], fontSize: 12),
                  ),
                ),
                const SizedBox(height: 30), // 稍微縮小間距
                // 新增：免責聲明黑字
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20.0),
                  child: Text(
                    "此頁面資料僅供參考\n請務必以學校官方網站之查詢結果為準",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.black87, 
                      fontSize: 12, 
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(height: 30), // 留白，避免文字太貼手機底部
                
              ],
            ),
          );
        },
      ),
    );
  }

  // 學生資訊卡
  Widget _buildStudentCard(GraduationData data) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: Colors.blue.withOpacity(0.1),
              child: Text(
                data.studentName.isNotEmpty ? data.studentName[0] : "生",
                style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(data.studentName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                Text("${data.department}  ${data.studentId}", style: TextStyle(color: Colors.grey[600])),
              ],
            )
          ],
        ),
      ),
    );
  }

  // 學分進度條
  Widget _buildCreditProgress(GraduationData data) {
    double progress = data.currentCredits / data.minCredits;
    if (progress > 1.0) progress = 1.0;
    
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("畢業學分進度", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 12,
                backgroundColor: Colors.grey[200],
                valueColor: AlwaysStoppedAnimation(
                  progress >= 1.0 ? Colors.green : Colors.orange,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("${(progress * 100).toStringAsFixed(1)}%", style: TextStyle(color: Colors.grey[600])),
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(text: "${data.currentCredits}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      TextSpan(text: " / ${data.minCredits}", style: TextStyle(color: Colors.grey[500])),
                    ]
                  )
                ),
              ],
            ),
            if (data.currentCredits < data.minCredits)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  "尚缺 ${data.minCredits - data.currentCredits} 學分",
                  style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                ),
              )
          ],
        ),
      ),
    );
  }

  // 必修缺修卡片 (紅色警戒)
  Widget _buildMissingRequiredCard(GraduationData data) {
    return Card(
      // color: const Color.fromARGB(255, 255, 255, 255),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        initiallyExpanded: false,
        leading: const Icon(Icons.warning_rounded, color: Colors.red),
        title: const Text("必修缺修", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
        children: data.missingRequiredCourses.map((course) => ListTile(
          dense: true,
          leading: const Icon(Icons.close, size: 16, color: Colors.red),
          title: Text(course, style: const TextStyle(fontSize: 15)),
        )).toList(),
      ),
    );
  }

  // 通識檢核


  // 通識檢核
  Widget _buildGenEdCard(GraduationData data) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        title: const Text("通識與畢業門檻", style: TextStyle(fontWeight: FontWeight.bold)),
        leading: const Icon(Icons.fact_check, color: Colors.teal),
        children: data.genEdStatuses.map((item) {
          bool isOk = item.status == "符合";
          
          // 狀態標籤
          Widget statusBadge = Container(
            margin: const EdgeInsets.only(left: 8),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: isOk ? Colors.green[50] : Colors.red[50],
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: isOk ? Colors.green.withOpacity(0.3) : Colors.red.withOpacity(0.3)),
            ),
            child: Text(item.status, style: TextStyle(
              color: isOk ? Colors.green : Colors.red,
              fontSize: 12,
              fontWeight: FontWeight.bold
            )),
          );

          // 判斷是否有子項目
          if (item.details.isNotEmpty) {
            // === 有子項目：使用 ExpansionTile ===
            return ExpansionTile(
              tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              leading: Icon(
                isOk ? Icons.check_circle : Icons.cancel,
                color: isOk ? Colors.green : Colors.redAccent,
              ),
              // 將狀態標籤放在 Title 旁邊
              title: Row(
                children: [
                  Flexible(child: Text(item.name, overflow: TextOverflow.ellipsis)),
                  statusBadge,
                ],
              ),
              subtitle: item.description.isNotEmpty 
                  ? Text(item.description, style: const TextStyle(color: Colors.red, fontSize: 13)) 
                  : null,
              // 不設定 trailing，保留預設箭頭
              children: item.details.map((detail) => Container(
                color: Colors.grey[50],
                child: ListTile(
                  dense: true,
                  contentPadding: const EdgeInsets.only(left: 56, right: 16),
                  leading: const Icon(Icons.subdirectory_arrow_right, size: 16, color: Colors.grey),
                  title: Text(detail, style: TextStyle(color: Colors.grey[800], fontSize: 14)),
                ),
              )).toList(),
            );
          } else {
            // === 無子項目：使用 ListTile ===
            return ListTile(
              dense: true,
              leading: Icon(
                isOk ? Icons.check_circle : Icons.cancel,
                color: isOk ? Colors.green : Colors.redAccent,
              ),
              title: Row(
                children: [
                  Flexible(child: Text(item.name)),
                  statusBadge,
                ],
              ),
              subtitle: item.description.isNotEmpty 
                  ? Text(item.description, style: const TextStyle(color: Colors.red)) 
                  : null,
            );
          }
        }).toList(),
      ),
    );
  }
  // 選修列表
  Widget _buildElectivesCard(GraduationData data) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        title: Text("已修習選修 (${data.takenElectiveCourses.length})", style: const TextStyle(fontWeight: FontWeight.bold)),
        leading: const Icon(Icons.book, color: Colors.indigo),
        children: [
          Container(
            height: 250, // 限制高度，內部可捲動
            child: ListView.separated(
              itemCount: data.takenElectiveCourses.length,
              separatorBuilder: (ctx, i) => const Divider(height: 1, indent: 16, endIndent: 16),
              itemBuilder: (ctx, i) {
                return ListTile(
                  dense: true,
                  leading: const Icon(Icons.bookmark_border, size: 18, color: Colors.grey),
                  title: Text(data.takenElectiveCourses[i]),
                );
              },
            ),
          )
        ],
      ),
    );
  }
}