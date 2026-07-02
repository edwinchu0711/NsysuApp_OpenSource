import 'package:flutter/material.dart';
import '../models/program_model.dart';
import '../theme/app_theme.dart';

class CrossDeptVerificationWidget extends StatefulWidget {
  final List<CrossDeptVerification> verifications;
  final Map<String, VerificationStatus> verificationStatuses;
  final void Function(String vKey, VerificationStatus status)?
      onVerificationChanged;

  const CrossDeptVerificationWidget({
    super.key,
    required this.verifications,
    this.verificationStatuses = const {},
    this.onVerificationChanged,
  });

  @override
  State<CrossDeptVerificationWidget> createState() =>
      _CrossDeptVerificationWidgetState();
}

class _CrossDeptVerificationWidgetState
    extends State<CrossDeptVerificationWidget> {
  late final Map<String, bool> _expandedMap;

  @override
  void initState() {
    super.initState();
    _initExpandedMap();
  }

  void _initExpandedMap() {
    _expandedMap = {
      for (final v in widget.verifications)
        v.key: _isUnfilled(v.key),
    };
  }

  @override
  void didUpdateWidget(CrossDeptVerificationWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    for (final v in widget.verifications) {
      final wasUnfilled = _isUnfilledIn(oldWidget.verificationStatuses, v.key);
      final isNowFilled = !_isUnfilled(v.key);

      if (wasUnfilled && isNowFilled) {
        _expandedMap[v.key] = false;
      }
    }
  }

  bool _isUnfilled(String vKey) =>
      (widget.verificationStatuses[vKey] ?? VerificationStatus.unfilled) ==
      VerificationStatus.unfilled;

  bool _isUnfilledIn(Map<String, VerificationStatus> map, String vKey) =>
      (map[vKey] ?? VerificationStatus.unfilled) == VerificationStatus.unfilled;

  void _toggleExpanded(String vKey) {
    setState(() {
      _expandedMap[vKey] = !(_expandedMap[vKey] ?? true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.isDark
            ? const Color(0xFF3D2E00)
            : const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFFCA28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.help_outline,
                size: 18,
                color: Color(0xFF856404),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '跨院選修需自行確認',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: colorScheme.isDark
                        ? const Color(0xFFFFCA28)
                        : const Color(0xFF856404),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '以下課程的開課系所為「跨院選修」，請確認是否符合學程規定。',
            style: TextStyle(
              fontSize: 12,
              color: colorScheme.isDark
                  ? const Color(0xFFFFCA28)
                  : const Color(0xFF856404),
            ),
          ),
          const SizedBox(height: 10),
          ...widget.verifications.map(
            (v) => _buildVerificationCard(colorScheme, v),
          ),
        ],
      ),
    );
  }

  Widget _buildVerificationCard(
    ColorScheme colorScheme,
    CrossDeptVerification v,
  ) {
    final vKey = v.key;
    final currentStatus =
        widget.verificationStatuses[vKey] ?? VerificationStatus.unfilled;
    final isExpanded = _expandedMap[vKey] ?? true;
    final isFilled = currentStatus != VerificationStatus.unfilled;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: colorScheme.cardBackground,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.borderColor),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => _toggleExpanded(vKey),
            borderRadius: isExpanded
                ? const BorderRadius.vertical(top: Radius.circular(8))
                : BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      v.courseName,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        color: colorScheme.primaryText,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  if (isFilled) _buildStatusBadge(currentStatus, colorScheme),
                  const SizedBox(width: 4),
                  AnimatedRotation(
                    turns: isExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.keyboard_arrow_down,
                      size: 18,
                      color: colorScheme.subtitleText,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 220),
            crossFadeState: isExpanded
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            firstChild: Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(height: 1, thickness: 0.5),
                  const SizedBox(height: 8),
                  _buildInfoRow('開課系所', v.department, colorScheme),
                  if (v.courseNo.isNotEmpty)
                    _buildInfoRow('課號', v.courseNo, colorScheme),
                  if (v.semester.isNotEmpty)
                    _buildInfoRow('學期', v.semester, colorScheme),
                  if (v.validDepts.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    _buildInfoRow(
                      '學程規定開課系所',
                      v.validDepts.join('、'),
                      colorScheme,
                      highlight: true,
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildVerificationOption(
                        colorScheme,
                        vKey,
                        VerificationStatus.unfilled,
                        '未填寫',
                        currentStatus,
                      ),
                      const SizedBox(width: 8),
                      _buildVerificationOption(
                        colorScheme,
                        vKey,
                        VerificationStatus.confirmed,
                        '符合規定',
                        currentStatus,
                      ),
                      const SizedBox(width: 8),
                      _buildVerificationOption(
                        colorScheme,
                        vKey,
                        VerificationStatus.rejected,
                        '不符合',
                        currentStatus,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            secondChild: const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(VerificationStatus status, ColorScheme colorScheme) {
    late final Color bg;
    late final Color fg;
    late final String label;

    switch (status) {
      case VerificationStatus.confirmed:
        bg = colorScheme.isDark
            ? const Color(0xFF1B3A1B)
            : const Color(0xFFE8F8E8);
        fg = colorScheme.isDark ? Colors.green[300]! : Colors.green[700]!;
        label = '符合規定';
      case VerificationStatus.rejected:
        bg = colorScheme.isDark
            ? const Color(0xFF3A1B1B)
            : const Color(0xFFFDE8E8);
        fg = colorScheme.isDark ? Colors.red[300]! : Colors.red[700]!;
        label = '不符合';
      case VerificationStatus.unfilled:
        bg = Colors.transparent;
        fg = colorScheme.subtitleText;
        label = '未填寫';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: fg.withOpacity(0.5)),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: fg),
      ),
    );
  }

  Widget _buildInfoRow(
    String label,
    String value,
    ColorScheme colorScheme, {
    bool highlight = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Text.rich(
        TextSpan(
          style: TextStyle(
            fontFamily: Theme.of(context).textTheme.bodyMedium?.fontFamily,
            fontSize: highlight ? 13 : 12,
            color: colorScheme.subtitleText,
          ),
          children: [
            TextSpan(
              text: '$label：',
              style: TextStyle(
                fontWeight: FontWeight.w400,
                color: highlight
                    ? (colorScheme.isDark
                          ? const Color(0xFFFFCA28)
                          : const Color(0xFF856404))
                    : colorScheme.subtitleText,
              ),
            ),
            TextSpan(
              text: value,
              style: TextStyle(
                fontWeight: highlight ? FontWeight.w700 : FontWeight.normal,
                fontSize: highlight ? 13 : 12,
                color: highlight
                    ? (colorScheme.isDark
                          ? const Color(0xFFFFCA28)
                          : const Color(0xFF856404))
                    : colorScheme.primaryText,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVerificationOption(
    ColorScheme colorScheme,
    String vKey,
    VerificationStatus option,
    String label,
    VerificationStatus currentStatus,
  ) {
    final isSelected = currentStatus == option;
    Color bgColor;
    Color borderColor;
    Color textColor;

    if (option == VerificationStatus.confirmed && isSelected) {
      bgColor = colorScheme.isDark
          ? const Color(0xFF1B3A1B)
          : const Color(0xFFE8F8E8);
      borderColor = Colors.green;
      textColor = colorScheme.isDark ? Colors.green[300]! : Colors.green[700]!;
    } else if (option == VerificationStatus.rejected && isSelected) {
      bgColor = colorScheme.isDark
          ? const Color(0xFF3A1B1B)
          : const Color(0xFFFDE8E8);
      borderColor = Colors.red;
      textColor = colorScheme.isDark ? Colors.red[300]! : Colors.red[700]!;
    } else if (option == VerificationStatus.unfilled && isSelected) {
      bgColor = colorScheme.isDark
          ? const Color(0xFF3D2E00)
          : const Color(0xFFFFF8E1);
      borderColor = const Color(0xFFFFCA28);
      textColor = colorScheme.isDark
          ? const Color(0xFFFFCA28)
          : const Color(0xFF856404);
    } else {
      bgColor = colorScheme.secondaryCardBackground;
      borderColor = colorScheme.borderColor;
      textColor = colorScheme.subtitleText;
    }

    return Expanded(
      child: GestureDetector(
        onTap: widget.onVerificationChanged != null
            ? () => widget.onVerificationChanged!(vKey, option)
            : null,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: borderColor),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: textColor,
            ),
          ),
        ),
      ),
    );
  }
}