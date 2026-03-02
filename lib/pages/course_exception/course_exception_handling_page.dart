// 檔案名稱：course_exception_handling_page.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../utils/utils.dart'; // 請確保此路徑能正確引入包含 base64md5 的 Utils 類別
import 'course_search_picker_page.dart'; // 確保路徑正確引入課程搜尋頁面
import 'course_exception_download_page.dart';

// --- 資料模型 ---

/// 預設的異常處理課程 (從網頁抓取)
class AbnormalCourse {
  final String id;           // checkbox 的 name: CHEM624_22
  final String actionName;   // 下拉選單 name: abn_SelClass_CHEM624_22
  final String reasonName;   // 原因選單 name: abn_rsn_CHEM624_22
  final String status;
  final String courseNo;
  final String courseName;
  final String credits;
  final String teacher;

  bool isSelected = false;
  String? selectedAction;
  String? selectedReason;

  AbnormalCourse({
    required this.id,
    required this.actionName,
    required this.reasonName,
    required this.status,
    required this.courseNo,
    required this.courseName,
    required this.credits,
    required this.teacher,
  });
}
/// 自行輸入的課程
class ManualCourse {
  String? selectedAction;
  String courseNo = "";
  String? selectedReason;
}

/// 下拉選單的選項
class ReasonOption {
  final String value; // 代碼: A1
  final String text; // 顯示文字

  ReasonOption(this.value, this.text);
}


// --- 頁面主體 ---

class CourseExceptionHandlingPage extends StatefulWidget {
  const CourseExceptionHandlingPage({Key? key}) : super(key: key);

  @override
  State<CourseExceptionHandlingPage> createState() => _CourseExceptionHandlingPageState();
}

class _CourseExceptionHandlingPageState extends State<CourseExceptionHandlingPage> {
  bool _isLoading = true;
  String? _errorMessage;
  
  // 爬取下來的資料
  List<AbnormalCourse> _courses = [];
  List<ReasonOption> _reasons = [];
  
  // 非清單上的手動輸入課程 (網頁預設提供兩筆)
  final List<ManualCourse> _manualCourses = [];

  final http.Client _client = http.Client();
  final String _baseUrl = "https://selcrs.nsysu.edu.tw";

  @override
  void initState() {
    super.initState();
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
    print("🔍 [_loginViaSSO2] 開始執行 SSO 登入流程...");
    final loginUri = Uri.parse("$_baseUrl/menu4/Studcheck_sso2.asp");
    String encryptedPass = Utils.base64md5(password); 
    
    try {
      print("📡 [_loginViaSSO2] 發送 POST 請求至 $loginUri (帳號: $stuid)");
      final response = await _client.post(
        loginUri,
        headers: {
          "Content-Type": "application/x-www-form-urlencoded",
          "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
        },
        body: {"stuid": stuid.toUpperCase(), "SPassword": encryptedPass},
      );
      
      print("📥 [_loginViaSSO2] 收到伺服器回應，狀態碼: ${response.statusCode}");
      
      String? rawCookie = response.headers['set-cookie'];
      print("🍪 [_loginViaSSO2] 解析 Header 中的 Set-Cookie: $rawCookie");
      
      // 檢查是否包含帳密錯誤的關鍵字
      if (response.body.contains("不符")) {
        print("❌ [_loginViaSSO2] 登入失敗：網頁提示帳號或密碼不符！");
        return null;
      }
      
      if (rawCookie != null) {
        print("✅ [_loginViaSSO2] 登入成功，順利取得 Cookie！");
        return rawCookie;
      } else {
        print("⚠️ [_loginViaSSO2] 登入似乎沒有報錯，但 Header 中沒有回傳 Set-Cookie！");
      }
    } catch (e) { 
      print("❌ [_loginViaSSO2] 發生連線例外錯誤: $e"); 
    }
    return null;
  }
  
  Future<void> _fetchAbnormalData() async {
    
      print("🚀 [_fetchAbnormalData] 開始抓取異常處理資料...");
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

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
        final response = await _client.get(url, headers: {
          "Cookie": cookie,
          "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
        });

        // 使用 allowMalformed 避免 Big5 編碼異常導致崩潰
        String htmlBody = utf8.decode(response.bodyBytes, allowMalformed: true);
        
        // --- 4. 解析原因選單 (Reason Options) ---
        List<ReasonOption> parsedReasons = [];
        // 考慮 select 標籤可能會有換行或屬性順序不同
        RegExp reasonSelectRegex = RegExp(r'''<select[^>]+name=["\']?NEW_CRSNO_RSN1["\']?[^>]*>(.*?)</select>''', caseSensitive: false, dotAll: true);
        Match? reasonMatch = reasonSelectRegex.firstMatch(htmlBody);
        
        if (reasonMatch != null) {
          String optionsHtml = reasonMatch.group(1)!;
          // 捕捉 value 和顯示文字，並處理引號可能不存在的情況
          RegExp optionRegex = RegExp(r'''<option[^>]+value=["\']?([^"\'\s>]+)["\']?[^>]*>([^<]*)</option>''', caseSensitive: false);
          for (Match m in optionRegex.allMatches(optionsHtml)) {
            parsedReasons.add(ReasonOption(m.group(1)!, m.group(2)!.trim()));
          }
        }
        _reasons = parsedReasons;

        // --- 5. 解析課程表格 (強效解析法) ---
        List<AbnormalCourse> parsedCourses = [];
      List<String> rows = htmlBody.split(RegExp(r'</tr\s*>', caseSensitive: false));
      
      for (String rowHtml in rows) {
        if (rowHtml.contains(RegExp(r'''type=["\']?checkbox["\']?''', caseSensitive: false))) {
          // 提取 checkbox ID
          String id = RegExp(r'''name=["\']?([^"\'\s>]+)["\']?''', caseSensitive: false).firstMatch(rowHtml)?.group(1) ?? "";
          
          // 提取該列中的選單名稱 (Action & Reason)
          String actionName = RegExp(r'''name=["\']?(abn_SelClass_[^"\'\s>]+)["\']?''', caseSensitive: false).firstMatch(rowHtml)?.group(1) ?? "";
          String reasonName = RegExp(r'''name=["\']?(abn_rsn_[^"\'\s>]+)["\']?''', caseSensitive: false).firstMatch(rowHtml)?.group(1) ?? "";

          List<String> tdTexts = [];
          RegExp tdRegex = RegExp(r'<td[^>]*>(.*?)</td>', caseSensitive: false, dotAll: true);
          for (Match td in tdRegex.allMatches(rowHtml)) {
            String cleanText = td.group(1)!.replaceAll(RegExp(r'<[^>]*>'), '').replaceAll('&nbsp;', ' ').trim();
            tdTexts.add(cleanText);
          }

          if (id.isNotEmpty && tdTexts.length >= 7) {
            parsedCourses.add(AbnormalCourse(
              id: id,
              actionName: actionName,
              reasonName: reasonName,
              status: tdTexts[2],
              courseNo: tdTexts[3],
              courseName: tdTexts[4],
              credits: tdTexts[5],
              teacher: tdTexts[6],
            ));
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

        setState(() {
          _courses = parsedCourses;
          _isLoading = false;
          if (_courses.isEmpty) {
            _errorMessage = "登入成功，但目前沒有異常處理課程資料";
          }
        });

      } catch (e) {
        print("❌ [_fetchAbnormalData] 錯誤: $e");
        setState(() {
          _errorMessage = e.toString().replaceAll("Exception:", "").trim();
          _isLoading = false;
        });
      }
    }
  
  // ==========================================================
  // UI 區塊建構
  // ==========================================================
@override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // 1. 移除粗體
        title: const Text('異常處理申請'), 
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
      ),
      backgroundColor: Colors.grey[50],
      body: _buildBody(),
      bottomNavigationBar: _isLoading || _errorMessage != null ? null : _buildSubmitButton(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.green),
            SizedBox(height: 16),
            Text("正在連線學校系統取得資料..."),
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
              Text(_errorMessage!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _fetchAbnormalData,
                child: const Text("重新嘗試"),
              )
            ],
          ),
        ),
      );
    }

    // 1. 分類課程
    // 假設 status 包含 "選上" 的屬於下方，其餘（如：未選上、人數已滿、衝堂）在上方
    final pendingCourses = _courses.where((c) => c.status.contains('未選上') || !c.status.contains('選上')).toList();
    final selectedCourses = _courses.where((c) => c.status.contains('選上') && !c.status.contains('未選上')).toList();

    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        // --- 上方：未選上（異常處理）科目 ---
        if (pendingCourses.isNotEmpty) ...[
          const Text("未選上科目", 
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color.fromARGB(255, 30, 184, 255))),
          const SizedBox(height: 8),
          ...pendingCourses.map((course) => _buildCourseCard(course)).toList(),
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
          const Text("已選上科目", 
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.green)),
          const SizedBox(height: 8),
          ...selectedCourses.map((course) => _buildCourseCard(course)).toList(),
        ],

        // --- 原有的自填課程區塊 ---
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text("自填課程", style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
            if (_manualCourses.length < 2)
              TextButton.icon(
                onPressed: _addNewManualCourse,
                icon: const Icon(Icons.add),
                label: const Text("新增課程"),
              ),
          ],
        ),
        const SizedBox(height: 8),
        ..._manualCourses.asMap().entries.map((entry) => _buildManualCourseCard(entry.key, entry.value)).toList(),
      ],
    );
  }
  
  void _addNewManualCourse() {
    setState(() {
      // 預設選項設定為 "加選"
      _manualCourses.add(ManualCourse()..selectedAction = "加選");
    });
  }
  /// 建立預設課程的卡片
  Widget _buildCourseCard(AbnormalCourse course) {
    // 處理課程名稱：只顯示 "-" 後面的部分
    String displayName = course.courseName.contains('-') 
        ? course.courseName.split('-').last.trim() 
        : course.courseName;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: course.isSelected ? 3 : 1,
      child: Column(
        children: [
          CheckboxListTile(
            title: Text(displayName, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text("學分：${course.credits} | 教師：${course.teacher}"),
            value: course.isSelected,
            activeColor: Colors.blue, // 勾選後為藍色
            onChanged: (val) {
              setState(() {
                course.isSelected = val ?? false;
                if (!course.isSelected) {
                  course.selectedAction = null;
                  course.selectedReason = null;
                }
              });
            },
          ),
          if (course.isSelected)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Column(
                children: [
                  _buildActionDropdown(
                    value: course.selectedAction, 
                    onChanged: (val) => setState(() => course.selectedAction = val)
                  ),
                  const SizedBox(height: 12),
                  _buildReasonDropdown(
                    value: course.selectedReason, 
                    onChanged: (val) => setState(() => course.selectedReason = val)
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            )
        ],
      ),
    );
  }
  // 修改後的手動課程卡片
  Widget _buildManualCourseCard(int index, ManualCourse manualCourse) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("自填項目 ${index + 1}", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                  onPressed: () => setState(() => _manualCourses.removeAt(index)),
                )
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: _buildActionDropdown(
                    value: manualCourse.selectedAction,
                    onChanged: (val) => setState(() => manualCourse.selectedAction = val)
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 5,
                  child: InkWell(
                    onTap: () => _pickCourseCode(manualCourse),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[400]!),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              manualCourse.courseNo.isEmpty ? "點擊選擇課號" : manualCourse.courseNo,
                              style: TextStyle(color: manualCourse.courseNo.isEmpty ? Colors.grey : Colors.black87),
                            ),
                          ),
                          const Icon(Icons.search, size: 18, color: Colors.grey),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildReasonDropdown(
              value: manualCourse.selectedReason,
              onChanged: (val) => setState(() => manualCourse.selectedReason = val)
            ),
          ],
        ),
      ),
    );
  }
  /// 加退選下拉選單共用元件
  Widget _buildActionDropdown({required String? value, required ValueChanged<String?> onChanged}) {
    return DropdownButtonFormField<String>(
      decoration: const InputDecoration(
        labelText: '加/退選',
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
      value: value,
      items: const [
        DropdownMenuItem(value: "加選", child: Text("加選")),
        DropdownMenuItem(value: "退選", child: Text("退選")),
      ],
      onChanged: onChanged,
    );
  }

  /// 申請原因下拉選單共用元件
  Widget _buildReasonDropdown({required String? value, required ValueChanged<String?> onChanged}) {
    return DropdownButtonFormField<String>(
      isExpanded: true, 
      // 移除固定高度限制，讓內容決定高度
      decoration: const InputDecoration(
        labelText: '選擇原因',
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 15), // 增加垂直間距
      ),
      value: value,
      items: _reasons.map((reason) {
        // 移除 [ ] 及其中的內容
        String cleanText = reason.text.replaceAll(RegExp(r'\【.*?\】'), '').trim();

        return DropdownMenuItem(
          value: reason.value,
          // 使用 IntrinsicHeight 或直接讓 Text 換行
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(
              cleanText, 
              style: const TextStyle(fontSize: 13), 
              softWrap: true,
              overflow: TextOverflow.visible, // 確保文字完整顯示並換行
            ),
          ),
        );
      }).toList(),
      // 調整選單彈出時的樣式
      selectedItemBuilder: (BuildContext context) {
        return _reasons.map<Widget>((reason) {
          String cleanText = reason.text.replaceAll(RegExp(r'\【.*?\】'), '').trim();
          return Text(
            cleanText,
            style: const TextStyle(fontSize: 13),
            overflow: TextOverflow.ellipsis, // 在收合狀態下保持單列
          );
        }).toList();
      },
      onChanged: onChanged,
    );
  }


  Future<void> _pickCourseCode(ManualCourse manual) async {
    // 跳轉到剛剛建立的挑選頁面
    final String? pickedCode = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const CourseSearchPickerPage()),
    );

    if (pickedCode != null) {
      setState(() {
        manual.courseNo = pickedCode;
      });
    }
  }

  Widget _buildSubmitButton() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blueGrey[800], // 改為深藍灰色
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: _handleSubmit,
          child: const Text("確認並送出申請", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }
  // ==========================================================
  // 送出邏輯
  // ==========================================================
  Future<void> _handleSubmit() async {
    final prefs = await SharedPreferences.getInstance();
    String studentId = (prefs.getString('username') ?? "").trim();
    String password = (prefs.getString('password') ?? "").trim();

    if (studentId.isEmpty || password.isEmpty) {
      _showSnackBar("請先設定帳號密碼");
      return;
    }

    // 1. 準備表單資料 (此處邏輯不變，保持原本的 formData 組合)
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

    // 處理自填課程 (固定 1 & 2 兩組)
    // 處理自填課程 (安全地處理動態長度)
    for (int i = 0; i < 2; i++) {
      int suffix = i + 1; // 網頁表單對應的編號 (1 或 2)
      
      // 檢查目前的索引是否存在於 _manualCourses 中
      if (i < _manualCourses.length) {
        var m = _manualCourses[i]; // 現在這裡安全了，不會報 RangeError
        
        // 檢查是否有選課號 (非必填可移除此判斷)
        if (m.courseNo.isEmpty) {
          _showSnackBar("請選擇自填項目 $suffix 的課號");
          return; 
        }

        formData["SEL_STATUS$suffix"] = m.selectedAction ?? "";
        formData["NEW_CRSNO$suffix"] = m.courseNo.trim();
        formData["NEW_CRSNO_RSN$suffix"] = m.selectedReason ?? "";
      } else {
        // 如果清單中沒有這筆，則傳送空字串給伺服器，確保表單結構完整
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
      ),
    );
  } 
    
  
  void _showSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red[600]),
    );
  }
}