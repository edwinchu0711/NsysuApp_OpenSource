import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/course_model.dart';
import '../../services/course_query_service.dart'; // 確認你的 service 路徑正確
import 'package:flutter/services.dart'; // 加上這行來使用 Clipboard


class AssistantImportPage extends StatefulWidget {
  const AssistantImportPage({Key? key}) : super(key: key);

  @override
  State<AssistantImportPage> createState() => _AssistantImportPageState();
}

class _AssistantImportPageState extends State<AssistantImportPage> {
  final TextEditingController _textController = TextEditingController();
  bool _isImporting = false;

  Future<void> _processImport() async {
    final String input = _textController.text;
    if (input.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("請先貼上程式碼！")));
      return;
    }

    setState(() => _isImporting = true);

    try {
      // 1. 利用 Regex 擷取 exportClass 後面的 JSON 陣列
      final regex = RegExp(r'exportClass\s*=\s*(\[.*?\]);', dotAll: true);
      final match = regex.firstMatch(input);

      if (match == null) {
        throw FormatException("找不到有效的 exportClass 資料，請確認貼上的程式碼是否正確。");
      }

      String jsonString = match.group(1)!;
      List<dynamic> parsedJson = jsonDecode(jsonString);
      
      // 取出所有要匯入的課號
      List<String> idsToImport = parsedJson.map((e) => e['id'].toString()).toList();

      // 2. 讀取目前選課助手裡已經有的課程
      final prefs = await SharedPreferences.getInstance();
      String? existingJson = prefs.getString('assistant_courses');
      List<Course> currentCourses = [];
      if (existingJson != null && existingJson.isNotEmpty) {
        List<dynamic> decoded = jsonDecode(existingJson);
        currentCourses = decoded.map((v) => Course.fromJson(Map<String, dynamic>.from(v))).toList();
      }

      int successCount = 0;
      int skipCount = 0;
      List<String> failIds = [];

      // 3. 透過 CourseQueryService 尋找這些課號
      // 3. 確保資料已經載入 (重要！跟新增頁面一樣)
      await CourseQueryService.instance.getCourses();

      for (String id in idsToImport) {
        // 如果已經在課表裡就跳過
        if (currentCourses.any((c) => c.code == id)) {
          skipCount++;
          continue;
        }

        // ✅ 修正：改用 CourseQueryService.instance.search()
        // 注意：search 通常是同步的，所以不需要加 await
        List<CourseJsonData> results = CourseQueryService.instance.search(code: id);

        if (results.isNotEmpty) {
          CourseJsonData target = results.first; // 取第一筆符合的
          Course newCourse = _convertToCourse(target);
          currentCourses.add(newCourse);
          successCount++;
        } else {
          failIds.add(id);
        }
      }

      // 4. 將更新後的課表存回 SharedPreferences
      List<Map<String, dynamic>> toSave = currentCourses.map((c) => c.toJson()).toList();
      await prefs.setString('assistant_courses', jsonEncode(toSave));

      // 5. 顯示結果並返回
      if (mounted) {
        _showResultDialog(successCount, skipCount, failIds);
      }

    } catch (e) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text("匯入失敗"),
            content: Text(e.toString()),
            actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("確定"))],
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
  }

  // --- 新增：從剪貼簿貼上的功能 ---
  Future<void> _pasteFromClipboard() async {
    // 讀取剪貼簿的純文字內容
    ClipboardData? data = await Clipboard.getData(Clipboard.kTextPlain);
    
    if (data != null && data.text != null && data.text!.isNotEmpty) {
      setState(() {
        _textController.text = data.text!;
      });
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("剪貼簿內沒有文字！")),
        );
      }
    }
  }

  // 將 API 取回的 CourseJsonData 轉換為課表用的 Course 物件
  Course _convertToCourse(CourseJsonData data) {
    List<CourseTime> parsedTimes = [];
    
    // 假設 data.classTime 是一個陣列，index 0 為星期一，內容為 "123" 這種字串
    for (int i = 0; i < data.classTime.length; i++) {
      String periods = data.classTime[i].trim();
      for (int j = 0; j < periods.length; j++) {
        String p = periods[j];
        if (p != ' ' && p != '\u00A0') { // 排除空白
          // ✅ 修正：移除 day: 和 period:，直接傳入位置參數
          parsedTimes.add(CourseTime(i + 1, p));
        }
      }
    }

    return Course(
      name: data.name,
      code: data.id,
      professor: data.teacher,
      location: data.room,
      timeString: data.classTime.join(', '), 
      credits: data.credit,
      required: data.className.contains("必修") ? "必修" : "選修", // 簡易判斷
      detailUrl: "",
      parsedTimes: parsedTimes,
    );
  }

  void _showResultDialog(int success, int skip, List<String> fails) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text("匯入結果"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("✅ 成功匯入: $success 筆"),
            if (skip > 0) Text("⏭️ 已存在跳過: $skip 筆"),
            if (fails.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Text("❌ 找不到課程:", style: TextStyle(color: Colors.red)),
              Text(fails.join(", "), style: const TextStyle(color: Colors.red, fontSize: 13)),
            ]
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // 關閉 Dialog
              Navigator.pop(context, true); // 關閉匯入頁面並回傳 true 要求重整
            },
            child: const Text("確定並返回"),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("匯入課表")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(8)),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue),
                      SizedBox(width: 8),
                      Text("匯入說明", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ],
                  ),
                  SizedBox(height: 8),
                  Text("請至「中山選課小幫手網頁版」匯出加選課程，將產生的完整 JavaScript 程式碼複製並貼在下方欄位中。"),
                ],
              ),
            ),
            const SizedBox(height: 12),
            
            // ✅ 新增：標題與「剪貼簿貼上」按鈕
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "程式碼內容：",
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black54),
                ),
                TextButton.icon(
                  onPressed: _pasteFromClipboard,
                  icon: const Icon(Icons.paste, size: 18),
                  label: const Text("剪貼簿貼上"),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.blue[700],
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
              ],
            ),
            Expanded(
              child: TextField(
                controller: _textController,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                decoration: InputDecoration(
                  hintText: "貼上從選課小幫手複製的程式碼...",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  filled: true,
                  fillColor: Colors.grey[50],
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _isImporting ? null : _processImport,
                icon: _isImporting 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.download),
                label: Text(_isImporting ? "正在搜尋並匯入..." : "開始匯入"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[700],
                  foregroundColor: Colors.white,
                  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}