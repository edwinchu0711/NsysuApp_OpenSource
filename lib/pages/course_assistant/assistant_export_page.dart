import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/course_model.dart'; // 請確認路徑
import '../../theme/app_theme.dart';
import '../../theme/layout_style_notifier.dart';
import '../../widgets/glass/glass_page_scaffold.dart';
import '../../widgets/glass/glass_dialog.dart';
import '../../widgets/glass/glass_card.dart';

class AssistantExportPage extends StatefulWidget {
  final bool isInline;
  final VoidCallback? onExportSuccess;
  final List<Course>? courses;
  const AssistantExportPage({
    super.key,
    this.isInline = false,
    this.onExportSuccess,
    this.courses,
  });

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
    if (widget.courses != null) {
      _assistantCourses = List<Course>.from(widget.courses!);
      _selectedCourseIds = _assistantCourses.map((c) => c.code).toSet();
      _isLoading = false;
    } else {
      _loadAssistantCourses();
    }
  }

  @override
  void didUpdateWidget(covariant AssistantExportPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.courses != null) {
      final oldCodes = oldWidget.courses?.map((c) => c.code).toList() ?? [];
      final newCodes = widget.courses!.map((c) => c.code).toList();

      bool listsAreEqual = oldCodes.length == newCodes.length;
      if (listsAreEqual) {
        for (int i = 0; i < oldCodes.length; i++) {
          if (oldCodes[i] != newCodes[i]) {
            listsAreEqual = false;
            break;
          }
        }
      }

      if (!listsAreEqual) {
        setState(() {
          _assistantCourses = List<Course>.from(widget.courses!);
          // Keep only the selected course IDs that still exist in the updated course list
          final currentCodes = _assistantCourses.map((c) => c.code).toSet();
          _selectedCourseIds.retainWhere((code) => currentCodes.contains(code));

          // Auto-select any newly added courses
          final oldCodesSet = oldCodes.toSet();
          for (var c in _assistantCourses) {
            if (!oldCodesSet.contains(c.code)) {
              _selectedCourseIds.add(c.code);
            }
          }
        });
      }
    }
  }

  String _getCourseKey(String scheduleId) {
    return scheduleId == 'default' ? 'assistant_courses' : 'assistant_courses_$scheduleId';
  }

  Future<void> _loadAssistantCourses() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final currentScheduleId = prefs.getString('current_assistant_schedule_id') ?? 'default';
      final courseKey = _getCourseKey(currentScheduleId);
      String? jsonStr = prefs.getString(courseKey);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        List<dynamic> decoded = jsonDecode(jsonStr);
        setState(() {
          _assistantCourses = decoded
              .map((v) => Course.fromJson(Map<String, dynamic>.from(v)))
              .toList();
          // 預設全選
          _selectedCourseIds = _assistantCourses.map((c) => c.code).toSet();
        });
      }
    } catch (e) {
      debugPrint("讀取助手課表失敗: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 執行匯出
  Future<void> _exportToCart() async {
    if (_selectedCourseIds.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("請至少選擇一門課程"), duration: const Duration(seconds: 2)));
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      // 將選取的課號存入一個專屬的 key，讓正式選課頁面去讀取
      await prefs.setStringList(
        'exported_course_ids',
        _selectedCourseIds.toList(),
      );

      if (mounted) {
        final colorScheme = Theme.of(context).colorScheme;
        showGlassDialog(
          context: context,
          barrierDismissible: false,
          title: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.green),
              const SizedBox(width: 8),
              Text(
                "匯出成功",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.primaryText,
                ),
              ),
            ],
          ),
          content: Text(
            "已成功將課程匯出！\n\n請在選課開放期間，前往「選課系統」頁面，系統會自動將這些課程加入您的待加選清單中。",
            style: TextStyle(color: colorScheme.bodyText),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context, rootNavigator: true).pop(); // 關閉 Dialog
                if (widget.isInline) {
                  widget.onExportSuccess?.call();
                } else {
                  Navigator.pop(context); // 返回助手頁面
                }
              },
              child: Text(
                "我知道了",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.primary,
                ),
              ),
            ),
          ],
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("匯出失敗：$e"), duration: const Duration(seconds: 2)));
      }
    }
  }

  // 複製選課代碼到剪貼簿 (格式與匯入一致，且 value 設為 0)
  Future<void> _exportCodeToClipboard() async {
    if (_selectedCourseIds.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("請至少選擇一門課程"), duration: const Duration(seconds: 2)));
      return;
    }

    try {
      final selectedCourses = _assistantCourses
          .where((c) => _selectedCourseIds.contains(c.code))
          .toList();

      final exportData = selectedCourses.map((c) {
        return {"id": c.code, "name": c.name, "value": 0, "isSel": "+"};
      }).toList();

      final jsonStr = jsonEncode(exportData);
      final exportText = 'const exportClass = $jsonStr;';

      await Clipboard.setData(ClipboardData(text: exportText));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text("已複製選課代碼到剪貼簿 (${selectedCourses.length} 門課程)"),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("複製代碼失敗: $e"), backgroundColor: Colors.red, duration: const Duration(seconds: 2)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isLiquidGlass = LayoutStyleNotifier.instance.isLiquidGlass;
    bool isAllSelected =
        _selectedCourseIds.length == _assistantCourses.length &&
        _assistantCourses.isNotEmpty;

    final appBar = widget.isInline
        ? null
        : AppBar(
            title: const Text("匯出至選課系統"),
            automaticallyImplyLeading: !widget.isInline,
            actions: [
              if (_assistantCourses.isNotEmpty)
                TextButton(
                  onPressed: () {
                    setState(() {
                      if (isAllSelected) {
                        _selectedCourseIds.clear();
                      } else {
                        _selectedCourseIds = _assistantCourses
                            .map((c) => c.code)
                            .toSet();
                      }
                    });
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: colorScheme.primary,
                  ),
                  child: Text(isAllSelected ? "取消全選" : "全選"),
                ),
            ],
          );
    final bool useScrollableLayout = widget.isInline && isLiquidGlass;

    final body = _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _assistantCourses.isEmpty
          ? Center(
              child: Text(
                "助手課表目前沒有正式課程，無法匯出",
                style: TextStyle(color: colorScheme.subtitleText),
              ),
            )
          : useScrollableLayout
              ? _buildScrollableExportBody(context, colorScheme)
              : Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: isLiquidGlass
                          ? (glassCardDecoration(context, borderRadius: 12) ??
                                BoxDecoration(color: colorScheme.warningContainer))
                          : BoxDecoration(color: colorScheme.warningContainer),
                      child: Row(
                        children: [
                          Icon(
                            Icons.lightbulb_outline,
                            color: colorScheme.isDark
                                ? const Color(0xFFFFB74D)
                                : Colors.orange,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              "勾選您想匯出的課程，點擊下方按鈕後，前往「選課系統」頁面即可自動加入待加選清單！",
                              style: TextStyle(
                                color: colorScheme.isDark
                                    ? const Color(0xFFFFB74D)
                                    : Colors.orange[800],
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.separated(
                        itemCount: _assistantCourses.length,
                        separatorBuilder: (context, index) =>
                            Divider(height: 1, color: colorScheme.borderColor),
                        itemBuilder: (context, index) {
                          final course = _assistantCourses[index];
                          final isSelected = _selectedCourseIds.contains(
                            course.code,
                          );
                          return CheckboxListTile(
                            value: isSelected,
                            title: Text(
                              course.name.split('\n')[0],
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.primaryText),
                            ),
                            subtitle: Text(
                              "${course.code} · ${course.professor}",
                              style: TextStyle(color: colorScheme.subtitleText),
                            ),
                            activeColor: colorScheme.primary,
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
                      margin: isLiquidGlass
                          ? EdgeInsets.fromLTRB(
                              12,
                              8,
                              12,
                              widget.isInline ? 100.0 : 12.0,
                            )
                          : null,
                      decoration: isLiquidGlass
                          ? (glassCardDecoration(context, borderRadius: 16) ??
                                BoxDecoration(color: colorScheme.cardBackground))
                          : BoxDecoration(
                              color: colorScheme.cardBackground,
                              boxShadow: [
                                BoxShadow(
                                  color: colorScheme.isDark
                                      ? Colors.black38
                                      : Colors.black12,
                                  blurRadius: 10,
                                  offset: const Offset(0, -5),
                                ),
                              ],
                            ),
                      child: SafeArea(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: double.infinity,
                              height: (isLiquidGlass && widget.isInline) ? 36 : 46,
                              child: ElevatedButton.icon(
                                onPressed: _selectedCourseIds.isEmpty
                                    ? null
                                    : _exportToCart,
                                icon: const Icon(Icons.shopping_cart_checkout),
                                label: Text(
                                  "匯出 ${_selectedCourseIds.length} 門課程至選課系統",
                                  style: TextStyle(
                                    fontSize: (isLiquidGlass && widget.isInline) ? 13 : 15,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: colorScheme.primary,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(
                              height: (isLiquidGlass && widget.isInline) ? 6 : 10,
                            ),
                            SizedBox(
                              width: double.infinity,
                              height: (isLiquidGlass && widget.isInline) ? 36 : 46,
                              child: OutlinedButton.icon(
                                onPressed: _selectedCourseIds.isEmpty
                                    ? null
                                    : _exportCodeToClipboard,
                                icon: const Icon(Icons.copy_all_rounded),
                                label: Text(
                                  "複製選課代碼 (${_selectedCourseIds.length} 門課程)",
                                  style: TextStyle(
                                    fontSize: (isLiquidGlass && widget.isInline) ? 13 : 15,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: colorScheme.primary,
                                  side: BorderSide(
                                    color: colorScheme.primary,
                                    width: 1.5,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );

    return widget.isInline
        ? Scaffold(
            appBar: appBar,
            backgroundColor: isLiquidGlass ? Colors.transparent : null,
            body: body,
          )
        : GlassPageScaffold(appBar: appBar, body: body);
  }

  Widget _buildScrollableExportBody(BuildContext context, ColorScheme colorScheme) {
    final isLiquidGlass = LayoutStyleNotifier.instance.isLiquidGlass;
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: isLiquidGlass
              ? (glassCardDecoration(context, borderRadius: 12) ??
                    BoxDecoration(color: colorScheme.warningContainer))
              : BoxDecoration(color: colorScheme.warningContainer),
          child: Row(
            children: [
              Icon(
                Icons.lightbulb_outline,
                color: colorScheme.isDark
                    ? const Color(0xFFFFB74D)
                    : Colors.orange,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  "勾選您想匯出的課程，點擊下方按鈕後，前往「選課系統」頁面即可自動加入待加選清單！",
                  style: TextStyle(
                    color: colorScheme.isDark
                        ? const Color(0xFFFFB74D)
                        : Colors.orange[800],
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _assistantCourses.length,
          separatorBuilder: (context, index) =>
              Divider(height: 1, color: colorScheme.borderColor),
          itemBuilder: (context, index) {
            final course = _assistantCourses[index];
            final isSelected = _selectedCourseIds.contains(
              course.code,
            );
            return CheckboxListTile(
              value: isSelected,
              title: Text(
                course.name.split('\n')[0],
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.primaryText,
                ),
              ),
              subtitle: Text(
                "${course.code} · ${course.professor}",
                style: TextStyle(color: colorScheme.subtitleText),
              ),
              activeColor: colorScheme.primary,
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
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: isLiquidGlass
              ? (glassCardDecoration(context, borderRadius: 16) ??
                    BoxDecoration(color: colorScheme.cardBackground))
              : BoxDecoration(color: colorScheme.cardBackground),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: double.infinity,
                height: 36,
                child: ElevatedButton.icon(
                  onPressed: _selectedCourseIds.isEmpty ? null : _exportToCart,
                  icon: const Icon(Icons.shopping_cart_checkout, size: 16),
                  label: Text(
                    "匯出 ${_selectedCourseIds.length} 門課程至選課系統",
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorScheme.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              SizedBox(
                width: double.infinity,
                height: 36,
                child: OutlinedButton.icon(
                  onPressed: _selectedCourseIds.isEmpty ? null : _exportCodeToClipboard,
                  icon: const Icon(Icons.copy_all_rounded, size: 16),
                  label: Text(
                    "複製選課代碼 (${_selectedCourseIds.length} 門課程)",
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colorScheme.primary,
                    side: BorderSide(
                      color: colorScheme.primary,
                      width: 1.5,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 100), // Bottom space for wide screen navigation bar
      ],
    );
  }
}
