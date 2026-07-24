import 'package:flutter/material.dart';

import '../../../models/course_model.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/layout_style_notifier.dart';
import '../assistant_add_course_page.dart';
import '../assistant_add_custom_event_form.dart';
import '../assistant_export_page.dart';
import '../assistant_import_page.dart';

/// 右側操作面板：新增課程 / 新增行程 / 匯入 / 匯出（原 _buildRightActionPane）
class RightActionPane extends StatefulWidget {
  final List<Course> courses;
  final VoidCallback onDataChanged;

  const RightActionPane({
    super.key,
    required this.courses,
    required this.onDataChanged,
  });

  @override
  State<RightActionPane> createState() => _RightActionPaneState();
}

class _RightActionPaneState extends State<RightActionPane> {
  int _selectedRightTab = 0;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isLiquidGlass = LayoutStyleNotifier.instance.isLiquidGlass;
    final isDark = colorScheme.isDark;

    return Container(
      decoration: BoxDecoration(
        color: isLiquidGlass ? Colors.transparent : colorScheme.cardBackground,
        border: Border(
          left: BorderSide(
            color: isLiquidGlass
                ? (isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.white.withValues(alpha: 0.35))
                : colorScheme.borderColor,
            width: 0.5,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            color: isLiquidGlass
                ? (isDark
                    ? Colors.white.withValues(alpha: 0.04)
                    : Colors.white.withValues(alpha: 0.2))
                : colorScheme.subtleBackground,
            child: Center(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildTabChip(0, "新增課程", Icons.add_box),
                    const SizedBox(width: 8),
                    _buildTabChip(1, "新增行程", Icons.event_note),
                    const SizedBox(width: 8),
                    _buildTabChip(2, "匯入課表", Icons.download),
                    const SizedBox(width: 8),
                    _buildTabChip(3, "匯出選課", Icons.upload),
                  ],
                ),
              ),
            ),
          ),
          Divider(
            height: 1,
            color: isLiquidGlass
                ? (isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.white.withValues(alpha: 0.35))
                : colorScheme.borderColor,
          ),
          Expanded(
            child: IndexedStack(
              index: _selectedRightTab,
              children: [
                AssistantAddCoursePage(
                  isInline: true,
                  onCourseAdded: widget.onDataChanged,
                ),
                AssistantAddCustomEventForm(onEventAdded: widget.onDataChanged),
                AssistantImportPage(
                  isInline: true,
                  onImportSuccess: widget.onDataChanged,
                ),
                AssistantExportPage(
                  isInline: true,
                  courses: List<Course>.from(widget.courses),
                  onExportSuccess: widget.onDataChanged,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabChip(int index, String label, IconData icon) {
    final colorScheme = Theme.of(context).colorScheme;
    final isSelected = _selectedRightTab == index;

    // Unique premium gradients for each active tab - softened and elegant
    final List<LinearGradient> activeGradients = [
      const LinearGradient(
        colors: [Color(0xFF5680E9), Color(0xFF8468E8)], // Soft Lavender Blue
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      const LinearGradient(
        colors: [Color(0xFF3B9A9C), Color(0xFF54B1A0)], // Soft Mint Teal
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      const LinearGradient(
        colors: [Color(0xFFD19F58), Color(0xFFCF7B6B)], // Soft Honey Amber
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      const LinearGradient(
        colors: [Color(0xFFD68875), Color(0xFFB57088)], // Soft Dusty Rose
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ];

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedRightTab = index;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7.5),
        decoration: BoxDecoration(
          gradient: isSelected
              ? activeGradients[index % activeGradients.length]
              : null,
          color: isSelected
              ? null
              : (LayoutStyleNotifier.instance.isLiquidGlass
                  ? (colorScheme.isDark
                      ? Colors.white.withValues(alpha: 0.04)
                      : Colors.white.withValues(alpha: 0.3))
                  : colorScheme.cardBackground),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? Colors.transparent
                : (LayoutStyleNotifier.instance.isLiquidGlass
                    ? (colorScheme.isDark
                        ? Colors.white.withValues(alpha: 0.1)
                        : Colors.white.withValues(alpha: 0.35))
                    : colorScheme.borderColor.withValues(alpha: 0.6)),
            width: 0.8,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: activeGradients[index % activeGradients.length]
                        .colors[0]
                        .withValues(alpha: 0.2),
                    blurRadius: 6,
                    spreadRadius: 0.5,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 15.5,
              color: isSelected
                  ? Colors.white
                  : colorScheme.primaryText.withValues(alpha: 0.7),
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : colorScheme.primaryText,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                fontSize: 12,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}