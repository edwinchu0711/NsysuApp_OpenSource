import 'package:flutter/material.dart';
import '../services/department_service.dart';
import '../theme/app_theme.dart';
import '../widgets/searchable_dropdown_field.dart';
import 'glass/glass_card.dart';

class CourseProgressProfileBar extends StatefulWidget {
  final List<DeptOption> departments;
  final String savedDept;
  final String savedDoubleMajor;
  final String savedMinor;
  final bool isDirty;
  final VoidCallback onFieldChanged;
  final void Function(String dept, String doubleMajor, String minor) onSave;
  final ValueChanged<bool>? onExpansionChanged;

  const CourseProgressProfileBar({
    super.key,
    required this.departments,
    required this.savedDept,
    required this.savedDoubleMajor,
    required this.savedMinor,
    required this.isDirty,
    required this.onFieldChanged,
    required this.onSave,
    this.onExpansionChanged,
  });

  @override
  State<CourseProgressProfileBar> createState() =>
      _CourseProgressProfileBarState();
}

class _CourseProgressProfileBarState extends State<CourseProgressProfileBar> {
  final _deptController = TextEditingController();
  final _doubleMajorController = TextEditingController();
  final _minorController = TextEditingController();
  final _deptFocusNode = FocusNode();
  final _doubleMajorFocusNode = FocusNode();
  final _minorFocusNode = FocusNode();
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _deptController.text = widget.savedDept;
    _doubleMajorController.text = widget.savedDoubleMajor.isEmpty
        ? '無'
        : widget.savedDoubleMajor;
    _minorController.text = widget.savedMinor.isEmpty ? '無' : widget.savedMinor;
    _isExpanded = widget.savedDept.isEmpty;
  }

  @override
  void didUpdateWidget(covariant CourseProgressProfileBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.savedDept != oldWidget.savedDept) {
      _deptController.text = widget.savedDept;
      if (oldWidget.savedDept.isEmpty && widget.savedDept.isNotEmpty) {
        _isExpanded = false;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            widget.onExpansionChanged?.call(false);
          }
        });
      }
    }
    if (widget.savedDoubleMajor != oldWidget.savedDoubleMajor) {
      _doubleMajorController.text = widget.savedDoubleMajor.isEmpty
          ? '無'
          : widget.savedDoubleMajor;
    }
    if (widget.savedMinor != oldWidget.savedMinor) {
      _minorController.text = widget.savedMinor.isEmpty
          ? '無'
          : widget.savedMinor;
    }
  }

  @override
  void dispose() {
    _deptController.dispose();
    _doubleMajorController.dispose();
    _minorController.dispose();
    _deptFocusNode.dispose();
    _doubleMajorFocusNode.dispose();
    _minorFocusNode.dispose();
    super.dispose();
  }

  List<String> get _deptSuggestions =>
      widget.departments.map((d) => d.displayName).toList();

  List<String> get _doubleMajorSuggestions => [
    '無',
    ...widget.departments.map((d) => d.displayName).toSet(),
  ];

  List<String> get _minorSuggestions => [
    '無',
    ...widget.departments.map((d) => d.displayName).toSet(),
  ];

  void _handleSave() {
    final dept = _deptController.text;
    final doubleMajor = _doubleMajorController.text == '無'
        ? ''
        : _doubleMajorController.text;
    final minor = _minorController.text == '無' ? '' : _minorController.text;
    widget.onSave(dept, doubleMajor, minor);
    if (dept.isNotEmpty) {
      setState(() {
        _isExpanded = false;
      });
      widget.onExpansionChanged?.call(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (!_isExpanded) {
      return GestureDetector(
        onTap: () {
          setState(() {
            _isExpanded = true;
          });
          widget.onExpansionChanged?.call(true);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: glassCardDecoration(context, borderRadius: 12) ??
              BoxDecoration(
                color: colorScheme.cardBackground,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colorScheme.borderColor),
              ),
          child: Row(
            children: [
              Icon(
                Icons.school_rounded,
                size: 16,
                color: colorScheme.accentBlue,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '主修：${widget.savedDept}'
                  '${widget.savedDoubleMajor.isNotEmpty ? ' | 雙修：${widget.savedDoubleMajor}' : ''}'
                  '${widget.savedMinor.isNotEmpty ? ' | 輔修：${widget.savedMinor}' : ''}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: colorScheme.primaryText,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.edit_note_rounded,
                size: 18,
                color: colorScheme.subtitleText,
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: glassCardDecoration(context, borderRadius: 12) ??
          BoxDecoration(
            color: colorScheme.cardBackground,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colorScheme.borderColor),
          ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '學系資料設定',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.primaryText,
                ),
              ),
              if (widget.savedDept.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.keyboard_arrow_up_rounded, size: 20),
                  onPressed: () {
                    setState(() {
                      _isExpanded = false;
                    });
                    widget.onExpansionChanged?.call(false);
                  },
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  splashColor: Colors.transparent,
                  highlightColor: Colors.transparent,
                  color: colorScheme.subtitleText,
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildField(
                  label: '你的科系',
                  controller: _deptController,
                  focusNode: _deptFocusNode,
                  hintText: widget.departments.isEmpty ? '載入中...' : '搜尋科系',
                  suggestions: _deptSuggestions,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildField(
                  label: '雙主修（選填）',
                  controller: _doubleMajorController,
                  focusNode: _doubleMajorFocusNode,
                  hintText: '選填，可搜尋',
                  suggestions: _doubleMajorSuggestions,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildField(
                  label: '輔系（選填）',
                  controller: _minorController,
                  focusNode: _minorFocusNode,
                  hintText: '選填，可搜尋',
                  suggestions: _minorSuggestions,
                ),
              ),
              const SizedBox(width: 16),
              SizedBox(
                width: 100,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      '',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    SizedBox(
                      height: 36,
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _handleSave,
                        icon: Icon(
                          widget.isDirty
                              ? Icons.save_rounded
                              : Icons.check_rounded,
                          size: 16,
                        ),
                        label: const Text(
                          '儲存',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colorScheme.accentBlue,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: colorScheme.accentBlue
                              .withValues(alpha: 0.35),
                          disabledForegroundColor: Colors.white.withValues(
                            alpha: 0.7,
                          ),
                          elevation: widget.isDirty ? 2 : 0,
                          shadowColor: colorScheme.accentBlue.withValues(
                            alpha: 0.4,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildField({
    required String label,
    required TextEditingController controller,
    required FocusNode focusNode,
    required String hintText,
    required List<String> suggestions,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: colorScheme.subtitleText,
          ),
        ),
        const SizedBox(height: 4),
        SizedBox(
          height: 36,
          child: SearchableDropdownField(
            controller: controller,
            focusNode: focusNode,
            hintText: hintText,
            suggestions: suggestions,
            onChanged: (_) => widget.onFieldChanged(),
          ),
        ),
      ],
    );
  }
}
