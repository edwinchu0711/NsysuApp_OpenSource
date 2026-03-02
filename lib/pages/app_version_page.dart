import 'package:flutter/material.dart';

// 1. 這裡加上 const 關鍵字，修復「isn't a const constructor」的問題
class VersionRecord {
  final String version;
  final String date;
  final String description;
  final bool isBeta;

  const VersionRecord({
    required this.version,
    required this.date,
    required this.description,
    this.isBeta = false,
  });
}

class AppVersionPage extends StatelessWidget {
  const AppVersionPage({Key? key}) : super(key: key);

  // 2. 現在這裡可以使用 const list 了
  final List<VersionRecord> history = const [
    VersionRecord(
      version: "v5.0.0",
      date: "2026-03-02",
      description: "移除登入紀錄、新增異常處理功能、移除更新功能（這是最後一版了，我要去忙其他事情了，謝謝大家一路上的支持😇）",
    ),
    VersionRecord(
      version: "v4.3.0",
      date: "2026-02-27",
      description: "新增選課助手功能、優化選課時程抓取方式、加入課程配分資訊",
    ),
    VersionRecord(
      version: "v4.2.0",
      date: "2026-02-23",
      description: "修改AppID(安裝後會有新的app，即可把舊的刪掉，之後才不會被其他app覆蓋過去)",
    ),
    VersionRecord(
      version: "v4.1.3",
      date: "2026-02-14",
      description: "初始化優化、課表新增第9節、課表時間修復",
    ),
    VersionRecord(
      version: "v4.1.2",
      date: "2026-02-11",
      description: "初始化功能修正、選課優化",
    ),
    VersionRecord(
      version: "v4.1.1",
      date: "2026-01-31",
      description: "新增選課課表預覽、修復選課問題",
    ),
    VersionRecord(
      version: "v4.1.0",
      date: "2026-01-30",
      description: "新增選課功能",
    ),
    VersionRecord(
      version: "v4.0.0",
      date: "2026-01-28",
      description: "新增行事曆、選課日程，增加通知功能、更新版本提醒和預覽名次功能",
    ),
    VersionRecord(
      version: "v3.1.1",
      date: "2026-01-15",
      description: "優化登入檢驗部分，防止亂碼登入",
    ),
    VersionRecord(
      version: "v3.1.0",
      date: "2026-01-13",
      description: "六個功能完整可使用",
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text("版本資訊", style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.all(24.0),
              margin: const EdgeInsets.only(bottom: 10),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
              ),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 35,
                    backgroundColor: Colors.green[100],
                    child: const Icon(Icons.verified_rounded, size: 35, color: Colors.green),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    "當前版本: v5.0.0",
                    style: TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    "已是最新版本",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "感謝您的使用",
                    style: TextStyle(color: Colors.grey[500], fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, 10),
              child: Text("版本歷史紀錄", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final item = history[index];
                return _buildHistoryCard(item);
              },
              childCount: history.length,
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }

  Widget _buildHistoryCard(VersionRecord item) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            spreadRadius: 1,
            blurRadius: 5,
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
                item.version,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  item.date,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            item.description,
            style: TextStyle(fontSize: 14, color: Colors.grey[800], height: 1.5),
          ),
        ],
      ),
    );
  }
}