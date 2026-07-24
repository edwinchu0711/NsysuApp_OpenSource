import 'package:flutter/material.dart';
import '../services/open_score_service.dart';
import '../services/offline_error_handler.dart';
import '../theme/app_theme.dart';
import '../theme/layout_style_notifier.dart';
import '../widgets/glass/glass_page_scaffold.dart';
import '../widgets/glass/glass_dialog.dart';
import '../widgets/glass/glass_card.dart';

class OpenScorePage extends StatefulWidget {
  const OpenScorePage({Key? key}) : super(key: key);

  @override
  State<OpenScorePage> createState() => _OpenScorePageState();
}

class _OpenScorePageState extends State<OpenScorePage> {
  int _selectedIndex = 0;

  /// 根據分數取得對應顏色 (支援暗色模式)
  Color _getScoreColor(String rawScore, ColorScheme colorScheme) {
    final cleaned = rawScore.trim();
    final double? scoreValue = double.tryParse(cleaned);

    if (scoreValue != null) {
      if (scoreValue >= 90) {
        return colorScheme.isDark
            ? const Color.fromARGB(255, 77, 210, 146)
            : Colors.green[700]!;
      } else if (scoreValue >= 60) {
        return colorScheme.primaryText;
      } else {
        return colorScheme.isDark ? Colors.redAccent[100]! : Colors.redAccent;
      }
    } else {
      // 等第制
      if (cleaned == "A+") {
        return colorScheme.isDark
            ? const Color.fromARGB(255, 77, 210, 146)
            : Colors.green[700]!;
      } else if (cleaned == "F" || cleaned == "E" || cleaned == "X") {
        return colorScheme.isDark ? Colors.redAccent[100]! : Colors.redAccent;
      } else {
        return colorScheme.primaryText;
      }
    }
  }

  /// 建立右側狀態顯示區塊 (總分或查無資料)
  Widget _buildTrailingWidget(
    List<Map<String, String>> scores,
    ColorScheme colorScheme,
  ) {
    // 1. 如果完全沒有分數資料
    if (scores.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: colorScheme.warningContainer,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: colorScheme.isDark
                ? Colors.orange.shade800
                : Colors.orange.shade300,
          ),
        ),
        child: Text(
          "無資料",
          style: TextStyle(
            color: colorScheme.isDark
                ? Colors.orange[200]
                : Colors.deepOrange[700],
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
      );
    }

    // 2. 尋找總成績項目 (比對 key: item)
    final totalScoreEntry = scores.firstWhere(
      (s) =>
          (s['item'] ?? "").contains("總成績") ||
          (s['item'] ?? "").contains("原始總成績"),
      orElse: () => {},
    );

    if (totalScoreEntry.isEmpty) {
      return const Icon(Icons.expand_more);
    }

    final String scoreText = totalScoreEntry['raw_score'] ?? "-";

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
                color: _getScoreColor(scoreText, colorScheme),
              ),
            ),
          ],
        ),
        const SizedBox(width: 4),
        Icon(Icons.expand_more, color: colorScheme.subtitleText),
      ],
    );
  }

  /// 建立寬螢幕底下的詳細成績面板
  Widget _buildDetailPanel(
    Map<String, dynamic> courseData,
    ColorScheme colorScheme,
  ) {
    final scores = (courseData['scores'] as List)
        .map((item) => Map<String, String>.from(item))
        .toList();

    // 尋找總成績項目
    final totalScoreEntry = scores.firstWhere(
      (s) =>
          (s['item'] ?? "").contains("總成績") ||
          (s['item'] ?? "").contains("原始總成績"),
      orElse: () => {},
    );
    final String totalScoreText = totalScoreEntry['raw_score'] ?? "-";

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 頂部課程彙整卡片
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: colorScheme.isDark
                  ? [Colors.teal[900]!, Colors.teal[800]!]
                  : [const Color(0xFFE0F2F1), const Color(0xFFB2DFDB)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color:
                    (colorScheme.isDark ? Colors.teal[200]! : Colors.teal[800]!)
                        .withValues(alpha: 0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "已選中課程",
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.isDark
                            ? Colors.teal[200]
                            : Colors.teal[800],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      courseData['course_name'],
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.isDark
                            ? Colors.white
                            : Colors.teal[900],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    "總分",
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.isDark
                          ? Colors.teal[200]
                          : Colors.teal[800],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    totalScoreText,
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: _getScoreColor(totalScoreText, colorScheme),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // 下半部明細列表 (獨立滾動)
        Expanded(
          child: Container(
            decoration: glassCardDecoration(context, borderRadius: 16) ??
                BoxDecoration(
                  color: colorScheme.cardBackground,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: colorScheme.borderColor.withValues(alpha: 0.5),
                  ),
                ),
            clipBehavior: Clip.antiAlias,
            child: scores.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(20.0),
                      child: Text("此課程尚無詳細評分明細"),
                    ),
                  )
                : ListView(
                    padding: EdgeInsets.only(
                      bottom: LayoutStyleNotifier.instance.isLiquidGlass ? 100 : 0,
                    ),
                    children: [
                       Container(
                        color: LayoutStyleNotifier.instance.isLiquidGlass
                            ? Colors.transparent
                            : colorScheme.secondaryCardBackground,
                        padding: const EdgeInsets.symmetric(
                          vertical: 12,
                          horizontal: 20,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: Text(
                                "評分項目",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: colorScheme.primaryText,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                "比例",
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: colorScheme.subtitleText,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                "得分",
                                textAlign: TextAlign.end,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: colorScheme.primaryText,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                      ...scores.map((scoreItem) {
                        bool isTotal =
                            (scoreItem['item'] ?? "").contains("總成績") ||
                            (scoreItem['item'] ?? "").contains("原始總成績");

                        return Container(
                          color: LayoutStyleNotifier.instance.isLiquidGlass
                              ? Colors.transparent
                              : (isTotal
                                  ? (colorScheme.isDark
                                      ? Colors.yellow[900]?.withValues(alpha: 0.1)
                                      : Colors.yellow.withValues(alpha: 0.04))
                                  : colorScheme.cardBackground),
                          padding: const EdgeInsets.symmetric(
                            vertical: 14.0,
                            horizontal: 20.0,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      scoreItem['item'] ?? "",
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: isTotal
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                        color: colorScheme.primaryText,
                                      ),
                                    ),
                                    if ((scoreItem['note'] ?? "")
                                        .isNotEmpty) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        scoreItem['note']!,
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: colorScheme.subtitleText,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  scoreItem['percentage'] ?? "",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: colorScheme.subtitleText,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  scoreItem['raw_score'] ?? "-",
                                  textAlign: TextAlign.end,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: _getScoreColor(
                                      scoreItem['raw_score'] ?? "0",
                                      colorScheme,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth >= 750;

    return GlassPageScaffold(
      appBar: AppBar(
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          tooltip: "返回",
          onPressed: () => Navigator.maybePop(context),
        ),
        title: ValueListenableBuilder<String?>(
          valueListenable: OpenScoreService.instance.lastUpdatedNotifier,
          builder: (context, lastUpdated, child) {
            return FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    "開放成績查詢",
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  if (lastUpdated != null && lastUpdated.isNotEmpty)
                    Text(
                      "最近更新: $lastUpdated",
                      style: TextStyle(
                        fontSize: 11,
                        color: colorScheme.subtitleText,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                ],
              ),
            );
          },
        ),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(
              Icons.info_outline_rounded,
              color: Colors.blueGrey,
            ),
            tooltip: "自動更新期間說明",
            onPressed: () {
              showGlassDialog(
                context: context,
                title: const Text("開放成績自動更新說明"),
                content: const Text(
                  "為了節省校務系統資源與電力，本 App 僅在「成績開放查詢期間」才會在啟動時自動於背景更新開放成績。\n\n"
                  "• 冬季開放期間：12/15 ~ 1/25\n"
                  "• 夏季開放期間：5/15 ~ 6/25\n\n"
                  "※ 非上述自動更新期間，您仍可隨時點擊右上角的重新整理按鈕手動更新資料。",
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
                    child: const Text("確定"),
                  ),
                ],
              );
            },
          ),
          ValueListenableBuilder<bool>(
            valueListenable: OpenScoreService.instance.isLoadingNotifier,
            builder: (context, isLoading, child) {
              return IconButton(
                icon: isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh),
                onPressed: isLoading
                    ? null
                    : () async {
                        if (await OfflineErrorHandler.handleRefresh(context)) return;
                        try {
                          ScaffoldMessenger.of(context).hideCurrentSnackBar();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("正在重新抓取資料..."),
                              duration: Duration(seconds: 1),
                            ),
                          );
                          await OpenScoreService.instance.fetchOpenScores();
                        } catch (e) {
                          if (mounted) {
                            await OfflineErrorHandler.show(context, e);
                          }
                        }
                      },
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // 錯誤提示區塊
          ValueListenableBuilder<String?>(
            valueListenable: OpenScoreService.instance.errorCodeNotifier,
            builder: (context, errorCode, child) {
              if (errorCode == null || errorCode.isEmpty) {
                return const SizedBox.shrink();
              }
              return Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 
                      colorScheme.isDark ? 0.2 : 0.07,
                    ),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.red.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 1),
                        child: Icon(
                          Icons.error_outline_rounded,
                          color: Colors.red,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          errorCode,
                          style: const TextStyle(
                            color: Colors.red,
                            fontSize: 13,
                            fontWeight: FontWeight.w400,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),

          // 1. 進度條區塊
          ValueListenableBuilder<bool>(
            valueListenable: OpenScoreService.instance.isLoadingNotifier,
            builder: (context, isLoading, child) {
              // 如果沒有在載入中，這裡什麼都不顯示 (height: 0)
              if (!isLoading) return const SizedBox.shrink();

              // 只回傳進度條
              return ValueListenableBuilder<double>(
                valueListenable: OpenScoreService.instance.progressNotifier,
                builder: (ctx, progress, _) => LinearProgressIndicator(
                  value: progress,
                  minHeight: 4,
                  backgroundColor: colorScheme.secondaryCardBackground,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    colorScheme.accentBlue,
                  ),
                ),
              );
            },
          ),

          // 2. 資料列表區塊
          Expanded(
            child: ValueListenableBuilder<List<Map<String, dynamic>>>(
              valueListenable: OpenScoreService.instance.resultsNotifier,
              builder: (context, results, child) {
                bool isLoading =
                    OpenScoreService.instance.isLoadingNotifier.value;

                if (results.isEmpty) {
                  return Center(
                    child: isLoading
                        ? const SizedBox.shrink()
                        : const Text(
                            "目前沒有成績資料\n請嘗試點擊右上角重新整理",
                            textAlign: TextAlign.center,
                          ),
                  );
                }

                // 安全邊界檢查，防範資料重新整理後 _selectedIndex 越界
                if (_selectedIndex >= results.length) {
                  _selectedIndex = 0;
                }

                if (isTablet) {
                  final double horizontalPadding = screenWidth > 1020
                      ? (screenWidth - 1020) / 2 + 16.0
                      : 16.0;

                  return Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: horizontalPadding,
                      vertical: 16,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 左側：課程 Master 列表 (固定寬度 320, 獨立滾動)
                        SizedBox(
                          width: 320,
                          child: ListView.builder(
                            padding: EdgeInsets.only(
                              bottom: LayoutStyleNotifier.instance.isLiquidGlass ? 100 : 0,
                            ),
                            itemCount: results.length,
                            itemBuilder: (context, index) {
                              final courseData = results[index];
                              final isSelected = index == _selectedIndex;
                              final scores = (courseData['scores'] as List)
                                  .map((item) => Map<String, String>.from(item))
                                  .toList();

                              // 尋找總分
                              final totalScoreEntry = scores.firstWhere(
                                (s) =>
                                    (s['item'] ?? "").contains("總成績") ||
                                    (s['item'] ?? "").contains("原始總成績"),
                                orElse: () => {},
                              );
                              final String scoreText =
                                  totalScoreEntry['raw_score'] ?? "-";

                              return Container(
                                margin: const EdgeInsets.only(bottom: 6),
                                decoration: glassCardDecoration(
                                      context,
                                      borderRadius: 12,
                                      isSelected: isSelected,
                                      selectedColor: colorScheme.primary,
                                    ) ??
                                    BoxDecoration(
                                      color: isSelected
                                          ? colorScheme.primaryContainer
                                                .withValues(alpha: 0.3)
                                          : colorScheme.cardBackground,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: isSelected
                                            ? colorScheme.primary
                                            : colorScheme.borderColor.withValues(alpha: 
                                                0.5,
                                              ),
                                        width: isSelected ? 1.5 : 1.0,
                                      ),
                                    ),
                                child: ListTile(
                                  dense: true,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 2,
                                  ),
                                  leading: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: LayoutStyleNotifier.instance.isLiquidGlass
                                          ? Colors.transparent
                                          : (isSelected
                                              ? colorScheme.primary.withValues(alpha: 0.1)
                                              : colorScheme.secondaryCardBackground),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.book_rounded,
                                      color: isSelected
                                          ? colorScheme.primary
                                          : colorScheme.accentBlue,
                                      size: 16,
                                    ),
                                  ),
                                  title: Text(
                                    courseData['course_name'],
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: colorScheme.primaryText,
                                    ),
                                  ),
                                  trailing: Text(
                                    scoreText,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: _getScoreColor(
                                        scoreText,
                                        colorScheme,
                                      ),
                                    ),
                                  ),
                                  onTap: () {
                                    setState(() {
                                      _selectedIndex = index;
                                    });
                                  },
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 24),
                        // 右側：選中課程的 Detail 詳情 (獨立滾動)
                        Expanded(
                          child: _buildDetailPanel(
                            results[_selectedIndex],
                            colorScheme,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                // 手機版：維持原有的 ExpansionTile 折疊卡片列表
                return ListView.builder(
                  padding: EdgeInsets.only(
                    left: 12,
                    right: 12,
                    top: 10,
                    bottom: LayoutStyleNotifier.instance.isLiquidGlass ? 100 : 10,
                  ),
                  itemCount: results.length,
                  itemBuilder: (context, index) {
                    final courseData = results[index];
                    final scores = (courseData['scores'] as List)
                        .map((item) => Map<String, String>.from(item))
                        .toList();

                    final tile = ExpansionTile(
                        initiallyExpanded: false,
                        leading: CircleAvatar(
                          backgroundColor: LayoutStyleNotifier.instance.isLiquidGlass
                              ? Colors.transparent
                              : colorScheme.secondaryCardBackground,
                          child: Icon(
                            Icons.book_rounded,
                            color: colorScheme.accentBlue,
                          ),
                        ),
                        title: Text(
                          courseData['course_name'],
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: colorScheme.primaryText,
                          ),
                        ),
                        trailing: _buildTrailingWidget(scores, colorScheme),
                        children: [
                          if (scores.isNotEmpty) ...[
                            Container(
                              color: LayoutStyleNotifier.instance.isLiquidGlass
                                  ? Colors.transparent
                                  : colorScheme.secondaryCardBackground,
                              padding: const EdgeInsets.symmetric(
                                vertical: 8,
                                horizontal: 16,
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    flex: 3,
                                    child: Text(
                                      "評分項目",
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      "比例",
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: colorScheme.subtitleText,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      "得分",
                                      textAlign: TextAlign.end,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Divider(height: 1),
                            ...scores.map((scoreItem) {
                              bool isTotal = (scoreItem['item'] ?? "").contains(
                                "總成績",
                              );

                              return Container(
                                color: LayoutStyleNotifier.instance.isLiquidGlass
                                    ? Colors.transparent
                                    : (isTotal
                                        ? (colorScheme.isDark
                                            ? Colors.yellow[900]?.withValues(
                                                alpha: 0.1,
                                              )
                                            : Colors.yellow.withValues(
                                                alpha: 0.04,
                                              ))
                                        : colorScheme.cardBackground),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12.0,
                                  horizontal: 16.0,
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      flex: 3,
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            scoreItem['item'] ?? "",
                                            style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: isTotal
                                                  ? FontWeight.bold
                                                  : FontWeight.normal,
                                            ),
                                          ),
                                          if ((scoreItem['note'] ?? "")
                                              .isNotEmpty)
                                            Text(
                                              scoreItem['note']!,
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: colorScheme.subtitleText,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        scoreItem['percentage'] ?? "",
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: colorScheme.subtitleText,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        scoreItem['raw_score'] ?? "-",
                                        textAlign: TextAlign.end,
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: _getScoreColor(
                                            scoreItem['raw_score'] ?? "0",
                                            colorScheme,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ] else
                            const Padding(
                              padding: EdgeInsets.all(20.0),
                              child: Text("此課程尚無詳細評分明細"),
                            ),
                          const SizedBox(height: 8),
                        ],
                      );

                    if (LayoutStyleNotifier.instance.isLiquidGlass) {
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        clipBehavior: Clip.antiAlias,
                        decoration: glassCardDecoration(context, borderRadius: 15) ??
                            const BoxDecoration(color: Colors.transparent),
                        child: Material(
                          color: Colors.transparent,
                          child: tile,
                        ),
                      );
                    }
                    return Card(
                      elevation: 2,
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: tile,
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
