import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/utils.dart'; // 請確認路徑

// --- 資料模型 ---
class CourseSelectionData {
  final String status;      // 選上/登記加選/退選
  final String dept;        // 系所
  final String code;        // 代號
  final String grade;       // 年級
  final String remarks; //點數志願
  final String name;        // 科目名稱
  final String credits;     // 學分
  final String type;        // 必/選修
  final String professor;   // 教師
  final String timeRoom;    // 時間教室
  final String note;        // 備註

  CourseSelectionData({
    required this.status,
    required this.dept,
    required this.code,
    required this.grade,
    required this.remarks,
    required this.name,
    required this.credits,
    required this.type,
    required this.professor,
    required this.timeRoom,
    required this.note,
  });
}

// --- 狀態列舉 ---
enum SelectionState {
  closed,           // 選課未開放
  needConfirmation, // 尚未完成預選確認
  open,             // 正常開放中
  error,            // 錯誤
}

class CourseSelectionService {
  static final CourseSelectionService instance = CourseSelectionService._privateConstructor();
  CourseSelectionService._privateConstructor();

  final String _baseUrl = "https://selcrs.nsysu.edu.tw";
  final http.Client _client = http.Client();

  /// 主要功能：抓取選課結果
  Future<Map<String, dynamic>> fetchSelectionResult() async {
    print("🔍 [偵錯] 開始執行 fetchSelectionResult...");

    try {
      final prefs = await SharedPreferences.getInstance();
      String studentId = (prefs.getString('username') ?? "").trim();
      String password = (prefs.getString('password') ?? "").trim();

      if (studentId.isEmpty || password.isEmpty) {
        print("❌ [偵錯] 帳號或密碼為空");
        throw "找不到帳號密碼";
      }

      // 1. 登入
      print("🔍 [偵錯] 正在登入...");
      String? cookie = await _loginViaSSO2(studentId, password);
      if (cookie == null) {
        print("❌ [偵錯] 登入失敗 (Cookie 為 null)");
        throw "登入失敗，請檢查帳號密碼";
      }
      print("✅ [偵錯] 登入成功，Cookie 取得");

      // --- [新步驟] 2. Request main_frame.asp 取得參數 ---
      final mainFrameUrl = Uri.parse("$_baseUrl/menu4/main_frame.asp");
      print("🔍 [偵錯] 請求 MainFrame: $mainFrameUrl");
      
      final mainFrameResponse = await _client.get(mainFrameUrl, headers: {
        "Cookie": cookie,
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
      });
      String mainFrameBody = utf8.decode(mainFrameResponse.bodyBytes, allowMalformed: true);
      
      // 解析 frame src 中的參數
      // 目標格式: src="Studfun.asp?DEG_COD=B&..."
      RegExp paramRegex = RegExp(r'src="Studfun\.asp\?([^"]+)"', caseSensitive: false);
      Match? paramMatch = paramRegex.firstMatch(mainFrameBody);
      
      String studFunParams = "";
      if (paramMatch != null) {
        studFunParams = paramMatch.group(1) ?? "";
        print("✅ [偵錯] 成功抓取參數串: $studFunParams");
      } else {
        print("⚠️ [偵錯] 在 main_frame 無法抓取參數，將嘗試不帶參數進入 (可能失敗)");
        // 印出 Body 前段供除錯
        print("📄 [偵錯] main_frame片段: ${mainFrameBody.substring(0, (mainFrameBody.length > 300 ? 300 : mainFrameBody.length))}");
      }

      // --- 3. Request Studfun.asp (帶參數) ---
      // 如果有參數就加上去，變成 Studfun.asp?DEG_COD=...
      String studFunUrlString = "$_baseUrl/menu4/Studfun.asp";
      if (studFunParams.isNotEmpty) {
        studFunUrlString += "?$studFunParams";
      }
      
      final studFunUrl = Uri.parse(studFunUrlString);
      print("🔍 [偵錯] 請求選單頁面 (帶參): $studFunUrl");
      
      final response = await _client.get(studFunUrl, headers: {
        "Cookie": cookie,
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
      });
      String body = utf8.decode(response.bodyBytes, allowMalformed: true);
      print("📄 [偵錯] Studfun.asp 回傳長度: ${body.length}");

      // --- 4. 尋找第一個 <a> 連結 ---
      RegExp hrefReg = RegExp(r'<a\s+href="([^"]+)"', caseSensitive: false);
      Match? match = hrefReg.firstMatch(body);

      if (match == null) {
        print("❌ [偵錯] 在 Studfun.asp 找不到任何 <a> 連結，可能選單結構改變或參數無效");
        print("📄 [偵錯] 頁面片段: ${body.substring(0, (body.length > 500 ? 500 : body.length))}");
        throw "找不到選課入口連結";
      }

      String firstLink = match.group(1) ?? "";
      print("🔗 [偵錯] 抓到的第一個連結為: [$firstLink]");
      
      // --- 5. 判斷選課是否開放 ---
      // if (firstLink.contains("query/result.asp")) {
      //   print("⚠️ [偵錯] 連結包含 query/result.asp，判斷為選課系統未開放");
      //   return {'state': SelectionState.closed, 'data': <CourseSelectionData>[]};
      // }

      // --- 6. 進入選課頁面 ---
      String targetUrl = "$_baseUrl/menu4/$firstLink";
      print("🔍 [偵錯] 準備請求目標選課頁面: $targetUrl");
      
      final selectionRes = await _client.get(Uri.parse(targetUrl), headers: {
        "Cookie": cookie,
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
        "Referer": studFunUrl.toString(),
      });
      String selectionBody = utf8.decode(selectionRes.bodyBytes, allowMalformed: true);
      print("📄 [偵錯] 選課頁面回傳長度: ${selectionBody.length}");

      // --- 7. 檢查是否需要「預選確認」 ---
      if (selectionBody.contains('value="送出"') && 
          selectionBody.contains('''onclick="document.getElementById('step_id').innerHTML='&lt;input type=hidden name=step value=2 &gt;';document.all['send'].click();"''')) {
          
          print("⚠️ [偵錯] 偵測到 '尚未完成預選確認' 按鈕");
          return {'state': SelectionState.needConfirmation, 'data': <CourseSelectionData>[]};
      }

    //  / --- [新步驟] 7.5 如果沒有預選確認，強制導向到選課結果頁面 ---
      print("🔍 [偵錯] 無須確認，導向至已選結果頁面...");
      final resultUrl = Uri.parse("$_baseUrl/menu4/query/slt_result.asp?admit=0");
      
      final resultRes = await _client.get(resultUrl, headers: {
        "Cookie": cookie,
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
        "Referer": targetUrl, // 從剛才的頁面跳轉過來
      });

      // 更新 selectionBody 為新頁面的內容
      selectionBody = utf8.decode(resultRes.bodyBytes, allowMalformed: true);
      print("📄 [偵錯] 已選結果頁面回傳長度: ${selectionBody.length}");

      // --- 8. 解析表格資料 ---
      print("🔍 [偵錯] 開始解析表格...");
      
      // 使用新的 selectionBody (slt_result.asp 的內容) 進行解析
      List<CourseSelectionData> courses = _parseSelectionTable(selectionBody);
      print("✅ [偵錯] 解析完成，共找到 ${courses.length} 門課");
      
      return {'state': SelectionState.open, 'data': courses};

    } catch (e) {
      print("❌ [偵錯] 發生例外狀況: $e");
      rethrow;
    }
  }

  // --- HTML 解析邏輯 (維持容錯模式) ---
  List<CourseSelectionData> _parseSelectionTable(String html) {
      List<CourseSelectionData> results = [];
      print("🛠️ [解析] 啟動結果頁面解析 (slt_result 模式)...");

      // 1. 統一結尾標籤 (轉小寫方便切割)
      String processedHtml = html.replaceAll(RegExp(r'</TR>', caseSensitive: false), '</tr>');

      // 2. 切割列
      List<String> rawRows = processedHtml.split('</tr>');
      print("📋 [解析] 切割出 ${rawRows.length} 個區塊");

      int validRowCount = 0;
      
      // Regex: 抓取 td 內的內容 (使用 dotAll 確保換行也被抓到)
      final tdRegex = RegExp(r'<td[^>]*>(.*?)</td>', caseSensitive: false, dotAll: true);
      
      // Helper: 去除 HTML 標籤與空白
      String strip(String s) {
        return s.replaceAll(RegExp(r'<[^>]+>'), '') // 去除標籤
                .replaceAll('&nbsp;', '')          // 去除空格實體
                .replaceAll(RegExp(r'\s+'), ' ')   // 縮減多餘空白
                .trim();
      }

      for (int i = 0; i < rawRows.length; i++) {
        String rowContent = rawRows[i];
        
        // 取得該列所有欄位
        List<String> cells = tdRegex.allMatches(rowContent).map((m) => m.group(1) ?? "").toList();

        // --- 過濾邏輯 ---
        
        // 1. 欄位過少：通常是 colspan 的分隔列 (例如 "※ ※ 選上課程 ※ ※") 或空列
        // 目標表格完整資料有 14 欄，少於 10 欄肯定不是課程資料
        if (cells.length < 10) {
          continue;
        }

        // 2. 標題列檢查：檢查第 0 欄是否為 "選上與否" 或第 1 欄為 "系所別"
        String cell0 = strip(cells[0]);
        if (cell0.contains("選上與否") || cell0 == "選上") { 
          // 有些標題寫 "選上<br>與否"，strip後變成 "選上與否"，但有時候資料列也可能只寫"選上"
          // 所以多檢查第二欄標題確保萬無一失
          if (strip(cells[1]).contains("系所別")) {
              print("   -> 跳過標題列");
              continue;
          }
        }

        // --- 資料解析 (根據提供的 HTML 結構) ---
        // index 0: 狀態 (選上/登記加選)
        // index 1: 系所別 (資管系)
        // index 2: 課號 (MIS324)
        // index 3: 年級 (3)
        // index 4: 課程代碼 (B4023329) -> 對應 code
        // index 5: 課程名稱 (含 <a>) -> 對應 name
        // index 6: 點數/志願 (20)
        // index 7: 階段 (22)
        // index 8: 學分 (3) -> 對應 credits
        // index 9: 學年期 (期)
        // index 10: 必選修 (必) -> 對應 type
        // index 11: 授課教師 (康藝晃) -> 對應 professor
        // index 12: 教室 (一A() ...) -> 對應 timeRoom
        // index 13: 說明 (限資管系...) -> 對應 note

        try {
          validRowCount++;
          
          String status = strip(cells[0]);    // 選上 / 登記加選
          String dept = strip(cells[1]);      // 系所
          //String courseNo = strip(cells[2]); // 課號 (MISxxx)
          String grade = strip(cells[3]);     // 年級
          String code = strip(cells[2]);      // 課程代碼 (Unique ID)
          String name = strip(cells[5]);      // 課程名稱
          String credits = strip(cells[8]);   // 學分
          String type = strip(cells[10]);     // 必選修
          String professor = strip(cells[11]);// 老師
          String timeRoom = strip(cells[12]); // 時間教室
          String note = strip(cells[6]);     // 說明

          // 處理備註：可以組合 點數(idx 6) 或 說明(idx 13)
          // 這裡將 "說明" 放進 note，如果需要也可以放進 remarks
          String remarks = note; 

          print("   -> ✅ 第 $validRowCount 筆: [$status] $name ($professor)");

          results.add(CourseSelectionData(
            status: status,
            dept: dept,
            code: code,
            grade: grade,
            name: name,
            credits: credits,
            type: type,
            professor: professor,
            timeRoom: timeRoom,
            note: note,
            remarks: remarks, // 視你的 Data Class 定義，若無 remarks 欄位可移除
          ));

        } catch (e) {
          print("   -> ⚠️ 解析資料列時發生錯誤 (Row $i): $e");
          // 印出該列內容以便除錯
          // print("        Raw: $cells");
        }
      }

      print("✅ [解析] 完成，共擷取到 ${results.length} 門課程");
      return results;
  }
  
  Future<String?> _loginViaSSO2(String stuid, String password) async {
    final loginUri = Uri.parse("$_baseUrl/menu4/Studcheck_sso2.asp");
    String encryptedPass = Utils.base64md5(password); 
    try {
      final response = await _client.post(
        loginUri,
        headers: {
          "Content-Type": "application/x-www-form-urlencoded",
          "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
        },
        body: {"stuid": stuid.toUpperCase(), "SPassword": encryptedPass},
      );
      String? rawCookie = response.headers['set-cookie'];
      if (rawCookie != null && !response.body.contains("不符")) return rawCookie;
    } catch (e) { 
      print("❌ [偵錯] Login Error: $e"); 
    }
    return null;
  }
}