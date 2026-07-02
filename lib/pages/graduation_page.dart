import 'package:flutter/material.dart';
import '../models/graduation_model.dart';
import '../services/graduation_service.dart';
import '../services/historical_score_service.dart';
import '../theme/app_theme.dart';

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
    _dataFuture = GraduationService.instance.fetchGraduationData(
      forceRefresh: false,
    );
    HistoricalScoreService.instance.coursesNotifier.addListener(
      _onCoursesChanged,
    );
    _checkAndFetchHistoricalScores();
  }

  @override
  void dispose() {
    HistoricalScoreService.instance.coursesNotifier.removeListener(
      _onCoursesChanged,
    );
    super.dispose();
  }

  void _onCoursesChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _checkAndFetchHistoricalScores() async {
    if (HistoricalScoreService.instance.coursesNotifier.value.isEmpty) {
      await HistoricalScoreService.instance.loadFromCache();
    }
    if (HistoricalScoreService.instance.coursesNotifier.value.isEmpty &&
        !HistoricalScoreService.instance.isLoadingNotifier.value) {
      debugPrint("畢業檢核：歷年成績為空，自動發起背景抓取歷年成績...");
      try {
        await HistoricalScoreService.instance.fetchAllData(
          forceFullRefresh: false,
        );
      } catch (e) {
        debugPrint("自動抓取歷年成績失敗: $e");
      }
    }
  }

  Future<void> _handleRefresh() async {
    if (_isRefreshing) return;

    setState(() {
      _isRefreshing = true;
      // 觸發重新抓取資料 (強制刷新)
      _dataFuture = GraduationService.instance.fetchGraduationData(
        forceRefresh: true,
      );
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
    final colorScheme = Theme.of(context).colorScheme;
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth >= 750;
    return Scaffold(
      appBar: AppBar(
        title: const Text("畢業檢核"),
        centerTitle: true,
        actions: [
          // 右上角按鈕區域
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: _isRefreshing
                ? Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: colorScheme.accentBlue,
                      ),
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
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: colorScheme.accentBlue),
                  const SizedBox(height: 16),
                  Text(
                    "正在連線教務處資料庫...",
                    style: TextStyle(color: colorScheme.subtitleText),
                  ),
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
                    Icon(
                      Icons.error_outline,
                      size: 48,
                      color: colorScheme.isDark
                          ? Colors.red[200]
                          : Colors.redAccent,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      "讀取失敗：\n${snapshot.error}",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: colorScheme.primaryText),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _handleRefresh,
                      child: const Text("重試"),
                    ),
                  ],
                ),
              ),
            );
          } else if (!snapshot.hasData || snapshot.data == null) {
            return Center(
              child: Text(
                "無法取得資料，請檢查網路或帳號狀態",
                style: TextStyle(color: colorScheme.subtitleText),
              ),
            );
          }

          // 確定有資料
          final data = snapshot.data!;

          return Center(
            child: SizedBox(
              width: isTablet ? 720 : double.infinity,
              child: RefreshIndicator(
                onRefresh: _handleRefresh,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  children: [
                    _buildStudentCard(data),
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
                        style: TextStyle(
                          color: colorScheme.subtitleText,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(height: 30), // 稍微縮小間距
                    // 新增：免責聲明
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20.0),
                      child: Text(
                        "此頁面資料僅供參考\n請務必以學校官方網站之查詢結果為準",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: colorScheme.primaryText,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(height: 30), // 留白，避免文字太貼手機底部
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  GPABreakdown? _getGPABreakdown() {
    final coursesMap = HistoricalScoreService.instance.coursesNotifier.value;
    if (coursesMap.isEmpty) return null;

    double totalWeightedPoints = 0;
    double totalGPACredits = 0;
    final Map<String, _SemesterGPADetail> semesterBreakdown = {};

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

    bool hasAnyValidGrade = false;

    coursesMap.forEach((semester, courses) {
      double semWeightedPoints = 0;
      double semGPACredits = 0;
      final List<_CourseGPADetail> semCourses = [];

      for (var course in courses) {
        double credit = double.tryParse(course.credits) ?? 0;
        String score = course.score.trim();

        if (score.contains("抵免")) continue;
        if (score == "(P)") continue;

        if (gradePoints.containsKey(score)) {
          double gp = gradePoints[score]!;
          double weighted = credit * gp;
          semWeightedPoints += weighted;
          semGPACredits += credit;
          semCourses.add(
            _CourseGPADetail(
              name: course.name,
              credits: course.credits,
              score: course.score,
              gp: gp,
            ),
          );
          hasAnyValidGrade = true;
        }
      }

      if (semGPACredits > 0) {
        totalWeightedPoints += semWeightedPoints;
        totalGPACredits += semGPACredits;
        semesterBreakdown[semester] = _SemesterGPADetail(
          weightedPoints: semWeightedPoints,
          gpaCredits: semGPACredits,
          courses: semCourses,
        );
      }
    });

    if (!hasAnyValidGrade || totalGPACredits == 0) return null;

    return GPABreakdown(
      cumulativeGPA: totalWeightedPoints / totalGPACredits,
      totalWeightedPoints: totalWeightedPoints,
      totalGPACredits: totalGPACredits,
      semesterBreakdown: semesterBreakdown,
    );
  }

  void _showGPADialog(GPABreakdown breakdown) {
    showDialog(
      context: context,
      builder: (context) {
        final colorScheme = Theme.of(context).colorScheme;
        final sortedSemesters = breakdown.semesterBreakdown.keys.toList()
          ..sort((a, b) => b.compareTo(a));

        return AlertDialog(
          backgroundColor: colorScheme.cardBackground,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(
                Icons.calculate_rounded,
                color: colorScheme.accentBlue,
                size: 24,
              ),
              const SizedBox(width: 10),
              Text(
                "總平均 GPA 試算細節",
                style: TextStyle(
                  color: colorScheme.primaryText,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 600,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colorScheme.secondaryCardBackground,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: colorScheme.borderColor),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "計算公式",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: colorScheme.primaryText,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          "總平均 GPA = 累計加權點數 / GPA 採計總學分\n"
                          "單科加權點數 = 單科等第點數 (GP) × 該科學分數\n\n"
                          "※ 只採計有等第點數的科目，排除「抵免」、無成績與「(P)」等科目。",
                          style: TextStyle(
                            fontSize: 13,
                            color: colorScheme.subtitleText,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildDialogStat(
                        "總平均 GPA",
                        breakdown.cumulativeGPA.toStringAsFixed(2),
                        colorScheme.accentBlue,
                      ),
                      _buildDialogStat(
                        "累計加權點數",
                        breakdown.totalWeightedPoints.toStringAsFixed(1),
                        colorScheme.primaryText,
                      ),
                      _buildDialogStat(
                        "採計總學分",
                        breakdown.totalGPACredits.toInt().toString(),
                        colorScheme.primaryText,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.isDark
                          ? Colors.orange[900]!.withValues(alpha: 0.2)
                          : Colors.orange[50]!,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.orange.withValues(alpha: 0.5),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          color: Colors.orange[400]!,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            "本系統試算結果僅供參考，實際學分採計與畢業審查資格請以學校教務處官方正式成績單與審查結果為準。",
                            style: TextStyle(
                              color: colorScheme.isDark
                                  ? Colors.orange[200]!
                                  : Colors.orange[800]!,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              height: 1.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "各學期採計明細",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: colorScheme.primaryText,
                    ),
                  ),
                  const Divider(),
                  ...sortedSemesters.map((sem) {
                    final detail = breakdown.semesterBreakdown[sem]!;
                    final semGPA = detail.weightedPoints / detail.gpaCredits;
                    return Theme(
                      data: Theme.of(
                        context,
                      ).copyWith(dividerColor: Colors.transparent),
                      child: ExpansionTile(
                        title: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "$sem",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: colorScheme.primaryText,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                "GPA: ${semGPA.toStringAsFixed(2)} (${detail.gpaCredits.toInt()} 學分)",
                                style: TextStyle(
                                  fontSize: 11,
                                  color: colorScheme.subtitleText,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        children: detail.courses.map((c) {
                          return ListTile(
                            dense: true,
                            title: Text(
                              c.name,
                              style: TextStyle(
                                color: colorScheme.primaryText,
                                fontSize: 13,
                              ),
                            ),
                            subtitle: Text(
                              "學分: ${c.credits} | 成績: ${c.score} | 等第點數 (GP): ${c.gp}",
                              style: TextStyle(fontSize: 11),
                            ),
                          );
                        }).toList(),
                      ),
                    );
                  }).toList(),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("關閉"),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDialogStat(String label, String value, Color valueColor) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Theme.of(context).colorScheme.subtitleText,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: valueColor,
          ),
        ),
      ],
    );
  }

  // 學生資訊卡
  Widget _buildStudentCard(GraduationData data) {
    final colorScheme = Theme.of(context).colorScheme;
    final overallGPABreakdown = _getGPABreakdown();
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: colorScheme.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.borderColor),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: colorScheme.secondaryCardBackground,
            child: Text(
              data.studentName.isNotEmpty ? data.studentName[0] : "生",
              style: TextStyle(
                color: colorScheme.accentBlue,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.studentName,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primaryText,
                  ),
                ),
                Text(
                  data.department,
                  style: TextStyle(color: colorScheme.subtitleText),
                ),
              ],
            ),
          ),
          if (overallGPABreakdown != null) ...[
            const SizedBox(width: 16),
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: () => _showGPADialog(overallGPABreakdown),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.secondaryCardBackground,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: colorScheme.accentBlue.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        "總平均 GPA",
                        style: TextStyle(
                          color: colorScheme.subtitleText,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        overallGPABreakdown.cumulativeGPA.toStringAsFixed(2),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.accentBlue,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // 學分進度條
  Widget _buildCreditProgress(GraduationData data) {
    final colorScheme = Theme.of(context).colorScheme;
    double progress = data.currentCredits / data.minCredits;
    if (progress > 1.0) progress = 1.0;

    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: colorScheme.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "畢業學分進度",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: colorScheme.primaryText,
            ),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 12,
              backgroundColor: colorScheme.secondaryCardBackground,
              valueColor: AlwaysStoppedAnimation(
                progress >= 1.0
                    ? (colorScheme.isDark ? Colors.green[400]! : Colors.green)
                    : (colorScheme.isDark
                          ? Colors.orange[400]!
                          : Colors.orange),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "${(progress * 100).toStringAsFixed(1)}%",
                style: TextStyle(color: colorScheme.subtitleText),
              ),
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: "${data.currentCredits}",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: colorScheme.primaryText,
                      ),
                    ),
                    TextSpan(
                      text: " / ${data.minCredits}",
                      style: TextStyle(color: colorScheme.subtitleText),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (data.currentCredits < data.minCredits)
            Container(
              margin: const EdgeInsets.only(top: 8.0),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: colorScheme.isDark
                    ? Colors.red[900]?.withValues(alpha: 0.2)
                    : Colors.red[50],
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                "尚缺 ${data.minCredits - data.currentCredits} 學分",
                style: TextStyle(
                  color: colorScheme.isDark ? Colors.red[200] : Colors.red[700],
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // 必修缺修卡片 (紅色警戒)
  Widget _buildMissingRequiredCard(GraduationData data) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: colorScheme.cardBackground,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colorScheme.borderColor),
      ),
      child: ExpansionTile(
        initiallyExpanded: false,
        leading: Icon(
          Icons.warning_rounded,
          color: colorScheme.isDark ? Colors.red[200] : Colors.red,
        ),
        title: Text(
          "必修缺修",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: colorScheme.isDark ? Colors.red[200] : Colors.red,
          ),
        ),
        children: data.missingRequiredCourses
            .map(
              (course) => ListTile(
                dense: true,
                leading: Icon(
                  Icons.close,
                  size: 16,
                  color: colorScheme.isDark ? Colors.red[200] : Colors.red,
                ),
                title: Text(
                  course,
                  style: TextStyle(
                    fontSize: 15,
                    color: colorScheme.primaryText,
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  // 通識檢核

  // 通識檢核
  Widget _buildGenEdCard(GraduationData data) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: colorScheme.cardBackground,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colorScheme.borderColor),
      ),
      child: ExpansionTile(
        title: Text(
          "通識與畢業門檻",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: colorScheme.primaryText,
          ),
        ),
        leading: const Icon(Icons.fact_check, color: Colors.teal),
        children: data.genEdStatuses.map((item) {
          bool isOk = item.status == "符合";

          // 狀態標籤
          Widget statusBadge = Container(
            margin: const EdgeInsets.only(left: 8),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: isOk
                  ? (colorScheme.isDark
                        ? Colors.green[900]?.withValues(alpha: 0.2)
                        : Colors.green[50])
                  : (colorScheme.isDark
                        ? Colors.red[900]?.withValues(alpha: 0.2)
                        : Colors.red[50]),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: isOk
                    ? Colors.green.withValues(alpha: 0.3)
                    : Colors.red.withValues(alpha: 0.3),
              ),
            ),
            child: Text(
              item.status,
              style: TextStyle(
                color: isOk
                    ? (colorScheme.isDark
                          ? Colors.green[200]
                          : Colors.green[700])
                    : (colorScheme.isDark ? Colors.red[200] : Colors.red[700]),
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          );

          // 判斷是否有子項目
          if (item.details.isNotEmpty) {
            // === 有子項目：使用 ExpansionTile ===
            return ExpansionTile(
              tilePadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 4,
              ),
              leading: Icon(
                isOk ? Icons.check_circle : Icons.cancel,
                color: isOk
                    ? Colors.green
                    : (colorScheme.isDark ? Colors.red[200] : Colors.redAccent),
              ),
              // 將狀態標籤放在 Title 旁邊
              title: Row(
                children: [
                  Flexible(
                    child: Text(
                      item.name,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: colorScheme.primaryText),
                    ),
                  ),
                  statusBadge,
                ],
              ),
              subtitle: item.description.isNotEmpty
                  ? Text(
                      item.description,
                      style: TextStyle(
                        color: colorScheme.isDark
                            ? Colors.red[200]
                            : Colors.red,
                        fontSize: 13,
                      ),
                    )
                  : null,
              // 不設定 trailing，保留預設箭頭
              children: item.details
                  .map(
                    (detail) => Container(
                      color: colorScheme.secondaryCardBackground,
                      child: ListTile(
                        dense: true,
                        contentPadding: const EdgeInsets.only(
                          left: 56,
                          right: 16,
                        ),
                        leading: Icon(
                          Icons.subdirectory_arrow_right,
                          size: 16,
                          color: colorScheme.subtitleText,
                        ),
                        title: Text(
                          detail,
                          style: TextStyle(
                            color: colorScheme.primaryText,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            );
          } else {
            // === 無子項目：使用 ListTile ===
            return ListTile(
              dense: true,
              leading: Icon(
                isOk ? Icons.check_circle : Icons.cancel,
                color: isOk
                    ? Colors.green
                    : (colorScheme.isDark ? Colors.red[200] : Colors.redAccent),
              ),
              title: Row(
                children: [
                  Flexible(
                    child: Text(
                      item.name,
                      style: TextStyle(color: colorScheme.primaryText),
                    ),
                  ),
                  statusBadge,
                ],
              ),
              subtitle: item.description.isNotEmpty
                  ? Text(
                      item.description,
                      style: TextStyle(
                        color: colorScheme.isDark
                            ? Colors.red[200]
                            : Colors.red,
                      ),
                    )
                  : null,
            );
          }
        }).toList(),
      ),
    );
  }

  // 選修列表
  Widget _buildElectivesCard(GraduationData data) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: colorScheme.cardBackground,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colorScheme.borderColor),
      ),
      child: ExpansionTile(
        title: Text(
          "已修習選修 (${data.takenElectiveCourses.length})",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: colorScheme.primaryText,
          ),
        ),
        leading: Icon(Icons.book, color: colorScheme.accentBlue),
        children: [
          SizedBox(
            height: 250, // 限制高度，內部可捲動
            child: ListView.separated(
              itemCount: data.takenElectiveCourses.length,
              separatorBuilder: (ctx, i) =>
                  const Divider(height: 1, indent: 16, endIndent: 16),
              itemBuilder: (ctx, i) {
                return ListTile(
                  dense: true,
                  leading: Icon(
                    Icons.bookmark_border,
                    size: 18,
                    color: colorScheme.subtitleText,
                  ),
                  title: Text(
                    data.takenElectiveCourses[i],
                    style: TextStyle(color: colorScheme.primaryText),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class GPABreakdown {
  final double cumulativeGPA;
  final double totalWeightedPoints;
  final double totalGPACredits;
  final Map<String, _SemesterGPADetail> semesterBreakdown;

  GPABreakdown({
    required this.cumulativeGPA,
    required this.totalWeightedPoints,
    required this.totalGPACredits,
    required this.semesterBreakdown,
  });
}

class _SemesterGPADetail {
  final double weightedPoints;
  final double gpaCredits;
  final List<_CourseGPADetail> courses;

  _SemesterGPADetail({
    required this.weightedPoints,
    required this.gpaCredits,
    required this.courses,
  });
}

class _CourseGPADetail {
  final String name;
  final String credits;
  final String score;
  final double gp;

  _CourseGPADetail({
    required this.name,
    required this.credits,
    required this.score,
    required this.gp,
  });
}
