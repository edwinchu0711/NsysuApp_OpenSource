import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:html/parser.dart' show parse;
// 假設這是你存放 base64md5 的地方
import '../utils/utils.dart'; 
import '../models/graduation_model.dart';

class GraduationService {
  // Singleton
  static final GraduationService instance = GraduationService._();
  GraduationService._();

  static const String _cacheKeyData = 'grad_data_cache';
  static const String _cacheKeyTime = 'grad_time_cache';

  /// 清除快取 (Logout 時呼叫)
  Future<void> clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cacheKeyData);
    await prefs.remove(_cacheKeyTime);
  }

  /// 獲取資料 (自動判斷是否使用快取)
  /// 回傳 GraduationData? 以防萬一出錯時可以 handle
  Future<GraduationData?> fetchGraduationData({bool forceRefresh = false}) async {
    final prefs = await SharedPreferences.getInstance();
    
    // 1. 檢查快取 (10分鐘內有效)
    if (!forceRefresh) {
      final int? lastTime = prefs.getInt(_cacheKeyTime);
      if (lastTime != null) {
        final diff = DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(lastTime));
        if (diff.inMinutes < 10) {
          final String? jsonStr = prefs.getString(_cacheKeyData);
          if (jsonStr != null && jsonStr.isNotEmpty) {
            try {
              print("📦 讀取畢業檢核快取資料 (10分鐘內)");
              return GraduationData.fromJson(jsonDecode(jsonStr));
            } catch (e) {
              print("快取解析失敗，將重新抓取: $e");
            }
          }
        }
      }
    }

    // 2. 從 Preferences 讀取帳密 (你的 main menu 應該已經存好了)
    final String username = (prefs.getString('username') ?? "").trim();
    final String password = (prefs.getString('password') ?? "").trim();

    if (username.isEmpty || password.isEmpty) {
      throw Exception("找不到帳號密碼，請嘗試重新登入 App");
    }

    // 3. 執行網路請求
    return await _fetchFromNetwork(username, password);
  }

  Future<GraduationData> _fetchFromNetwork(String username, String password) async {
    print("🌐 開始連線教務處取得畢業檢核...");
    final dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      responseType: ResponseType.plain,
    ));

    try {
      // Step A: SSO 登入
      final String base64md5Password = Utils.base64md5(password);
      
      final loginResponse = await dio.post(
        'https://selcrs.nsysu.edu.tw/gadchk/gad_chk_login_prs_sso2.asp',
        data: {
          'SID': username.toUpperCase(),
          'PASSWD': base64md5Password,
          'ACTION': '0',
          'INTYPE': '1',
        },
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          // 👇 關鍵修改：禁止自動跳轉，並允許 302 狀態碼
          followRedirects: false,
          validateStatus: (status) {
            return status != null && status < 500; // 只要小於 500 (包含 302) 都視為成功
          },
        ),
      );

      // 取得 Cookies (通常在 302 回應的 Header 中)
      List<String>? cookies = loginResponse.headers['set-cookie'];
      
      // 補充判斷：有時候成功會直接回傳 302，有時候是 200，只要拿到 Cookie 就算成功
      if (cookies == null || cookies.isEmpty) {
        throw Exception("登入失敗：無法取得 Session (請檢查帳號密碼)");
      }
      String cookieString = cookies.map((s) => s.split(';').first).join('; ');

      // Step B: 抓取檢核表 HTML
      final dataResponse = await dio.get(
        'https://selcrs.nsysu.edu.tw/gadchk/gad_chk_stu_list.asp',
        queryParameters: {
          'stno': username,
          'KIND': '5',
          'frm': '1',
        },
        options: Options(
          headers: {'Cookie': cookieString},
          responseType: ResponseType.plain, // 確保以純文字讀取 HTML
        ),
      );

      // Step C: 解析 HTML
      String htmlContent = dataResponse.data.toString();
      
      // 簡單檢查是否被導回登入頁 (如果 Cookie 無效，學校系統通常會回傳登入畫面)
      if (htmlContent.contains("請輸入學號及密碼")) {
         throw Exception("Session 無效，請稍後再試");
      }

      GraduationData data = _parseHtml(htmlContent);

      // Step D: 寫入快取
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKeyData, jsonEncode(data.toJson()));
      await prefs.setInt(_cacheKeyTime, DateTime.now().millisecondsSinceEpoch);
      print("✅ 畢業檢核資料抓取並快取完成");
      return data;

    } catch (e) {
      print("❌ 畢業檢核抓取錯誤: $e");
      rethrow;
    }
  }
  GraduationData _parseHtml(String html) {
    var document = parse(html);
    String fullText = document.body?.text ?? "";

    // 1. 基本資料 Regex
    String checkTime = "";
    String department = "";
    String name = "";
    String id = "";
    
    // 抓審查時間
    if (html.contains("審查時間：")) {
      int idx = html.indexOf("審查時間：");
      // 簡單找換行或 tag 結束
      int endIdx = html.indexOf("<", idx);
      if (endIdx > idx) {
        checkTime = html.substring(idx + 5, endIdx).trim();
      }
    }

    // 抓系級/姓名/學號
    // 你的 HTML 範例: 系級：?? 姓名：?? 學號：???
    RegExp infoReg = RegExp(r"系級：(.*?)姓名：(.*?)學號：(.*?)(EMAIL|$)");
    var infoMatch = infoReg.firstMatch(fullText.replaceAll('\n', '').replaceAll('\r', ''));
    if (infoMatch != null) {
      department = infoMatch.group(1)?.trim() ?? "";
      name = infoMatch.group(2)?.trim() ?? "";
      id = infoMatch.group(3)?.trim() ?? "";
    }

    // 2. 解析表格 (使用狀態機 State Machine)
    List<String> missing = [];
    List<GenEdStatus> genEds = [];
    List<String> electives = [];

    bool inMissingSection = false;
    bool inGenEdSection = false;
    bool inElectiveSection = false;

    GenEdStatus? currentGenEdItem;

    var trs = document.querySelectorAll('tr');

    for (var tr in trs) {
      String text = tr.text.trim();

      // --- 區塊判斷 ---
      if (text.contains("學系必修課程缺修")) {
        inMissingSection = true; inGenEdSection = false; inElectiveSection = false; continue;
      }
      if (text.contains("通識課程：")) {
        inMissingSection = false; inGenEdSection = true; inElectiveSection = false; continue;
      }
      if (text.contains("選修課程：")) {
        inMissingSection = false; inGenEdSection = false; inElectiveSection = true; continue;
      }

      var tds = tr.querySelectorAll('td');
      if (tds.isEmpty) continue;

      // === 通識區塊邏輯 ===
      if (inGenEdSection) {
        // 判斷 1: 是否為主項目 (含有狀態關鍵字)
        bool isMainStatusRow = text.contains("符合") || text.contains("未符");

        if (isMainStatusRow) {
          // --- 解析主項目 ---
          String status = text.contains("符合") ? "符合" : "未符";
          String itemName = "";
          String desc = "";

          for (var td in tds) {
            String t = td.text.trim();
            if (t.isEmpty || t == "符合" || t == "未符" || t == "／" || RegExp(r'^\d+$').hasMatch(t)) continue;
            if (t.contains("應修") || t.contains("實得")) break; 
            
            if (t.contains("缺") || t.contains("尚缺")) {
              desc = t;
            } else if (itemName.isEmpty && t.length > 2) {

              itemName = t.replaceAll('\n', '');
              if (itemName == "※注意：以上各類別之「檢核欄」必須全部為「符合」且通識課程必修至少２８學分，方達成所有通識課程畢業要求。") {
                itemName = "通識28學分要求";
              }
              }
          }

          if (itemName.isNotEmpty) {
            List<String> detailsBuffer = []; // 準備裝子項目
            var newItem = GenEdStatus(
              name: itemName, 
              status: status, 
              description: desc,
              details: detailsBuffer
            );
            genEds.add(newItem);
            currentGenEdItem = newItem; // 更新焦點
          }
        } 
        else if (currentGenEdItem != null) {
          // --- 判斷 2: 子細項檢查 (檢查 Height != 18) ---
          bool isChildRow = false;
          
          // 嘗試抓取 height 屬性 (模擬你原本的 p5 邏輯)
          try {
            var firstTd = tr.querySelector('td');
            if (firstTd != null) {
               // 根據結構往上找 tr
               // 向上找父節點
              var p1 = firstTd.parent;      // tr (height=18)
              var p2 = p1?.parent;     // tbody
              var p3 = p2?.parent;     // table
              var p4 = p3?.parent;     // td (colspan=3)
              var p5 = p4?.parent;     // 這是您要檢查的那層 tr
              //  var p5 = firstTd.parent?.parent?.parent?.parent; 
               if (p5 != null && p5.localName == 'tr') {
                 if (p5.attributes['height'] != '18') {
                   isChildRow = true;
                 }
               }
            }
          } catch (_) {
            // 結構如果不對就忽略
          }

          if (isChildRow) {
            // 整理文字 (去除多餘空白)
            String detailText = text.replaceAll(RegExp(r'\s+'), ' ').trim();
            if (detailText.isNotEmpty) {
              // 加入到當前主項目的 details
              currentGenEdItem.details.add(detailText);
            }
          }
        }
      } 
      // === 必修區塊邏輯 ===
      else if (inMissingSection) { 
         if (tds.length >= 3) {
           String col1 = tds[0].text.trim();
           String col2 = tds[1].text.trim();
           // 簡單判斷第二欄是否為數字(學分)，避免抓到表頭
           if (RegExp(r'^\d+$').hasMatch(col2)) {
             missing.add(col1);
           }
        }
      }
      // === 選修區塊邏輯 ===
      else if (inElectiveSection) {
         if (tds.length >= 3) {
            String col1 = tds[0].text.trim();
            String col3 = tds[2].text.trim();
            if (!col1.contains("已修習科目") && RegExp(r'^\d+$').hasMatch(col3)) {
              electives.add("$col1 ($col3學分)");
            }
         }
      }
    }
    // 3. 畢業總學分 (Regex 搜尋全文)
    int minC = 128;
    int currC = 0;
    // 你的 HTML: "最低畢業學分數為 135 學分，目前累計學分數為 92 學分"
    RegExp creditExp = RegExp(r"最低畢業學分數為\s*(\d+)\s*學分.*目前累計學分數為\s*(\d+)\s*學分");
    var cMatch = creditExp.firstMatch(fullText);
    if (cMatch != null) {
      minC = int.parse(cMatch.group(1)!);
      currC = int.parse(cMatch.group(2)!);
    }

    return GraduationData(
      checkTime: checkTime,
      department: department,
      studentName: name,
      studentId: id,
      minCredits: minC,
      currentCredits: currC,
      missingRequiredCourses: missing,
      genEdStatuses: genEds,
      takenElectiveCourses: electives,
    );
  }
}