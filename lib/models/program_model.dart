class ProgramRule {
  final String programId;
  final String programName;
  final bool isDiscontinued;
  final String? discontinuedDate;
  final String? formerName;
  final List<ProgramVersion> versions;

  ProgramRule({
    required this.programId,
    required this.programName,
    this.isDiscontinued = false,
    this.discontinuedDate,
    this.formerName,
    required this.versions,
  });

  factory ProgramRule.fromJson(Map<String, dynamic> json) => ProgramRule(
        programId: json['program_id'] ?? '',
        programName: json['program_name'] ?? '',
        isDiscontinued: json['is_discontinued'] ?? false,
        discontinuedDate: json['discontinued_date']?.toString(),
        formerName: json['former_name']?.toString(),
        versions: ((json['versions'] ?? []) as List)
            .map((v) =>
                ProgramVersion.fromJson(v as Map<String, dynamic>))
            .toList(),
      );
}

class ProgramVersion {
  final int academicYear;
  final int? semester;
  final String? approvalInfo;
  final ProgramRequirements requirements;
  final List<CourseGroup> courseGroups;

  ProgramVersion({
    required this.academicYear,
    this.semester,
    this.approvalInfo,
    required this.requirements,
    required this.courseGroups,
  });

  factory ProgramVersion.fromJson(Map<String, dynamic> json) => ProgramVersion(
        academicYear: json['academic_year'] ?? 0,
        semester: json['semester'],
        approvalInfo: json['approval_info']?.toString(),
        requirements: ProgramRequirements.fromJson(
            json['requirements'] ?? {}),
        courseGroups: ((json['course_groups'] ?? []) as List)
            .map((g) =>
                CourseGroup.fromJson(g as Map<String, dynamic>))
            .toList(),
      );
}

class ProgramRequirements {
  final int totalMinCredits;
  final ExternalCreditsRule externalCredits;
  final List<dynamic> nonCourseRequirements;
  final List<String> specialNotes;

  ProgramRequirements({
    this.totalMinCredits = 0,
    required this.externalCredits,
    this.nonCourseRequirements = const [],
    this.specialNotes = const [],
  });

  factory ProgramRequirements.fromJson(Map<String, dynamic> json) =>
      ProgramRequirements(
        totalMinCredits: json['total_min_credits'] ?? 0,
        externalCredits: ExternalCreditsRule.fromJson(
            json['external_credits'] ?? {}),
        nonCourseRequirements: json['non_course_requirements'] ?? [],
        specialNotes: (json['special_notes'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [],
      );
}

class ExternalCreditsRule {
  final int min;
  final bool excludeDoubleMajor;
  final bool excludeMinor;

  ExternalCreditsRule({
    this.min = 0,
    this.excludeDoubleMajor = true,
    this.excludeMinor = true,
  });

  factory ExternalCreditsRule.fromJson(Map<String, dynamic> json) =>
      ExternalCreditsRule(
        min: json['min'] is int ? json['min'] : 0,
        excludeDoubleMajor: json['exclude_double_major'] ?? true,
        excludeMinor: json['exclude_minor'] ?? true,
      );
}

class CourseGroup {
  final String id;
  final String label;
  final SelectionRule selectionRule;
  final CreditRequirement creditRequirement;
  final ExternalCreditsRule? externalCredits;
  final List<Subject> subjects;

  CourseGroup({
    required this.id,
    required this.label,
    required this.selectionRule,
    required this.creditRequirement,
    this.externalCredits,
    required this.subjects,
  });

  factory CourseGroup.fromJson(Map<String, dynamic> json) => CourseGroup(
        id: json['id'] ?? '',
        label: json['label'] ?? '',
        selectionRule:
            SelectionRule.fromJson(json['selection_rule'] ?? {}),
        creditRequirement: CreditRequirement.fromJson(
            json['credit_requirement'] ?? {}),
        externalCredits: json['external_credits'] != null
            ? ExternalCreditsRule.fromJson(
                json['external_credits'] as Map<String, dynamic>)
            : null,
        subjects: ((json['subjects'] ?? []) as List)
            .map((s) => Subject.fromJson(s as Map<String, dynamic>))
            .toList(),
      );
}

class SelectionRule {
  final String type;
  final int? pick;

  SelectionRule({required this.type, this.pick});

  factory SelectionRule.fromJson(Map<String, dynamic> json) => SelectionRule(
        type: json['type'] ?? 'min_credits',
        pick: json['pick'],
      );
}

class CreditRequirement {
  final int min;
  final List<RequiredTag>? requiredTags;

  CreditRequirement({this.min = 0, this.requiredTags});

  factory CreditRequirement.fromJson(Map<String, dynamic> json) {
    List<RequiredTag>? tags;
    if (json['required_tags'] != null) {
      tags = (json['required_tags'] as List<dynamic>)
          .map((t) =>
              RequiredTag.fromJson(t as Map<String, dynamic>))
          .toList();
    }
    return CreditRequirement(min: json['min'] ?? 0, requiredTags: tags);
  }
}

class RequiredTag {
  final String tag;
  final int minCredits;

  RequiredTag({required this.tag, required this.minCredits});

  factory RequiredTag.fromJson(Map<String, dynamic> json) => RequiredTag(
        tag: json['tag'] ?? '',
        minCredits: json['min_credits'] ?? 0,
      );
}

class Subject {
  final String programSubject;
  final List<Alternative> alternatives;
  final String? prerequisiteNote;
  final List<String> tags;
  final WaiverRule waiver;

  Subject({
    required this.programSubject,
    required this.alternatives,
    this.prerequisiteNote,
    this.tags = const [],
    required this.waiver,
  });

  factory Subject.fromJson(Map<String, dynamic> json) => Subject(
        programSubject: json['program_subject'] ?? '',
        alternatives: ((json['alternatives'] ?? []) as List)
            .map((a) => a is String
                ? Alternative(name: a)
                : Alternative.fromJson(a as Map<String, dynamic>))
            .toList(),
        prerequisiteNote: json['prerequisite_note']?.toString(),
        tags: ((json['tags'] ?? []) as List)
            .map((t) => t.toString())
            .toList(),
        waiver: WaiverRule.fromJson(json['waiver'] ?? {}),
      );
}

class Alternative {
  final String name;
  final List<String> departments;
  final dynamic credits;
  final String? note;

  Alternative({
    required this.name,
    this.departments = const [],
    this.credits,
    this.note,
  });

  double? get parsedCredits {
    if (credits is int) return (credits as int).toDouble();
    if (credits is double) return credits as double;
    final s = credits?.toString().trim() ?? '';
    if (s.isEmpty) return null;
    if (s.contains('-')) {
      final parts = s.split('-');
      return double.tryParse(parts.last);
    }
    return double.tryParse(s);
  }

  factory Alternative.fromJson(Map<String, dynamic> json) => Alternative(
        name: json['name'] ?? '',
        departments: ((json['departments'] ?? []) as List)
            .map((d) => d.toString())
            .toList(),
        credits: json['credits'],
        note: json['note']?.toString(),
      );
}

class WaiverRule {
  final bool allowed;
  final int? maxCredits;
  final String? note;
  final List<WaiverAlternative> waiverAlternatives;

  WaiverRule({
    this.allowed = false,
    this.maxCredits,
    this.note,
    this.waiverAlternatives = const [],
  });

  factory WaiverRule.fromJson(Map<String, dynamic> json) => WaiverRule(
        allowed: json['allowed'] ?? false,
        maxCredits: json['max_credits'] is int ? json['max_credits'] : null,
        note: json['note']?.toString(),
        waiverAlternatives: ((json['waiver_alternatives'] ?? []) as List)
            .map((w) =>
                WaiverAlternative.fromJson(w as Map<String, dynamic>))
            .toList(),
      );
}

class WaiverAlternative {
  final String condition;
  final int creditsGranted;
  final String? note;

  WaiverAlternative({
    required this.condition,
    this.creditsGranted = 0,
    this.note,
  });

  factory WaiverAlternative.fromJson(Map<String, dynamic> json) =>
      WaiverAlternative(
        condition: json['condition'] ?? '',
        creditsGranted: json['credits_granted'] is int
            ? json['credits_granted']
            : 0,
        note: json['note']?.toString(),
      );
}

// --- Eligibility result models ---

class CourseTakenInput {
  final String name;
  final String department;
  final String courseNo;
  final String semester;

  CourseTakenInput({
    required this.name,
    this.department = '',
    this.courseNo = '',
    this.semester = '',
  });
}

enum DeptValidationResult { valid, invalid, needsVerification }

enum VerificationStatus { unfilled, confirmed, rejected }

class CrossDeptVerification {
  final String courseName;
  final String department;
  final String courseNo;
  final String semester;
  final List<String> validDepts;
  final VerificationStatus status;

  CrossDeptVerification({
    required this.courseName,
    required this.department,
    this.courseNo = '',
    this.semester = '',
    this.validDepts = const [],
    this.status = VerificationStatus.unfilled,
  });

  CrossDeptVerification copyWith({VerificationStatus? status}) {
    return CrossDeptVerification(
      courseName: courseName,
      department: department,
      courseNo: courseNo,
      semester: semester,
      validDepts: validDepts,
      status: status ?? this.status,
    );
  }

  String get key => '${courseName}::${department}';
}

class CompletionRange {
  final double minRate;
  final double maxRate;

  CompletionRange({required this.minRate, required this.maxRate});

  bool get hasRange => (maxRate - minRate) > 0.001;
}

class SubjectResult {
  final String subject;
  final bool satisfied;
  final String? satisfiedBy;
  final String? satisfiedType;
  final int credits;
  final bool isOwnDept;
  final List<String> department;
  final List<WaiverOptionResult> waiverOptions;
  final List<String> tags;
  final List<String>? alternatives;
  final Map<String, List<String>>? alternativeDepartments;
  final Map<String, int>? alternativeCredits;
  final List<DepartmentMismatch>? departmentMismatches;
  final String? waiverNote;
  final bool isCrossDept;
  final DeptValidationResult deptValidationResult;
  final CrossDeptVerification? crossDeptVerification;
  final List<String> allMatchedCourses;

  SubjectResult({
    required this.subject,
    required this.satisfied,
    this.satisfiedBy,
    this.satisfiedType,
    this.credits = 0,
    this.isOwnDept = false,
    this.department = const [],
    this.waiverOptions = const [],
    this.tags = const [],
    this.alternatives,
    this.alternativeDepartments,
    this.alternativeCredits,
    this.departmentMismatches,
    this.waiverNote,
    this.isCrossDept = false,
    this.deptValidationResult = DeptValidationResult.valid,
    this.crossDeptVerification,
    this.allMatchedCourses = const [],
  });
}

class WaiverOptionResult {
  final String id;
  final String condition;
  final int creditsGranted;
  final String? note;

  WaiverOptionResult({
    required this.id,
    required this.condition,
    this.creditsGranted = 0,
    this.note,
  });
}

class DepartmentMismatch {
  final String name;
  final String takenDept;
  final List<String> validDepts;

  DepartmentMismatch({
    required this.name,
    required this.takenDept,
    required this.validDepts,
  });
}

class GroupResult {
  final String id;
  final String label;
  final SelectionRule selectionRule;
  final int creditsRequired;
  final int creditsEarned;
  final int externalCreditsEarned;
  final List<SubjectResult> subjectsTaken;
  final List<SubjectResult> subjectsMissing;
  final bool isMet;
  final Map<String, double> tagCreditsEarned;
  final ExternalCreditsRule? groupExternalCredits;

  GroupResult({
    required this.id,
    required this.label,
    required this.selectionRule,
    required this.creditsRequired,
    this.creditsEarned = 0,
    this.externalCreditsEarned = 0,
    this.subjectsTaken = const [],
    this.subjectsMissing = const [],
    this.isMet = false,
    this.tagCreditsEarned = const {},
    this.groupExternalCredits,
  });
}

class TagDetail {
  final String tag;
  final int earned;
  final int required;
  final bool met;

  TagDetail({
    required this.tag,
    required this.earned,
    required this.required,
    required this.met,
  });
}

class EligibilityResult {
  final String programName;
  final String programId;
  final int academicYear;
  final int? semester;
  final String studentDepartment;
  final List<String> doubleMajorDepts;
  final List<String> minorDepts;
  final List<String> ownDepartments;
  final List<GroupResult> groups;
  final int totalCreditsEarned;
  final int totalCreditsRequired;
  final int externalCreditsEarned;
  final int externalCreditsRequired;
  final Map<String, int> tagCredits;
  final bool eligible;
  final String summary;
  final List<String> unmetRequirements;
  final List<TagDetail> tagDetails;
  final String? error;
  final CompletionRange completionRange;
  final List<CrossDeptVerification> crossDeptVerifications;
  final List<String> specialNotes;

  EligibilityResult({
    required this.programName,
    required this.programId,
    required this.academicYear,
    this.semester,
    required this.studentDepartment,
    this.doubleMajorDepts = const [],
    this.minorDepts = const [],
    this.ownDepartments = const [],
    this.groups = const [],
    this.totalCreditsEarned = 0,
    this.totalCreditsRequired = 0,
    this.externalCreditsEarned = 0,
    this.externalCreditsRequired = 0,
    this.tagCredits = const {},
    this.eligible = false,
    this.summary = '',
    this.unmetRequirements = const [],
    this.tagDetails = const [],
    this.error,
    CompletionRange? completionRange,
    this.crossDeptVerifications = const [],
    this.specialNotes = const [],
  }) : completionRange = completionRange ?? CompletionRange(minRate: 0.0, maxRate: 0.0);
}

class AppliedProgram {
  final String programName;
  final String applicationSemester;
  final String? certificateSemester;
  final int appAcademicYear;
  final int appSemester;

  AppliedProgram({
    required this.programName,
    required this.applicationSemester,
    this.certificateSemester,
    required this.appAcademicYear,
    required this.appSemester,
  });

  factory AppliedProgram.fromJson(Map<String, dynamic> json) => AppliedProgram(
        programName: json['programName'] ?? '',
        applicationSemester: json['applicationSemester'] ?? '',
        certificateSemester: json['certificateSemester'],
        appAcademicYear: json['appAcademicYear'] ?? 0,
        appSemester: json['appSemester'] ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'programName': programName,
        'applicationSemester': applicationSemester,
        'certificateSemester': certificateSemester,
        'appAcademicYear': appAcademicYear,
        'appSemester': appSemester,
      };
}

class FavoriteProgram {
  final String programId;
  final int academicYear;

  FavoriteProgram({
    required this.programId,
    required this.academicYear,
  });

  factory FavoriteProgram.fromJson(Map<String, dynamic> json) => FavoriteProgram(
        programId: json['programId'] ?? '',
        academicYear: json['academicYear'] ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'programId': programId,
        'academicYear': academicYear,
      };
}