import '../models/program_model.dart';

/// Parses a semester string like "113 學年度 第 1 學期" into (year, semester).
/// Returns null if parsing fails.
(int, int)? parseSemesterString(String s) {
  // Match patterns like "113學年度第1學期", "113 學年度 第 1 學期", "113學年度第2學期"
  final regex = RegExp(r'(\d{2,3})\s*學年度\s*第?\s*(\d)\s*學期');
  final match = regex.firstMatch(s);
  if (match == null) return null;
  final year = int.tryParse(match.group(1) ?? '');
  final sem = int.tryParse(match.group(2) ?? '');
  if (year == null || sem == null) return null;
  return (year, sem);
}

/// Converts an academic year and semester to a comparable numeric value.
/// E.g., year=113, semester=1 → 1131
int semesterToNumeric(int year, int semester) {
  return year * 10 + semester;
}

/// Given an AppliedProgram and ProgramRule, finds the best matching ProgramVersion.
/// The best match is the latest version where the version's year/semester ≤ the application's year/semester.
/// Returns null if no matching version is found.
ProgramVersion? findMatchingVersion(AppliedProgram applied, ProgramRule rule) {
  final appNumeric = semesterToNumeric(applied.appAcademicYear, applied.appSemester);

  ProgramVersion? best;
  int? bestNumeric;

  for (final version in rule.versions) {
    final versionNumeric = semesterToNumeric(
      version.academicYear,
      version.semester ?? 0,
    );
    if (versionNumeric <= appNumeric) {
      if (bestNumeric == null || versionNumeric > bestNumeric) {
        best = version;
        bestNumeric = versionNumeric;
      }
    }
  }

  return best;
}

/// Finds a ProgramRule from the list by exact name match.
/// Returns null if no match is found.
ProgramRule? findProgramByName(List<ProgramRule> programs, String name) {
  for (final program in programs) {
    if (program.programName == name) return program;
  }
  return null;
}