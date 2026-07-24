import 'dart:convert';
import 'dart:isolate';
import 'package:flutter/material.dart';
import '../models/program_model.dart';
import '../services/course_history_sync_service.dart';
import '../services/department_service.dart';
import '../services/eligibility_checker.dart';
import '../services/offline_error_handler.dart';
import '../services/offline_mode_service.dart';
import '../services/program_application_service.dart';
import '../services/program_link_service.dart';
import '../services/historical_score_service.dart';
import '../services/program_service.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import '../theme/layout_style_notifier.dart';
import '../widgets/glass/glass_page_scaffold.dart';
import '../widgets/glass/glass_card.dart';
import '../widgets/glass/glass_dialog.dart';
import '../widgets/course_progress_left_panel.dart';
import '../widgets/course_progress_profile_bar.dart';
import '../widgets/course_progress_right_panel.dart';
import 'package:url_launcher/url_launcher.dart';

class CourseProgressPage extends StatefulWidget {
  const CourseProgressPage({super.key});

  @override
  State<CourseProgressPage> createState() => _CourseProgressPageState();
}

class _CourseProgressPageState extends State<CourseProgressPage> {
  final _programService = ProgramService.instance;
  final _deptService = DepartmentService.instance;
  final _courseService = CourseHistorySyncService.instance;

  // Profile fields (committed values -- only updated on save)
  String _selectedDept = '';
  String _doubleMajor = '';
  String _minor = '';

  // Dirty state tracking
  bool _isDirty = false;

  // Left panel state
  LeftTab _currentTab = LeftTab.allPrograms;
  ProgramRule? _selectedProgram;
  int? _selectedYear;
  EligibilityResult? _selectedResult;

  // All programs completion data
  Map<String, EligibilityResult> _allProgramResults = {};
  bool _isComputingAll = false;
  bool _hasComputedAll = false;
  bool _isLoading = true;
  bool _isProfileExpanded = false;
  String? _loadError;

  // Waivers
  final Map<String, List<String>> _waivers = {};

  // Cross-dept verification statuses: key = "courseName::department"
  Map<String, VerificationStatus> _verificationStatuses = {};

  // Selected program/year for verification persistence
  String? _lastProgramId;
  int? _lastYear;

  // Favorites
  List<FavoriteProgram> _favoritePrograms = [];

  // PDF link for selected program
  String? _pdfLink;

  @override
  void initState() {
    super.initState();
    _loadData();
    _programService.programsNotifier.addListener(_onDataChanged);
    _programService.isLoadingNotifier.addListener(_onDataChanged);
    _deptService.departmentsNotifier.addListener(_onDataChanged);
    _courseService.resultsNotifier.addListener(_onDataChanged);
    _courseService.isLoadingNotifier.addListener(_onDataChanged);
  }

  @override
  void dispose() {
    _programService.programsNotifier.removeListener(_onDataChanged);
    _programService.isLoadingNotifier.removeListener(_onDataChanged);
    _deptService.departmentsNotifier.removeListener(_onDataChanged);
    _courseService.resultsNotifier.removeListener(_onDataChanged);
    _courseService.isLoadingNotifier.removeListener(_onDataChanged);
    super.dispose();
  }

  void _onDataChanged() {
    if (mounted) {
      setState(() {});
      if (_selectedDept.isNotEmpty &&
          _coursesTaken.isNotEmpty &&
          !_hasComputedAll &&
          !_isComputingAll) {
        _computeAllPrograms();
      }
    }
  }

  Future<void> _loadData() async {
    try {
      if (mounted) {
        setState(() {
          _isLoading = true;
          _loadError = null;
        });
      }

      // 1. 立即從本機快取讀取基本個人學科資料（小於幾毫秒），以利瞬間渲染最上方欄位，避免 UI 卡頓感受
      try {
        final savedDept = await StorageService.instance.read(
          'progress_selected_dept',
        );
        final savedDoubleMajor = await StorageService.instance.read(
          'progress_double_major',
        );
        final savedMinor = await StorageService.instance.read('progress_minor');
        if (mounted) {
          setState(() {
            _selectedDept = savedDept ?? '';
            _doubleMajor = savedDoubleMajor ?? '';
            _minor = savedMinor ?? '';
            _isProfileExpanded = _selectedDept.isEmpty;
          });
        }
      } catch (e) {
        debugPrint('Error loading initial profile info: $e');
      }

      // 2. 延遲載入以確保首頁 Bento 轉場動畫流暢播放完畢，避免阻塞 UI 線程
      await Future.delayed(const Duration(milliseconds: 400));

      await Future.wait([
        _programService.loadFromCache(),
        _deptService.loadFromCache(),
        _courseService.loadFromCache(),
        ProgramApplicationService.instance.loadFromCache(),
      ]);

      // 離線模式：跳過 network fetch，只用快取
      if (!OfflineModeService.instance.isOffline) {
        // 如果修課資料快取為空，或者與歷年成績快取有落差，則自動執行同步
        final bool needsSync = await _courseService.checkIfSyncNeeded();
        if (_courseService.resultsNotifier.value.isEmpty || needsSync) {
          _courseService.fetchCourseHistory();
        }
      }

      await _loadFavorites();

      final savedProgramId = await StorageService.instance.read(
        'progress_last_program_id',
      );
      final savedYearStr = await StorageService.instance.read(
        'progress_last_year',
      );
      final savedYear = savedYearStr != null
          ? int.tryParse(savedYearStr)
          : null;

      // 如果快取有資料，先結束 loading 讓使用者看到內容
      final hasCachedPrograms =
          _programService.programsNotifier.value.isNotEmpty;
      final hasCachedDepts = _deptService.departmentsNotifier.value.isNotEmpty;
      if (hasCachedPrograms && hasCachedDepts) {
        if (mounted) setState(() => _isLoading = false);
      }

      // 從網路取得最新資料（進入頁面且記憶體無資料時自動下載）
      if (!OfflineModeService.instance.isOffline) {
        try {
          if (!hasCachedPrograms) {
            await _programService.fetchPrograms();
          }
          if (!hasCachedDepts) {
            await _deptService.fetchDepartments();
          }
        } catch (e) {
          debugPrint('Network fetch error: $e');
        }
      }

      if (!mounted) return;

      // 檢查最終狀態：如果都沒有資料就是錯誤
      if (_programService.programsNotifier.value.isEmpty ||
          _deptService.departmentsNotifier.value.isEmpty) {
        setState(() {
          _isLoading = false;
          _loadError = OfflineModeService.instance.isOffline
              ? '離線模式不可用，請連接網路並重啟 App 以使用此功能'
              : '無法載入資料，請檢查網路連線後重試';
        });
        return;
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
          _loadError = null;
        });
        // 每次進入頁面載入完成後，自動跳出「關於學程進度」提示視窗
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _showInfoDialog(Theme.of(context).colorScheme);
          }
        });
      }

      if (savedProgramId != null && savedYear != null) {
        final programs = _programService.programsNotifier.value;
        final savedProgram = programs
            .where((p) => p.programId == savedProgramId)
            .toList();
        if (savedProgram.isNotEmpty) {
          final isWideScreen = MediaQuery.of(context).size.width >= 900;
          setState(() {
            _lastProgramId = savedProgramId;
            _lastYear = savedYear;
          });
          await _loadVerificationStatuses();

          if (isWideScreen && mounted && _selectedDept.isNotEmpty) {
            final prog = savedProgram.first;
            setState(() {
              _selectedProgram = prog;
              _selectedYear = savedYear;
            });
            ProgramLinkService.instance.getPdfLink(prog.programName).then((
              link,
            ) {
              if (mounted) {
                setState(() => _pdfLink = link);
              }
            });
            final result = await _isolateCheckEligibility(
              program: prog,
              year: savedYear,
              semester: null,
              studentDept: _selectedDept,
              coursesTaken: _coursesTaken,
              waivers: _waivers,
              doubleMajorDepts: _doubleMajorDepts,
              minorDepts: _minorDepts,
              verificationStatuses: _verificationStatuses,
            );
            if (mounted) {
              setState(() {
                _selectedResult = result;
              });
            }
          }
        }
      }

      if (mounted && _selectedDept.isNotEmpty && _coursesTaken.isNotEmpty) {
        await _computeAllPrograms();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        if (e is OfflineDisabledException) {
          await OfflineErrorHandler.show(context, e);
        } else {
          rethrow;
        }
      } else {
        rethrow;
      }
    }
  }

  Future<void> _saveProfile(
    String dept,
    String doubleMajor,
    String minor,
  ) async {
    await StorageService.instance.save('progress_selected_dept', dept);
    await StorageService.instance.save('progress_double_major', doubleMajor);
    await StorageService.instance.save('progress_minor', minor);

    if (mounted) {
      setState(() {
        _selectedDept = dept;
        _doubleMajor = doubleMajor;
        _minor = minor;
        _isDirty = false;
        _hasComputedAll = false;
        _allProgramResults = {};
        _selectedResult = null;
      });
      _computeAllPrograms();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已儲存'), duration: Duration(seconds: 1)),
      );
    }
  }

  void _markDirty() {
    if (!_isDirty) {
      setState(() => _isDirty = true);
    }
  }

  Future<void> _loadFavorites() async {
    try {
      final jsonStr = await StorageService.instance.read(
        'progress_favorite_programs',
      );
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final decoded = jsonDecode(jsonStr) as List<dynamic>;
        setState(() {
          _favoritePrograms = decoded
              .map((e) => FavoriteProgram.fromJson(e as Map<String, dynamic>))
              .toList();
        });
      }
    } catch (e) {
      debugPrint('Error loading favorites: $e');
    }
  }

  Future<void> _toggleFavorite() async {
    if (_selectedProgram == null || _selectedYear == null) return;

    final existingIndex = _favoritePrograms.indexWhere(
      (f) =>
          f.programId == _selectedProgram!.programId &&
          f.academicYear == _selectedYear!,
    );

    setState(() {
      if (existingIndex >= 0) {
        _favoritePrograms.removeAt(existingIndex);
      } else {
        _favoritePrograms.add(
          FavoriteProgram(
            programId: _selectedProgram!.programId,
            academicYear: _selectedYear!,
          ),
        );
      }
    });

    try {
      final encoded = jsonEncode(
        _favoritePrograms.map((e) => e.toJson()).toList(),
      );
      await StorageService.instance.save('progress_favorite_programs', encoded);
    } catch (e) {
      debugPrint('Error saving favorites: $e');
    }
  }

  bool get _isCurrentFavorite {
    if (_selectedProgram == null || _selectedYear == null) return false;
    return _favoritePrograms.any(
      (f) =>
          f.programId == _selectedProgram!.programId &&
          f.academicYear == _selectedYear,
    );
  }

  Future<void> _removeFavorite(FavoriteProgram fav) async {
    setState(() {
      _favoritePrograms.removeWhere(
        (f) =>
            f.programId == fav.programId && f.academicYear == fav.academicYear,
      );
    });
    try {
      final encoded = jsonEncode(
        _favoritePrograms.map((e) => e.toJson()).toList(),
      );
      await StorageService.instance.save('progress_favorite_programs', encoded);
    } catch (e) {
      debugPrint('Error saving favorites: $e');
    }
  }

  List<CourseTakenInput> get _coursesTaken => _courseService
      .resultsNotifier
      .value
      .where((r) => r.passed)
      .map(
        (r) => CourseTakenInput(
          name: r.courseName,
          department: r.department,
          courseNo: r.courseNo,
          semester: r.semester,
        ),
      )
      .toList();

  List<String> get _doubleMajorDepts => _doubleMajor.isEmpty
      ? []
      : _doubleMajor
            .split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList();

  Future<void> _loadVerificationStatuses() async {
    if (_lastProgramId == null || _lastYear == null) return;
    final key = 'progress_verifications_${_lastProgramId}_${_lastYear}';
    final jsonStr = await StorageService.instance.read(key);

    if (!mounted) return;

    if (jsonStr != null && jsonStr.isNotEmpty) {
      try {
        final decoded = jsonDecode(jsonStr) as Map<String, dynamic>;
        setState(() {
          _verificationStatuses = decoded.map(
            (k, v) => MapEntry(
              k,
              VerificationStatus.values.firstWhere(
                (e) => e.name == v,
                orElse: () => VerificationStatus.unfilled,
              ),
            ),
          );
        });
      } catch (_) {
        setState(() => _verificationStatuses = {});
      }
    } else {
      setState(() => _verificationStatuses = {});
    }
  }

  Future<void> _saveVerificationStatuses() async {
    if (_lastProgramId == null || _lastYear == null) return;
    final key = 'progress_verifications_${_lastProgramId}_${_lastYear}';
    final encoded = jsonEncode(
      _verificationStatuses.map((k, v) => MapEntry(k, v.name)),
    );
    await StorageService.instance.save(key, encoded);
  }

  void _updateVerificationStatus(String vKey, VerificationStatus status) async {
    setState(() {
      _verificationStatuses[vKey] = status;
    });
    _saveVerificationStatuses();

    if (_selectedProgram != null && _selectedYear != null) {
      final result = await _isolateCheckEligibility(
        program: _selectedProgram!,
        year: _selectedYear!,
        semester: null,
        studentDept: _selectedDept,
        coursesTaken: _coursesTaken,
        waivers: _waivers,
        doubleMajorDepts: _doubleMajorDepts,
        minorDepts: _minorDepts,
        verificationStatuses: _verificationStatuses,
      );
      if (mounted) {
        setState(() {
          _selectedResult = result;
          _allProgramResults[_selectedProgram!.programId] = result;
        });
      }
    }

    _computeAllPrograms();
  }

  void _updateWaiver(String subject, String waiverId, bool checked) async {
    setState(() {
      if (checked) {
        _waivers.putIfAbsent(subject, () => []);
        if (!_waivers[subject]!.contains(waiverId)) {
          _waivers[subject]!.add(waiverId);
        }
      } else {
        _waivers[subject]?.remove(waiverId);
        if (_waivers[subject]?.isEmpty ?? false) {
          _waivers.remove(subject);
        }
      }
    });

    if (_selectedProgram != null && _selectedYear != null) {
      final result = await _isolateCheckEligibility(
        program: _selectedProgram!,
        year: _selectedYear!,
        semester: null,
        studentDept: _selectedDept,
        coursesTaken: _coursesTaken,
        waivers: _waivers,
        doubleMajorDepts: _doubleMajorDepts,
        minorDepts: _minorDepts,
        verificationStatuses: _verificationStatuses,
      );
      if (mounted) {
        setState(() {
          _selectedResult = result;
          _allProgramResults[_selectedProgram!.programId] = result;
        });
      }
    }

    _computeAllPrograms();
  }

  static Future<Map<String, EligibilityResult>> _isolateComputeAll(
    ProgramComputationParams params,
  ) {
    return Isolate.run(() => EligibilityChecker.computeAll(params));
  }

  static Future<EligibilityResult> _isolateCheckEligibility({
    required ProgramRule program,
    required int year,
    required int? semester,
    required String studentDept,
    required List<CourseTakenInput> coursesTaken,
    required Map<String, List<String>> waivers,
    required List<String> doubleMajorDepts,
    required List<String> minorDepts,
    required Map<String, VerificationStatus>? verificationStatuses,
  }) {
    return Isolate.run(
      () => EligibilityChecker.checkEligibility(
        program,
        year,
        semester,
        studentDept,
        coursesTaken,
        waivers,
        doubleMajorDepts,
        minorDepts,
        verificationStatuses,
      ),
    );
  }

  List<String> get _minorDepts => _minor.isEmpty
      ? []
      : _minor
            .split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList();

  Future<void> _computeAllPrograms() async {
    if (_selectedDept.isEmpty || _coursesTaken.isEmpty) return;
    if (_isComputingAll) return;
    setState(() => _isComputingAll = true);

    try {
      final programs = _programService.programsNotifier.value;

      // 1. Parallelize loading verification statuses from cache
      final verificationFutures = programs.map((program) async {
        if (program.isDiscontinued || program.versions.isEmpty) {
          return MapEntry(program.programId, <String, VerificationStatus>{});
        }
        final latestVersion = program.versions.reduce(
          (a, b) => b.academicYear > a.academicYear ? b : a,
        );
        final vKey =
            'progress_verifications_${program.programId}_${latestVersion.academicYear}';
        try {
          final jsonStr = await StorageService.instance.read(vKey);
          if (jsonStr != null && jsonStr.isNotEmpty) {
            final decoded = jsonDecode(jsonStr) as Map<String, dynamic>;
            final programVerifications = decoded.map(
              (k, v) => MapEntry(
                k,
                VerificationStatus.values.firstWhere(
                  (e) => e.name == v,
                  orElse: () => VerificationStatus.unfilled,
                ),
              ),
            );
            return MapEntry(program.programId, programVerifications);
          }
        } catch (_) {}
        return MapEntry(program.programId, <String, VerificationStatus>{});
      }).toList();

      final verificationList = await Future.wait(verificationFutures);
      final allProgramVerifications = Map.fromEntries(verificationList);

      // 2. Package calculation parameters
      final params = ProgramComputationParams(
        programs: programs,
        studentDept: _selectedDept,
        coursesTaken: _coursesTaken,
        waivers: _waivers,
        doubleMajorDepts: _doubleMajorDepts,
        minorDepts: _minorDepts,
        allProgramVerifications: allProgramVerifications,
      );

      // 3. Delegate heavy calculation to a background Isolate
      final results = await _isolateComputeAll(params);

      if (mounted) {
        setState(() {
          _allProgramResults = results;
          _hasComputedAll = true;
        });
      }
    } finally {
      if (mounted) setState(() => _isComputingAll = false);
    }
  }

  Future<void> _checkProgram(ProgramRule program, int year) async {
    if (_selectedDept.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('請先填寫你的科系並儲存'),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    setState(() {
      _selectedProgram = program;
      _selectedYear = year;
      _lastProgramId = program.programId;
      _lastYear = year;
      _selectedResult = null;
      _pdfLink = null;
    });

    ProgramLinkService.instance.getPdfLink(program.programName).then((link) {
      if (mounted) {
        setState(() => _pdfLink = link);
      }
    });

    await StorageService.instance.save(
      'progress_last_program_id',
      program.programId,
    );
    await StorageService.instance.save('progress_last_year', year.toString());

    await _loadVerificationStatuses();

    if (!mounted) return;
    final result = await _isolateCheckEligibility(
      program: program,
      year: year,
      semester: null,
      studentDept: _selectedDept,
      coursesTaken: _coursesTaken,
      waivers: _waivers,
      doubleMajorDepts: _doubleMajorDepts,
      minorDepts: _minorDepts,
      verificationStatuses: _verificationStatuses,
    );

    if (mounted) {
      setState(() {
        _selectedResult = result;
      });
    }

    final isWideScreen = MediaQuery.of(context).size.width >= 900;
    if (isWideScreen) {
      return;
    }

    // On mobile, navigate to detail page
    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CourseProgressDetailPage(
            result: result,
            program: program,
            isFavorite: _isCurrentFavorite,
            onFavoriteToggle: _toggleFavorite,
            waivers: _waivers,
            onWaiverChanged: _updateWaiver,
            verificationStatuses: _verificationStatuses,
            onVerificationChanged: _updateVerificationStatus,
            pdfLink: _pdfLink,
            selectedDept: _selectedDept,
            coursesTaken: _coursesTaken,
            doubleMajorDepts: _doubleMajorDepts,
            minorDepts: _minorDepts,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final programs = _programService.programsNotifier.value;
    final departments = _deptService.departmentsNotifier.value;
    final isDisabled = _selectedDept.isEmpty;
    final isWideScreen = MediaQuery.of(context).size.width >= 900;

    final mainContent = _isLoading
        ? _buildSkeletonLoading(colorScheme)
        : _loadError != null
        ? _buildErrorState(colorScheme)
        : _coursesTaken.isEmpty
        ? _buildManualSyncCard(colorScheme)
        : IgnorePointer(
            ignoring: isDisabled,
            child: Opacity(
              opacity: isDisabled ? 0.4 : 1.0,
              child: isWideScreen
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 360,
                          child: CourseProgressLeftPanel(
                            currentTab: _currentTab,
                            onTabChanged: (tab) =>
                                setState(() => _currentTab = tab),
                            isComputingAll: _isComputingAll,
                            isLoading: _isLoading,
                            isCourseDataLoading:
                                _courseService.isLoadingNotifier.value,
                            selectedDept: _selectedDept,
                            programs: programs,
                            departments: departments,
                            allProgramResults: _allProgramResults,
                            selectedProgramId: _selectedProgram?.programId,
                            onProgramSelected: _checkProgram,
                            isDisabled: isDisabled,
                            favoritePrograms: _favoritePrograms,
                            verificationStatuses: _verificationStatuses,
                            onRemoveFavorite: _removeFavorite,
                            shrinkWrap: false,
                          ),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: CourseProgressRightPanel(
                            result: _selectedResult,
                            program: _selectedProgram,
                            isFavorite: _isCurrentFavorite,
                            onFavoriteToggle: _toggleFavorite,
                            waivers: _waivers,
                            onWaiverChanged: _updateWaiver,
                            verificationStatuses: _verificationStatuses,
                            onVerificationChanged: _updateVerificationStatus,
                            pdfLink: _pdfLink,
                          ),
                        ),
                      ],
                    )
                  : CourseProgressLeftPanel(
                      currentTab: _currentTab,
                      onTabChanged: (tab) => setState(() => _currentTab = tab),
                      isComputingAll: _isComputingAll,
                      isLoading: _isLoading,
                      isCourseDataLoading:
                          _courseService.isLoadingNotifier.value,
                      selectedDept: _selectedDept,
                      programs: programs,
                      departments: departments,
                      allProgramResults: _allProgramResults,
                      selectedProgramId: _selectedProgram?.programId,
                      onProgramSelected: _checkProgram,
                      isDisabled: isDisabled,
                      favoritePrograms: _favoritePrograms,
                      verificationStatuses: _verificationStatuses,
                      onRemoveFavorite: _removeFavorite,
                      shrinkWrap: true,
                    ),
            ),
          );

    final showProfileAndCoursesRow = isWideScreen && !_isProfileExpanded;

    final bodyChildren = [
      if (showProfileAndCoursesRow)
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: CourseProgressProfileBar(
                departments: departments,
                savedDept: _selectedDept,
                savedDoubleMajor: _doubleMajor,
                savedMinor: _minor,
                isDirty: _isDirty,
                onFieldChanged: _markDirty,
                onSave: _saveProfile,
                onExpansionChanged: (expanded) {
                  setState(() {
                    _isProfileExpanded = expanded;
                  });
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: _buildPassedCoursesTile(colorScheme)),
          ],
        )
      else ...[
        CourseProgressProfileBar(
          departments: departments,
          savedDept: _selectedDept,
          savedDoubleMajor: _doubleMajor,
          savedMinor: _minor,
          isDirty: _isDirty,
          onFieldChanged: _markDirty,
          onSave: _saveProfile,
          onExpansionChanged: (expanded) {
            setState(() {
              _isProfileExpanded = expanded;
            });
          },
        ),
        const SizedBox(height: 12),
        _buildPassedCoursesTile(colorScheme),
      ],
      const SizedBox(height: 12),
      isWideScreen ? Expanded(child: mainContent) : mainContent,
      if (!isWideScreen && LayoutStyleNotifier.instance.isLiquidGlass)
        const SizedBox(height: 100),
    ];

    return GlassPageScaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: const Text('學程進度'),
        actions: [_buildInfoButton(colorScheme), const SizedBox(width: 12)],
      ),
      body: isWideScreen
          ? Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Column(children: bodyChildren),
            )
          : SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                child: Column(children: bodyChildren),
              ),
            ),
    );
  }

  Widget _buildPassedCoursesTile(ColorScheme colorScheme) {
    return ValueListenableBuilder<List<CourseHistoryResult>>(
      valueListenable: _courseService.resultsNotifier,
      builder: (context, results, _) {
        final coursesCount = results.length;
        return GestureDetector(
          onTap: _showPassedCoursesBottomSheet,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration:
                glassCardDecoration(context, borderRadius: 12) ??
                BoxDecoration(
                  color: colorScheme.cardBackground,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: colorScheme.borderColor),
                ),
            child: Row(
              children: [
                Icon(
                  Icons.assignment_turned_in_rounded,
                  size: 16,
                  color: colorScheme.accentBlue,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '已修課程 (${coursesCount} 門)',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: colorScheme.primaryText,
                    ),
                  ),
                ),
                Text(
                  '查看與同步',
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.subtitleText,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.keyboard_arrow_right_rounded,
                  size: 18,
                  color: colorScheme.subtitleText,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showPassedCoursesBottomSheet() {
    final colorScheme = Theme.of(context).colorScheme;
    final searchQueryNotifier = ValueNotifier<String>('');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.85,
          decoration: LayoutStyleNotifier.instance.isLiquidGlass
              ? BoxDecoration(
                  color: colorScheme.isDark
                      ? Colors.black.withValues(alpha: 0.92)
                      : Colors.white.withValues(alpha: 0.92),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(20),
                  ),
                  border: Border.all(
                    color: colorScheme.isDark
                        ? Colors.white.withValues(alpha: 0.2)
                        : Colors.black.withValues(alpha: 0.12),
                    width: 1.0,
                  ),
                )
              : BoxDecoration(
                  color: colorScheme.cardBackground,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(20),
                  ),
                ),
          child: Column(
            children: [
              // Handle bar
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colorScheme.borderColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '已修課程',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.primaryText,
                      ),
                    ),
                    Row(
                      children: [
                        ValueListenableBuilder<bool>(
                          valueListenable: _courseService.isLoadingNotifier,
                          builder: (context, isLoading, _) {
                            return isLoading
                                ? SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: colorScheme.accentBlue,
                                    ),
                                  )
                                : IconButton(
                                    icon: Icon(
                                      Icons.refresh_rounded,
                                      color: colorScheme.accentBlue,
                                    ),
                                    onPressed: _startManualSync,
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  );
                          },
                        ),
                        const SizedBox(width: 16),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.pop(context),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          color: colorScheme.subtitleText,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // Sync status loading message
              ValueListenableBuilder<bool>(
                valueListenable: _courseService.isLoadingNotifier,
                builder: (context, isLoading, _) {
                  if (!isLoading) return const SizedBox.shrink();
                  return ValueListenableBuilder<String>(
                    valueListenable: _courseService.statusMessageNotifier,
                    builder: (context, statusMsg, _) {
                      return Container(
                        width: double.infinity,
                        color: colorScheme.accentBlue.withValues(alpha: 0.1),
                        padding: const EdgeInsets.symmetric(
                          vertical: 8,
                          horizontal: 20,
                        ),
                        child: Text(
                          statusMsg.isNotEmpty ? statusMsg : "正在載入選課資料...",
                          style: TextStyle(
                            fontSize: 13,
                            color: colorScheme.accentBlue,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      );
                    },
                  );
                },
              ),
              // List
              Expanded(
                child: ValueListenableBuilder<List<CourseHistoryResult>>(
                  valueListenable: _courseService.resultsNotifier,
                  builder: (context, allHistory, _) {
                    return ValueListenableBuilder<String>(
                      valueListenable: searchQueryNotifier,
                      builder: (context, query, _) {
                        // Filter
                        final filtered = allHistory.where((c) {
                          if (query.isEmpty) return true;
                          final q = query.toLowerCase();
                          return c.courseName.toLowerCase().contains(q) ||
                              c.courseNo.toLowerCase().contains(q) ||
                              c.department.toLowerCase().contains(q);
                        }).toList();

                        if (allHistory.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.assignment_late_outlined,
                                  size: 48,
                                  color: colorScheme.subtitleText.withValues(
                                    alpha: 0.5,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  '尚無已修課程資料',
                                  style: TextStyle(
                                    fontSize: 15,
                                    color: colorScheme.subtitleText,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                ValueListenableBuilder<bool>(
                                  valueListenable:
                                      _courseService.isLoadingNotifier,
                                  builder: (context, isLoading, _) {
                                    if (isLoading)
                                      return const SizedBox.shrink();
                                    return ElevatedButton.icon(
                                      onPressed: _startManualSync,
                                      icon: const Icon(Icons.sync_rounded),
                                      label: const Text('立即同步'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: colorScheme.accentBlue,
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          );
                        }

                        if (filtered.isEmpty) {
                          return Center(
                            child: Text(
                              '找不到符合的課程',
                              style: TextStyle(
                                fontSize: 15,
                                color: colorScheme.subtitleText,
                              ),
                            ),
                          );
                        }

                        // Group by semester, sorted descending
                        final Map<String, List<CourseHistoryResult>> grouped =
                            {};
                        for (var c in filtered) {
                          grouped.putIfAbsent(c.semester, () => []).add(c);
                        }
                        final sortedSemesters = grouped.keys.toList()
                          ..sort((a, b) => b.compareTo(a));

                        return ListView.builder(
                          padding: EdgeInsets.only(
                            bottom: LayoutStyleNotifier.instance.isLiquidGlass
                                ? 100
                                : 24,
                          ),
                          itemCount: sortedSemesters.length,
                          itemBuilder: (context, index) {
                            final sem = sortedSemesters[index];
                            final courses = grouped[sem] ?? [];
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Semester Header
                                Container(
                                  width: double.infinity,
                                  color:
                                      LayoutStyleNotifier.instance.isLiquidGlass
                                      ? (colorScheme.isDark
                                            ? Colors.white.withValues(
                                                alpha: 0.08,
                                              )
                                            : Colors.black.withValues(
                                                alpha: 0.04,
                                              ))
                                      : colorScheme.secondaryCardBackground,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 8,
                                  ),
                                  child: Text(
                                    sem,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: colorScheme.primaryText,
                                    ),
                                  ),
                                ),
                                // Courses
                                ...courses.map((c) {
                                  return Container(
                                    decoration: BoxDecoration(
                                      border: Border(
                                        bottom: BorderSide(
                                          color: colorScheme.borderColor,
                                          width: 0.5,
                                        ),
                                      ),
                                    ),
                                    child: ListTile(
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 20,
                                            vertical: 4,
                                          ),
                                      title: Text(
                                        c.courseName,
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                          color: colorScheme.primaryText,
                                        ),
                                      ),
                                      subtitle: Text(
                                        '${c.courseNo} • ${c.credits} 學分 • ${c.department}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: colorScheme.subtitleText,
                                        ),
                                      ),
                                      trailing: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            c.score,
                                            style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.bold,
                                              color: c.passed
                                                  ? (colorScheme.isDark
                                                        ? Colors.greenAccent
                                                        : Colors.green.shade700)
                                                  : Colors.redAccent,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: c.passed
                                                  ? colorScheme.successContainer
                                                  : (colorScheme.isDark
                                                        ? Colors.red.withValues(
                                                            alpha: 0.2,
                                                          )
                                                        : Colors.red.shade50),
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              c.passed ? '已通過' : '未通過',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: c.passed
                                                    ? (colorScheme.isDark
                                                          ? Colors.greenAccent
                                                          : Colors
                                                                .green
                                                                .shade800)
                                                    : Colors.red,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }),
                              ],
                            );
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildManualSyncCard(ColorScheme colorScheme) {
    return Center(
      child: SingleChildScrollView(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          padding: const EdgeInsets.all(24),
          decoration:
              glassCardDecoration(context, borderRadius: 20) ??
              BoxDecoration(
                color: colorScheme.cardBackground,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: colorScheme.borderColor, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
          child: ValueListenableBuilder<bool>(
            valueListenable: _courseService.isLoadingNotifier,
            builder: (context, isLoading, _) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: colorScheme.accentBlue.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isLoading ? Icons.sync : Icons.cloud_download_outlined,
                      size: 48,
                      color: colorScheme.accentBlue,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    isLoading ? "正在同步已修課程..." : "同步已修課程資料",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.primaryText,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      isLoading
                          ? "正在與學校選課系統連線，這可能需要幾十秒鐘，請不要關閉此畫面..."
                          : "在分析您的學程進度前，系統需要讀取您的已修課程資料。請點擊下方按鈕進行同步。",
                      style: TextStyle(
                        fontSize: 14,
                        color: colorScheme.subtitleText,
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (isLoading) ...[
                    ValueListenableBuilder<String>(
                      valueListenable: _courseService.statusMessageNotifier,
                      builder: (context, statusMsg, _) {
                        return Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  color: colorScheme.accentBlue,
                                  backgroundColor: colorScheme.borderColor,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              statusMsg.isNotEmpty ? statusMsg : "準備中...",
                              style: TextStyle(
                                fontSize: 13,
                                color: colorScheme.accentBlue,
                                fontWeight: FontWeight.w500,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        );
                      },
                    ),
                  ] else ...[
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _startManualSync,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colorScheme.accentBlue,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text(
                          '立即同步已修課程',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _startManualSync() async {
    // 離線模式：跳對話框，不觸發任何 fetch
    if (await OfflineErrorHandler.handleRefresh(context)) return;

    try {
      // 先執行完整更新，重新下載歷年所有學期成績
      await HistoricalScoreService.instance.fetchAllData(
        forceFullRefresh: true,
      );
      // 再根據最新成績快取同步已修課程
      await _courseService.fetchCourseHistory();
      if (_coursesTaken.isEmpty) {
        _showErrorSnackBar("同步失敗，或未找到您的已修課程。請確認登入狀態，或稍後再試！");
      } else {
        _showSuccessSnackBar("同步成功！已載入 ${_coursesTaken.length} 門已修課程。");
        _loadData();
      }
    } catch (e) {
      if (e is OfflineDisabledException) {
        // 防禦：gate 已擋住，但若有人改動仍接住
        if (mounted) await OfflineErrorHandler.show(context, e);
      } else {
        _showErrorSnackBar("同步發生異常，請確認連線或稍後再試！");
      }
    }
  }

  void _showSuccessSnackBar(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showErrorSnackBar(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // Error / no-network state
  // ─────────────────────────────────────────────
  Widget _buildErrorState(ColorScheme colorScheme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.wifi_off_rounded,
              size: 64,
              color: colorScheme.subtitleText.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 20),
            Text(
              _loadError ?? '無法載入資料',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: colorScheme.primaryText,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              '請確認網路連線狀態後再試一次',
              style: TextStyle(fontSize: 13, color: colorScheme.subtitleText),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: 160,
              height: 44,
              child: ElevatedButton.icon(
                onPressed: _loadData,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text(
                  '重新載入',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.accentBlue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // Loading state
  // ─────────────────────────────────────────────
  Widget _buildSkeletonLoading(ColorScheme colorScheme) {
    final isLiquidGlass = LayoutStyleNotifier.instance.isLiquidGlass;
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircularProgressIndicator(color: colorScheme.accentBlue),
        const SizedBox(height: 16),
        Text(
          '載入中…',
          style: TextStyle(fontSize: 15, color: colorScheme.subtitleText),
        ),
      ],
    );
    return Center(
      child: isLiquidGlass
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
              decoration: BoxDecoration(
                color: colorScheme.isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : Colors.white.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: colorScheme.isDark
                      ? Colors.white.withValues(alpha: 0.14)
                      : Colors.black.withValues(alpha: 0.05),
                  width: 0.5,
                ),
              ),
              child: content,
            )
          : content,
    );
  }

  // ─────────────────────────────────────────────
  // Info button + disclaimer dialog
  // ─────────────────────────────────────────────
  Widget _buildInfoButton(ColorScheme colorScheme) {
    return Tooltip(
      message: '關於本頁面的說明',
      child: InkWell(
        onTap: () => _showInfoDialog(colorScheme),
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Icon(
            Icons.info_outline_rounded,
            size: 22,
            color: colorScheme.primaryText,
          ),
        ),
      ),
    );
  }

  void _showInfoDialog(ColorScheme colorScheme) {
    if (LayoutStyleNotifier.instance.isLiquidGlass) {
      showGlassDialog(
        context: context,
        title: const Text(
          '關於學程進度',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Builder(
          builder: (context) {
            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildInfoRow(
                    colorScheme: colorScheme,
                    accentColor: Colors.orange.shade400,
                    title: 'AI 數據轉換',
                    body: '學程規則由 AI 自動解析，數據可能存在誤差，請務必以官方公告為準。',
                  ),
                  const SizedBox(height: 20),
                  _buildInfoRow(
                    colorScheme: colorScheme,
                    accentColor: Colors.teal.shade400,
                    title: '跨院課程確認',
                    body: '部分課程認定較為複雜，系統無法自動涵蓋所有情況，建議與系辦再次確認。',
                  ),
                  const SizedBox(height: 20),
                  _buildInfoRow(
                    colorScheme: colorScheme,
                    accentColor: colorScheme.accentBlue,
                    title: '完成度參考',
                    body: '進度百分比為系統估算值，僅供選課參考，不代表最終審核結果。',
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: colorScheme.isDark
                          ? Colors.orange[900]!.withValues(alpha: 0.2)
                          : Colors.orange[50]!,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.orange.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      '⚠️ 提醒：因資訊落差導致的任何問題，本系統不負擔相關責任。',
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.isDark
                            ? Colors.orange[200]
                            : Colors.orange[800],
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
            child: const Text('我知道了'),
          ),
        ],
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: colorScheme.surface,
        elevation: 12,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '關於學程進度',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.primaryText,
                    letterSpacing: 0.5,
                  ),
                ),

                const SizedBox(height: 24),

                _buildInfoRow(
                  colorScheme: colorScheme,
                  accentColor: Colors.orange.shade400,
                  title: 'AI 數據轉換',
                  body: '學程規則由 AI 自動解析，數據可能存在誤差，請務必以官方公告為準。',
                ),

                const SizedBox(height: 20),

                _buildInfoRow(
                  colorScheme: colorScheme,
                  accentColor: Colors.teal.shade400,
                  title: '跨院課程確認',
                  body: '部分課程認定較為複雜，系統無法自動涵蓋所有情況，建議與系辦再次確認。',
                ),

                const SizedBox(height: 20),

                _buildInfoRow(
                  colorScheme: colorScheme,
                  accentColor: colorScheme.accentBlue,
                  title: '完成度參考',
                  body: '進度百分比為系統估算值，僅供選課參考，不代表最終審核結果。',
                ),

                const SizedBox(height: 28),

                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: colorScheme.subtleBackground,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    '⚠️ 提醒：因資訊落差導致的任何問題，本系統不負擔相關責任。',
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.subtitleText.withValues(alpha: 0.8),
                      height: 1.5,
                    ),
                  ),
                ),

                const SizedBox(height: 28),

                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorScheme.accentBlue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      '我知道了',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow({
    required ColorScheme colorScheme,
    required Color accentColor,
    required String title,
    required String body,
  }) {
    return Container(
      padding: const EdgeInsets.only(left: 14, top: 2, bottom: 2),
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(
            color: accentColor.withValues(alpha: 0.8),
            width: 3.5,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w600,
              color: colorScheme.primaryText,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: TextStyle(
              fontSize: 12.5,
              color: colorScheme.subtitleText.withValues(alpha: 0.95),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Detail page (shown on mobile when a program is selected)
// ─────────────────────────────────────────────
class CourseProgressDetailPage extends StatefulWidget {
  final EligibilityResult? result;
  final ProgramRule? program;
  final bool isFavorite;
  final VoidCallback? onFavoriteToggle;
  final Map<String, List<String>> waivers;
  final void Function(String subject, String waiverId, bool checked)?
  onWaiverChanged;
  final Map<String, VerificationStatus> verificationStatuses;
  final void Function(String vKey, VerificationStatus status)?
  onVerificationChanged;
  final String? pdfLink;

  // Inputs needed for local recomputation
  final String selectedDept;
  final List<CourseTakenInput> coursesTaken;
  final List<String> doubleMajorDepts;
  final List<String> minorDepts;

  const CourseProgressDetailPage({
    super.key,
    required this.result,
    required this.program,
    this.isFavorite = false,
    this.onFavoriteToggle,
    this.waivers = const {},
    this.onWaiverChanged,
    this.verificationStatuses = const {},
    this.onVerificationChanged,
    this.pdfLink,
    required this.selectedDept,
    required this.coursesTaken,
    required this.doubleMajorDepts,
    required this.minorDepts,
  });

  @override
  State<CourseProgressDetailPage> createState() =>
      _CourseProgressDetailPageState();
}

class _CourseProgressDetailPageState extends State<CourseProgressDetailPage> {
  late bool _localIsFavorite;
  EligibilityResult? _localResult;
  late Map<String, List<String>> _localWaivers;
  late Map<String, VerificationStatus> _localVerificationStatuses;

  @override
  void initState() {
    super.initState();
    _localIsFavorite = widget.isFavorite;
    _localResult = widget.result;
    _localWaivers = _deepCopyWaivers(widget.waivers);
    _localVerificationStatuses = Map<String, VerificationStatus>.from(
      widget.verificationStatuses,
    );
  }

  Map<String, List<String>> _deepCopyWaivers(
    Map<String, List<String>> original,
  ) {
    return original.map((k, v) => MapEntry(k, List<String>.from(v)));
  }

  void _recomputeResult() async {
    if (widget.program == null || _localResult == null) return;
    final result = await _CourseProgressPageState._isolateCheckEligibility(
      program: widget.program!,
      year: _localResult!.academicYear,
      semester: null,
      studentDept: widget.selectedDept,
      coursesTaken: widget.coursesTaken,
      waivers: _localWaivers,
      doubleMajorDepts: widget.doubleMajorDepts,
      minorDepts: widget.minorDepts,
      verificationStatuses: _localVerificationStatuses,
    );
    if (mounted) {
      setState(() {
        _localResult = result;
      });
    }
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return GlassPageScaffold(
      appBar: AppBar(
        title: Text(widget.program?.programName ?? '學程進度'),
        actions: [
          if (widget.pdfLink != null && widget.pdfLink!.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.picture_as_pdf_rounded),
              tooltip: '查看 PDF 詳細資料',
              onPressed: () => _launchUrl(widget.pdfLink!),
            ),
          if (widget.onFavoriteToggle != null)
            IconButton(
              icon: Icon(
                _localIsFavorite
                    ? Icons.star_rounded
                    : Icons.star_outline_rounded,
                color: _localIsFavorite
                    ? Colors.amber[600]
                    : colorScheme.primaryText,
              ),
              tooltip: _localIsFavorite ? '移除最愛' : '加入最愛',
              onPressed: () {
                widget.onFavoriteToggle?.call();
                setState(() {
                  _localIsFavorite = !_localIsFavorite;
                });
              },
            ),
          const SizedBox(width: 12),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.only(left: 16.0, right: 16.0, top: 14.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: CourseProgressRightPanel(
              result: _localResult,
              program: widget.program,
              isFavorite: _localIsFavorite,
              onFavoriteToggle: () {
                widget.onFavoriteToggle?.call();
                setState(() {
                  _localIsFavorite = !_localIsFavorite;
                });
              },
              waivers: _localWaivers,
              onWaiverChanged: (subject, waiverId, checked) {
                widget.onWaiverChanged?.call(subject, waiverId, checked);
                setState(() {
                  if (checked) {
                    _localWaivers.putIfAbsent(subject, () => []);
                    if (!_localWaivers[subject]!.contains(waiverId)) {
                      _localWaivers[subject]!.add(waiverId);
                    }
                  } else {
                    _localWaivers[subject]?.remove(waiverId);
                    if (_localWaivers[subject]?.isEmpty ?? false) {
                      _localWaivers.remove(subject);
                    }
                  }
                });
                _recomputeResult();
              },
              verificationStatuses: _localVerificationStatuses,
              onVerificationChanged: (vKey, status) {
                widget.onVerificationChanged?.call(vKey, status);
                setState(() {
                  _localVerificationStatuses[vKey] = status;
                });
                _recomputeResult();
              },
              pdfLink: widget.pdfLink,
            ),
          ),
        ),
      ),
    );
  }
}
