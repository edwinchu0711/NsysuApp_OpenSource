// 檔案名稱：widgets/abnormal_course_card.dart
import 'package:flutter/material.dart';
import '../course_exception_models.dart';
import 'course_dropdowns.dart';

/// 預設異常處理科目的卡片 UI
class AbnormalCourseCard extends StatefulWidget {
  final AbnormalCourse course;
  final List<ReasonOption> reasons;
  final VoidCallback onChanged;

  const AbnormalCourseCard({
    Key? key,
    required this.course,
    required this.reasons,
    required this.onChanged,
  }) : super(key: key);

  @override
  State<AbnormalCourseCard> createState() => _AbnormalCourseCardState();
}

class _AbnormalCourseCardState extends State<AbnormalCourseCard> {
  @override
  Widget build(BuildContext context) {
    final course = widget.course;
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
            title: Text(
              displayName,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
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
              widget.onChanged();
            },
          ),
          if (course.isSelected)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 8.0,
              ),
              child: Column(
                children: [
                  ActionDropdown(
                    value: course.selectedAction,
                    onChanged: (val) {
                      setState(() {
                        course.selectedAction = val;
                      });
                      widget.onChanged();
                    },
                  ),
                  const SizedBox(height: 12),
                  ReasonDropdown(
                    value: course.selectedReason,
                    reasons: widget.reasons,
                    onChanged: (val) {
                      setState(() {
                        course.selectedReason = val;
                      });
                      widget.onChanged();
                    },
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
