import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/course_assistant_models.dart';
import '../../models/course_model.dart';
import '../../services/course_query_service.dart';
import 'assistant_add_course_page.dart';
import 'assistant_export_page.dart';
import 'assistant_import_page.dart';
import 'course_assistant_utils.dart';
import 'dialogs/add_custom_event_dialog.dart';
import 'dialogs/course_detail_dialog.dart';
import 'dialogs/custom_event_detail_dialog.dart';
import 'dialogs/info_dialog.dart';
import 'dialogs/manage_courses_sheet.dart';
import 'dialogs/schedule_dialogs.dart';
import 'widgets/assistant_app_bar_dropdown.dart';
import 'widgets/assistant_credits_bar.dart';
import 'widgets/assistant_empty_state.dart';
import 'widgets/assistant_manage_list_pane.dart';
import 'widgets/assistant_right_action_pane.dart';
import 'widgets/assistant_timetable.dart';

class CourseAssistantPage extends StatefulWidget {
  const CourseAssistantPage({super.key});

  @override
  State<CourseAssistantPage> createState() => _CourseAssistantPageState();
}

class _CourseAssistantPageState extends State<CourseAssistantPage> {
  List<Course> _assistantCourses = [];
  List<CustomEvent> _customEvents = []; // 存放自訂行程的列表
  List<AssistantSchedule> _schedules = []; // 課表列表
  String _currentScheduleId = 'default'; // 當前課表 ID
  bool _isLoading = false;

  // --- API 資料狀態 (選課助手中的系所與學程) ---
  final ValueNotifier<List<CourseJsonData>> _apiCoursesNotifier = ValueNotifier(
    [],
  );
  final ValueNotifier<bool> _isApiLoadingNotifier = ValueNotifier(false);
  String? _apiLoadedSemester;

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  @override
  void dispose() {
    _apiCoursesNotifier.dispose();
    _isApiLoadingNotifier.dispose();
    super.dispose();
  }

  // 統一載入課程與自訂行程 (支持多課表)
  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();

      // 載入課表列表
      String? schedulesJson = prefs.getString('assistant_schedules_list');
      if (schedulesJson != null && schedulesJson.isNotEmpty) {
        List<dynamic> decoded = jsonDecode(schedulesJson);
        _schedules = decoded
            .map(
              (v) => AssistantSchedule.fromJson(Map<String, dynamic>.from(v)),
            )
            .toList();
      } else {
        _schedules = [AssistantSchedule(id: 'default', name: '課表 1')];
        await prefs.setString(
          'assistant_schedules_list',
          jsonEncode(_schedules.map((s) => s.toJson()).toList()),
        );
      }

      // 載入當前選取課表 ID
      _currentScheduleId =
          prefs.getString('current_assistant_schedule_id') ?? 'default';
      // 防呆：如果當前選取的 ID 不在列表中，設為第一個
      if (!_schedules.any((s) => s.id == _currentScheduleId)) {
        _currentScheduleId = _schedules.first.id;
        await prefs.setString(
          'current_assistant_schedule_id',
          _currentScheduleId,
        );
      }

      final courseKey = getCourseKey(_currentScheduleId);
      final eventKey = getEventKey(_currentScheduleId);

      // 讀取課程
      String? courseJson = prefs.getString(courseKey);
      if (courseJson != null && courseJson.isNotEmpty) {
        List<dynamic> decoded = jsonDecode(courseJson);
        _assistantCourses = decoded
            .map((v) => Course.fromJson(Map<String, dynamic>.from(v)))
            .toList();
      } else {
        _assistantCourses = [];
      }

      // 讀取自訂行程
      String? eventJson = prefs.getString(eventKey);
      if (eventJson != null && eventJson.isNotEmpty) {
        List<dynamic> decoded = jsonDecode(eventJson);
        _customEvents = decoded
            .map((v) => CustomEvent.fromJson(Map<String, dynamic>.from(v)))
            .toList();
      } else {
        _customEvents = [];
      }
    } catch (e) {
      debugPrint("讀取資料失敗: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _removeCourseFromAssistant(Course course) async {
    setState(() {
      _assistantCourses.removeWhere((c) => c.code == course.code);
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      getCourseKey(_currentScheduleId),
      jsonEncode(_assistantCourses.map((c) => c.toJson()).toList()),
    );
    if (mounted)
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("已移除 ${course.name}"),
          duration: const Duration(milliseconds: 1500),
        ),
      );
  }

  // 移除自訂行程
  Future<void> _removeCustomEvent(String eventId) async {
    setState(() {
      _customEvents.removeWhere((e) => e.id == eventId);
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      getEventKey(_currentScheduleId),
      jsonEncode(_customEvents.map((e) => e.toJson()).toList()),
    );
    if (mounted)
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("已移除自訂行程"),
          duration: const Duration(milliseconds: 1500),
        ),
      );
  }

  Future<void> _clearAllData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(getCourseKey(_currentScheduleId));
    await prefs.remove(getEventKey(_currentScheduleId));
    _loadAllData();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text("已清空當前課表的課程與行程"),
        duration: const Duration(milliseconds: 1500),
      ),
    );
  }

  Future<void> _switchSchedule(String scheduleId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('current_assistant_schedule_id', scheduleId);
    setState(() {
      _currentScheduleId = scheduleId;
    });
    await _loadAllData();
  }

  // --- 課表管理回呼（由 dialog 呼叫，於此執行持久化 + 切換 + snackbar）---

  Future<void> _doCreateSchedule(String name, bool cloneCurrent) async {
    final newId = DateTime.now().millisecondsSinceEpoch.toString();
    final newSchedule = AssistantSchedule(id: newId, name: name);

    final prefs = await SharedPreferences.getInstance();
    _schedules.add(newSchedule);
    await prefs.setString(
      'assistant_schedules_list',
      jsonEncode(_schedules.map((s) => s.toJson()).toList()),
    );

    if (cloneCurrent) {
      // Clone courses
      final currentCourseJson = prefs.getString(getCourseKey(_currentScheduleId));
      if (currentCourseJson != null) {
        await prefs.setString(getCourseKey(newId), currentCourseJson);
      }
      // Clone events
      final currentEventJson = prefs.getString(getEventKey(_currentScheduleId));
      if (currentEventJson != null) {
        await prefs.setString(getEventKey(newId), currentEventJson);
      }
    }

    await _switchSchedule(newId);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("課表「${newSchedule.name}」已建立！"),
          duration: const Duration(milliseconds: 1500),
        ),
      );
    }
  }

  Future<void> _doRenameSchedule(AssistantSchedule schedule, String newName) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      final idx = _schedules.indexWhere((s) => s.id == schedule.id);
      if (idx != -1) {
        _schedules[idx] = AssistantSchedule(id: schedule.id, name: newName);
      }
    });
    await prefs.setString(
      'assistant_schedules_list',
      jsonEncode(_schedules.map((s) => s.toJson()).toList()),
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("已重命名課表"),
          duration: const Duration(milliseconds: 1500),
        ),
      );
    }
  }

  Future<void> _doCloneSchedule(AssistantSchedule source, String newName) async {
    final newId = DateTime.now().millisecondsSinceEpoch.toString();
    final newSchedule = AssistantSchedule(id: newId, name: newName);

    final prefs = await SharedPreferences.getInstance();
    _schedules.add(newSchedule);
    await prefs.setString(
      'assistant_schedules_list',
      jsonEncode(_schedules.map((s) => s.toJson()).toList()),
    );

    // Clone data
    final courseJson = prefs.getString(getCourseKey(source.id));
    if (courseJson != null) {
      await prefs.setString(getCourseKey(newId), courseJson);
    }
    final eventJson = prefs.getString(getEventKey(source.id));
    if (eventJson != null) {
      await prefs.setString(getEventKey(newId), eventJson);
    }

    await _switchSchedule(newId);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("已複製至新課表「${newSchedule.name}」"),
          duration: const Duration(milliseconds: 1500),
        ),
      );
    }
  }

  Future<void> _doDeleteSchedule(AssistantSchedule schedule) async {
    final prefs = await SharedPreferences.getInstance();
    _schedules.removeWhere((s) => s.id == schedule.id);
    await prefs.setString(
      'assistant_schedules_list',
      jsonEncode(_schedules.map((s) => s.toJson()).toList()),
    );

    // Clean data
    await prefs.remove(getCourseKey(schedule.id));
    await prefs.remove(getEventKey(schedule.id));

    if (_currentScheduleId == schedule.id) {
      _currentScheduleId = _schedules.first.id;
      await prefs.setString(
        'current_assistant_schedule_id',
        _currentScheduleId,
      );
    }

    await _switchSchedule(_currentScheduleId);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("已刪除課表「${schedule.name}」"),
          duration: const Duration(milliseconds: 1500),
        ),
      );
    }
  }

  // --- 課表管理對話框開啟回呼 ---

  void _openAddScheduleDialog() =>
      showAddScheduleDialog(context, onCreate: _doCreateSchedule);

  void _openRenameScheduleDialog(AssistantSchedule schedule) =>
      showRenameScheduleDialog(context, schedule, onRename: _doRenameSchedule);

  void _openCloneScheduleDialog(AssistantSchedule schedule) =>
      showCloneScheduleDialog(context, schedule, onClone: _doCloneSchedule);

  void _openDeleteScheduleConfirmDialog(AssistantSchedule schedule) =>
      showDeleteScheduleConfirmDialog(
        context,
        schedule,
        onDelete: _doDeleteSchedule,
      );

  void _showManageSchedulesSheet() {
    showManageSchedulesSheet(
      context,
      schedules: _schedules,
      currentScheduleId: _currentScheduleId,
      onRename: _openRenameScheduleDialog,
      onClone: _openCloneScheduleDialog,
      onDelete: _openDeleteScheduleConfirmDialog,
    );
  }

  // 新增自訂行程（由 dialog 呼叫）
  Future<void> _addCustomEvent(CustomEvent event) async {
    _customEvents.add(event);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      getEventKey(_currentScheduleId),
      jsonEncode(_customEvents.map((e) => e.toJson()).toList()),
    );
    if (mounted) {
      _loadAllData(); // 重新整理課表
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("行程已加入！"),
          duration: const Duration(milliseconds: 1500),
        ),
      );
    }
  }

  void _showManageCoursesSheet() {
    showManageCoursesSheet(
      context,
      courses: _assistantCourses,
      events: _customEvents,
      onRemoveCourse: _removeCourseFromAssistant,
      onRemoveEvent: _removeCustomEvent,
    );
  }

  void _showInfoDialog() => showInfoDialog(context);

  void _handleMenuSelection(String value) {
    switch (value) {
      case 'add':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const AssistantAddCoursePage(),
          ),
        ).then((_) => _loadAllData());
        break;
      case 'add_event': // 呼叫自訂行程 Dialog
        showAddCustomEventDialog(context, onSave: _addCustomEvent);
        break;
      case 'import':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const AssistantImportPage()),
        ).then((_) => _loadAllData());
        break;
      case 'export':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AssistantExportPage(
              courses: List<Course>.from(_assistantCourses),
            ),
          ),
        );
        break;
      case 'clear':
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text("確認清除"),
            content: const Text("確定要清空選課助手裡的所有課程與自訂行程嗎？(不影響正式課表)"),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("取消"),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _clearAllData();
                },
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text("確定清除"),
              ),
            ],
          ),
        );
        break;
    }
  }

  // 課程詳情：先觸發 API 載入（快取在 State），再顯示對話框
  void _showCourseDetail(Course course) {
    _loadApiCoursesForAssistant(course.semester);
    showDialog(
      context: context,
      builder: (context) => CourseDetailDialog(
        course: course,
        apiCoursesNotifier: _apiCoursesNotifier,
        isApiLoadingNotifier: _isApiLoadingNotifier,
        onRemove: _removeCourseFromAssistant,
      ),
    );
  }

  void _showCustomEventDetail(CustomEvent event) {
    showDialog(
      context: context,
      builder: (context) => CustomEventDetailDialog(
        event: event,
        onRemove: _removeCustomEvent,
      ),
    );
  }

  Future<void> _loadApiCoursesForAssistant(String? semester) async {
    // 如果沒有傳入學期，就抓取最新學期作為 fallback
    String targetSem = semester ?? "";
    if (targetSem.isEmpty) {
      try {
        final data = await CourseQueryService.instance.getSemesters();
        targetSem = data['latest'] as String;
      } catch (e) {
        debugPrint("❌ [選課助手-課程API] 取得學期失敗: $e");
        return;
      }
    }

    if (_apiLoadedSemester == targetSem &&
        _apiCoursesNotifier.value.isNotEmpty) {
      return; // 已經載入
    }

    _isApiLoadingNotifier.value = true;
    _apiCoursesNotifier.value = [];

    try {
      final courses = await CourseQueryService.instance.getCourses(
        semester: targetSem,
      );
      if (mounted) {
        _apiCoursesNotifier.value = courses;
        _apiLoadedSemester = targetSem;
        _isApiLoadingNotifier.value = false;
      }
    } catch (e) {
      debugPrint("❌ [選課助手-課程API] 載入失敗: $e");
      if (mounted) {
        _apiCoursesNotifier.value = [];
        _isApiLoadingNotifier.value = false;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text(
            "選課助手",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;

        if (width < 800) {
          // Mobile layout
          return Scaffold(
            appBar: AppBar(
              title: Row(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2.0),
                    child: const Text(
                      "選課助手",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: AppBarScheduleDropdown(
                      schedules: _schedules,
                      currentScheduleId: _currentScheduleId,
                      isNarrow: width < 450,
                      onSwitchSchedule: _switchSchedule,
                      onAddSchedule: _openAddScheduleDialog,
                      onManageSchedules: _showManageSchedulesSheet,
                    ),
                  ),
                ],
              ),
              centerTitle: false,
              titleSpacing: 0,
              actions: [
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.info_outline),
                  tooltip: "功能說明",
                  padding: width < 450
                      ? const EdgeInsets.symmetric(horizontal: 4)
                      : const EdgeInsets.all(8.0),
                  constraints: width < 450
                      ? const BoxConstraints(minWidth: 32, minHeight: 32)
                      : null,
                  onPressed: _showInfoDialog,
                ),
                const SizedBox(width: 4),
                PopupMenuButton<String>(
                  padding: width < 450
                      ? const EdgeInsets.symmetric(horizontal: 4)
                      : const EdgeInsets.all(8.0),
                  constraints: width < 450
                      ? const BoxConstraints(minWidth: 32, minHeight: 32)
                      : null,
                  onSelected: _handleMenuSelection,
                  itemBuilder: (BuildContext context) => [
                    const PopupMenuItem(
                      value: 'add',
                      child: Row(
                        children: [
                          Icon(Icons.add_box, color: Colors.blue),
                          SizedBox(width: 8),
                          Text("新增課程"),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'add_event',
                      child: Row(
                        children: [
                          Icon(Icons.event_note, color: Colors.blueGrey),
                          SizedBox(width: 8),
                          Text("新增其他行程"),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'import',
                      child: Row(
                        children: [
                          Icon(Icons.download),
                          SizedBox(width: 8),
                          Text("匯入課表"),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'export',
                      child: Row(
                        children: [
                          Icon(Icons.upload),
                          SizedBox(width: 8),
                          Text("匯出至選課"),
                        ],
                      ),
                    ),
                    const PopupMenuDivider(),
                    const PopupMenuItem(
                      value: 'clear',
                      child: Row(
                        children: [
                          Icon(Icons.delete_forever, color: Colors.red),
                          SizedBox(width: 8),
                          Text("清除全部資料", style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            body: (_assistantCourses.isEmpty && _customEvents.isEmpty)
                ? const AssistantEmptyState()
                : SingleChildScrollView(
                    child: Column(
                      children: [
                        CreditsBar(
                          courseCount: _assistantCourses.length,
                          totalCredits: getTotalCredits(_assistantCourses),
                          showManageButton: true,
                          onManage: _showManageCoursesSheet,
                        ),
                        AssistantTimetable(
                          courses: _assistantCourses,
                          events: _customEvents,
                          onCourseTap: _showCourseDetail,
                          onEventTap: _showCustomEventDetail,
                          screenWidth: width,
                        ),
                      ],
                    ),
                  ),
          );
        } else if (width < 1200) {
          // Medium layout
          return Scaffold(
            appBar: AppBar(
              title: Row(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2.0),
                    child: const Text(
                      "選課助手",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: AppBarScheduleDropdown(
                      schedules: _schedules,
                      currentScheduleId: _currentScheduleId,
                      isNarrow: false,
                      onSwitchSchedule: _switchSchedule,
                      onAddSchedule: _openAddScheduleDialog,
                      onManageSchedules: _showManageSchedulesSheet,
                    ),
                  ),
                ],
              ),
              centerTitle: false,
              titleSpacing: 0,
              actions: [
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.info_outline),
                  tooltip: "功能說明",
                  onPressed: _showInfoDialog,
                ),
                const SizedBox(width: 8),
                PopupMenuButton<String>(
                  onSelected: _handleMenuSelection,
                  itemBuilder: (BuildContext context) => [
                    const PopupMenuItem(
                      value: 'clear',
                      child: Row(
                        children: [
                          Icon(Icons.delete_forever, color: Colors.red),
                          SizedBox(width: 8),
                          Text("清除全部資料", style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            body: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 60,
                  child: Column(
                    children: [
                      CreditsBar(
                        courseCount: _assistantCourses.length,
                        totalCredits: getTotalCredits(_assistantCourses),
                        showManageButton: false,
                        onManage: _showManageCoursesSheet,
                      ),
                      Expanded(
                        child: SingleChildScrollView(
                          child: AssistantTimetable(
                            courses: _assistantCourses,
                            events: _customEvents,
                            onCourseTap: _showCourseDetail,
                            onEventTap: _showCustomEventDetail,
                            screenWidth: width,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  flex: 40,
                  child: RightActionPane(
                    courses: _assistantCourses,
                    onDataChanged: _loadAllData,
                  ),
                ),
              ],
            ),
          );
        } else {
          // Wide layout
          return Scaffold(
            appBar: AppBar(
              title: Row(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2.0),
                    child: const Text(
                      "選課助手",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: AppBarScheduleDropdown(
                      schedules: _schedules,
                      currentScheduleId: _currentScheduleId,
                      isNarrow: false,
                      onSwitchSchedule: _switchSchedule,
                      onAddSchedule: _openAddScheduleDialog,
                      onManageSchedules: _showManageSchedulesSheet,
                    ),
                  ),
                ],
              ),
              centerTitle: false,
              titleSpacing: 0,
              actions: [
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.info_outline),
                  tooltip: "功能說明",
                  onPressed: _showInfoDialog,
                ),
                const SizedBox(width: 8),
                PopupMenuButton<String>(
                  onSelected: _handleMenuSelection,
                  itemBuilder: (BuildContext context) => [
                    const PopupMenuItem(
                      value: 'clear',
                      child: Row(
                        children: [
                          Icon(Icons.delete_forever, color: Colors.red),
                          SizedBox(width: 8),
                          Text("清除全部資料", style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            body: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 25,
                  child: ManageListPaneInline(
                    courses: _assistantCourses,
                    events: _customEvents,
                    onRemoveCourse: _removeCourseFromAssistant,
                    onRemoveEvent: _removeCustomEvent,
                  ),
                ),
                Expanded(
                  flex: 38,
                  child: Column(
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          child: AssistantTimetable(
                            courses: _assistantCourses,
                            events: _customEvents,
                            onCourseTap: _showCourseDetail,
                            onEventTap: _showCustomEventDetail,
                            screenWidth: width,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  flex: 40,
                  child: RightActionPane(
                    courses: _assistantCourses,
                    onDataChanged: _loadAllData,
                  ),
                ),
              ],
            ),
          );
        }
      },
    );
  }
}