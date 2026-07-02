import 'package:flutter/material.dart';
import '../models/program_model.dart';
import '../services/department_service.dart';
import '../services/program_application_service.dart';
import '../theme/app_theme.dart';
import '../utils/completion_rate.dart';
import '../utils/program_matching.dart';
import '../widgets/searchable_dropdown_field.dart';

enum LeftTab { allPrograms, yourPrograms, searchPrograms }

class CourseProgressLeftPanel extends StatefulWidget {
  final LeftTab currentTab;
  final ValueChanged<LeftTab> onTabChanged;
  final bool isComputingAll;
  final bool isLoading;
  final bool isCourseDataLoading;
  final String selectedDept;
  final List<ProgramRule> programs;
  final List<DeptOption> departments;
  final Map<String, EligibilityResult> allProgramResults;
  final String? selectedProgramId;
  final void Function(ProgramRule program, int year) onProgramSelected;
  final bool isDisabled;
  final List<FavoriteProgram> favoritePrograms;
  final Map<String, VerificationStatus> verificationStatuses;
  final void Function(FavoriteProgram)? onRemoveFavorite;
  final bool shrinkWrap;

  const CourseProgressLeftPanel({
    super.key,
    required this.currentTab,
    required this.onTabChanged,
    required this.isComputingAll,
    required this.isLoading,
    this.isCourseDataLoading = false,
    required this.selectedDept,
    required this.programs,
    required this.departments,
    required this.allProgramResults,
    required this.selectedProgramId,
    required this.onProgramSelected,
    required this.isDisabled,
    required this.favoritePrograms,
    this.verificationStatuses = const {},
    this.onRemoveFavorite,
    this.shrinkWrap = false,
  });

  @override
  State<CourseProgressLeftPanel> createState() =>
      _CourseProgressLeftPanelState();
}

class _CourseProgressLeftPanelState extends State<CourseProgressLeftPanel> {
  ProgramRule? _searchSelectedProgram;

  /// 記錄已經播放過入場動畫的 programId，避免 scroll 時重播
  final Set<String> _animatedPrograms = {};

  final _searchProgramController = TextEditingController();
  final _searchProgramFocusNode = FocusNode();
  final _searchYearController = TextEditingController();
  final _searchYearFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    ProgramApplicationService.instance.appliedProgramsNotifier.addListener(
      _onAppDataChanged,
    );
    ProgramApplicationService.instance.isLoadingNotifier.addListener(
      _onAppDataChanged,
    );
    ProgramApplicationService.instance.statusMessageNotifier.addListener(
      _onAppDataChanged,
    );
  }

  @override
  void dispose() {
    ProgramApplicationService.instance.appliedProgramsNotifier.removeListener(
      _onAppDataChanged,
    );
    ProgramApplicationService.instance.isLoadingNotifier.removeListener(
      _onAppDataChanged,
    );
    ProgramApplicationService.instance.statusMessageNotifier.removeListener(
      _onAppDataChanged,
    );
    _searchProgramController.dispose();
    _searchProgramFocusNode.dispose();
    _searchYearController.dispose();
    _searchYearFocusNode.dispose();
    super.dispose();
  }

  void _onAppDataChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildTabs(colorScheme),
        const SizedBox(height: 12),
        widget.shrinkWrap
            ? _buildTabContent(colorScheme)
            : Expanded(child: _buildTabContent(colorScheme)),
      ],
    );
  }

  Widget _buildTabs(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: colorScheme.secondaryCardBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _buildTabItem(LeftTab.allPrograms, '全部學程', colorScheme),
          _buildTabItem(LeftTab.yourPrograms, '你的學程', colorScheme),
          _buildTabItem(LeftTab.searchPrograms, '查詢學程', colorScheme),
        ],
      ),
    );
  }

  Widget _buildTabItem(LeftTab tab, String label, ColorScheme colorScheme) {
    final isSelected = widget.currentTab == tab;
    return Expanded(
      child: GestureDetector(
        onTap: () => widget.onTabChanged(tab),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? colorScheme.cardBackground : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              color: isSelected
                  ? colorScheme.accentBlue
                  : colorScheme.subtitleText,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTabContent(ColorScheme colorScheme) {
    switch (widget.currentTab) {
      case LeftTab.allPrograms:
        return _buildAllProgramsTab(colorScheme);
      case LeftTab.yourPrograms:
        return _buildYourProgramsTab(colorScheme);
      case LeftTab.searchPrograms:
        return _buildSearchTab(colorScheme);
    }
  }

  Widget _buildAllProgramsTab(ColorScheme colorScheme) {
    if (widget.isLoading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 12),
            Text(
              '載入中…',
              style: TextStyle(color: colorScheme.subtitleText, fontSize: 14),
            ),
          ],
        ),
      );
    }

    if (widget.isComputingAll) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 12),
            Text(
              '計算學程進度中…',
              style: TextStyle(color: colorScheme.subtitleText, fontSize: 14),
            ),
          ],
        ),
      );
    }

    if (widget.selectedDept.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            '請先填寫科系並儲存',
            style: TextStyle(color: colorScheme.subtitleText, fontSize: 14),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    if (widget.allProgramResults.isEmpty) {
      if (widget.isCourseDataLoading) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: colorScheme.accentBlue,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '正在載入修課資料…',
                  style: TextStyle(
                    color: colorScheme.subtitleText,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      }
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            '尚未載入修課資料',
            style: TextStyle(color: colorScheme.subtitleText, fontSize: 14),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final sorted = widget.programs.where((p) => !p.isDiscontinued).toList();
    sorted.sort((a, b) {
      final aResult = widget.allProgramResults[a.programId];
      final bResult = widget.allProgramResults[b.programId];
      final aRate = aResult != null
          ? computeEffectiveCompletionRate(aResult)
          : 0.0;
      final bRate = bResult != null
          ? computeEffectiveCompletionRate(bResult)
          : 0.0;

      final rateComparison = bRate.compareTo(aRate);
      if (rateComparison != 0) return rateComparison;

      final aHasRange = aResult?.completionRange.hasRange ?? false;
      final bHasRange = bResult?.completionRange.hasRange ?? false;
      return bHasRange.toString().compareTo(aHasRange.toString());
    });

    return ListView.builder(
      shrinkWrap: widget.shrinkWrap,
      physics: widget.shrinkWrap ? const NeverScrollableScrollPhysics() : null,
      itemCount: sorted.length,
      itemBuilder: (context, index) {
        final program = sorted[index];
        if (program.versions.isEmpty) return const SizedBox.shrink();

        final result = widget.allProgramResults[program.programId];
        final completionRate = result != null
            ? computeEffectiveCompletionRate(result)
            : 0.0;
        final latestYear = program.versions
            .reduce((a, b) => b.academicYear > a.academicYear ? b : a)
            .academicYear;

        // 只有第一次出現時才播動畫，之後 rebuild / scroll 回來不重播
        final alreadyAnimated = _animatedPrograms.contains(program.programId);

        if (!alreadyAnimated) {
          // 用 microtask 避免在 build 階段呼叫 setState
          Future.microtask(() {
            if (mounted) {
              setState(() => _animatedPrograms.add(program.programId));
            }
          });
        }

        final card = _buildProgramCard(
          programName: program.programName,
          completionRate: completionRate,
          completionRange: result?.completionRange,
          isSelected: widget.selectedProgramId == program.programId,
          colorScheme: colorScheme,
          onTap: () => widget.onProgramSelected(program, latestYear),
        );

        // 已動畫過：直接回傳，不包 TweenAnimationBuilder
        if (alreadyAnimated) return card;

        // 首次出現：播入場動畫（stagger 上限 300ms，避免尾端 item 等太久）
        final staggerDelay = (index * 40).clamp(0, 300);
        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: Duration(milliseconds: 350 + staggerDelay),
          curve: Curves.easeOut,
          builder: (context, progress, child) {
            return Transform.translate(
              offset: Offset(0, 16 * (1 - progress)),
              child: Opacity(opacity: progress, child: child),
            );
          },
          child: card, // 傳入 child 讓 builder 不重建 card
        );
      },
    );
  }

  Widget _buildYourProgramsTab(ColorScheme colorScheme) {
    final appService = ProgramApplicationService.instance;
    final appliedPrograms = appService.appliedProgramsNotifier.value;
    final isLoading = appService.isLoadingNotifier.value;
    final statusMsg = appService.statusMessageNotifier.value;

    if (isLoading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 12),
            Text(
              statusMsg.isEmpty ? '載入中…' : statusMsg,
              style: TextStyle(color: colorScheme.subtitleText, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return ListView(
      shrinkWrap: widget.shrinkWrap,
      physics: widget.shrinkWrap ? const NeverScrollableScrollPhysics() : null,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '已申請學程',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: colorScheme.primaryText,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.refresh, size: 18),
              onPressed: () =>
                  ProgramApplicationService.instance.fetchAppliedPrograms(),
              tooltip: '重新整理學程資料',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              style: IconButton.styleFrom(
                minimumSize: const Size(28, 28),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (appliedPrograms.isEmpty && statusMsg.isNotEmpty)
          _buildInfoCard(colorScheme, statusMsg, Icons.info_outline)
        else if (appliedPrograms.isEmpty)
          _buildInfoCard(colorScheme, '尚未載入申請學程資料', Icons.cloud_download)
        else ...[
          ...appliedPrograms.map(
            (ap) => _buildAppliedProgramCard(colorScheme, ap),
          ),
        ],
        if (appliedPrograms.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () =>
                    ProgramApplicationService.instance.fetchAppliedPrograms(),
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('重新載入'),
              ),
            ),
          ),
        const SizedBox(height: 20),
        Text(
          '⭐ 最愛學程',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: colorScheme.primaryText,
          ),
        ),
        const SizedBox(height: 8),
        if (widget.favoritePrograms.isEmpty)
          _buildInfoCard(colorScheme, '在右側面板點擊星號加入最愛', Icons.star_outline)
        else ...[
          ...widget.favoritePrograms.map((fav) {
            final program = widget.programs
                .where((p) => p.programId == fav.programId)
                .toList();
            if (program.isEmpty) {
              return _buildStaleFavoriteCard(colorScheme, fav);
            }
            final result = widget.allProgramResults[fav.programId];
            final completionRate = result != null
                ? computeEffectiveCompletionRate(result)
                : 0.0;
            return _buildProgramCard(
              programName: program.first.programName,
              completionRate: completionRate,
              completionRange: result?.completionRange,
              isSelected: widget.selectedProgramId == fav.programId,
              colorScheme: colorScheme,
              onTap: () =>
                  widget.onProgramSelected(program.first, fav.academicYear),
            );
          }),
        ],
        const SizedBox(height: 50),
      ],
    );
  }

  Widget _buildAppliedProgramCard(ColorScheme colorScheme, AppliedProgram ap) {
    final matchedProgram = findProgramByName(widget.programs, ap.programName);
    ProgramVersion? matchedVersion;
    String ruleYearText;
    VoidCallback? onTap;

    if (matchedProgram != null) {
      matchedVersion = findMatchingVersion(ap, matchedProgram);
      if (matchedVersion != null) {
        ruleYearText = '適用 ${matchedVersion.academicYear} 學年度規定';
        onTap = () => widget.onProgramSelected(
          matchedProgram,
          matchedVersion!.academicYear,
        );
      } else {
        ruleYearText = '目前找不到相關規定';
      }
    } else {
      ruleYearText = '未找到對應規定';
    }

    final isMatched = matchedProgram != null && matchedVersion != null;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colorScheme.cardBackground,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isMatched
                ? colorScheme.borderColor
                : colorScheme.borderColor.withValues(alpha: 0.5),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              ap.programName,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: isMatched
                    ? colorScheme.primaryText
                    : colorScheme.subtitleText,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '申請：${ap.applicationSemester}',
              style: TextStyle(fontSize: 12, color: colorScheme.subtitleText),
            ),
            const SizedBox(height: 2),
            Text(
              ruleYearText,
              style: TextStyle(
                fontSize: 12,
                color: isMatched
                    ? colorScheme.accentBlue
                    : colorScheme.subtitleText.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(
    ColorScheme colorScheme,
    String message,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.secondaryCardBackground,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: colorScheme.subtitleText),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(fontSize: 13, color: colorScheme.subtitleText),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStaleFavoriteCard(ColorScheme colorScheme, FavoriteProgram fav) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: colorScheme.secondaryCardBackground,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colorScheme.borderColor),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, size: 16, color: colorScheme.subtitleText),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '學程已不存在',
              style: TextStyle(fontSize: 13, color: colorScheme.subtitleText),
            ),
          ),
          if (widget.onRemoveFavorite != null)
            SizedBox(
              width: 28,
              height: 28,
              child: IconButton(
                icon: Icon(
                  Icons.close,
                  size: 16,
                  color: colorScheme.subtitleText,
                ),
                onPressed: () => widget.onRemoveFavorite!(fav),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                tooltip: '移除最愛',
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSearchTab(ColorScheme colorScheme) {
    final availableYears = _searchSelectedProgram != null
        ? (_searchSelectedProgram!.versions
              .map((v) => v.academicYear)
              .toSet()
              .toList()
            ..sort((a, b) => b.compareTo(a)))
        : <int>[];

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '學程',
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
              controller: _searchProgramController,
              focusNode: _searchProgramFocusNode,
              hintText: widget.programs.isEmpty ? '載入中...' : '搜尋學程',
              suggestions: widget.programs.map((p) => p.programName).toList(),
              onChanged: (val) {
                final match = widget.programs
                    .where((p) => p.programName == val)
                    .toList();
                setState(() {
                  _searchSelectedProgram = match.isNotEmpty
                      ? match.first
                      : null;
                  _searchYearController.clear();
                });
              },
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '學年度',
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
              controller: _searchYearController,
              focusNode: _searchYearFocusNode,
              hintText: _searchSelectedProgram == null ? '請先選擇學程' : '搜尋學年度',
              suggestions: availableYears.map((y) => '$y 學年度').toList(),
              enableSearch: false,
              onChanged: (val) {
                final year = int.tryParse(val.replaceAll(' 學年度', ''));
                if (year != null && _searchSelectedProgram != null) {
                  widget.onProgramSelected(_searchSelectedProgram!, year);
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgramCard({
    required String programName,
    required double completionRate,
    CompletionRange? completionRange,
    required bool isSelected,
    required ColorScheme colorScheme,
    required VoidCallback onTap,
  }) {
    final percentage = (completionRate * 100).round();
    final hasRange = completionRange != null && completionRange.hasRange;
    final isComplete = percentage >= 100;
    final displayText = '$percentage%';

    final barColor = percentage >= 100
        ? (colorScheme.isDark
              ? Colors.green[200]!
              : Colors.green[800]!) // 更深/亮的綠
        : percentage >= 70
        ? (colorScheme.isDark ? Colors.green[300]! : Colors.green[700]!)
        : percentage >= 30
        ? (colorScheme.isDark ? Colors.orange[300]! : Colors.orange[700]!)
        : (colorScheme.isDark ? Colors.red[300]! : Colors.red[700]!);

    // 100% 完成的特殊邊框色
    final borderColor = isComplete
        ? (colorScheme.isDark ? Colors.green[400]! : Colors.green[600]!)
        : isSelected
        ? colorScheme.accentBlue
        : colorScheme.borderColor;

    final borderWidth = (isComplete || isSelected) ? 2.0 : 1.0;

    // 100% 完成的背景微光
    final cardColor = isComplete
        ? (colorScheme.isDark
              ? const Color(0xFF0A2200)
              : const Color(0xFFF0FFF0))
        : colorScheme.cardBackground;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: borderColor, width: borderWidth),
          // 100% 完成加上外發光
          boxShadow: isComplete
              ? [
                  BoxShadow(
                    color:
                        (colorScheme.isDark
                                ? Colors.green[400]!
                                : Colors.green[300]!)
                            .withValues(alpha: 0.35),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    programName,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: colorScheme.primaryText,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // 100% 完成徽章
                if (isComplete) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.isDark
                          ? Colors.green[800]!.withValues(alpha: 0.5)
                          : Colors.green[100],
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: colorScheme.isDark
                            ? Colors.green[400]!
                            : Colors.green[600]!,
                      ),
                    ),
                    child: Text(
                      '🎉 完成',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: colorScheme.isDark
                            ? Colors.green[300]
                            : Colors.green[800],
                      ),
                    ),
                  ),
                ] else if (hasRange) ...[
                  const SizedBox(width: 4),
                  Tooltip(
                    message:
                        '完成度可能介於 ${(completionRange.minRate * 100).round()}%~${(completionRange.maxRate * 100).round()}% 之間，點進去查看跨院選修確認狀態',
                    child: Icon(
                      Icons.info_outline,
                      size: 14,
                      color: colorScheme.subtitleText,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: _buildProgressBar(
                    programName: programName,
                    completionRate: completionRate,
                    completionRange: completionRange,
                    barColor: barColor,
                    colorScheme: colorScheme,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  displayText,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: barColor,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 獨立出進度條 Widget，處理有/無範圍兩種情況
  Widget _buildProgressBar({
    required String programName,
    required double completionRate,
    required CompletionRange? completionRange,
    required Color barColor,
    required ColorScheme colorScheme,
  }) {
    final hasRange = completionRange != null && completionRange.hasRange;
    final bgColor = colorScheme.isDark
        ? const Color(0xFF2A3040)
        : const Color(0xFFE0E0E0);

    return TweenAnimationBuilder<double>(
      key: ValueKey('bar_$programName'),
      tween: Tween<double>(begin: 0, end: completionRate.clamp(0.0, 1.0)),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
      builder: (context, animatedValue, _) {
        if (!hasRange) {
          // 無範圍：原本的進度條
          return ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: animatedValue,
              backgroundColor: bgColor,
              valueColor: AlwaysStoppedAnimation(barColor),
              minHeight: 6,
            ),
          );
        }

        // 有範圍：自訂 CustomPaint 畫實體進度 + 虛線上界
        final maxRate = completionRange.maxRate.clamp(0.0, 1.0);
        return SizedBox(
          height: 8,
          child: CustomPaint(
            painter: _RangeProgressPainter(
              value: animatedValue,
              maxValue: maxRate,
              barColor: barColor,
              bgColor: bgColor,
              dashColor: colorScheme.isDark
                  ? Colors.orange[300]!
                  : Colors.orange[700]!,
            ),
          ),
        );
      },
    );
  }
}

class _RangeProgressPainter extends CustomPainter {
  final double value; // 實體進度（minRate）
  final double maxValue; // 虛線上界（maxRate）
  final Color barColor;
  final Color bgColor;
  final Color dashColor;

  const _RangeProgressPainter({
    required this.value,
    required this.maxValue,
    required this.barColor,
    required this.bgColor,
    required this.dashColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const radius = Radius.circular(4);
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      radius,
    );

    // 1. 背景
    canvas.drawRRect(rrect, Paint()..color = bgColor);

    // 2. 實體進度條（minRate）
    if (value > 0) {
      final fillWidth = size.width * value;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(0, 0, fillWidth, size.height),
          radius,
        ),
        Paint()..color = barColor,
      );
    }

    // 3. maxRate 與 minRate 之間的淡色填充
    if (maxValue > value) {
      final fillStart = size.width * value;
      final fillEnd = size.width * maxValue;
      canvas.drawRect(
        Rect.fromLTWH(fillStart, 0, fillEnd - fillStart, size.height),
        Paint()..color = barColor.withValues(alpha: 0.20),
      );
    }

    // 4. 虛線邊界線（在 maxRate 位置畫一條垂直虛線）
    if (maxValue > value && maxValue < 1.0) {
      final x = size.width * maxValue;
      final dashPaint = Paint()
        ..color = dashColor
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke;

      const dashHeight = 3.0;
      const dashGap = 2.0;
      double y = 0;
      while (y < size.height) {
        canvas.drawLine(
          Offset(x, y),
          Offset(x, (y + dashHeight).clamp(0, size.height)),
          dashPaint,
        );
        y += dashHeight + dashGap;
      }
    }
  }

  @override
  bool shouldRepaint(_RangeProgressPainter old) =>
      old.value != value ||
      old.maxValue != maxValue ||
      old.barColor != barColor;
}
