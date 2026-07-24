// 檔案名稱：course_exception_handling_page.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'course_search_picker_page.dart'; // 確保路徑正確引入課程搜尋頁面
import 'course_exception_download_page.dart';
import '../../theme/app_theme.dart';
import '../../theme/layout_style_notifier.dart';
import 'course_exception_models.dart';
import 'widgets/abnormal_course_card.dart';
import 'widgets/manual_course_card.dart';
import 'widgets/inline_course_picker.dart';
import '../../utils/utils.dart';
import '../../widgets/glass/glass_page_scaffold.dart';
import '../../widgets/glass/glass_dialog.dart';
import '../../services/http_client_factory.dart';

bool test = false;

class CourseExceptionHandlingPage extends StatefulWidget {
  const CourseExceptionHandlingPage({Key? key}) : super(key: key);

  @override
  State<CourseExceptionHandlingPage> createState() =>
      _CourseExceptionHandlingPageState();
}

class _CourseExceptionHandlingPageState
    extends State<CourseExceptionHandlingPage> {
  bool _isLoading = true;
  String? _errorMessage;

  // 爬取下來的資料
  List<AbnormalCourse> _courses = [];
  List<ReasonOption> _reasons = [];

  // 非清單上的手動輸入課程 (網頁預設提供兩筆)
  final List<ManualCourse> _manualCourses = [];

  final http.Client _client = createHttpClient();
  final String _baseUrl = "https://selcrs.nsysu.edu.tw";

  // Widescreen inline picker states
  ManualCourse? _pickingManualCourse;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showNoticeDialog();
    });
    _fetchAbnormalData();
  }

  @override
  void dispose() {
    _client.close();
    super.dispose();
  }

  // ==========================================================
  // 網路請求與爬蟲邏輯 (加入詳細偵錯 Print)
  // ==========================================================

  Future<String?> _loginViaSSO2(String stuid, String password) async {
    debugPrint("🔍 [_loginViaSSO2] 開始執行 SSO 登入流程...");
    final loginUri = Uri.parse("$_baseUrl/menu4/Studcheck_sso2.asp");
    String encryptedPass = Utils.base64md5(password);

    try {
      debugPrint("📡 [_loginViaSSO2] 發送 POST 請求至 $loginUri (帳號: $stuid)");
      final response = await _client.post(
        loginUri,
        headers: {
          "Content-Type": "application/x-www-form-urlencoded",
          "User-Agent":
              "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
        },
        body: {"stuid": stuid.toUpperCase(), "SPassword": encryptedPass},
      );

      debugPrint("📥 [_loginViaSSO2] 收到伺服器回應，狀態碼: ${response.statusCode}");

      String? rawCookie = response.headers['set-cookie'];
      debugPrint("🍪 [_loginViaSSO2] 解析 Header 中的 Set-Cookie: $rawCookie");

      // 檢查是否包含帳密錯誤的關鍵字
      if (response.body.contains("不符")) {
        debugPrint("❌ [_loginViaSSO2] 登入失敗：網頁提示帳號或密碼不符！");
        return null;
      }

      if (rawCookie != null) {
        debugPrint("✅ [_loginViaSSO2] 登入成功，順利取得 Cookie！");
        return rawCookie;
      } else {
        debugPrint("⚠️ [_loginViaSSO2] 登入似乎沒有報錯，但 Header 中沒有回傳 Set-Cookie！");
      }
    } catch (e) {
      debugPrint("❌ [_loginViaSSO2] 發生連線例外錯誤: $e");
    }
    return null;
  }

  Future<void> _fetchAbnormalData() async {
    debugPrint("🚀 [_fetchAbnormalData] 開始抓取異常處理資料...");
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    if (test) {
      await Future.delayed(const Duration(seconds: 1));
      List<ReasonOption> parsedReasons = [
        ReasonOption("1", "雙主修/輔系/學程課程衝突"),
        ReasonOption("2", "畢業年級必修課衝堂"),
        ReasonOption("3", "加簽已滿，特殊專案處理"),
      ];
      List<AbnormalCourse> parsedCourses = [
        AbnormalCourse(
          id: "chk_crs_1",
          actionName: "abn_SelClass_chk_crs_1",
          reasonName: "abn_rsn_chk_crs_1",
          status: "未選上(異常處理)",
          courseNo: "MIS321",
          courseName: "系統分析與設計 Systems Analysis and Design",
          credits: "3",
          teacher: "張大衛",
        ),
        AbnormalCourse(
          id: "chk_crs_2",
          actionName: "abn_SelClass_chk_crs_2",
          reasonName: "abn_rsn_chk_crs_2",
          status: "未選上(異常處理)",
          courseNo: "CSE2311",
          courseName: "演算法概論 Introduction to Algorithms",
          credits: "3",
          teacher: "李小華",
        ),
        AbnormalCourse(
          id: "chk_crs_3",
          actionName: "abn_SelClass_chk_crs_3",
          reasonName: "abn_rsn_chk_crs_3",
          status: "已選上",
          courseNo: "GEN1001",
          courseName: "現代中文大意 Modern Chinese Literature",
          credits: "2",
          teacher: "王大明",
        ),
        AbnormalCourse(
          id: "chk_crs_4",
          actionName: "abn_SelClass_chk_crs_4",
          reasonName: "abn_rsn_chk_crs_4",
          status: "已選上",
          courseNo: "PE1002",
          courseName: "體育：羽球 Physical Education: Badminton",
          credits: "0",
          teacher: "陳教練",
        ),
      ];

      for (var course in parsedCourses) {
        if (course.status.contains('未選上')) {
          course.selectedAction = "加選";
        } else {
          course.selectedAction = "退選";
        }
      }

      if (!mounted) return;
      setState(() {
        _reasons = parsedReasons;
        _courses = parsedCourses;
        _isLoading = false;
      });
      return;
    }

    try {
      // 1. 讀取憑證
      final prefs = await SharedPreferences.getInstance();
      String studentId = (prefs.getString('username') ?? "").trim();
      String password = (prefs.getString('password') ?? "").trim();

      if (studentId.isEmpty || password.isEmpty) {
        throw "未登入 (請先至設定頁面設定帳號)";
      }

      // 2. 取得 SSO Cookie
      String? cookie = await _loginViaSSO2(studentId, password);
      if (cookie == null) {
        throw "SSO 登入失敗，請確認帳號密碼是否正確";
      }

      // 3. 請求異常處理頁面
      final url = Uri.parse("$_baseUrl/menu4/query/abnormal_list.asp");
      final response = await _client.get(
        url,
        headers: {
          "Cookie": cookie,
          "User-Agent":
              "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
        },
      );

      // 使用 allowMalformed 避免 Big5 編碼異常導致崩潰
      String htmlBody = utf8.decode(response.bodyBytes, allowMalformed: true);

      // --- 4. 解析原因選單 (Reason Options) ---
      List<ReasonOption> parsedReasons = [];
      // 考慮 select 標籤可能會有換行或屬性順序不同
      RegExp reasonSelectRegex = RegExp(
        r'''<select[^>]+name=["\']?NEW_CRSNO_RSN1["\']?[^>]*>(.*?)</select>''',
        caseSensitive: false,
        dotAll: true,
      );
      Match? reasonMatch = reasonSelectRegex.firstMatch(htmlBody);

      if (reasonMatch != null) {
        String optionsHtml = reasonMatch.group(1)!;
        // 捕捉 value 和顯示文字，並處理引號可能不存在的情況
        RegExp optionRegex = RegExp(
          r'''<option[^>]+value=["\']?([^"\'\s>]+)["\']?[^>]*>([^<]*)</option>''',
          caseSensitive: false,
        );
        for (Match m in optionRegex.allMatches(optionsHtml)) {
          parsedReasons.add(ReasonOption(m.group(1)!, m.group(2)!.trim()));
        }
      }
      _reasons = parsedReasons;

      // --- 5. 解析課程表格 (強效解析法) ---
      List<AbnormalCourse> parsedCourses = [];
      List<String> rows = htmlBody.split(
        RegExp(r'</tr\s*>', caseSensitive: false),
      );

      for (String rowHtml in rows) {
        if (rowHtml.contains(
          RegExp(r'''type=["\']?checkbox["\']?''', caseSensitive: false),
        )) {
          // 提取 checkbox ID
          String id =
              RegExp(
                r'''name=["\']?([^"\'\s>]+)["\']?''',
                caseSensitive: false,
              ).firstMatch(rowHtml)?.group(1) ??
              "";

          // 提取該列中的選單名稱 (Action & Reason)
          String actionName =
              RegExp(
                r'''name=["\']?(abn_SelClass_[^"\'\s>]+)["\']?''',
                caseSensitive: false,
              ).firstMatch(rowHtml)?.group(1) ??
              "";
          String reasonName =
              RegExp(
                r'''name=["\']?(abn_rsn_[^"\'\s>]+)["\']?''',
                caseSensitive: false,
              ).firstMatch(rowHtml)?.group(1) ??
              "";

          List<String> tdTexts = [];
          RegExp tdRegex = RegExp(
            r'<td[^>]*>(.*?)</td>',
            caseSensitive: false,
            dotAll: true,
          );
          for (Match td in tdRegex.allMatches(rowHtml)) {
            String cleanText = td
                .group(1)!
                .replaceAll(RegExp(r'<[^>]*>'), '')
                .replaceAll('&nbsp;', ' ')
                .trim();
            tdTexts.add(cleanText);
          }

          if (id.isNotEmpty && tdTexts.length >= 7) {
            parsedCourses.add(
              AbnormalCourse(
                id: id,
                actionName: actionName,
                reasonName: reasonName,
                status: tdTexts[2],
                courseNo: tdTexts[3],
                courseName: tdTexts[4],
                credits: tdTexts[5],
                teacher: tdTexts[6],
              ),
            );
          }
        }
      }
      for (var course in parsedCourses) {
        if (course.status.contains('未選上')) {
          course.selectedAction = "加選"; // 已選上的課程預設為退選
        } else {
          course.selectedAction = "退選"; // 未選上的課程預設為加選
        }
      }

      if (!mounted) return;
      setState(() {
        _courses = parsedCourses;
        _isLoading = false;
        if (_courses.isEmpty) {
          _errorMessage = "登入成功，但目前沒有異常處理課程資料";
        }
      });
    } catch (e) {
      debugPrint("❌ [_fetchAbnormalData] 錯誤: $e");
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceAll("Exception:", "").trim();
        _isLoading = false;
      });
    }
  }

  void _showNoticeDialog() {
    if (!mounted) return;
    final colorScheme = Theme.of(context).colorScheme;
    showGlassDialog(
      context: context,
      barrierDismissible: false,
      title: Row(
        children: [
          Icon(
            Icons.warning_amber_rounded,
            color: Colors.amber[800] ?? Colors.amber,
            size: 28,
          ),
          const SizedBox(width: 8),
          Text(
            "重要提醒",
            style: TextStyle(
              color: colorScheme.primaryText,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
      content: Text(
        "此部分功能僅供產出「異常處理申請表」的 PDF 檔案以供下載列印，並非線上直接完成異常處理的登錄與辦理。請在生成 PDF 之後，務必按照學校規定的流程進行後續辦理。",
        style: TextStyle(
          color: colorScheme.bodyText,
          fontSize: 15,
          height: 1.5,
        ),
      ),
      actions: [
        Builder(
          builder: (dialogCtx) => TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: Text(
              "我知道了",
              style: TextStyle(
                color: colorScheme.accentBlue,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWarningBanner(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.warningContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.amber.withValues(alpha: 0.4),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline,
            color: Colors.amber[800] ?? Colors.amber,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              "提示：此部分功能僅供生成 PDF 申請表，並非線上直接完成辦理，下載後仍須依學校規定流程送交辦理。",
              style: TextStyle(
                color: colorScheme.isDark
                    ? const Color(0xFFFFCC80)
                    : Colors.amber[900],
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // UI 區塊建構
  // ==========================================================
  @override
  Widget build(BuildContext context) {
    final bool isWide = MediaQuery.of(context).size.width >= 800;

    final colorScheme = Theme.of(context).colorScheme;
    final isLiquidGlass = LayoutStyleNotifier.instance.isLiquidGlass;

    return GlassPageScaffold(
      appBar: AppBar(
        title: const Text('異常處理申請'),
        centerTitle: true,
        backgroundColor: isLiquidGlass
            ? Colors.transparent
            : colorScheme.cardBackground,
        surfaceTintColor: isLiquidGlass ? Colors.transparent : null,
        elevation: isLiquidGlass ? 0 : 0.5,
        scrolledUnderElevation: isLiquidGlass ? 0 : null,
        foregroundColor: colorScheme.primaryText,
      ),
      backgroundColor: colorScheme.pageBackground,
      body: _buildBody(),
      bottomNavigationBar: isWide || _isLoading || _errorMessage != null
          ? null
          : _buildSubmitButton(),
    );
  }

  Widget _buildBody() {
    final colorScheme = Theme.of(context).colorScheme;
    final isLiquidGlass = LayoutStyleNotifier.instance.isLiquidGlass;

    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              color: isLiquidGlass ? colorScheme.primary : Colors.green,
            ),
            const SizedBox(height: 16),
            Text(
              "正在連線學校系統取得資料...",
              style: TextStyle(
                color: isLiquidGlass ? colorScheme.subtitleText : null,
              ),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 60, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: isLiquidGlass ? colorScheme.primaryText : null,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _fetchAbnormalData,
                child: const Text("重新嘗試"),
              ),
            ],
          ),
        ),
      );
    }

    // 分類課程
    final pendingCourses = _courses
        .where((c) => c.status.contains('未選上') || !c.status.contains('選上'))
        .toList();
    final selectedCourses = _courses
        .where((c) => c.status.contains('選上') && !c.status.contains('未選上'))
        .toList();

    final bool isWide = MediaQuery.of(context).size.width >= 800;
    if (isWide) {
      return _buildWideBody(pendingCourses, selectedCourses);
    } else {
      return _buildNarrowBody(pendingCourses, selectedCourses);
    }
  }

  Widget _buildNarrowBody(
    List<AbnormalCourse> pendingCourses,
    List<AbnormalCourse> selectedCourses,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        _buildWarningBanner(colorScheme),
        const SizedBox(height: 16),
        // --- 上方：未選上（異常處理）科目 ---
        if (pendingCourses.isNotEmpty) ...[
          const Text(
            "未選上科目",
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Color.fromARGB(255, 30, 184, 255),
            ),
          ),
          const SizedBox(height: 8),
          ...pendingCourses
              .map(
                (course) => AbnormalCourseCard(
                  key: ValueKey(course.id),
                  course: course,
                  reasons: _reasons,
                  onChanged: () => setState(() {}),
                ),
              )
              .toList(),
        ],

        // --- 中間分割線：只有當兩者都有資料時才顯示 ---
        if (pendingCourses.isNotEmpty && selectedCourses.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Divider(thickness: 1.5, color: Colors.grey),
          ),
        ],

        // --- 下方：已選上科目 ---
        if (selectedCourses.isNotEmpty) ...[
          const Text(
            "已選上科目",
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Colors.green,
            ),
          ),
          const SizedBox(height: 8),
          ...selectedCourses
              .map(
                (course) => AbnormalCourseCard(
                  key: ValueKey(course.id),
                  course: course,
                  reasons: _reasons,
                  onChanged: () => setState(() {}),
                ),
              )
              .toList(),
        ],

        // --- 自填課程區塊 ---
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              "自填課程",
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: Colors.blueGrey,
              ),
            ),
            if (_manualCourses.length < 2)
              TextButton.icon(
                onPressed: _addNewManualCourse,
                icon: const Icon(Icons.add),
                label: const Text("新增課程"),
              ),
          ],
        ),
        const SizedBox(height: 8),
        ..._manualCourses
            .asMap()
            .entries
            .map(
              (entry) => ManualCourseCard(
                key: ObjectKey(entry.value),
                index: entry.key,
                manualCourse: entry.value,
                reasons: _reasons,
                isActive: _pickingManualCourse == entry.value,
                onDelete: () {
                  setState(() {
                    _manualCourses.removeAt(entry.key);
                  });
                },
                onPickCourseCode: () => _pickCourseCode(entry.value),
                onChanged: () => setState(() {}),
              ),
            )
            .toList(),
      ],
    );
  }

  Widget _buildWideBody(
    List<AbnormalCourse> pendingCourses,
    List<AbnormalCourse> selectedCourses,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 左半邊：55% 寬度，顯示預設課程列表或行內搜尋器
        Expanded(
          flex: 11,
          child: Container(
            color: colorScheme.pageBackground,
            child: _pickingManualCourse != null
                ? InlineCoursePicker(
                    key: ObjectKey(_pickingManualCourse!),
                    onBack: () {
                      setState(() {
                        _pickingManualCourse = null;
                      });
                    },
                    onCourseSelected: (course) {
                      setState(() {
                        if (_pickingManualCourse != null) {
                          _pickingManualCourse!.courseNo = course.id;
                          _pickingManualCourse!.isExpanded = false;
                          _pickingManualCourse = null;
                        }
                      });
                    },
                  )
                : _buildWideDefaultCoursesList(pendingCourses, selectedCourses),
          ),
        ),
        // 分割線
        VerticalDivider(width: 1, color: colorScheme.borderColor),
        // 右半邊：45% 寬度，顯示自填課程與送出面板
        Expanded(
          flex: 9,
          child: Container(
            color: colorScheme.pageBackground,
            child: _buildWideManualPanel(),
          ),
        ),
      ],
    );
  }

  Widget _buildWideDefaultCoursesList(
    List<AbnormalCourse> pendingCourses,
    List<AbnormalCourse> selectedCourses,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.all(24.0),
      children: [
        Row(
          children: [
            Icon(
              Icons.assignment_late_outlined,
              color: colorScheme.accentBlue,
              size: 24,
            ),
            const SizedBox(width: 8),
            Text(
              "預設異常處理科目",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: colorScheme.primaryText,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          "請在此處勾選並設定需要加選或退選的異常科目。系統會自動解析您目前在選課系統中的狀態。",
          style: TextStyle(fontSize: 14, color: colorScheme.subtitleText),
        ),
        const SizedBox(height: 16),
        _buildWarningBanner(colorScheme),
        const SizedBox(height: 24),

        // --- 未選上（異常處理）科目 ---
        if (pendingCourses.isNotEmpty) ...[
          Text(
            "未選上科目",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: colorScheme.accentBlue,
            ),
          ),
          const SizedBox(height: 12),
          ...pendingCourses
              .map(
                (course) => AbnormalCourseCard(
                  key: ValueKey(course.id),
                  course: course,
                  reasons: _reasons,
                  onChanged: () => setState(() {}),
                ),
              )
              .toList(),
        ],

        // --- 中間分割線 ---
        if (pendingCourses.isNotEmpty && selectedCourses.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Divider(thickness: 1, color: colorScheme.borderColor),
          ),
        ],

        // --- 已選上科目 ---
        if (selectedCourses.isNotEmpty) ...[
          const Text(
            "已選上科目",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.green,
            ),
          ),
          const SizedBox(height: 12),
          ...selectedCourses
              .map(
                (course) => AbnormalCourseCard(
                  key: ValueKey(course.id),
                  course: course,
                  reasons: _reasons,
                  onChanged: () => setState(() {}),
                ),
              )
              .toList(),
        ],

        if (pendingCourses.isEmpty && selectedCourses.isEmpty) ...[
          Container(
            padding: const EdgeInsets.symmetric(vertical: 48),
            alignment: Alignment.center,
            child: Column(
              children: [
                Icon(
                  Icons.inbox_outlined,
                  size: 48,
                  color: colorScheme.iconColor,
                ),
                const SizedBox(height: 12),
                Text(
                  "無預設課程資料",
                  style: TextStyle(color: colorScheme.subtitleText),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildWideManualPanel() {
    final colorScheme = Theme.of(context).colorScheme;
    final isLiquidGlass = LayoutStyleNotifier.instance.isLiquidGlass;
    final isDark = colorScheme.isDark;
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(24.0),
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.edit_note_outlined,
                        color: colorScheme.accentBlue,
                        size: 24,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        "自填課程",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.primaryText,
                        ),
                      ),
                    ],
                  ),
                  if (_manualCourses.length < 2)
                    ElevatedButton.icon(
                      onPressed: _addNewManualCourse,
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text("新增自填"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colorScheme.primary,
                        foregroundColor: colorScheme.onPrimary,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                "若名單中沒有您想加退選的科目，請使用自填項目手動新增。至多可填寫 2 筆項目。",
                style: TextStyle(fontSize: 14, color: colorScheme.subtitleText),
              ),
              const SizedBox(height: 24),

              if (_manualCourses.isEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 48),
                  decoration: BoxDecoration(
                    color: colorScheme.subtleBackground,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: colorScheme.borderColor),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.add_circle_outline,
                        size: 40,
                        color: colorScheme.iconColor,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        "尚無自填項目",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.primaryText,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "點擊右上方按鈕新增自填課程",
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.subtitleText,
                        ),
                      ),
                    ],
                  ),
                )
              else
                ..._manualCourses
                    .asMap()
                    .entries
                    .map(
                      (entry) => ManualCourseCard(
                        key: ObjectKey(entry.value),
                        index: entry.key,
                        manualCourse: entry.value,
                        reasons: _reasons,
                        isActive: _pickingManualCourse == entry.value,
                        onDelete: () {
                          setState(() {
                            if (_pickingManualCourse == entry.value) {
                              _pickingManualCourse = null;
                            }
                            _manualCourses.removeAt(entry.key);
                          });
                        },
                        onPickCourseCode: () => _pickCourseCode(entry.value),
                        onChanged: () => setState(() {}),
                      ),
                    )
                    .toList(),
            ],
          ),
        ),
        Divider(height: 1, color: colorScheme.borderColor),
        () {
          final Widget barChild = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  // liquid glass：按鈕透明，透出毛玻璃底框；其他模式維持原深藍灰。
                  backgroundColor: isLiquidGlass
                      ? Colors.transparent
                      : Colors.blueGrey[800],
                  foregroundColor: isLiquidGlass
                      ? colorScheme.primaryText
                      : Colors.white,
                  side: isLiquidGlass
                      ? BorderSide(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.14)
                              : Colors.white.withValues(alpha: 0.4),
                        )
                      : null,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                onPressed: _handleSubmit,
                child: const Text(
                  "確認並獲取PDF",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          );
          if (isLiquidGlass) {
            return Container(
              padding: const EdgeInsets.all(24.0),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF1E222D).withValues(alpha: 0.90)
                    : Colors.white.withValues(alpha: 0.90),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
                border: Border(
                  top: BorderSide(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.14)
                        : Colors.black.withValues(alpha: 0.08),
                    width: 1.0,
                  ),
                ),
              ),
              child: barChild,
            );
          }
          return Container(
            padding: const EdgeInsets.all(24.0),
            color: colorScheme.cardBackground,
            child: barChild,
          );
        }(),
      ],
    );
  }

  void _addNewManualCourse() {
    setState(() {
      _manualCourses.add(ManualCourse()..selectedAction = "加選");
    });
  }

  Future<void> _pickCourseCode(ManualCourse manual) async {
    final bool isWide = MediaQuery.of(context).size.width >= 800;
    if (isWide) {
      setState(() {
        _pickingManualCourse = manual;
        manual.isExpanded = true;
      });
      return;
    }

    final String? pickedCode = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const CourseSearchPickerPage()),
    );

    if (!mounted) return;
    if (pickedCode != null) {
      setState(() {
        manual.courseNo = pickedCode;
      });
    }
  }

  Widget _buildSubmitButton() {
    final colorScheme = Theme.of(context).colorScheme;
    final isLiquidGlass = LayoutStyleNotifier.instance.isLiquidGlass;
    final isDark = colorScheme.isDark;

    final Widget button = ElevatedButton(
      style: ElevatedButton.styleFrom(
        // liquid glass：按鈕透明，直接透出毛玻璃底框，僅以邊框與文字定義；
        // 其他模式維持原深藍灰。
        backgroundColor: isLiquidGlass
            ? Colors.transparent
            : Colors.blueGrey[800],
        foregroundColor: isLiquidGlass ? colorScheme.primaryText : Colors.white,
        side: isLiquidGlass
            ? BorderSide(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.14)
                    : Colors.white.withValues(alpha: 0.4),
              )
            : null,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: isLiquidGlass ? 0 : null,
      ),
      onPressed: _handleSubmit,
      child: const Text(
        "確認並送出申請",
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
    );

    if (isLiquidGlass) {
      // glass 模式：高不透明度玻璃底框
      return SafeArea(
        child: Container(
          padding: const EdgeInsets.all(16.0),
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF1E222D).withValues(alpha: 0.90)
                : Colors.white.withValues(alpha: 0.90),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            border: Border(
              top: BorderSide(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.14)
                    : Colors.black.withValues(alpha: 0.08),
                width: 1.0,
              ),
            ),
          ),
          child: button,
        ),
      );
    }

    return SafeArea(
      child: Padding(padding: const EdgeInsets.all(16.0), child: button),
    );
  }

  // ==========================================================
  // 送出邏輯
  // ==========================================================
  Future<void> _handleSubmit() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    String studentId = (prefs.getString('username') ?? "").trim();
    String password = (prefs.getString('password') ?? "").trim();

    if (studentId.isEmpty || password.isEmpty) {
      _showSnackBar("請先設定帳號密碼");
      return;
    }

    // 1. 準備表單資料
    Map<String, String> formData = {};
    // 處理已勾選的課程
    for (var course in _courses) {
      if (course.isSelected) {
        if (course.selectedAction == null || course.selectedReason == null) {
          _showSnackBar("請填寫 [${course.courseName}] 的選項");
          return;
        }
        formData[course.id] = "ON";
        formData[course.actionName] = course.selectedAction!;
        formData[course.reasonName] = course.selectedReason!;
      }
    }

    // 處理自填課程 (安全地處理動態長度)
    for (int i = 0; i < 2; i++) {
      int suffix = i + 1; // 網頁表單對應的編號 (1 或 2)

      if (i < _manualCourses.length) {
        var m = _manualCourses[i];

        if (m.courseNo.isEmpty) {
          _showSnackBar("請選擇自填項目 $suffix 的課號");
          return;
        }

        formData["SEL_STATUS$suffix"] = m.selectedAction ?? "";
        formData["NEW_CRSNO$suffix"] = m.courseNo.trim();
        formData["NEW_CRSNO_RSN$suffix"] = m.selectedReason ?? "";
      } else {
        formData["SEL_STATUS$suffix"] = "";
        formData["NEW_CRSNO$suffix"] = "";
        formData["NEW_CRSNO_RSN$suffix"] = "";
      }
    }
    formData["B1"] = "確定送出";

    // 2. 直接跳轉，不傳遞 Cookie，只傳遞原始帳密
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AbnormalWebViewPage(
          postData: formData,
          stuid: studentId,
          password: password,
        ),
        settings: const RouteSettings(name: 'course_exception_download'),
      ),
    );
  }

  void _showSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.red[600],
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
