import 'package:flutter/material.dart';
import '../models/program_model.dart';
import '../theme/app_theme.dart';
import '../widgets/dashed_rect.dart';

/// Source of a course for badge display in RequiredCourseSimRightPanel.
enum CourseSource { taken, required, missing }

/// Resolver function that determines the [CourseSource] for a given
/// [SubjectResult]. Returns null when no badge column is desired.
typedef CourseSourceResolver = CourseSource? Function(SubjectResult s);

/// A reusable widget that renders a single [GroupResult] card, including:
/// - Group header (check/cross icon, label, ruleText, credits)
/// - Optional group-level external credits row
/// - Taken subjects table (with optional badge column)
/// - Missing subjects table (with optional badge column)
///
/// Waivers and cross-dept verification cards are NOT included here;
/// they live in [WaiverSectionWidget] and [CrossDeptVerificationWidget].
class GroupCardWidget extends StatelessWidget {
  final GroupResult group;
  final ColorScheme colorScheme;
  final Map<String, VerificationStatus> verificationStatuses;
  final void Function(String vKey, VerificationStatus status)?
  onVerificationChanged;
  final Map<String, List<String>> waivers;
  final void Function(String subject, String waiverId, bool checked)?
  onWaiverChanged;
  final Set<String>? requiredCourseNames;
  final CourseSourceResolver? courseSourceResolver;

  const GroupCardWidget({
    super.key,
    required this.group,
    required this.colorScheme,
    this.verificationStatuses = const {},
    this.onVerificationChanged,
    this.waivers = const {},
    this.onWaiverChanged,
    this.requiredCourseNames,
    this.courseSourceResolver,
  });

  bool get _showBadgeColumn => courseSourceResolver != null;

  @override
  Widget build(BuildContext context) {
    final g = group;
    final ruleText = g.selectionRule.type == 'all'
        ? '全部必修'
        : g.selectionRule.type == 'pick_n'
        ? '選 ${g.selectionRule.pick} 科'
        : '至少 ${g.creditsRequired} 學分';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: colorScheme.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Group header
          Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            decoration: BoxDecoration(
              color: colorScheme.secondaryCardBackground,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Text(
                  g.isMet ? '✓' : '✗',
                  style: TextStyle(
                    fontSize: 16,
                    color: g.isMet ? Colors.green[700] : Colors.red[700],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    g.label,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: colorScheme.primaryText,
                    ),
                  ),
                ),
                Text(
                  '$ruleText — ${g.creditsEarned}/${g.creditsRequired} 學分',
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.subtitleText,
                  ),
                ),
              ],
            ),
          ),
          // Group external credits row
          if (g.groupExternalCredits != null) _buildGroupExternalCreditsRow(g),
          // Subject tables
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (g.subjectsTaken.isNotEmpty)
                  _buildTakenSubjectsTable(colorScheme, g.subjectsTaken),
                if (g.subjectsMissing.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _buildMissingSubjectsTable(
                    colorScheme,
                    g.subjectsMissing,
                    g.isMet,
                  ),
                ],
                const SizedBox(height: 4),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupExternalCreditsRow(GroupResult g) {
    final rule = g.groupExternalCredits!;
    final met = g.externalCreditsEarned >= rule.min;
    final icon = met ? Icons.check_circle_outline : Icons.info_outline;
    final iconColor = met
        ? Colors.green[700]
        : (colorScheme.isDark ? Colors.orange[300] : Colors.orange[700]);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.secondaryCardBackground,
        border: Border(
          top: BorderSide(
            color: colorScheme.borderColor.withValues(alpha: 0.5),
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: iconColor),
          const SizedBox(width: 6),
          Text(
            '外系學分：${g.externalCreditsEarned} / ${rule.min} 學分',
            style: TextStyle(fontSize: 12, color: colorScheme.subtitleText),
          ),
        ],
      ),
    );
  }

  Widget _buildTakenSubjectsTable(
    ColorScheme colorScheme,
    List<SubjectResult> subjects,
  ) {
    final borderColor = colorScheme.isDark
        ? const Color(0xFF4CAF50).withValues(alpha: 0.4)
        : const Color(0xFF4CAF50).withValues(alpha: 0.5);

    final columnWidths = _showBadgeColumn
        ? const {
            0: FixedColumnWidth(24),
            1: FlexColumnWidth(3),
            2: FlexColumnWidth(5),
            3: FixedColumnWidth(40),
            4: FixedColumnWidth(60),
          }
        : const {
            0: FixedColumnWidth(24),
            1: FlexColumnWidth(3),
            2: FlexColumnWidth(5),
            3: FixedColumnWidth(40),
          };

    final headerChildren = <Widget>[
      _buildTableHeaderCell('', colorScheme),
      _buildTableHeaderCell('課程名稱', colorScheme),
      _buildTableHeaderCell('滿足方式', colorScheme),
      _buildTableHeaderCell('學分', colorScheme),
    ];
    if (_showBadgeColumn) {
      headerChildren.add(_buildTableHeaderCell('類型', colorScheme));
    }

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Table(
          columnWidths: columnWidths,
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          children: [
            TableRow(
              decoration: BoxDecoration(
                color: colorScheme.isDark
                    ? const Color(0xFF1B3A1B)
                    : const Color(0xFFE8F8E8),
              ),
              children: headerChildren,
            ),
            ...subjects.asMap().entries.map((entry) {
              final idx = entry.key;
              final s = entry.value;
              return _buildTakenSubjectRow(
                colorScheme,
                s,
                isLast: idx == subjects.length - 1,
              );
            }),
          ],
        ),
      ),
    );
  }

  TableRow _buildTakenSubjectRow(
    ColorScheme colorScheme,
    SubjectResult s, {
    bool isLast = false,
  }) {
    final isWaiver = s.satisfiedType == 'waiver';
    final needsVerification =
        s.deptValidationResult == DeptValidationResult.needsVerification;

    final verificationStatus = s.crossDeptVerification != null
        ? (verificationStatuses[s.crossDeptVerification!.key] ??
              VerificationStatus.unfilled)
        : null;

    String icon;
    Color iconColor;

    if (isWaiver) {
      icon = '📌';
      iconColor = const Color(0xFFFFCA28);
    } else if (needsVerification) {
      if (verificationStatus == VerificationStatus.confirmed) {
        icon = '✓';
        iconColor = Colors.green;
      } else if (verificationStatus == VerificationStatus.rejected) {
        icon = '✗';
        iconColor = Colors.red;
      } else {
        icon = '⚠️';
        iconColor = Colors.orange;
      }
    } else {
      icon = '✓';
      iconColor = Colors.green;
    }

    final satisfiedText = StringBuffer();
    if (s.allMatchedCourses.isNotEmpty) {
      if (s.allMatchedCourses.length == 1) {
        satisfiedText.write(s.allMatchedCourses.first);
      } else {
        satisfiedText.write(
          '符合課程：\n${s.allMatchedCourses.join('\n')}\n⚠️（計算以學校官方為準）',
        );
      }
    } else {
      satisfiedText.write('以「${s.satisfiedBy}」滿足');
      if (s.department.isNotEmpty) {
        satisfiedText.write('\n開課：${s.department.join('、')}');
      }
      if (!s.isOwnDept) satisfiedText.write('\n🔹外系');
      if (s.isCrossDept) satisfiedText.write('\n⚠️跨院選修');
    }

    Widget? verificationBadge;
    if (needsVerification && verificationStatus != null) {
      Color badgeBg;
      Color badgeText;
      String badgeLabel;
      if (verificationStatus == VerificationStatus.confirmed) {
        badgeBg = Colors.green.withValues(alpha: 0.15);
        badgeText = colorScheme.isDark
            ? Colors.green[300]!
            : Colors.green[700]!;
        badgeLabel = '已確認符合';
      } else if (verificationStatus == VerificationStatus.rejected) {
        badgeBg = Colors.red.withValues(alpha: 0.15);
        badgeText = colorScheme.isDark ? Colors.red[300]! : Colors.red[700]!;
        badgeLabel = '不符合';
      } else {
        badgeBg = Colors.orange.withValues(alpha: 0.15);
        badgeText = colorScheme.isDark
            ? Colors.orange[300]!
            : Colors.orange[700]!;
        badgeLabel = '待確認';
      }
      verificationBadge = Container(
        margin: const EdgeInsets.only(top: 3),
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
        decoration: BoxDecoration(
          color: badgeBg,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          badgeLabel,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w400,
            color: badgeText,
          ),
        ),
      );
    }

    final rowDecoration = !isLast
        ? BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: colorScheme.borderColor.withValues(alpha: 0.5),
              ),
            ),
          )
        : null;

    final children = <Widget>[
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        child: Text(icon, style: TextStyle(fontSize: 13, color: iconColor)),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              s.subject,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: colorScheme.primaryText,
              ),
            ),
            if (verificationBadge != null) verificationBadge,
          ],
        ),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: Text(
          satisfiedText.toString(),
          style: TextStyle(fontSize: 11, color: colorScheme.subtitleText),
        ),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: Text(
          '${s.credits}',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w400,
            color: colorScheme.primaryText,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    ];

    if (_showBadgeColumn) {
      final source = courseSourceResolver!(s);
      children.add(
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
          child: _buildBadge(source!, colorScheme),
        ),
      );
    }

    return TableRow(decoration: rowDecoration, children: children);
  }

  Widget _buildMissingSubjectsTable(
    ColorScheme colorScheme,
    List<SubjectResult> subjects,
    bool groupIsMet,
  ) {
    final dashColor = colorScheme.isDark
        ? Colors.grey[600]!
        : Colors.grey[400]!;

    final columnWidths = _showBadgeColumn
        ? const {
            0: FixedColumnWidth(24),
            1: FlexColumnWidth(3),
            2: FlexColumnWidth(5),
            3: FixedColumnWidth(40),
            4: FixedColumnWidth(60),
          }
        : const {
            0: FixedColumnWidth(24),
            1: FlexColumnWidth(3),
            2: FlexColumnWidth(5),
            3: FixedColumnWidth(40),
          };

    final headerChildren = <Widget>[
      _buildTableHeaderCell('', colorScheme),
      _buildTableHeaderCell('課程名稱', colorScheme),
      _buildTableHeaderCell('可修課程', colorScheme),
      _buildTableHeaderCell('學分', colorScheme),
    ];
    if (_showBadgeColumn) {
      headerChildren.add(_buildTableHeaderCell('類型', colorScheme));
    }

    return DashedRect(
      dashColor: dashColor,
      strokeWidth: 1,
      borderRadius: 8,
      child: Table(
        columnWidths: columnWidths,
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        children: [
          TableRow(
            decoration: BoxDecoration(
              color: colorScheme.isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.black.withValues(alpha: 0.03),
            ),
            children: headerChildren,
          ),
          ...subjects.map(
            (s) =>
                _buildMissingSubjectRow(colorScheme, s, groupIsMet, dashColor),
          ),
        ],
      ),
    );
  }

  TableRow _buildMissingSubjectRow(
    ColorScheme colorScheme,
    SubjectResult s,
    bool groupIsMet,
    Color dashColor,
  ) {
    final textColor = groupIsMet
        ? colorScheme.subtitleText
        : colorScheme.primaryText;

    String alternativesText;
    if (s.alternatives != null && s.alternatives!.isNotEmpty) {
      if (s.alternativeDepartments != null) {
        final parts = <String>[];
        for (final alt in s.alternatives!) {
          final depts = s.alternativeDepartments?[alt];
          if (depts != null && depts.isNotEmpty) {
            parts.add('$alt（${depts.join('、')}）');
          } else {
            parts.add(alt);
          }
        }
        alternativesText = parts.length > 3
            ? '${parts.sublist(0, 3).join('、')} 等${parts.length}門'
            : parts.join('、');
      } else {
        alternativesText = s.alternatives!.length > 3
            ? '${s.alternatives!.sublist(0, 3).join('、')} 等${s.alternatives!.length}門'
            : s.alternatives!.join('、');
      }
    } else {
      alternativesText = '—';
    }

    final creditsDisplay = s.credits > 0
        ? '${s.credits}'
        : (s.alternativeCredits != null && s.alternativeCredits!.isNotEmpty
              ? '${s.alternativeCredits!.values.reduce((a, b) => a > b ? a : b)}'
              : '—');

    final children = <Widget>[
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Text(
          '✗',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w400,
            color: dashColor,
          ),
        ),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              s.subject,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: textColor,
              ),
            ),
            const SizedBox(height: 2),
            _buildFailureReason(colorScheme, s),
          ],
        ),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Text(
          alternativesText,
          style: TextStyle(fontSize: 11, color: colorScheme.subtitleText),
        ),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Text(
          creditsDisplay,
          style: TextStyle(fontSize: 12, color: textColor),
          textAlign: TextAlign.center,
        ),
      ),
    ];

    if (_showBadgeColumn) {
      final source = courseSourceResolver!(s);
      children.add(
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
          child: _buildBadge(source!, colorScheme),
        ),
      );
    }

    return TableRow(children: children);
  }

  Widget _buildBadge(CourseSource source, ColorScheme colorScheme) {
    Color bgColor;
    Color borderColor;
    Color textColor;
    String label;

    switch (source) {
      case CourseSource.taken:
        bgColor = Colors.green.withValues(alpha: 0.15);
        borderColor = Colors.green;
        textColor = colorScheme.isDark
            ? Colors.green[300]!
            : Colors.green[700]!;
        label = '已修';
        break;
      case CourseSource.required:
        bgColor = Colors.blue.withValues(alpha: 0.15);
        borderColor = Colors.blue;
        textColor = colorScheme.isDark ? Colors.blue[300]! : Colors.blue[700]!;
        label = '必修課程';
        break;
      case CourseSource.missing:
        bgColor = Colors.red.withValues(alpha: 0.15);
        borderColor = Colors.red;
        textColor = colorScheme.isDark ? Colors.red[300]! : Colors.red[700]!;
        label = '未修';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: borderColor.withValues(alpha: 0.5)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w400,
          color: textColor,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildTableHeaderCell(String text, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: colorScheme.subtitleText,
        ),
      ),
    );
  }

  Widget _buildFailureReason(ColorScheme colorScheme, SubjectResult s) {
    final mismatches = s.departmentMismatches;
    if (mismatches != null && mismatches.isNotEmpty) {
      final text = mismatches
          .map((m) {
            final taken = m.takenDept.isEmpty ? '未知系所' : m.takenDept;
            final valid = m.validDepts.isEmpty ? '無限制' : m.validDepts.join('、');
            return '開課系所不符（已修「${m.name}」，開課系所為「$taken」，不符合規定「$valid」）';
          })
          .join('\n');
      return Text(
        text,
        style: TextStyle(
          fontSize: 10,
          color: colorScheme.isDark
              ? const Color(0xFFFF8A80)
              : const Color(0xFFD32F2F),
          fontWeight: FontWeight.normal,
        ),
      );
    } else {
      return Text(
        '課程未修習或名稱不符',
        style: TextStyle(
          fontSize: 10,
          color: colorScheme.isDark
              ? const Color(0xFFFFB74D)
              : const Color(0xFFEF6C00),
          fontWeight: FontWeight.normal,
        ),
      );
    }
  }
}
