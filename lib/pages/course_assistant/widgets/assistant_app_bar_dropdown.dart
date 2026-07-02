import 'package:flutter/material.dart';

import '../../../models/course_assistant_models.dart';
import '../../../widgets/glass_dropdown.dart';

/// AppBar 上的課表切換下拉選單（原 _buildAppBarDropdown）
class AppBarScheduleDropdown extends StatelessWidget {
  final List<AssistantSchedule> schedules;
  final String currentScheduleId;
  final bool isNarrow;
  final void Function(String scheduleId) onSwitchSchedule;
  final VoidCallback onAddSchedule;
  final VoidCallback onManageSchedules;

  const AppBarScheduleDropdown({
    super.key,
    required this.schedules,
    required this.currentScheduleId,
    required this.isNarrow,
    required this.onSwitchSchedule,
    required this.onAddSchedule,
    required this.onManageSchedules,
  });

  @override
  Widget build(BuildContext context) {
    final List<String> dropdownItems = [
      ...schedules.map((s) => s.id),
      'add_new_schedule',
      'manage_schedules',
    ];

    final Map<String, String> displayMap = {
      for (var s in schedules) s.id: s.name,
      'add_new_schedule': '新增課表',
      'manage_schedules': '管理課表',
    };

    return Center(
      child: GlassSingleSelectDropdown(
        label: "",
        items: dropdownItems,
        value: currentScheduleId,
        onChanged: (String? value) {
          if (value == 'add_new_schedule') {
            onAddSchedule();
          } else if (value == 'manage_schedules') {
            onManageSchedules();
          } else if (value != null) {
            onSwitchSchedule(value);
          }
        },
        displayMap: displayMap,
        dense: true,
        minWidth: isNarrow ? 160 : 195,
        width: double.infinity,
        height: 34,
        horizontalPadding: isNarrow ? 8 : 12,
      ),
    );
  }
}