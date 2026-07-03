// 檔案名稱：widgets/manual_course_card.dart
import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart'; // 引入 AppTheme 與 AppColors 擴充
import '../course_exception_models.dart';
import 'course_dropdowns.dart';

/// 自行手動輸入課程的卡片 UI (支援寬/窄螢幕)
class ManualCourseCard extends StatefulWidget {
  final int index;
  final ManualCourse manualCourse;
  final List<ReasonOption> reasons;
  final bool isActive;
  final VoidCallback onDelete;
  final VoidCallback onPickCourseCode;
  final VoidCallback onChanged;

  const ManualCourseCard({
    Key? key,
    required this.index,
    required this.manualCourse,
    required this.reasons,
    required this.isActive,
    required this.onDelete,
    required this.onPickCourseCode,
    required this.onChanged,
  }) : super(key: key);

  @override
  State<ManualCourseCard> createState() => _ManualCourseCardState();
}

class _ManualCourseCardState extends State<ManualCourseCard> {
  String _getReasonText(String? value) {
    if (value == null || value.isEmpty) return "未選擇原因";
    final match = widget.reasons.firstWhere(
      (r) => r.value == value,
      orElse: () => ReasonOption(value, value),
    );
    return match.text.replaceAll(RegExp(r'\【.*?\】'), '').trim();
  }

  @override
  Widget build(BuildContext context) {
    final bool isWide = MediaQuery.of(context).size.width >= 800;
    final manualCourse = widget.manualCourse;

    if (!isWide) {
      // 窄螢幕排版，完全保持原有邏輯
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
                  Text(
                    "自填項目 ${widget.index + 1}",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.delete_outline,
                      color: Colors.red,
                      size: 20,
                    ),
                    onPressed: widget.onDelete,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
<<<<<<< HEAD
                crossAxisAlignment: CrossAxisAlignment.end,
=======
>>>>>>> cb0e69536426ceb2a943a1d70f3df893136211d7
                children: [
                  Expanded(
                    flex: 3,
                    child: ActionDropdown(
                      value: manualCourse.selectedAction,
                      onChanged: (val) {
                        setState(() {
                          manualCourse.selectedAction = val;
                        });
                        widget.onChanged();
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 5,
                    child: InkWell(
                      onTap: widget.onPickCourseCode,
                      child: Container(
<<<<<<< HEAD
                        height: 42,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
=======
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
>>>>>>> cb0e69536426ceb2a943a1d70f3df893136211d7
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey[400]!),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                manualCourse.courseNo.isEmpty
                                    ? "點擊選擇課號"
                                    : manualCourse.courseNo,
                                style: TextStyle(
                                  color: manualCourse.courseNo.isEmpty
                                      ? Colors.grey
                                      : Colors.black87,
                                ),
                              ),
                            ),
                            const Icon(
                              Icons.search,
                              size: 18,
                              color: Colors.grey,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ReasonDropdown(
                value: manualCourse.selectedReason,
                reasons: widget.reasons,
                onChanged: (val) {
                  setState(() {
                    manualCourse.selectedReason = val;
                  });
                  widget.onChanged();
                },
              ),
            ],
          ),
        ),
      );
    }

    // 寬螢幕排版，具有收合、醒目邊框與狀態指引
    final colorScheme = Theme.of(context).colorScheme;
    final bool isActive = widget.isActive;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: colorScheme.cardBackground,
        border: Border.all(
          color: isActive
              ? colorScheme.primary
              : (manualCourse.courseNo.isNotEmpty
                  ? colorScheme.borderColor
                  : Colors.orange.shade300),
          width: isActive ? 2.0 : 1.0,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isActive ? 0.08 : 0.03),
            blurRadius: isActive ? 8 : 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 卡片標頭部
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: isActive
                  ? colorScheme.primary.withValues(alpha: 0.08)
                  : colorScheme.subtleBackground,
              child: Row(
                children: [
                  Icon(
                    isActive
                        ? Icons.edit_outlined
                        : Icons.sticky_note_2_outlined,
                    size: 20,
                    color: isActive
                        ? colorScheme.primary
                        : colorScheme.iconColor,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    "自填項目 ${widget.index + 1}",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isActive
                          ? colorScheme.primary
                          : colorScheme.primaryText,
                    ),
                  ),
                  if (isActive) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.primary,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        "正在選擇",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                  const Spacer(),
                  // 收合按鈕 (Chevron)
                  IconButton(
                    icon: Icon(
                      manualCourse.isExpanded
                          ? Icons.expand_less
                          : Icons.expand_more,
                      size: 20,
                      color: colorScheme.iconColor,
                    ),
                    onPressed: () {
                      setState(() {
                        manualCourse.isExpanded = !manualCourse.isExpanded;
                      });
                      widget.onChanged();
                    },
                    tooltip: manualCourse.isExpanded ? "收合欄位" : "展開欄位",
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.delete_outline,
                      color: Colors.red,
                      size: 20,
                    ),
                    onPressed: widget.onDelete,
                    tooltip: "刪除項目",
                  ),
                ],
              ),
            ),

            if (manualCourse.isExpanded)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
<<<<<<< HEAD
                      crossAxisAlignment: CrossAxisAlignment.end,
=======
>>>>>>> cb0e69536426ceb2a943a1d70f3df893136211d7
                      children: [
                        Expanded(
                          flex: 3,
                          child: ActionDropdown(
                            value: manualCourse.selectedAction,
                            onChanged: (val) {
                              setState(() {
                                manualCourse.selectedAction = val;
                              });
                              widget.onChanged();
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 5,
                          child: InkWell(
                            onTap: widget.onPickCourseCode,
                            child: Container(
<<<<<<< HEAD
                              height: 42,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
=======
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 12,
>>>>>>> cb0e69536426ceb2a943a1d70f3df893136211d7
                              ),
                              decoration: BoxDecoration(
                                color: isActive
                                    ? colorScheme.primary.withValues(
                                        alpha: 0.05,
                                      )
                                    : null,
                                border: Border.all(
                                  color: isActive
                                      ? colorScheme.primary
                                      : colorScheme.borderColor,
                                  width: isActive ? 1.5 : 1.0,
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      manualCourse.courseNo.isEmpty
                                          ? "點擊選擇課號"
                                          : manualCourse.courseNo,
                                      style: TextStyle(
                                        color: manualCourse.courseNo.isEmpty
                                            ? colorScheme.subtitleText
                                            : colorScheme.primaryText,
                                        fontWeight:
                                            manualCourse.courseNo.isEmpty
                                                ? FontWeight.normal
                                                : FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  Icon(
                                    isActive ? Icons.arrow_back : Icons.search,
                                    size: 18,
                                    color: isActive
                                        ? colorScheme.primary
                                        : colorScheme.iconColor,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (isActive && manualCourse.courseNo.isEmpty) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.arrow_back,
                            size: 14,
                            color: colorScheme.primary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            "請在左側搜尋課程並點擊「選取」",
                            style: TextStyle(
                              color: colorScheme.primary,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 12),
                    ReasonDropdown(
                      value: manualCourse.selectedReason,
                      reasons: widget.reasons,
                      onChanged: (val) {
                        setState(() {
                          manualCourse.selectedReason = val;
                        });
                        widget.onChanged();
                      },
                    ),
                  ],
                ),
              )
            else
              // 收合狀態的摘要行
              InkWell(
                onTap: () {
                  setState(() {
                    manualCourse.isExpanded = true;
                  });
                  widget.onChanged();
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 14.0,
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: manualCourse.selectedAction == "退選"
                              ? Colors.red.shade50
                              : Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          manualCourse.selectedAction ?? "加選",
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: manualCourse.selectedAction == "退選"
                                ? Colors.red.shade700
                                : Colors.blue.shade700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        manualCourse.courseNo.isEmpty
                            ? "未選取課號"
                            : manualCourse.courseNo,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: manualCourse.courseNo.isEmpty
                              ? colorScheme.subtitleText
                              : colorScheme.primaryText,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          _getReasonText(manualCourse.selectedReason),
                          style: TextStyle(
                            fontSize: 13,
                            color: colorScheme.subtitleText,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Icon(Icons.edit, size: 14, color: colorScheme.iconColor),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
