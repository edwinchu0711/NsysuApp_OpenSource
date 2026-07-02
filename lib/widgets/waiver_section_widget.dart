import 'package:flutter/material.dart';
import '../models/program_model.dart';
import '../services/eligibility_checker.dart';
import '../theme/app_theme.dart';

class WaiverSectionWidget extends StatelessWidget {
  final ProgramRule program;
  final int? selectedYear;
  final Map<String, List<String>> waivers;
  final void Function(String subject, String waiverId, bool checked)?
      onWaiverChanged;

  const WaiverSectionWidget({
    super.key,
    required this.program,
    this.selectedYear,
    this.waivers = const {},
    this.onWaiverChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (selectedYear == null) return const SizedBox.shrink();

    // Find the matching version
    ProgramVersion? version;
    final matching = program.versions
        .where((v) => v.academicYear == selectedYear)
        .toList();
    if (matching.isNotEmpty) {
      version = matching.first;
    }
    if (version == null) return const SizedBox.shrink();

    final waiverSubjects = <Subject>[];
    for (final group in version.courseGroups) {
      for (final subject in group.subjects) {
        if (subject.waiver.allowed &&
            subject.waiver.waiverAlternatives.isNotEmpty) {
          waiverSubjects.add(subject);
        }
      }
    }

    if (waiverSubjects.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.isDark
            ? const Color(0xFF2A2520)
            : const Color(0xFFFFFBF0),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFFCA28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.assignment_turned_in_outlined,
                size: 18,
                color: Color(0xFF856404),
              ),
              const SizedBox(width: 8),
              Text(
                '抵免選項',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: colorScheme.isDark
                      ? const Color(0xFFFFCA28)
                      : const Color(0xFF856404),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...waiverSubjects.expand((subject) {
            return subject.waiver.waiverAlternatives.map((wa) {
              final waId = EligibilityChecker.makeWaiverId(
                subject.programSubject,
                wa.condition,
              );
              final isChecked =
                  (waivers[subject.programSubject] ?? []).contains(waId);
              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: Checkbox(
                        value: isChecked,
                        activeColor: const Color(0xFFFFCA28),
                        onChanged: onWaiverChanged != null
                            ? (val) => onWaiverChanged!(
                                subject.programSubject,
                                waId,
                                val ?? false,
                              )
                            : null,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${subject.programSubject} — ${wa.condition}',
                            style: TextStyle(
                              fontSize: 13,
                              color: colorScheme.primaryText,
                            ),
                          ),
                          if (wa.creditsGranted > 0)
                            Text(
                              '${wa.creditsGranted} 學分',
                              style: TextStyle(
                                fontSize: 11,
                                color: colorScheme.subtitleText,
                              ),
                            ),
                          if (wa.note != null && wa.note!.isNotEmpty)
                            Text(
                              wa.note!,
                              style: TextStyle(
                                fontSize: 11,
                                color: colorScheme.subtitleText,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            });
          }),
        ],
      ),
    );
  }
}