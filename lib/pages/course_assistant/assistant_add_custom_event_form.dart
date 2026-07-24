import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/course_assistant_models.dart';
import '../../theme/app_theme.dart';
import '../../theme/layout_style_notifier.dart';

class AssistantAddCustomEventForm extends StatefulWidget {
  final VoidCallback onEventAdded;
  const AssistantAddCustomEventForm({super.key, required this.onEventAdded});

  @override
  State<AssistantAddCustomEventForm> createState() =>
      _AssistantAddCustomEventFormState();
}

class _AssistantAddCustomEventFormState
    extends State<AssistantAddCustomEventForm> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _detailsCtrl = TextEditingController();
  int _selectedDay = 1; // 預設星期一
  final Set<String> _selectedPeriods = {};

  final List<String> _periods = [
    'A',
    '1',
    '2',
    '3',
    '4',
    'B',
    '5',
    '6',
    '7',
    '8',
    '9',
    'C',
    'D',
    'E',
    'F',
  ];
  final List<String> _fullWeekDays = ['一', '二', '三', '四', '五', '六', '日'];

  double _calculateTextLength(String text) {
    double length = 0.0;
    for (var rune in text.runes) {
      if (rune <= 128) {
        length += 0.5;
      } else {
        length += 1.0;
      }
    }
    return length;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _locationCtrl.dispose();
    _detailsCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveEvent() async {
    if (_titleCtrl.text.trim().isEmpty || _selectedPeriods.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("請填寫標題並至少選擇一節課"), duration: const Duration(seconds: 2)));
      return;
    }
    if (_calculateTextLength(_locationCtrl.text.trim()) > 6.0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("位置輸入過長，請縮減至6個中文字或12個英數字以內"), duration: const Duration(seconds: 2)),
      );
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final currentScheduleId =
          prefs.getString('current_assistant_schedule_id') ?? 'default';
      final eventKey = currentScheduleId == 'default'
          ? 'custom_events'
          : 'custom_events_$currentScheduleId';
      List<CustomEvent> events = [];
      String? eventJson = prefs.getString(eventKey);
      if (eventJson != null && eventJson.isNotEmpty) {
        List<dynamic> decoded = jsonDecode(eventJson);
        events = decoded
            .map((v) => CustomEvent.fromJson(Map<String, dynamic>.from(v)))
            .toList();
      }

      final newEvent = CustomEvent(
        id: DateTime.now().millisecondsSinceEpoch.toString(), // 產生唯一ID
        title: _titleCtrl.text.trim(),
        details: _detailsCtrl.text.trim(),
        day: _selectedDay,
        periods: _selectedPeriods.toList()
          ..sort((a, b) => _periods.indexOf(a).compareTo(_periods.indexOf(b))),
        location: _locationCtrl.text.trim(),
      );

      events.add(newEvent);
      await prefs.setString(
        eventKey,
        jsonEncode(events.map((e) => e.toJson()).toList()),
      );

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("行程已加入！"), duration: const Duration(seconds: 2)));

      // 清空表單
      _titleCtrl.clear();
      _locationCtrl.clear();
      _detailsCtrl.clear();
      setState(() {
        _selectedDay = 1;
        _selectedPeriods.clear();
      });

      widget.onEventAdded();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("儲存失敗：$e"), duration: const Duration(seconds: 2)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isLiquidGlass = LayoutStyleNotifier.instance.isLiquidGlass;
    final isDark = colorScheme.isDark;
    final Color fieldFill = isLiquidGlass
        ? (isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.white.withValues(alpha: 0.4))
        : colorScheme.subtleBackground;
    final Color fieldBorder = isLiquidGlass
        ? (isDark
              ? Colors.white.withValues(alpha: 0.35)
              : Colors.black.withValues(alpha: 0.08))
        : colorScheme.borderColor;
    InputDecoration fieldDecoration(String label) => InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: colorScheme.subtitleText),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: fieldBorder, width: 1.0),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: fieldBorder, width: 1.0),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
      ),
      filled: true,
      fillColor: fieldFill,
    );
    return Scaffold(
      appBar: null,
      backgroundColor: isLiquidGlass ? Colors.transparent : null,
      body: SingleChildScrollView(
        padding: EdgeInsets.only(
          left: 16.0,
          right: 16.0,
          top: 16.0,
          bottom: (isLiquidGlass && MediaQuery.of(context).size.width >= 800)
              ? 100.0
              : 16.0,
        ),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Text(
                  "新增自訂行程",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primaryText,
                  ),
                ),
              ),
              TextField(
                controller: _titleCtrl,
                style: TextStyle(color: colorScheme.primaryText),
                decoration: fieldDecoration('標題 (如: 工讀、社團)'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _locationCtrl,
                style: TextStyle(color: colorScheme.primaryText),
                decoration: fieldDecoration('位置'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _detailsCtrl,
                style: TextStyle(color: colorScheme.primaryText),
                decoration: fieldDecoration('詳細內容 (地點、備註)'),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              Text(
                "選擇星期：",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.subtitleText,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: isLiquidGlass
                    ? BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.08)
                            : Colors.white.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.12)
                              : Colors.black.withValues(alpha: 0.08),
                          width: 1.0,
                        ),
                      )
                    : null,
                child: DropdownButton<int>(
                  isExpanded: true,
                  value: _selectedDay,
                  dropdownColor: colorScheme.cardBackground,
                  style: TextStyle(color: colorScheme.primaryText),
                  underline: isLiquidGlass ? const SizedBox.shrink() : null,
                  items: List.generate(7, (index) {
                    return DropdownMenuItem(
                      value: index + 1,
                      child: Text(
                        "星期${_fullWeekDays[index]}",
                        style: TextStyle(color: colorScheme.primaryText),
                      ),
                    );
                  }),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedDay = val);
                  },
                ),
              ),
              const SizedBox(height: 16),
              Text(
                "選擇節次 (可多選)：",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.subtitleText,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6.0,
                runSpacing: 4.0,
                children: _periods.map((p) {
                  final isSelected = _selectedPeriods.contains(p);
                  return FilterChip(
                    label: Text(
                      p,
                      style: TextStyle(
                        color: isSelected
                            ? colorScheme.primary
                            : colorScheme.primaryText,
                      ),
                    ),
                    selected: isSelected,
                    selectedColor: colorScheme.primaryContainer,
                    backgroundColor: isLiquidGlass
                        ? (isDark
                              ? Colors.white.withValues(alpha: 0.06)
                              : Colors.white.withValues(alpha: 0.4))
                        : colorScheme.subtleBackground,
                    checkmarkColor: colorScheme.primary,
                    showCheckmark: false,
                    onSelected: (bool selected) {
                      setState(() {
                        if (selected) {
                          _selectedPeriods.add(p);
                        } else {
                          _selectedPeriods.remove(p);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorScheme.primary,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: _saveEvent,
                  icon: const Icon(Icons.save),
                  label: const Text(
                    "儲存行程",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
