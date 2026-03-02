import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart'; // <--- 新增這一行
import '../services/historical_score_service.dart';

class ScoreResultPage extends StatefulWidget {
  final String cookies;
  const ScoreResultPage({Key? key, required this.cookies}) : super(key: key);
  
  @override
  State<ScoreResultPage> createState() => _ScoreResultPageState();
}

enum SummaryType { official, preview, calculated }

class _ScoreResultPageState extends State<ScoreResultPage> {
  String? _selectedYear;
  String? _selectedSem;
  bool _hasInitializedSelection = false;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: HistoricalScoreService.instance.isLoadingNotifier,
      builder: (context, isLoading, _) {
        return Scaffold(
          backgroundColor: Colors.grey[100],
          appBar: AppBar(
            title: Text("歷年成績查詢"),
            backgroundColor: Colors.white,
            elevation: 0,
            titleTextStyle: TextStyle(color: Colors.black87, fontSize: 20, fontWeight: FontWeight.bold),
            iconTheme: IconThemeData(color: Colors.black87),
            actions: [
              // ★★★ 新增：資訊按鈕 ★★★
              IconButton(
                icon: Icon(Icons.info_outline_rounded, color: Colors.blueGrey),
                tooltip: "預覽功能說明",
                onPressed: () {
                  _showPreviewStatusDialog();
                },
              ),
              // 原有的重新整理按鈕
              IconButton(
                icon: isLoading 
                  ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) 
                  : Icon(Icons.refresh),
                onPressed: isLoading ? null : () {
                  HistoricalScoreService.instance.fetchAllData();
                },
              ),
            ],
          ),
          body: Column(
            children: [
              if (isLoading)
                ValueListenableBuilder<double>(
                  valueListenable: HistoricalScoreService.instance.progressNotifier,
                  builder: (context, progress, _) => LinearProgressIndicator(
                    value: progress, 
                    backgroundColor: Colors.grey[200], 
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.pinkAccent)
                  ),
                ),

              Expanded(
                child: ValueListenableBuilder<Set<String>>(
                  valueListenable: HistoricalScoreService.instance.validYearsNotifier,
                  builder: (context, validYearsSet, child) {
                    
                    if (validYearsSet.isEmpty) {
                      return Center(
                        child: isLoading 
                          ? Text("正在搜尋歷年成績...\n請稍候", textAlign: TextAlign.center)
                          : Text("查無任何成績資料"),
                      );
                    }

                    List<String> sortedYears = validYearsSet.toList()
                      ..sort((a, b) => int.parse(b).compareTo(int.parse(a)));

                    if (_selectedYear == null || !validYearsSet.contains(_selectedYear)) {
                      _selectedYear = sortedYears.first;
                    }

                    List<String> availableSems = HistoricalScoreService.instance.validSemestersNotifier.value[_selectedYear] ?? [];
                    availableSems.sort(); 

                    if (_selectedSem == null || !availableSems.contains(_selectedSem)) {
                      _selectedSem = availableSems.last;
                    }

                    return Column(
                      children: [
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          color: Colors.white,
                          child: Row(
                            children: [
                              Expanded(
                                child: _buildDropdown("學年", sortedYears, _selectedYear!, (val) {
                                  setState(() {
                                    _selectedYear = val;
                                    _selectedSem = null;
                                  });
                                }),
                              ),
                              SizedBox(width: 16),
                              Expanded(
                                child: _buildDropdown("學期", availableSems, _selectedSem!, (val) {
                                  setState(() => _selectedSem = val);
                                }, displayMap: {"1": "上學期", "2": "下學期", "3": "暑修"}),
                              ),
                            ],
                          ),
                        ),

                        Expanded(
                          child: _buildScoreListContent(_selectedYear!, _selectedSem!),
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

  Widget _buildScoreListContent(String year, String sem) {
    String key = "$year-$sem";
    final courses = HistoricalScoreService.instance.coursesNotifier.value[key] ?? [];
    
    // 取得原始官方資料
    var officialSummary = HistoricalScoreService.instance.summaryNotifier.value[key] ?? ScoreSummary();
    
    // 取得預覽資料
    var previewData = HistoricalScoreService.instance.previewRanksNotifier.value[key];

    if (courses.isEmpty) {
      return Center(child: Text("資料載入異常"));
    }

    // --- 輔助判斷函式 (定義在方法內或類別內皆可) ---
    // 判斷字串是否為有效數值 (不為 null, 不為空, 不為 "-")
    bool hasValidValue(String? value) {
      return value != null && value.isNotEmpty && value != "-";
    }

    // --- 決定顯示哪種 Summary ---
    ScoreSummary finalSummary;
    SummaryType type;

    // 判斷邏輯修正：
    // 只有當「官方平均分」是有效數值時，我們才視為官方資料已公佈。
    // (名次比較晚出，所以用平均分來判斷是否為官方數據比較準確)
    bool isOfficialValid = hasValidValue(officialSummary.average);

    if (isOfficialValid) {
      // 1. 官方資料優先 (學校系統已有計算好的平均)
      finalSummary = officialSummary;
      type = SummaryType.official;
      
      // 進階：如果官方有名次就用官方的，沒有則試著補預覽名次 (可選)
      if (!hasValidValue(finalSummary.rank) && 
          previewData != null && 
          hasValidValue(previewData['rank'])) {
          finalSummary.rank = previewData['rank']!;
          finalSummary.classSize = previewData['classSize'] ?? "-";
          // 這裡可以考慮是否要改變 type，或者保持 official 但標記名次是預覽
      }

    } else {
      // 官方沒資料 (average 為 "-") -> 進入本地試算模式
      ScoreSummary calculated = _calculateSemesterSummary(courses);
      
      // 檢查是否有預覽名次
      bool hasPreviewRank = previewData != null && hasValidValue(previewData['rank']);

      if (hasPreviewRank) {
        // 2. 預覽模式：使用「本地試算的學分/平均」 + 「抓取到的預覽名次」
        finalSummary = ScoreSummary(
          creditsTaken: calculated.creditsTaken,
          creditsEarned: calculated.creditsEarned,
          average: calculated.average,
          rank: previewData!['rank']!, // 確定不為 null
          classSize: previewData['classSize'] ?? "-",
        );
        type = SummaryType.preview;
      } else {
        // 3. 純試算模式：全部試算，名次顯示 "-"
        finalSummary = calculated;
        type = SummaryType.calculated;
      }
    }

    print("DEBUG key=$key Type=$type OffAvg=${officialSummary.average} PreviewRank=${previewData?['rank']}");

    return ListView(
      padding: EdgeInsets.all(12),
      children: [
        _buildSummaryCard(finalSummary, type),
        SizedBox(height: 20),
        _buildTableHeader(),
        SizedBox(height: 8),
        ...courses.map((c) => _buildCourseCard(c)).toList(),
        SizedBox(height: 40),
      ],
    );
  }

  // ★★★ 新增：顯示預覽狀態說明的彈窗 ★★★
  Future<void> _showPreviewStatusDialog() async {
    final prefs = await SharedPreferences.getInstance();
    // 讀取設定，預設為 false
    bool isPreviewEnabled = prefs.getBool('is_preview_rank_enabled') ?? false;

    String title;
    String content;

    if (isPreviewEnabled) {
      // 開啟狀態
      title = "預覽名次：已開啟";
      content = "現在有開啟預覽名次，每次抓取會比較久。\n\n"
          "若是已抓到要的資料，可以先去設定關閉以加快速度。\n\n"
          "※ 注意：\n1. 3/20~6/5 和 10/15~1/5 期間此功能會強制關閉，為了節省時間。\n2. 若寒暑假期間查無預覽資料，推測為校務平台系統更動所致，建議暫時關閉此功能以維持查詢效率。";
    } else {
      // 關閉狀態
      title = "預覽名次：未開啟";
      content = "目前沒有開啟預覽名次，抓取速度快。\n\n"
          "若是要看預覽名次，請到設定頁面去開啟。\n\n"
          "※ 注意：\n3/20~6/5 和 10/15~1/5 期間此功能會強制關閉，為了節省時間。";
    }

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title, style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text(content, style: TextStyle(height: 1.5)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("了解"),
          ),
        ],
      ),
    );
  }
  
  ScoreSummary _calculateSemesterSummary(List<CourseScore> courses) {
    double totalWeightedPoints = 0;
    double gpaCredits = 0;
    double creditsTaken = 0;
    double creditsEarned = 0;

    final Map<String, double> gradePoints = {
      "A+": 4.3, "A": 4.0, "A-": 3.7,
      "B+": 3.3, "B": 3.0, "B-": 2.7,
      "C+": 2.3, "C": 2.0, "C-": 1.7,
      "D": 1.0, "E": 0.0, "F": 0.0, "X": 0.0,
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
    HistoricalScoreService.instance.summaryNotifier.addListener(_autoSelectSemester);
  }

  @override
  void dispose() {
    HistoricalScoreService.instance.summaryNotifier.removeListener(_autoSelectSemester);
    super.dispose();
  }

  void _autoSelectSemester() {
  if (_hasInitializedSelection) return;

  final coursesMap = HistoricalScoreService.instance.coursesNotifier.value;
  final yearsSet = HistoricalScoreService.instance.validYearsNotifier.value;
  if (yearsSet.isEmpty || coursesMap.isEmpty) return;

  // 排序年份：114, 113, 112...
  List<String> years = yearsSet.toList()..sort((a, b) => b.compareTo(a));

  int currentMonth = DateTime.now().month;
  String targetSem = (currentMonth >= 5 && currentMonth <= 10) ? "2" : "1";

  // --- 策略 1：精準匹配 (找最新年份且符合月份的學期) ---
  // 假設現在 1 月，targetSem = "1"，我們會找 114-1，找不到就找 113-1
  for (var year in years) {
    String key = "$year-$targetSem";
    if (coursesMap.containsKey(key) && coursesMap[key]!.isNotEmpty) {
      setState(() {
        _selectedYear = year;
        _selectedSem = targetSem;
        _hasInitializedSelection = true;
      });
      print("DEBUG: 自動定位成功 -> $key");
      return;
    }
  }

  // --- 策略 2：退而求其次 (找最新有資料的學期，不論學期號) ---
  // 如果 1 月份卻還沒 114-1 的資料，就抓目前最新的一筆 (可能是 113-2)
  for (var year in years) {
    final sems = HistoricalScoreService.instance.validSemestersNotifier.value[year] ?? []
      ..sort((a, b) => b.compareTo(a)); // 由大到小排序 (2 -> 1)
    
    for (var sem in sems) {
      String key = "$year-$sem";
      if (coursesMap[key]?.isNotEmpty ?? false) {
        setState(() {
          _selectedYear = year;
          _selectedSem = sem;
          _hasInitializedSelection = true;
        });
        print("DEBUG: 保底定位成功 -> $key");
        return;
      }
    }
  }
}
  Widget _buildTableHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        children: [
          SizedBox(width: 45, child: Text("學分", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.bold, fontSize: 13))),
          SizedBox(width: 16),
          Expanded(child: Text("課程名稱 / 代碼", style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.bold, fontSize: 13))),
          Text("成績", style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.bold, fontSize: 13)),
        ],
      ),
    );
  }

   Widget _buildDropdown(String label, List<String> items, String value, Function(String?) onChanged, {Map<String, String>? displayMap}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        SizedBox(height: 4),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(8)),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: items.contains(value) ? value : null,
              isExpanded: true,
              icon: Icon(Icons.arrow_drop_down, color: Colors.grey[600]),
              items: items.map((item) {
                return DropdownMenuItem(value: item, child: Text(displayMap != null ? (displayMap[item] ?? item) : item, style: TextStyle(fontWeight: FontWeight.w500)));
              }).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildCourseCard(CourseScore course) {
    double scoreVal = double.tryParse(course.score) ?? 0;
    bool isPass = scoreVal >= 60;
    bool isNumber = RegExp(r'^\d+$').hasMatch(course.score);
    Color scoreColor = isNumber ? (isPass ? Colors.black87 : Colors.redAccent) : Colors.blueGrey;
    if (scoreVal >= 90) scoreColor = Colors.red[700]!;

    return Container(
      margin: EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.08), spreadRadius: 2, blurRadius: 8, offset: Offset(0, 2))],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 16.0),
        child: Row(
          children: [
            Container(
              width: 45, height: 45,
              decoration: BoxDecoration(color: Colors.pink[50], shape: BoxShape.circle),
              child: Center(child: Text(course.credits, style: TextStyle(color: Colors.pink[800], fontWeight: FontWeight.bold, fontSize: 18))),
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(course.name, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
                  SizedBox(height: 4),
                  Text(course.id, style: TextStyle(fontSize: 13, color: Colors.grey[500])),
                ],
              ),
            ),
            Text(course.score, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: scoreColor)),
          ],
        ),
      ),
    );
  }

  // ★★★ 修改：根據 Type 切換顏色與標題 ★★★
  Widget _buildSummaryCard(ScoreSummary summary, SummaryType type) {
    List<Color> bgColors;
    Color themeColor;
    String title;
    IconData icon;
    bool showRank = true;

    switch (type) {
      case SummaryType.official:
        bgColors = [const Color(0xFFE0F2F1), const Color(0xFFB2DFDB)]; // 藍綠色系
        themeColor = Colors.teal[800]!;
        title = "學期統計";
        icon = Icons.analytics_outlined;
        break;
      case SummaryType.preview:
        // 恢復粉紅色系
        bgColors = [const Color(0xFFFFF1F1), const Color(0xFFFFE4E8)]; 
        themeColor = Colors.pink[800]!;
        title = "學期統計 (預覽)";
        icon = Icons.preview_rounded;
        break;
      case SummaryType.calculated:
        bgColors = [const Color(0xFFE8F5E9), const Color(0xFFC8E6C9)]; // 綠色系
        themeColor = Colors.green[800]!;
        title = "學期統計 (試算)";
        icon = Icons.calculate_outlined;
        showRank = false;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16), // 稍微縮減上下內距
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: bgColors, begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: themeColor.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 使用 Row 並限制高度，解決 Icon 撐開空間的問題
          SizedBox(
            height: 32, // 固定標題列高度，讓視覺更緊湊
            child: Row(
              children: [
                Icon(icon, color: themeColor, size: 22), // 稍微縮小 Icon
                const SizedBox(width: 8),
                Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: themeColor)),
                if (type == SummaryType.preview) ...[
                  const Spacer(),
                  // 使用 GestureDetector 取代 IconButton 以節省空間
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
                            "請注意：這不是教務處正式成績單，僅供參考，準確資料請以開學後學校正式公告為準。"
                          ),
                          actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text("了解"))],
                        ),
                      );
                    },
                    child: Icon(Icons.info_outline_rounded, color: themeColor.withOpacity(0.7), size: 18),
                  )
                ]
              ],
            ),
          ),
          Divider(color: themeColor.withOpacity(0.2), height: 16), // 縮小 Divider 的高度
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween, 
            children: [
              _buildSummaryItem("修習學分", summary.creditsTaken, themeColor),
              _buildSummaryItem("實得學分", summary.creditsEarned, themeColor),
              _buildSummaryItem("平均分數", summary.average, themeColor, isHighlight: true),
            ]
          ),
          
          if (showRank) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.5), // 讓底色透明一點融入黃色背景
                borderRadius: BorderRadius.circular(8)
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween, 
                children: [
                  Text("本學期名次", style: TextStyle(color: themeColor, fontSize: 13, fontWeight: FontWeight.w500)),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(summary.rank, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: themeColor)), 
                      Text(" / ${summary.classSize}", style: TextStyle(color: themeColor.withOpacity(0.7), fontSize: 12))
                    ]
                  ),
                ]
              ),
            ),
          ],
        ],
      ),
    );
  }
  Widget _buildSummaryItem(String label, String value, Color color, {bool isHighlight = false}) {
    return Column(children: [
      Text(label, style: TextStyle(fontSize: 12, color: color)),
      SizedBox(height: 4),
      Text(value, style: TextStyle(fontSize: isHighlight ? 20 : 18, fontWeight: FontWeight.bold, color: isHighlight ? Colors.deepOrange : color))
    ]);
  }
}