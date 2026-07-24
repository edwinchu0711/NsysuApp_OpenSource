import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../theme/layout_style_notifier.dart';
import '../widgets/glass/glass_page_scaffold.dart';
import '../widgets/glass/glass_card.dart';

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
      version: "v6.1.3",
      date: "2026-07-08",
      description: "新增全新主題、優化初始化、優化頁面渲染、修復課程查詢Bug",
    ),
    VersionRecord(
      version: "v6.1.2",
      date: "2026-07-01",
      description: "UI/UX優化、課表內容新增學程與開課系所、新增預覽名次設定",
    ),
    VersionRecord(
      version: "v6.1.1",
      date: "2026-06-28",
      description: "資料抓取優化、後台任務流程優化、選課匯入新增學期選擇、\"開放成績查詢\"功能自動抓取期間調整",
    ),
    VersionRecord(
      version: "v6.1.0",
      date: "2026-06-21",
      description: "UI/UX優化、新增試算總平均GPA、優化成績抓取、選課優化",
    ),
    VersionRecord(
      version: "v6.0.0",
      date: "2026-05-26",
      description: "UI/UX全面優化、新增學程進度、分數試算、校園公車、關於開發者介面與深色模式",
    ),
    VersionRecord(
      version: "v5.0.0",
      date: "2026-03-02",
      description: "移除登入紀錄、移除通知功能、新增異常處理功能、移除更新功能",
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
    VersionRecord(version: "v4.1.0", date: "2026-01-30", description: "新增選課功能"),
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
    final colorScheme = Theme.of(context).colorScheme;
    final isWide = MediaQuery.of(context).size.width >= 800;
    final isLiquidGlass = LayoutStyleNotifier.instance.isLiquidGlass;

    if (isWide) {
      return GlassPageScaffold(
        appBar: AppBar(
          title: const Text(
            "版本資訊",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
          backgroundColor: isLiquidGlass
              ? Colors.transparent
              : colorScheme.cardBackground,
          foregroundColor: colorScheme.primaryText,
          elevation: 0,
          iconTheme: IconThemeData(color: colorScheme.primaryText),
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left Column: Current App Info Card
                  SizedBox(
                    width: 320,
                    child: Container(
                      padding: const EdgeInsets.all(24.0),
                      // liquid glass：學生服務系統區塊不使用模糊背景，直接透出極光；
                      // 其他模式維持原卡片樣式。
                      decoration: isLiquidGlass
                          ? null
                          : BoxDecoration(
                              color: colorScheme.cardBackground,
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: colorScheme.borderColor,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.02),
                                  spreadRadius: 1,
                                  blurRadius: 5,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildInfoIcon(context, 40),
                          const SizedBox(height: 20),
                          Text(
                            "學生服務系統",
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: colorScheme.primaryText,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: colorScheme.secondaryCardBackground,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              "當前版本: v6.1.3",
                              style: TextStyle(
                                color: colorScheme.accentBlue,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          Divider(color: colorScheme.borderColor),
                          const SizedBox(height: 16),
                          Text(
                            "本應用程式由開源社群維護與開發，持續為學生提供更便利的校園生活服務體驗。",
                            style: TextStyle(
                              color: colorScheme.subtitleText,
                              fontSize: 13,
                              height: 1.5,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 24),
                  // Right Column: Version History List
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(
                            left: 8.0,
                            bottom: 16.0,
                          ),
                          child: Text(
                            "版本歷史紀錄",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: colorScheme.primaryText,
                            ),
                          ),
                        ),
                        Expanded(
                          child: ListView.builder(
                            itemCount: history.length,
                            padding: EdgeInsets.only(
                              bottom: LayoutStyleNotifier.instance.isLiquidGlass
                                  ? 100
                                  : 0,
                            ),
                            itemBuilder: (context, index) {
                              final item = history[index];
                              return _buildHistoryCard(context, item);
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // Mobile layout (EXACTLY as original)
    return GlassPageScaffold(
      appBar: AppBar(
        title: const Text(
          "版本資訊",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: isLiquidGlass
            ? Colors.transparent
            : colorScheme.cardBackground,
        foregroundColor: colorScheme.primaryText,
        elevation: 0,
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.all(24.0),
              margin: const EdgeInsets.only(bottom: 10),
              // liquid glass：學生服務系統區塊不使用模糊背景，直接透出極光；
              // 其他模式維持原卡片樣式。
              decoration: isLiquidGlass
                  ? null
                  : BoxDecoration(
                      color: colorScheme.cardBackground,
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(30),
                        bottomRight: Radius.circular(30),
                      ),
                      border: Border(
                        bottom: BorderSide(color: colorScheme.borderColor),
                      ),
                    ),
              child: Column(
                children: [
                  _buildInfoIcon(context, 35),
                  const SizedBox(height: 16),
                  Text(
                    "學生服務系統",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.primaryText,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "當前版本: v6.1.3",
                    style: TextStyle(
                      color: colorScheme.subtitleText,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
              child: Text(
                "版本歷史紀錄",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.primaryText,
                ),
              ),
            ),
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
              final item = history[index];
              return _buildHistoryCard(context, item);
            }, childCount: history.length),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: LayoutStyleNotifier.instance.isLiquidGlass ? 100 : 40,
            ),
          ),
        ],
      ),
    );
  }

  /// 應用程式資訊 icon：liquid glass 模式下以半透明圓框框起來；
  /// 其他模式維持原本的淡藍色圓底 CircleAvatar。
  Widget _buildInfoIcon(BuildContext context, double radius) {
    final isLiquidGlass = LayoutStyleNotifier.instance.isLiquidGlass;
    if (!isLiquidGlass) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: Colors.blue[50],
        child: Icon(
          Icons.info_outline_rounded,
          size: radius,
          color: Colors.blue,
        ),
      );
    }
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isDark
            ? Colors.white.withValues(alpha: 0.10)
            : Colors.white.withValues(alpha: 0.5),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.14)
              : Colors.white.withValues(alpha: 0.4),
        ),
      ),
      child: Icon(Icons.info_outline_rounded, size: radius, color: Colors.blue),
    );
  }

  Widget _buildHistoryCard(BuildContext context, VersionRecord item) {
    final colorScheme = Theme.of(context).colorScheme;
    final isLiquidGlass = LayoutStyleNotifier.instance.isLiquidGlass;
    final isDark = colorScheme.isDark;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: isLiquidGlass
          ? glassCardDecoration(context, borderRadius: 12)
          : BoxDecoration(
              color: colorScheme.cardBackground,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colorScheme.borderColor, width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
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
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.primaryText,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isLiquidGlass
                      ? (isDark
                            ? Colors.white.withValues(alpha: 0.10)
                            : Colors.white.withValues(alpha: 0.5))
                      : colorScheme.secondaryCardBackground,
                  borderRadius: BorderRadius.circular(6),
                  border: isLiquidGlass
                      ? Border.all(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.14)
                              : Colors.white.withValues(alpha: 0.4),
                        )
                      : null,
                ),
                child: Text(
                  item.date,
                  style: TextStyle(
                    fontSize: 12,
                    color: isLiquidGlass
                        ? colorScheme.primaryText
                        : colorScheme.subtitleText,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            item.description,
            style: TextStyle(
              fontSize: 14,
              color: colorScheme.bodyText,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
