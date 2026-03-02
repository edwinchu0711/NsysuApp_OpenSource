import 'package:flutter/material.dart';
import '../services/open_score_service.dart';

class OpenScorePage extends StatelessWidget {
  final String cookies;
  final String userAgent;

  const OpenScorePage({
    Key? key,
    required this.cookies,
    required this.userAgent,
  }) : super(key: key);

  /// 建立右側狀態顯示區塊 (總分或查無資料)
  Widget _buildTrailingWidget(List<Map<String, String>> scores) {
    // 1. 如果完全沒有分數資料
    if (scores.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.orange[50],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.orange.shade300),
        ),
        child: Text(
          "無成績資料",
          style: TextStyle(
            color: Colors.deepOrange[700],
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
      );
    }

    // 2. 尋找總成績項目 (比對 key: item)
    final totalScoreEntry = scores.firstWhere(
      (s) => (s['item'] ?? "").contains("總成績") || (s['item'] ?? "").contains("原始總成績"),
      orElse: () => {},
    );

    if (totalScoreEntry.isEmpty) {
      return const Icon(Icons.expand_more);
    }

    final String scoreText = totalScoreEntry['raw_score'] ?? "-";
    final double? scoreValue = double.tryParse(scoreText);

    // 3. 顯示總分
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              scoreText,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: (scoreValue ?? 0) < 60 ? Colors.red : Colors.green[800],
              ),
            ),
          ],
        ),
        const SizedBox(width: 4),
        const Icon(Icons.expand_more, color: Colors.grey),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("開放成績查詢"),
        elevation: 0,
        actions: [
          ValueListenableBuilder<bool>(
            valueListenable: OpenScoreService.instance.isLoadingNotifier,
            builder: (context, isLoading, child) {
              return IconButton(
                icon: isLoading 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) 
                  : const Icon(Icons.refresh),
                onPressed: isLoading ? null : () { // 【關鍵：isLoading 時按鈕失效】
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("正在重新抓取資料..."), duration: Duration(seconds: 1)),
                  );
                  OpenScoreService.instance.fetchOpenScores();
                },
              );
            },
          )
        ],
      ),
      body: Column(
        children: [
          // 1. 進度條區塊 (只保留進度條，移除文字顯示)
          ValueListenableBuilder<bool>(
            valueListenable: OpenScoreService.instance.isLoadingNotifier,
            builder: (context, isLoading, child) {
              // 如果沒有在載入中，這裡什麼都不顯示 (height: 0)
              if (!isLoading) return const SizedBox.shrink();

              // 只回傳進度條
              return ValueListenableBuilder<double>(
                valueListenable: OpenScoreService.instance.progressNotifier,
                builder: (ctx, progress, _) => LinearProgressIndicator(
                  value: progress, // 這裡會根據 service 計算的 (current / total) 來顯示進度
                  minHeight: 4,     // 線條高度
                  backgroundColor: Colors.grey[200],
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
                ),
              );
            },
          ),

          // 2. 資料列表區塊 (保持不變)
          Expanded(
            child: ValueListenableBuilder<List<Map<String, dynamic>>>(
              valueListenable: OpenScoreService.instance.resultsNotifier,
              builder: (context, results, child) {
                bool isLoading = OpenScoreService.instance.isLoadingNotifier.value;

                if (results.isEmpty) {
                  return Center(
                    child: isLoading
                        ? const SizedBox.shrink() // 載入中時下方留白，上方已有進度條
                        : const Text("目前沒有成績資料\n請嘗試點擊右上角重新整理", textAlign: TextAlign.center),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  itemCount: results.length,
                  itemBuilder: (context, index) {
                    final courseData = results[index];
                    // 使用 List.from 並明確指定類型，或使用 map 轉換
                  final scores = (courseData['scores'] as List)
                      .map((item) => Map<String, String>.from(item))
                      .toList();

                    return Card(
                      elevation: 2,
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      clipBehavior: Clip.antiAlias,
                      child: ExpansionTile(
                        initiallyExpanded: false,
                        leading: CircleAvatar(
                          backgroundColor: Colors.blue[50],
                          child: Icon(Icons.book_rounded, color: Colors.blue[700]),
                        ),
                        title: Text(
                          courseData['course_name'],
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.black87,
                          ),
                        ),
                        trailing: _buildTrailingWidget(scores),
                        children: [
                          if (scores.isNotEmpty) ...[
                            Container(
                              color: Colors.grey[50],
                              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                              child: Row(
                                children: const [
                                  Expanded(flex: 3, child: Text("評分項目", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                                  Expanded(flex: 2, child: Text("比例", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 13))),
                                  Expanded(flex: 2, child: Text("得分", textAlign: TextAlign.end, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                                ],
                              ),
                            ),
                            const Divider(height: 1),
                            ...scores.map((scoreItem) {
                              bool isTotal = (scoreItem['item'] ?? "").contains("總成績");
                              
                              return Container(
                                color: isTotal ? Colors.yellow.withOpacity(0.1) : Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
                                child: Row(
                                  children: [
                                    Expanded(
                                      flex: 3,
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(scoreItem['item'] ?? "", style: TextStyle(fontSize: 15, fontWeight: isTotal ? FontWeight.bold : FontWeight.normal)),
                                          if ((scoreItem['note'] ?? "").isNotEmpty)
                                            Text(scoreItem['note']!, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                        ],
                                      ),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Text(scoreItem['percentage'] ?? "", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[600], fontSize: 14)),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        scoreItem['raw_score'] ?? "-",
                                        textAlign: TextAlign.end,
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: (double.tryParse(scoreItem['raw_score'] ?? "0") ?? 0) < 60 ? Colors.red : Colors.green[800],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ] else 
                            const Padding(
                              padding: EdgeInsets.all(20.0),
                              child: Text("此課程尚無詳細評分明細"),
                            ),
                          const SizedBox(height: 8),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}