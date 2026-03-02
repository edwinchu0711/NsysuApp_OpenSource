import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/course_model.dart'; // 請確認路徑

class AssistantExportPage extends StatefulWidget {
  const AssistantExportPage({Key? key}) : super(key: key);

  @override
  State<AssistantExportPage> createState() => _AssistantExportPageState();
}

class _AssistantExportPageState extends State<AssistantExportPage> {
  List<Course> _assistantCourses = [];
  Set<String> _selectedCourseIds = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAssistantCourses();
  }

  Future<void> _loadAssistantCourses() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? jsonStr = prefs.getString('assistant_courses');
      if (jsonStr != null && jsonStr.isNotEmpty) {
        List<dynamic> decoded = jsonDecode(jsonStr);
        setState(() {
          _assistantCourses = decoded.map((v) => Course.fromJson(Map<String, dynamic>.from(v))).toList();
          // 預設全選
          _selectedCourseIds = _assistantCourses.map((c) => c.code).toSet();
        });
      }
    } catch (e) {
      print("讀取助手課表失敗: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 執行匯出
  Future<void> _exportToCart() async {
    if (_selectedCourseIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("請至少選擇一門課程")));
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      // 將選取的課號存入一個專屬的 key，讓正式選課頁面去讀取
      await prefs.setStringList('exported_course_ids', _selectedCourseIds.toList());

      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Row(children: [Icon(Icons.check_circle, color: Colors.green), SizedBox(width: 8), Text("匯出成功")]),
            content: const Text("已成功將課程匯出！\n\n請在選課開放期間，前往「選課系統」頁面，系統會自動將這些課程加入您的待加選清單中。"),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context); // 關閉 Dialog
                  Navigator.pop(context); // 返回助手頁面
                },
                child: const Text("我知道了"),
              )
            ],
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("匯出失敗：$e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isAllSelected = _selectedCourseIds.length == _assistantCourses.length && _assistantCourses.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text("匯出至選課系統"),
        actions: [
          if (_assistantCourses.isNotEmpty)
            TextButton(
              onPressed: () {
                setState(() {
                  if (isAllSelected) {
                    _selectedCourseIds.clear();
                  } else {
                    _selectedCourseIds = _assistantCourses.map((c) => c.code).toSet();
                  }
                });
              },
              style: TextButton.styleFrom(foregroundColor: Colors.blue[800]),
              child: Text(isAllSelected ? "取消全選" : "全選"),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _assistantCourses.isEmpty
              ? const Center(child: Text("助手課表目前沒有正式課程，無法匯出", style: TextStyle(color: Colors.grey)))
              : Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      color: Colors.orange[50],
                      child: const Row(
                        children: [
                          Icon(Icons.lightbulb_outline, color: Colors.orange),
                          SizedBox(width: 8),
                          Expanded(child: Text("勾選您想匯出的課程，點擊下方按鈕後，前往「選課系統」頁面即可自動加入待加選清單！", style: TextStyle(color: Colors.orange, fontSize: 13))),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.separated(
                        itemCount: _assistantCourses.length,
                        separatorBuilder: (context, index) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final course = _assistantCourses[index];
                          final isSelected = _selectedCourseIds.contains(course.code);
                          return CheckboxListTile(
                            value: isSelected,
                            title: Text(course.name.split('\n')[0], style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text("${course.code} · ${course.professor}"),
                            activeColor: Colors.blue[700],
                            onChanged: (bool? value) {
                              setState(() {
                                if (value == true) {
                                  _selectedCourseIds.add(course.code);
                                } else {
                                  _selectedCourseIds.remove(course.code);
                                }
                              });
                            },
                          );
                        },
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: const Offset(0, -5))],
                      ),
                      child: SafeArea(
                        child: SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton.icon(
                            onPressed: _selectedCourseIds.isEmpty ? null : _exportToCart,
                            icon: const Icon(Icons.shopping_cart_checkout),
                            label: Text("匯出 ${_selectedCourseIds.length} 門課程", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue[700],
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    )
                  ],
                ),
    );
  }
}