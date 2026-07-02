import '../models/program_model.dart';

class EligibilityChecker {
  static String normalize(String s) {
    final converted = String.fromCharCodes(
      s.runes.map((rune) {
        if (rune >= 0xFF01 && rune <= 0xFF5E) {
          return rune - 0xFEE0; // 全形英數字轉半形
        } else if (rune == 0x3000) {
          return 0x0020; // 全形空格轉半形空格
        }
        return rune;
      }),
    );
    return converted
        .toLowerCase() // 轉小寫
        .replaceAll('（', '(') // 全形左括號轉半形
        .replaceAll('）', ')') // 全形右括號轉半形
        .replaceAll(RegExp(r'\s+'), '') // 移除所有空白字元(包含空格、換行、Tab等)
        .trim(); // 去除前後空白(其實這行已經不需要了)
  }

  static bool nameMatches(String courseName, String targetName) {
    final a = normalize(courseName);
    final b = normalize(targetName);
    if (a == b) return true;

    // "全民國防教育" courses must match exactly — no fuzzy matching
    if (a.contains('全民國防教育') || b.contains('全民國防教育')) return false;

    // If both names are 10+ chars, check for 10-char common subsequence
    if (a.length >= 11 && b.length >= 11) {
      if (hasCommonSubsequence(a, b, 11)) return true;
      if (hasCommonSubsequence(b, a, 11)) return true;
    }

    return false;
  }

  // 檢查 source 中是否有長度為 minLen 的子序列存在於 target 中
  static bool hasCommonSubsequence(String source, String target, int minLen) {
    // 使用滑動窗口檢查 source 的每個連續 minLen 字元
    for (int i = 0; i <= source.length - minLen; i++) {
      final subseq = source.substring(i, i + minLen);
      if (isSubsequence(subseq, target)) return true;
    }
    // debugPrint("hasCommonSubsequence: $source, $target, $minLen");
    return false;
  }

  // 檢查 subseq 是否為 str 的子序列（順序相對位置正確）
  static bool isSubsequence(String subseq, String str) {
    int j = 0; // str 的指標
    for (int i = 0; i < subseq.length; i++) {
      // 在 str 中尋找 subseq[i]
      while (j < str.length && str[j] != subseq[i]) {
        j++;
      }
      // 如果找不到，表示不是子序列
      if (j >= str.length) return false;
      j++; // 移動到下一個位置
    }
    return true;
  }

  static int resolveCredits(dynamic creditsValue) {
    if (creditsValue is int) return creditsValue;
    if (creditsValue is double) return creditsValue.round();
    final s = creditsValue?.toString().trim() ?? '';
    if (s.isEmpty) return 3;
    if (s.contains('-')) {
      final parts = s.split('-');
      return int.tryParse(parts.last) ?? 3;
    }
    if (s.contains('依') || s.contains('規定')) return 3;
    final parsed = double.tryParse(s);
    if (parsed == null) return 3;
    return parsed.round();
  }

  static String makeWaiverId(String subject, String condition) {
    int hash = 0;
    final str = '$subject:$condition';
    for (int i = 0; i < str.length; i++) {
      hash = ((hash << 5) - hash) + str.codeUnitAt(i);
      hash = hash & 0xFFFFFFFF;
    }
    // padLeft 確保 hex 字串至少 8 位，不足時補 '0'
    final hex = hash.abs().toRadixString(16).padLeft(8, '0');
    return 'waiver_${hex.substring(0, 8)}';
  }

  static List<WaiverOptionResult> getWaiverOptions(Subject subject) {
    if (!subject.waiver.allowed) return [];
    return subject.waiver.waiverAlternatives
        .map(
          (wa) => WaiverOptionResult(
            id: makeWaiverId(subject.programSubject, wa.condition),
            condition: wa.condition,
            creditsGranted: wa.creditsGranted,
            note: wa.note,
          ),
        )
        .toList();
  }

  static String normalizeDept(String dept) {
    // 1. Basic character normalization
    var norm = normalize(dept).replaceAll(RegExp(r'\(.*?\)'), '');
    final stripped = norm.replaceAll(' ', '');
    if (stripped.contains('教育部ai聯盟博雅中心') || stripped.contains('ai聯盟')) {
      return 'ai聯盟';
    }

    // 2. Normalize English-taught programs / classes to corresponding '系'
    norm = norm
        .replaceAll('全英班', '系')
        .replaceAll('全英語班', '系')
        .replaceAll('英文專班', '系')
        .replaceAll('英文班', '系');

    // 3. Explicit mapping to preserve 系 and 所 distinction
    final Map<String, String> aliasMap = {
      // Short names without "系" mapping to canonical "系" names
      '政經': '政經系',
      '資工': '資工系',
      '電機': '電機系',
      '企管': '企管系',
      '資管': '資管系',
      '財管': '財管系',
      '光電': '光電系',
      '海工': '海工系',
      '應數': '應數系',
      '生科': '生科系',
      '海科': '海科系',
      '中文': '中文系',
      '外文': '外文系',
      '劇藝': '劇藝系',
      '公事': '公事系',
      '財金': '財金系',

      // 政治經濟 / 政經
      '政治經濟學系': '政經系',
      '政治經濟系': '政經系',
      '政經系': '政經系',
      '政治經濟研究所': '政經所',
      '政治經濟學系碩士班': '政經所',
      '政治經濟學系碩士在職專班': '政經所',
      '政經所': '政經所',

      // 資訊工程 / 資工
      '資訊工程學系': '資工系',
      '資訊工程系': '資工系',
      '資工系': '資工系',
      '資訊工程研究所': '資工所',
      '資訊工程學系碩士班': '資工所',
      '資訊工程學系碩士在職專班': '資工所',
      '資工所': '資工所',

      // 電機工程 / 電機
      '電機工程學系': '電機系',
      '電機工程系': '電機系',
      '電機系': '電機系',
      '電機工程研究所': '電機所',
      '電機工程學系碩士班': '電機所',
      '電機工程學系碩士在職專班': '電機所',
      '電機所': '電機所',

      // 企業管理 / 企管
      '企業管理學系': '企管系',
      '企業管理系': '企管系',
      '企管系': '企管系',
      '企業管理研究所': '企管所',
      '企業管理學系碩士班': '企管所',
      '企業管理學系碩士在職專班': '企管所',
      '企管所': '企管所',

      // 資訊管理 / 資管
      '資訊管理學系': '資管系',
      '資訊管理系': '資管系',
      '資管系': '資管系',
      '資訊管理研究所': '資管所',
      '資訊管理學系碩士班': '資管所',
      '資訊管理學系碩士在職專班': '資管所',
      '資管所': '資管所',

      // 財務管理 / 財管
      '財務管理學系': '財管系',
      '財務管理系': '財管系',
      '財管系': '財管系',
      '財務管理研究所': '財管所',
      '財務管理學系碩士班': '財管所',
      '財務管理學系碩士在職專班': '財管所',
      '財管所': '財管所',

      // 光電工程 / 光電
      '光電工程學系': '光電系',
      '光電工程系': '光電系',
      '光電系': '光電系',
      '光電工程研究所': '光電所',
      '光電工程學系碩士班': '光電所',
      '光電所': '光電所',

      // 海洋環境及工程 / 海工
      '海洋環境及工程學系': '海工系',
      '海洋環境及工程系': '海工系',
      '海工系': '海工系',
      '海洋環境及工程研究所': '海工所',
      '海洋環境及工程學系碩士班': '海工所',
      '海工所': '海工所',

      // 應用數學 / 應數
      '應用數學系': '應數系',
      '應數系': '應數系',
      '應用數學系碩士班': '應數所',
      '應數所': '應數所',

      // 生物科學 / 生科
      '生物科學系': '生科系',
      '生科系': '生科系',
      '生物科學系碩士班': '生科所',
      '生科所': '生科所',

      // 海洋科學 / 海科
      '海洋科學系': '海科系',
      '海科系': '海科系',
      '海洋科學系碩士班': '海科所',
      '海科所': '海科所',

      // 中國文學 / 中文
      '中國文學系': '中文系',
      '中文系': '中文系',
      '中國文學系碩士班': '中文所',
      '中文所': '中文所',

      // 外國語文學 / 外文
      '外國語文學系': '外文系',
      '外文系': '外文系',
      '外國語文學系碩士班': '外文所',
      '外文所': '外文所',

      // 劇場藝術 / 劇藝
      '劇場藝術學系': '劇藝系',
      '劇場藝術系': '劇藝系',
      '劇藝系': '劇藝系',
      '劇場藝術學系碩士班': '劇藝所',
      '劇藝所': '劇藝所',

      // 公共事務管理 / 公事
      '公共事務管理學系': '公事系',
      '公共事務管理研究所': '公事所',
      '公共事務管理學系碩士班': '公事所',
      '公事所': '公事所',

      // 財務金融 / 財金
      '財務金融學系': '財金系',
      '財務金融研究所': '財金所',
      '財務金融學系碩士班': '財金所',
      '財金所': '財金所',
    };

    if (aliasMap.containsKey(norm)) {
      return aliasMap[norm]!;
    }

    return norm;
  }

  static DeptValidationResult isDepartmentValid(
    String studentDept,
    List<String> alternativeDepts,
  ) {
    // Empty departments list → any department valid (各開課系所, 校內各系)
    if (alternativeDepts.isEmpty) return DeptValidationResult.valid;

    // Check if program rules have 跨院選修
    final programHasCrossDept = alternativeDepts.any((d) => d.contains('跨院選修'));

    // Check if student's department is 跨院選修
    final studentIsCrossDept =
        studentDept.isNotEmpty && studentDept.contains('跨院選修');

    if (programHasCrossDept) {
      if (studentIsCrossDept) {
        // Both have 跨院選修 → valid
        return DeptValidationResult.valid;
      } else if (studentDept.isEmpty) {
        // No student department info → lenient match
        return DeptValidationResult.valid;
      } else {
        // Program has 跨院選修 but student's department is not → invalid
        return DeptValidationResult.invalid;
      }
    }

    // Program does NOT have 跨院選修
    if (studentIsCrossDept) {
      // Student's dept is 跨院選修 but program doesn't allow it → needs verification
      return DeptValidationResult.needsVerification;
    }

    if (studentDept.isEmpty) return DeptValidationResult.valid;

    // Normal department matching
    final normStudent = normalizeDept(studentDept);
    final normAlts = alternativeDepts.map(normalizeDept).toList();

    if (normAlts.contains(normStudent)) return DeptValidationResult.valid;
    if (normStudent.contains('博雅') || normStudent.contains('通識教育')) {
      if (normAlts.any((d) => d.contains('博雅') || d.contains('通識教育'))) {
        return DeptValidationResult.valid;
      }
    }
    for (final d in normAlts) {
      if (normStudent == d) return DeptValidationResult.valid;
    }
    return DeptValidationResult.invalid;
  }

  static bool isCrossDept(String studentDept, List<String> alternativeDepts) {
    final result = isDepartmentValid(studentDept, alternativeDepts);
    if (result == DeptValidationResult.valid) {
      // Check if this valid match was via 跨院選修 rule
      final studentIsCrossDept =
          studentDept.isNotEmpty &&
          studentDept.contains('跨院選修') &&
          !(studentDept.contains('必修'));
      final programHasCrossDept = alternativeDepts.any(
        (d) => d.contains('跨院選修'),
      );
      if (studentIsCrossDept || programHasCrossDept) return true;
    }
    return false;
  }

  static SubjectResult checkSubject(
    Subject subject,
    Set<String> courseNames,
    Map<String, String> courseByNameDept,
    Map<String, String> courseByNameCourseNo,
    Map<String, String> courseByNameSemester,
    Set<String> ownDepts,
    Map<String, List<String>> waivers,
    Map<String, VerificationStatus> verificationStatuses, [
    Map<String, String>? courseByNameOriginalName,
  ]) {
    final programSubject = subject.programSubject;
    final departmentMismatches = <DepartmentMismatch>[];
    final crossDeptVerifications = <CrossDeptVerification>[];
    final allMatchedCourses = <String>[];

    _SubjectMatch? bestMatch;
    DeptValidationResult bestMatchDeptResult = DeptValidationResult.valid;
    bool bestMatchIsCrossDept = false;

    for (final alt in subject.alternatives) {
      final normalizedAltName = normalize(alt.name);
      String? matchedCourseName;
      if (courseNames.contains(normalizedAltName)) {
        matchedCourseName = normalizedAltName;
      } else {
        for (final name in courseNames) {
          if (nameMatches(name, alt.name)) {
            matchedCourseName = name;
            break;
          }
        }
      }

      if (matchedCourseName == null) continue;

      final credits = resolveCredits(alt.credits);
      final altDepts = alt.departments;
      final matchedDept = courseByNameDept[matchedCourseName] ?? '';
      final deptResult = isDepartmentValid(matchedDept, altDepts);
      final isCrossDeptMatch = isCrossDept(matchedDept, altDepts);

      if (deptResult == DeptValidationResult.invalid) {
        departmentMismatches.add(
          DepartmentMismatch(
            name: alt.name,
            takenDept: matchedDept,
            validDepts: altDepts,
          ),
        );
        continue;
      }

      if (deptResult == DeptValidationResult.needsVerification) {
        final courseNo = courseByNameCourseNo[matchedCourseName] ?? '';
        final semester = courseByNameSemester[matchedCourseName] ?? '';
        final vKey = '$matchedCourseName::$matchedDept';
        final status =
            verificationStatuses[vKey] ?? VerificationStatus.unfilled;
        crossDeptVerifications.add(
          CrossDeptVerification(
            courseName: matchedCourseName,
            department: matchedDept,
            courseNo: courseNo,
            semester: semester,
            validDepts: altDepts,
            status: status,
          ),
        );
        if (status != VerificationStatus.confirmed) continue;
      }

      bool isOwn;
      if (matchedDept.isNotEmpty) {
        isOwn = ownDepts.contains(matchedDept);
      } else {
        isOwn = altDepts.any((d) => ownDepts.contains(d));
      }

      // Add to matched list with formatted string: "XX系 - 課程名稱（外系或跨院選修）"
      final originalName =
          courseByNameOriginalName?[matchedCourseName] ?? alt.name;
      final tags = <String>[];
      if (!isOwn) tags.add('外系');
      if (isCrossDeptMatch) tags.add('跨院選修');
      final suffix = tags.isNotEmpty ? '（${tags.join('或')}）' : '';
      final deptPrefix = matchedDept.isNotEmpty ? '$matchedDept - ' : '';
      final formattedCourse = '$deptPrefix$originalName$suffix';

      if (!allMatchedCourses.contains(formattedCourse)) {
        allMatchedCourses.add(formattedCourse);
      }

      if (bestMatch == null || (bestMatch.isOwn && !isOwn)) {
        bestMatch = _SubjectMatch(
          alt: alt,
          credits: credits,
          isOwn: isOwn,
          isCrossDept: isCrossDeptMatch,
          altDepts: altDepts,
        );
        bestMatchDeptResult = deptResult;
        bestMatchIsCrossDept = isCrossDeptMatch;
      }
    }

    if (bestMatch != null) {
      CrossDeptVerification? crossDeptInfo;
      if (crossDeptVerifications.isNotEmpty) {
        crossDeptInfo = crossDeptVerifications.first;
      }
      return SubjectResult(
        subject: programSubject,
        satisfied: true,
        satisfiedBy: bestMatch.alt.name,
        satisfiedType: 'course',
        credits: bestMatch.credits,
        isOwnDept: bestMatch.isOwn,
        isCrossDept: bestMatchIsCrossDept,
        department: bestMatch.altDepts,
        waiverOptions: getWaiverOptions(subject),
        tags: subject.tags,
        deptValidationResult: bestMatchDeptResult,
        crossDeptVerification: crossDeptInfo,
        allMatchedCourses: allMatchedCourses,
      );
    }

    final subjectWaivers = waivers[programSubject] ?? [];
    if (subject.waiver.allowed && subjectWaivers.isNotEmpty) {
      for (final wa in subject.waiver.waiverAlternatives) {
        final waId = makeWaiverId(programSubject, wa.condition);
        if (subjectWaivers.contains(waId)) {
          return SubjectResult(
            subject: programSubject,
            satisfied: true,
            satisfiedBy: '抵免：${wa.condition}',
            satisfiedType: 'waiver',
            credits: wa.creditsGranted,
            isOwnDept: false,
            department: [],
            waiverNote: wa.note,
            waiverOptions: getWaiverOptions(subject),
            tags: subject.tags,
          );
        }
      }
    }

    // If no match but we have cross-dept verifications, include them in the missing result
    if (crossDeptVerifications.isNotEmpty) {
      return SubjectResult(
        subject: programSubject,
        satisfied: false,
        waiverOptions: getWaiverOptions(subject),
        tags: subject.tags,
        alternatives: subject.alternatives.map((a) => a.name).toList(),
        alternativeDepartments: Map.fromEntries(
          subject.alternatives.map((a) => MapEntry(a.name, a.departments)),
        ),
        alternativeCredits: Map.fromEntries(
          subject.alternatives.map(
            (a) => MapEntry(a.name, resolveCredits(a.credits)),
          ),
        ),
        departmentMismatches: departmentMismatches.isNotEmpty
            ? departmentMismatches
            : null,
        deptValidationResult: DeptValidationResult.needsVerification,
        crossDeptVerification: crossDeptVerifications.first,
      );
    }

    return SubjectResult(
      subject: programSubject,
      satisfied: false,
      waiverOptions: getWaiverOptions(subject),
      tags: subject.tags,
      alternatives: subject.alternatives.map((a) => a.name).toList(),
      alternativeDepartments: Map.fromEntries(
        subject.alternatives.map((a) => MapEntry(a.name, a.departments)),
      ),
      alternativeCredits: Map.fromEntries(
        subject.alternatives.map(
          (a) => MapEntry(a.name, resolveCredits(a.credits)),
        ),
      ),
      departmentMismatches: departmentMismatches.isNotEmpty
          ? departmentMismatches
          : null,
    );
  }

  static GroupResult checkGroup(
    CourseGroup group,
    Set<String> courseNames,
    Map<String, String> courseByNameDept,
    Map<String, String> courseByNameCourseNo,
    Map<String, String> courseByNameSemester,
    Set<String> ownDepts,
    Map<String, List<String>> waivers,
    Map<String, VerificationStatus> verificationStatuses, [
    Map<String, String>? courseByNameOriginalName,
  ]) {
    final rule = group.selectionRule;
    final minCredits = group.creditRequirement.min;

    int creditsEarned = 0;
    int externalCreditsEarned = 0;
    final subjectsTaken = <SubjectResult>[];
    final subjectsMissing = <SubjectResult>[];
    final tagCreditsEarned = <String, double>{};
    int subjectsSatisfied = 0;

    for (final subject in group.subjects) {
      final sr = checkSubject(
        subject,
        courseNames,
        courseByNameDept,
        courseByNameCourseNo,
        courseByNameSemester,
        ownDepts,
        waivers,
        verificationStatuses,
        courseByNameOriginalName,
      );
      if (sr.satisfied) {
        subjectsSatisfied++;
        creditsEarned += sr.credits;
        subjectsTaken.add(sr);
        if (!sr.isOwnDept) externalCreditsEarned += sr.credits;
        for (final tag in sr.tags) {
          tagCreditsEarned[tag] = (tagCreditsEarned[tag] ?? 0) + sr.credits;
        }
      } else {
        subjectsMissing.add(sr);
      }
    }

    bool isMet;
    if (rule.type == 'all') {
      isMet =
          subjectsSatisfied == group.subjects.length &&
          creditsEarned >= minCredits;
    } else if (rule.type == 'pick_n' && rule.pick != null) {
      isMet = subjectsSatisfied >= rule.pick! && creditsEarned >= minCredits;
    } else {
      isMet = creditsEarned >= minCredits;
    }

    // Convert tag credits map to int values
    final tagCreditsInt = <String, double>{};
    tagCreditsEarned.forEach((k, v) => tagCreditsInt[k] = v);

    return GroupResult(
      id: group.id,
      label: group.label,
      selectionRule: rule,
      creditsRequired: minCredits,
      creditsEarned: creditsEarned,
      externalCreditsEarned: externalCreditsEarned,
      subjectsTaken: subjectsTaken,
      subjectsMissing: subjectsMissing,
      isMet: isMet,
      tagCreditsEarned: tagCreditsInt,
      groupExternalCredits: group.externalCredits,
    );
  }

  static EligibilityResult checkEligibility(
    ProgramRule program,
    int academicYear,
    int? semester,
    String studentDept,
    List<CourseTakenInput> coursesTaken,
    Map<String, List<String>> waivers,
    List<String> doubleMajorDepts,
    List<String> minorDepts, [
    Map<String, VerificationStatus>? verificationStatuses,
    Set<String>? additionalOwnDepts,
  ]) {
    ProgramVersion? version;

    final matching = program.versions
        .where((v) => v.academicYear == academicYear)
        .toList();
    if (matching.isNotEmpty) {
      if (semester != null) {
        final exact = matching.where((v) => v.semester == semester).toList();
        if (exact.isNotEmpty) version = exact.first;
      }
      version ??= matching.reduce(
        (a, b) => (b.semester ?? 0) > (a.semester ?? 0) ? b : a,
      );
    } else {
      final candidates = program.versions
          .where((v) => v.academicYear <= academicYear)
          .toList();
      if (candidates.isNotEmpty) {
        candidates.sort((a, b) {
          if (b.academicYear != a.academicYear) {
            return b.academicYear.compareTo(a.academicYear);
          }
          return (b.semester ?? 0).compareTo(a.semester ?? 0);
        });
        version = candidates.first;
      }
    }

    if (version == null) {
      return EligibilityResult(
        programName: program.programName,
        programId: program.programId,
        academicYear: academicYear,
        studentDepartment: studentDept,
        error: 'No version found for year $academicYear',
      );
    }

    final externalReq = version.requirements.externalCredits;
    final ownDepts = <String>{studentDept};
    if (externalReq.excludeDoubleMajor) {
      ownDepts.addAll(doubleMajorDepts);
    }
    if (externalReq.excludeMinor) {
      ownDepts.addAll(minorDepts);
    }
    if (additionalOwnDepts != null) {
      ownDepts.addAll(additionalOwnDepts);
    }

    final courseByNameDept = <String, String>{};
    final courseByNameCourseNo = <String, String>{};
    final courseByNameSemester = <String, String>{};
    final courseByNameOriginalName = <String, String>{};
    final courseNames = <String>{};
    for (final c in coursesTaken) {
      final normalized = normalize(c.name);
      courseByNameDept[normalized] = c.department;
      courseByNameCourseNo[normalized] = c.courseNo;
      courseByNameSemester[normalized] = c.semester;
      courseByNameOriginalName[normalized] = c.name;
      courseNames.add(normalized);
    }

    final verStatuses = verificationStatuses ?? <String, VerificationStatus>{};

    final groups = <GroupResult>[];
    int totalCreditsEarned = 0;
    int totalExternalEarned = 0;
    final tagCredits = <String, int>{};
    final allCrossDeptVerifications = <CrossDeptVerification>[];

    for (final group in version.courseGroups) {
      final gr = checkGroup(
        group,
        courseNames,
        courseByNameDept,
        courseByNameCourseNo,
        courseByNameSemester,
        ownDepts,
        waivers,
        verStatuses,
        courseByNameOriginalName,
      );
      groups.add(gr);
      totalCreditsEarned += gr.creditsEarned;
      totalExternalEarned += gr.externalCreditsEarned;
      for (final entry in gr.tagCreditsEarned.entries) {
        tagCredits[entry.key] =
            (tagCredits[entry.key] ?? 0) + entry.value.toInt();
      }
      // Collect cross-dept verifications from all subjects
      for (final sr in [...gr.subjectsTaken, ...gr.subjectsMissing]) {
        if (sr.crossDeptVerification != null) {
          allCrossDeptVerifications.add(sr.crossDeptVerification!);
        }
      }
    }

    final requiredTags = <RequiredTag>[];
    for (final group in version.courseGroups) {
      final req = group.creditRequirement.requiredTags;
      if (req != null) requiredTags.addAll(req);
    }

    final tagDetails = <TagDetail>[];
    bool tagsMet = true;
    for (final req in requiredTags) {
      final earned = tagCredits[req.tag] ?? 0;
      final met = earned >= req.minCredits;
      if (!met) tagsMet = false;
      tagDetails.add(
        TagDetail(
          tag: req.tag,
          earned: earned,
          required: req.minCredits,
          met: met,
        ),
      );
    }

    final totalMet = totalCreditsEarned >= version.requirements.totalMinCredits;
    final externalMet =
        totalExternalEarned >= version.requirements.externalCredits.min;
    final allGroupsMet = groups.every((g) => g.isMet);
    final nonCourseMet = version.requirements.nonCourseRequirements.isEmpty;
    final eligible =
        totalMet && externalMet && allGroupsMet && nonCourseMet && tagsMet;

    // Compute completion range (min: without unverified cross-dept, max: with)
    final hasUnverified = allCrossDeptVerifications.any(
      (v) => v.status == VerificationStatus.unfilled,
    );
    CompletionRange completionRange;
    if (hasUnverified) {
      // Recompute without the unverified cross-dept courses for min rate
      // The current rate IS the min rate (unverified courses were excluded)
      final minRate = version.requirements.totalMinCredits > 0
          ? (totalCreditsEarned / version.requirements.totalMinCredits).clamp(
              0.0,
              1.0,
            )
          : 0.0;
      // Max rate: assume all unverified cross-dept courses count
      int maxCredits = totalCreditsEarned;
      for (final v in allCrossDeptVerifications) {
        if (v.status == VerificationStatus.unfilled) {
          // Find the subject that has this verification and add its credits
          for (final g in groups) {
            for (final s in g.subjectsMissing) {
              if (s.crossDeptVerification != null &&
                  s.crossDeptVerification!.key == v.key) {
                // Find alternative credits
                final altCredits = s.alternatives != null
                    ? _findAlternativeCredits(s, version)
                    : 0;
                maxCredits += altCredits;
              }
            }
          }
        }
      }
      final maxRate = version.requirements.totalMinCredits > 0
          ? (maxCredits / version.requirements.totalMinCredits).clamp(0.0, 1.0)
          : 0.0;
      completionRange = CompletionRange(minRate: minRate, maxRate: maxRate);
    } else {
      final rate = version.requirements.totalMinCredits > 0
          ? (totalCreditsEarned / version.requirements.totalMinCredits).clamp(
              0.0,
              1.0,
            )
          : 0.0;
      completionRange = CompletionRange(minRate: rate, maxRate: rate);
    }

    String summary;
    final unmet = <String>[];
    if (eligible) {
      summary = '✅ 符合「${program.programName}」證書資格！';
    } else {
      final parts = <String>[];
      if (!totalMet) {
        final deficit =
            version.requirements.totalMinCredits - totalCreditsEarned;
        parts.add(
          '總學分不足 $deficit 學分（已修 $totalCreditsEarned/${version.requirements.totalMinCredits}）',
        );
      }
      if (!externalMet) {
        final deficit =
            version.requirements.externalCredits.min - totalExternalEarned;
        parts.add(
          '外系學分不足 $deficit 學分（已修 $totalExternalEarned/${version.requirements.externalCredits.min}，不含本系${ownDepts.join('、')}）',
        );
      }
      if (!tagsMet) {
        for (final td in tagDetails) {
          if (!td.met) {
            parts.add('＊號選修不足 ${td.required} 學分（已修 ${td.earned} 學分）');
          }
        }
      }
      if (!allGroupsMet) {
        final unmetGroups = groups.where((g) => !g.isMet).map((g) => g.label);
        parts.add('未滿足：${unmetGroups.join('、')}');
      }
      summary = '❌ 尚未符合「${program.programName}」證書資格。${parts.join('；')}';
      unmet.addAll(parts);
    }

    return EligibilityResult(
      programName: program.programName,
      programId: program.programId,
      academicYear: version.academicYear,
      semester: version.semester,
      studentDepartment: studentDept,
      doubleMajorDepts: doubleMajorDepts,
      minorDepts: minorDepts,
      ownDepartments: ownDepts.toList()..sort(),
      groups: groups,
      totalCreditsEarned: totalCreditsEarned,
      totalCreditsRequired: version.requirements.totalMinCredits,
      externalCreditsEarned: totalExternalEarned,
      externalCreditsRequired: version.requirements.externalCredits.min,
      tagCredits: tagCredits,
      eligible: eligible,
      summary: summary,
      unmetRequirements: unmet,
      tagDetails: tagDetails,
      completionRange: completionRange,
      crossDeptVerifications: allCrossDeptVerifications,
      specialNotes: version.requirements.specialNotes,
    );
  }

  static int _findAlternativeCredits(SubjectResult s, ProgramVersion version) {
    // Try to find the credits for this subject's alternatives
    for (final group in version.courseGroups) {
      for (final subject in group.subjects) {
        if (subject.programSubject == s.subject) {
          if (subject.alternatives.isNotEmpty) {
            return resolveCredits(subject.alternatives.first.credits);
          }
        }
      }
    }
    return 3; // Default fallback
  }

  static Map<String, EligibilityResult> computeAll(ProgramComputationParams params) {
    final results = <String, EligibilityResult>{};
    for (final program in params.programs) {
      if (program.isDiscontinued) continue;
      if (program.versions.isEmpty) continue;

      final latestVersion = program.versions.reduce(
        (a, b) => b.academicYear > a.academicYear ? b : a,
      );

      final programVerifications = params.allProgramVerifications[program.programId];

      final result = checkEligibility(
        program,
        latestVersion.academicYear,
        null,
        params.studentDept,
        params.coursesTaken,
        params.waivers,
        params.doubleMajorDepts,
        params.minorDepts,
        programVerifications,
      );
      results[program.programId] = result;
    }
    return results;
  }
}

class ProgramComputationParams {
  final List<ProgramRule> programs;
  final String studentDept;
  final List<CourseTakenInput> coursesTaken;
  final Map<String, List<String>> waivers;
  final List<String> doubleMajorDepts;
  final List<String> minorDepts;
  final Map<String, Map<String, VerificationStatus>> allProgramVerifications;

  ProgramComputationParams({
    required this.programs,
    required this.studentDept,
    required this.coursesTaken,
    required this.waivers,
    required this.doubleMajorDepts,
    required this.minorDepts,
    required this.allProgramVerifications,
  });
}


class _SubjectMatch {
  final Alternative alt;
  final int credits;
  final bool isOwn;
  final bool isCrossDept;
  final List<String> altDepts;

  _SubjectMatch({
    required this.alt,
    required this.credits,
    required this.isOwn,
    required this.isCrossDept,
    required this.altDepts,
  });
}
