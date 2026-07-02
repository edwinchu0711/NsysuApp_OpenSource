import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/historical_score_service.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_dropdown.dart';

class ScoreResultPage extends StatefulWidget {
  const ScoreResultPage({Key? key}) : super(key: key);

  @override
  State<ScoreResultPage> createState() => _ScoreResultPageState();
}

enum SummaryType { official, preview, calculated }

class _ScoreResultPageState extends State<ScoreResultPage> {
  String? _selectedYear;
  String? _selectedSem;
  bool _hasInitializedSelection = false;
  String? _selectedCourseId;
  Timer? _refreshTimer;
  bool _isLongPressTriggered = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth >= 750;
    final double horizontalPadding = screenWidth > 1020
        ? (screenWidth - 1020) / 2 + 16.0
        : 16.0;
    return ValueListenableBuilder<bool>(
      valueListenable: HistoricalScoreService.instance.isLoadingNotifier,
      builder: (context, isLoading, _) {
        return Scaffold(
          backgroundColor: colorScheme.pageBackground,
          appBar: AppBar(
            titleSpacing: 0,
            centerTitle: false,
            title: ValueListenableBuilder<String?>(
              valueListenable:
                  HistoricalScoreService.instance.syncErrorNotifier,
              builder: (context, syncError, _) {
                return ValueListenableBuilder<String?>(
                  valueListenable:
                      HistoricalScoreService.instance.lastUpdatedNotifier,
                  builder: (context, lastUpdated, _) {
                    return FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            "歷年成績查詢",
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          if (syncError != null)
                            GestureDetector(
                              onTap: () {
                                showDialog(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text("同步失敗資訊"),
                                    content: Text(syncError),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context),
                                        child: const Text("確定"),
                                      ),
                                    ],
                                  ),
                                );
                              },
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    "同步失敗",
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: colorScheme.isDark
                                          ? Colors.redAccent[100]
                                          : Colors.red[700],
                                      fontWeight: FontWeight.w500,
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(
                                    Icons.info_outline_rounded,
                                    size: 12,
                                    color: colorScheme.isDark
                                        ? Colors.redAccent[100]
                                        : Colors.red[700],
                                  ),
                                ],
                              ),
                            )
                          else if (lastUpdated != null &&
                              lastUpdated.isNotEmpty)
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
                );
              },
            ),
            elevation: 0,
            actions: [
              // 資訊按鈕
              IconButton(
                icon: Icon(Icons.info_outline_rounded, color: Colors.blueGrey),
                tooltip: "預覽功能說明",
                onPressed: () {
                  _showPreviewStatusDialog();
                },
              ),
              // 重新整理按鈕
              GestureDetector(
                onTapDown: isLoading
                    ? null
                    : (details) {
                        _isLongPressTriggered = false;
                        _refreshTimer = Timer(
                          const Duration(milliseconds: 2500),
                          () {
                            _isLongPressTriggered = true;
                            HistoricalScoreService.instance.fetchAllData(
                              forceFullRefresh: true,
                            );
                          },
                        );
                      },
                onTapUp: isLoading
                    ? null
                    : (details) {
                        _refreshTimer?.cancel();
                        if (!_isLongPressTriggered) {
                          HistoricalScoreService.instance.fetchAllData(
                            forceFullRefresh: false,
                          );
                        }
                      },
                onTapCancel: isLoading
                    ? null
                    : () {
                        _refreshTimer?.cancel();
                      },
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 12.0,
                  ),
                  child: isLoading
                      ? const Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : const Icon(Icons.refresh),
                ),
              ),
            ],
          ),
          body: Column(
            children: [
              if (isLoading)
                ValueListenableBuilder<double>(
                  valueListenable:
                      HistoricalScoreService.instance.progressNotifier,
                  builder: (context, progress, _) => LinearProgressIndicator(
                    value: progress,
                    backgroundColor: colorScheme.secondaryCardBackground,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      colorScheme.accentBlue,
                    ),
                  ),
                ),

              Expanded(
                child: ValueListenableBuilder<Set<String>>(
                  valueListenable:
                      HistoricalScoreService.instance.validYearsNotifier,
                  builder: (context, validYearsSet, child) {
                    if (validYearsSet.isEmpty) {
                      return Center(
                        child: isLoading
                            ? const Text(
                                "正在搜尋歷年成績...\n請稍候",
                                textAlign: TextAlign.center,
                              )
                            : const Text("查無任何成績資料"),
                      );
                    }

                    List<String> sortedYears = validYearsSet.toList()
                      ..sort((a, b) => int.parse(b).compareTo(int.parse(a)));

                    if (_selectedYear == null ||
                        !validYearsSet.contains(_selectedYear)) {
                      _selectedYear = sortedYears.first;
                    }

                    List<String> availableSems =
                        HistoricalScoreService
                            .instance
                            .validSemestersNotifier
                            .value[_selectedYear] ??
                        [];
                    availableSems.sort();

                    if (_selectedSem == null ||
                        !availableSems.contains(_selectedSem)) {
                      _selectedSem = availableSems.last;
                    }

                    return isTablet
                        ? _buildScoreListContent(
                            _selectedYear!,
                            _selectedSem!,
                            isTablet: true,
                            horizontalPadding: horizontalPadding,
                            sortedYears: sortedYears,
                            availableSems: availableSems,
                          )
                        : Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.only(
                                  left: 16,
                                  right: 16,
                                  top: 4,
                                  bottom: 10,
                                ),
                                color: colorScheme.cardBackground,
                                child: _buildDropdownRow(
                                  sortedYears: sortedYears,
                                  availableSems: availableSems,
                                  isTablet: false,
                                ),
                              ),
                              Expanded(
                                child: _buildScoreListContent(
                                  _selectedYear!,
                                  _selectedSem!,
                                  isTablet: false,
                                  horizontalPadding: horizontalPadding,
                                  sortedYears: sortedYears,
                                  availableSems: availableSems,
                                ),
                              ),
                            ],
                          );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDropdownRow({
    required List<String> sortedYears,
    required List<String> availableSems,
    required bool isTablet,
  }) {
    return Row(
      children: [
        Expanded(
          child: _buildDropdown("學年", sortedYears, _selectedYear!, (val) {
            setState(() {
              _selectedYear = val;
              _selectedSem = null;
            });
          }),
        ),
        SizedBox(width: isTablet ? 12 : 16),
        Expanded(
          child: _buildDropdown(
            "學期",
            availableSems,
            _selectedSem!,
            (val) {
              setState(() => _selectedSem = val);
            },
            displayMap: const {"0": "碩專暑", "1": "上學期", "2": "下學期", "3": "暑修"},
          ),
        ),
      ],
    );
  }

  Widget _buildScoreListContent(
    String year,
    String sem, {
    required bool isTablet,
    required double horizontalPadding,
    required List<String> sortedYears,
    required List<String> availableSems,
  }) {
    String key = "$year-$sem";
    final courses =
        HistoricalScoreService.instance.coursesNotifier.value[key] ?? [];

    // 取得原始官方資料
    var officialSummary =
        HistoricalScoreService.instance.summaryNotifier.value[key] ??
        ScoreSummary();

    // 取得預覽資料
    var previewData =
        HistoricalScoreService.instance.previewRanksNotifier.value[key];

    if (courses.isEmpty) {
      return Center(child: Text("資料載入異常"));
    }

    // 將有成績的課程放在最上方，無成績的課程放在下方，其餘相對順序保持不變
    final List<CourseScore> gradedCourses = [];
    final List<CourseScore> ungradedCourses = [];
    for (var c in courses) {
      final cleaned = c.score.replaceAll(RegExp(r'[\s\u00A0]+'), '');
      if (cleaned.isNotEmpty && cleaned != '-') {
        gradedCourses.add(c);
      } else {
        ungradedCourses.add(c);
      }
    }
    final sortedCourses = [...gradedCourses, ...ungradedCourses];

    // --- 輔助判斷函式 ---
    bool hasValidValue(String? value) {
      return value != null && value.isNotEmpty && value != "-";
    }

    // --- 決定顯示哪種 Summary ---
    ScoreSummary finalSummary;
    SummaryType type;

    bool isOfficialValid = hasValidValue(officialSummary.average);

    if (isOfficialValid) {
      finalSummary = officialSummary;
      type = SummaryType.official;

      if (!hasValidValue(finalSummary.rank) &&
          previewData != null &&
          hasValidValue(previewData['rank'])) {
        finalSummary.rank = previewData['rank']!;
        finalSummary.classSize = previewData['classSize'] ?? "-";
      }
    } else {
      ScoreSummary calculated = _calculateSemesterSummary(sortedCourses);

      bool hasPreviewRank =
          previewData != null && hasValidValue(previewData['rank']);

      if (hasPreviewRank) {
        finalSummary = ScoreSummary(
          creditsTaken: calculated.creditsTaken,
          creditsEarned: calculated.creditsEarned,
          average: calculated.average,
          rank: previewData['rank']!,
          classSize: previewData['classSize'] ?? "-",
        );
        type = SummaryType.preview;
      } else {
        finalSummary = calculated;
        type = SummaryType.calculated;
      }
    }

    if (isTablet) {
      final colorScheme = Theme.of(context).colorScheme;
      return Padding(
        padding: EdgeInsets.symmetric(
          horizontal: horizontalPadding,
          vertical: 16,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 左側控制與統計面板 (固定寬度 340, 獨立滾動以防溢出)
            SizedBox(
              width: 340,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 篩選選單卡片
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: colorScheme.cardBackground,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: colorScheme.borderColor.withOpacity(0.08),
                            spreadRadius: 2,
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: _buildDropdownRow(
                        sortedYears: sortedYears,
                        availableSems: availableSems,
                        isTablet: true,
                      ),
                    ),
                    const SizedBox(height: 16),
                    // 統計摘要卡片
                    _buildSummaryCard(finalSummary, type),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 24),
            // 右側成績列表面板 (自適應寬度, 獨立滾動)
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  _buildTableHeader(),
                  const SizedBox(height: 8),
                  ...sortedCourses.map((c) => _buildCourseCard(c)).toList(),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        _buildSummaryCard(finalSummary, type),
        const SizedBox(height: 20),
        _buildTableHeader(),
        const SizedBox(height: 8),
        ...sortedCourses.map((c) => _buildCourseCard(c)).toList(),
        const SizedBox(height: 40),
      ],
    );
  }

  Future<void> _showPreviewStatusDialog() async {
    final prefs = await SharedPreferences.getInstance();
    int previewRankMode = 2;
    if (prefs.containsKey('preview_rank_mode')) {
      previewRankMode = prefs.getInt('preview_rank_mode') ?? 2;
    } else if (prefs.containsKey('is_preview_rank_enabled')) {
      bool? oldVal = prefs.getBool('is_preview_rank_enabled');
      if (oldVal == false) {
        previewRankMode = 1;
      } else if (oldVal == true) {
        previewRankMode = 2;
      }
    }

    String previewTitle = "";
    String previewContent = "";

    if (previewRankMode == 1) {
      previewTitle = "預覽名次：已關閉";
      previewContent =
          "目前已關閉預覽功能，查詢速度最快。\n\n"
          "若欲查看預覽名次，請至「設定 > 進階功能設定」中開啟。";
    } else if (previewRankMode == 2) {
      previewTitle = "預覽名次：部分期間開啟";
      previewContent =
          "目前開啟部分期間預覽。此功能僅在以下「成績開放查詢期間」才會抓取預覽名次：\n"
          "• 春夏季開放期：5/25 ~ 10/10\n"
          "• 秋冬季開放期：12/25 ~ 3/20\n\n"
          "※ 其餘時間為關閉狀態，不會進行預覽名次抓取以維持效率。";
    } else if (previewRankMode == 3) {
      previewTitle = "預覽名次：永久開啟";
      previewContent =
          "目前設定為永久開啟預覽名次，全年皆會嘗試進行抓取。\n\n"
          "※ 注意：在非期末期間系統可能查無預覽資料，且會顯著拉長查詢的等待時間。";
    }

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) {
        final colorScheme = Theme.of(context).colorScheme;
        return AlertDialog(
          title: const Text(
            "功能說明",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // 預覽名次區塊
                Row(
                  children: [
                    Icon(
                      Icons.preview_rounded,
                      size: 16,
                      color: colorScheme.primary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      previewTitle,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.primary,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  previewContent,
                  style: const TextStyle(height: 1.5, fontSize: 13),
                ),

                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),

                // 更新按鈕說明區塊
                Row(
                  children: [
                    Icon(Icons.refresh, size: 16, color: Colors.orange[700]),
                    const SizedBox(width: 6),
                    Text(
                      "更新按鈕操作說明",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.orange[700],
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _buildRefreshInfoRow(
                  icon: Icons.touch_app_outlined,
                  color: Colors.blueGrey,
                  title: "單擊 → 部分更新",
                  desc: "僅重新抓取近期學期，保留歷史舊成績，速度極快。",
                ),
                const SizedBox(height: 8),
                _buildRefreshInfoRow(
                  icon: Icons.touch_app,
                  color: Colors.deepOrange,
                  title: "長按 3 秒 → 完整更新",
                  desc: "從入學年度起重新抓取所有歷史學年度成績，耗時較長。",
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("了解"),
            ),
          ],
        );
      },
    );
  }

  Widget _buildRefreshInfoRow({
    required IconData icon,
    required Color color,
    required String title,
    required String desc,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: color,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 2),
              Text(desc, style: const TextStyle(fontSize: 12, height: 1.4)),
            ],
          ),
        ),
      ],
    );
  }

  ScoreSummary _calculateSemesterSummary(List<CourseScore> courses) {
    double totalWeightedPoints = 0;
    double gpaCredits = 0;
    double creditsTaken = 0;
    double creditsEarned = 0;

    final Map<String, double> gradePoints = {
      "A+": 4.3,
      "A": 4.0,
      "A-": 3.7,
      "B+": 3.3,
      "B": 3.0,
      "B-": 2.7,
      "C+": 2.3,
      "C": 2.0,
      "C-": 1.7,
      "D": 1.0,
      "E": 0.0,
      "F": 0.0,
      "X": 0.0,
    };

    for (var course in courses) {
      double credit = double.tryParse(course.credits) ?? 0;
      String score = course.score.trim();

      if (score.contains("抵免")) continue;
      creditsTaken += credit;

      if (score != "E" && score != "F" && score != "X" && score != "") {
        creditsEarned += credit;
      }

      if (score != "(P)" && gradePoints.containsKey(score)) {
        gpaCredits += credit;
        totalWeightedPoints += (credit * gradePoints[score]!);
      }
    }

    double avg = gpaCredits > 0 ? (totalWeightedPoints / gpaCredits) : 0.0;

    return ScoreSummary(
      creditsTaken: creditsTaken.toInt().toString(),
      creditsEarned: creditsEarned.toInt().toString(),
      average: avg == 0.0 ? "0" : avg.toStringAsFixed(2),
      rank: "--",
      classSize: "--",
    );
  }

  @override
  void initState() {
    super.initState();
    _autoSelectSemester();
    HistoricalScoreService.instance.summaryNotifier.addListener(
      _autoSelectSemester,
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    HistoricalScoreService.instance.summaryNotifier.removeListener(
      _autoSelectSemester,
    );
    super.dispose();
  }

  void _autoSelectSemester() {
    if (_hasInitializedSelection) return;

    final coursesMap = HistoricalScoreService.instance.coursesNotifier.value;
    final yearsSet = HistoricalScoreService.instance.validYearsNotifier.value;
    if (yearsSet.isEmpty || coursesMap.isEmpty) return;

    List<String> years = yearsSet.toList()..sort((a, b) => b.compareTo(a));

    int currentMonth = DateTime.now().month;
    String targetSem = (currentMonth >= 5 && currentMonth <= 10) ? "2" : "1";

    for (var year in years) {
      String key = "$year-$targetSem";
      if (coursesMap.containsKey(key) && coursesMap[key]!.isNotEmpty) {
        setState(() {
          _selectedYear = year;
          _selectedSem = targetSem;
          _hasInitializedSelection = true;
        });
        return;
      }
    }

    for (var year in years) {
      final sems =
          HistoricalScoreService.instance.validSemestersNotifier.value[year] ??
                []
            ..sort((a, b) => b.compareTo(a));

      for (var sem in sems) {
        String key = "$year-$sem";
        if (coursesMap[key]?.isNotEmpty ?? false) {
          setState(() {
            _selectedYear = year;
            _selectedSem = sem;
            _hasInitializedSelection = true;
          });
          return;
        }
      }
    }
  }

  Widget _buildTableHeader() {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        children: [
          SizedBox(
            width: 45,
            child: Text(
              "學分",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colorScheme.subtitleText,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Text(
              "課程名稱 / 代碼",
              style: TextStyle(
                color: colorScheme.subtitleText,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
          Text(
            "成績",
            style: TextStyle(
              color: colorScheme.subtitleText,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown(
    String label,
    List<String> items,
    String value,
    Function(String?) onChanged, {
    Map<String, String>? displayMap,
  }) {
    return GlassSingleSelectDropdown(
      label: label,
      items: items,
      value: value,
      onChanged: onChanged,
      displayMap: displayMap,
    );
  }

  Widget _buildCourseCard(CourseScore course) {
    final colorScheme = Theme.of(context).colorScheme;
    double scoreVal = double.tryParse(course.score) ?? 0;
    bool isPass = scoreVal >= 60;
    bool isNumber = RegExp(r'^\d+$').hasMatch(course.score);
    Color scoreColor;
    if (isNumber) {
      if (scoreVal >= 90) {
        scoreColor = colorScheme.isDark ? Colors.redAccent : Colors.red[700]!;
      } else if (isPass) {
        scoreColor = colorScheme.primaryText;
      } else {
        scoreColor = colorScheme.isDark
            ? Colors.redAccent[100]!
            : Colors.redAccent;
      }
    } else {
      scoreColor = colorScheme.isDark ? Colors.blueGrey[300]! : Colors.blueGrey;
    }

    final isSelected = _selectedCourseId == course.id;

    return GestureDetector(
      onTap: () {
        setState(() {
          if (isSelected) {
            _selectedCourseId = null;
          } else {
            _selectedCourseId = course.id;
          }
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: colorScheme.cardBackground,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? colorScheme.accentBlue : Colors.transparent,
            width: 2.0,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? colorScheme.accentBlue.withOpacity(0.4)
                  : colorScheme.borderColor.withOpacity(0.08),
              spreadRadius: isSelected ? 2 : 2,
              blurRadius: isSelected ? 12 : 8,
              offset: isSelected ? Offset.zero : const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 16.0),
          child: Row(
            children: [
              Container(
                width: 45,
                height: 45,
                decoration: BoxDecoration(
                  color: colorScheme.secondaryCardBackground,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    course.credits,
                    style: TextStyle(
                      color: colorScheme.accentBlue,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      course.name,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.primaryText,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      course.id,
                      style: TextStyle(
                        fontSize: 13,
                        color: colorScheme.subtitleText,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                course.score,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: scoreColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCard(ScoreSummary summary, SummaryType type) {
    final colorScheme = Theme.of(context).colorScheme;
    List<Color> bgColors;
    Color themeColor;
    String title;
    IconData icon;
    bool showRank = true;

    switch (type) {
      case SummaryType.official:
        bgColors = colorScheme.isDark
            ? [Colors.teal[900]!, Colors.teal[800]!]
            : [const Color(0xFFE0F2F1), const Color(0xFFB2DFDB)];
        themeColor = colorScheme.isDark ? Colors.teal[200]! : Colors.teal[800]!;
        title = "學期統計";
        icon = Icons.analytics_outlined;
        break;
      case SummaryType.preview:
        bgColors = colorScheme.isDark
            ? [Colors.pink[900]!, Colors.pink[800]!]
            : [const Color(0xFFFFF1F1), const Color(0xFFFFE4E8)];
        themeColor = colorScheme.isDark ? Colors.pink[200]! : Colors.pink[800]!;
        title = "學期統計 (預覽)";
        icon = Icons.preview_rounded;
        break;
      case SummaryType.calculated:
        bgColors = colorScheme.isDark
            ? [Colors.green[900]!, Colors.green[800]!]
            : [const Color(0xFFE8F5E9), const Color(0xFFC8E6C9)];
        themeColor = colorScheme.isDark
            ? Colors.green[200]!
            : Colors.green[800]!;
        title = "學期統計 (試算)";
        icon = Icons.calculate_outlined;
        showRank = false;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: bgColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: themeColor.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 32,
            child: Row(
              children: [
                Icon(icon, color: themeColor, size: 22),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: themeColor,
                  ),
                ),
                if (type == SummaryType.preview) ...[
                  const Spacer(),
                  GestureDetector(
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (c) => AlertDialog(
                          title: const Text("預覽資料說明"),
                          content: const Text(
                            "此名次資料是從學校其他系統中抓取的資料，並非最終結果。\n\n"
                            "• 學分/平均：由程式依據下方課程成績自動試算。\n"
                            "• 名次與人數：抓取來源非學校成績查訊系統。\n\n"
                            "請注意：這不是教務處正式成績單，僅供參考，準確資料請以開學後學校正式公告為準。",
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(c),
                              child: const Text("了解"),
                            ),
                          ],
                        ),
                      );
                    },
                    child: Icon(
                      Icons.info_outline_rounded,
                      color: themeColor.withOpacity(0.7),
                      size: 18,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Divider(color: themeColor.withOpacity(0.2), height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildSummaryItem("修習學分", summary.creditsTaken, themeColor),
              _buildSummaryItem("實得學分", summary.creditsEarned, themeColor),
              _buildSummaryItem(
                "平均分數",
                _formatAverage(summary.average),
                themeColor,
                isHighlight: true,
              ),
            ],
          ),

          if (showRank) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              decoration: BoxDecoration(
                color: colorScheme.isDark
                    ? Colors.black.withOpacity(0.3)
                    : Colors.white.withOpacity(0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "本學期名次",
                    style: TextStyle(
                      color: themeColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        summary.rank,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: themeColor,
                        ),
                      ),
                      Text(
                        " / ${summary.classSize}",
                        style: TextStyle(
                          color: themeColor.withOpacity(0.7),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSummaryItem(
    String label,
    String value,
    Color color, {
    bool isHighlight = false,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: color)),
        SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: isHighlight ? 20 : 18,
            fontWeight: FontWeight.bold,
            color: isHighlight
                ? (colorScheme.isDark ? Colors.orangeAccent : Colors.deepOrange)
                : color,
          ),
        ),
      ],
    );
  }

  String _formatAverage(String average) {
    if (RegExp(r'^\-?\d+\.\d0$').hasMatch(average)) {
      return average.substring(0, average.length - 1);
    }
    return average;
  }
}
