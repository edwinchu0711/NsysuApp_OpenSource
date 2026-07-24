import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import '../theme/theme_notifier.dart';
import '../theme/layout_style_notifier.dart';
import '../widgets/glass/aurora_background.dart';
import '../widgets/glass/glass_page_scaffold.dart';
import '../services/course_service.dart';
import '../services/open_score_service.dart';
import '../services/historical_score_service.dart';
import 'main_menu_page.dart';

class InitializationPage extends StatefulWidget {
  final String cookies;
  final String userAgent;
  final List<Future<void> Function()>? initTasks;
  final Duration? initTimeout;
  final Duration? autoNavDelay;
  final VoidCallback? onComplete;
  final bool forceModeA;

  const InitializationPage({
    super.key,
    required this.cookies,
    required this.userAgent,
    this.initTasks,
    this.initTimeout,
    this.autoNavDelay,
    this.onComplete,
    this.forceModeA = false,
  });

  @override
  State<InitializationPage> createState() => _InitializationPageState();
}

class _InitializationPageState extends State<InitializationPage> {
  final ValueNotifier<double> _progress = ValueNotifier(0.0);
  bool _initDone = false;
  bool _isModeA = false;
  int _currentStep = 1; // 1: 主題設定, 2: 主頁面外觀設定
  double _opacity = 1.0; // 用於跳轉頁面時的淡出動畫
  String _selectedLayout = 'liquid_glass';
  Timer? _timer;
  late List<Future<void> Function()> _tasks;

  static const String _kHasInitialized = 'has_initialized';
  static const String _kThemeKey = 'app_theme_mode';
  static const String _kLayoutKey = 'main_menu_layout_style';

  static List<Future<void> Function()> get _defaultInitTasks => [
    () => CourseService.instance.refreshAndCache(),
    () => OpenScoreService.instance.fetchOpenScores(),
    () => HistoricalScoreService.instance.fetchAllData(),
  ];

  @override
  void initState() {
    super.initState();
    _tasks = widget.initTasks ?? _defaultInitTasks;
    _init();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    final bool hasTheme = prefs.containsKey(_kThemeKey);
    final bool hasLayout = prefs.containsKey(_kLayoutKey);
    _isModeA = widget.forceModeA || !(hasTheme && hasLayout);

    if (_isModeA && !hasTheme) {
      await ThemeNotifier.instance.setThemeMode(ThemeMode.system);
    }

    if (_isModeA && !hasLayout) {
      await LayoutStyleNotifier.instance.set('liquid_glass');
    } else if (_isModeA && hasLayout) {
      // Re-entering A mode after an interrupted first run: reflect their
      // previously-chosen layout in the selector instead of the field default.
      _selectedLayout = prefs.getString(_kLayoutKey) ?? 'liquid_glass';
    }
    if (mounted) setState(() {});
    _startInitTasks();
  }

  void _startInitTasks() {
    if (widget.forceModeA) {
      // 重新設定/預覽時，不需要重新下載快取或跑背景初始化任務
      _progress.value = 1.0;
      _initDone = true;
      return;
    }

    int completed = 0;
    void markDone() {
      if (_initDone) return;
      completed++;
      _progress.value = completed / _tasks.length;
      if (completed >= _tasks.length) _finish();
    }

    for (final t in _tasks) {
      t().then((_) => markDone()).catchError((_) => markDone());
    }

    final timeout = widget.initTimeout ?? const Duration(seconds: 8);
    _timer = Timer(timeout, () {
      if (!_initDone) {
        _progress.value = 1.0;
        _finish();
      }
    });
  }

  void _finish() {
    if (_initDone) return;
    _initDone = true;
    if (!_isModeA) {
      final delay = widget.autoNavDelay ?? const Duration(milliseconds: 500);
      Future.delayed(delay, _completeAndProceed);
    } else if (mounted) {
      setState(() {});
    }
  }

  Future<void> _completeAndProceed() async {
    if (!mounted) return;

    // 啟動淡出動畫
    setState(() {
      _opacity = 0.0;
    });

    // 等待淡出動畫 (300ms) 播放完畢後，再進行實際跳轉 (若 autoNavDelay 為 zero 則不等待)
    final animDelay = widget.autoNavDelay == Duration.zero
        ? Duration.zero
        : const Duration(milliseconds: 300);
    if (animDelay > Duration.zero) {
      await Future.delayed(animDelay);
    }
    if (!mounted) return;

    if (widget.forceModeA) {
      // 如果是從設定頁或選課系統點擊進來的預覽/重新設定，設定完成後直接返回即可
      Navigator.of(context).pop();
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kHasInitialized, true);
    if (!prefs.containsKey('preview_rank_mode')) {
      await prefs.setInt('preview_rank_mode', 2);
    }
    if (!prefs.containsKey('is_preview_rank_enabled')) {
      await prefs.setBool('is_preview_rank_enabled', true);
    }
    if (!mounted) return;
    if (widget.onComplete != null) {
      widget.onComplete!();
      return;
    }
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) =>
            MainMenuPage(cookies: widget.cookies, userAgent: widget.userAgent),
      ),
      (_) => false,
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _progress.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _isModeA ? _buildModeA(context) : _buildModeB(context);
  }

  Widget _buildModeB(BuildContext context) {
    return GlassPageScaffold(
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '初始化中',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 32),
              _progressIndicator(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModeA(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Stack(
      children: [
        const AuroraBackground(),
        Scaffold(
          backgroundColor: Colors.transparent,
          body: AnimatedOpacity(
            opacity: _opacity,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 24,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '歡迎使用學生服務系統',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.primaryText,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (_currentStep == 1) ...[
                              _buildThemeSelector(context),
                            ] else if (_currentStep == 2) ...[
                              _buildLayoutSelector(context),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_currentStep == 2) _progressIndicator(),
                    const SizedBox(height: 16),
                    _buildEnterButton(context),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  BoxDecoration _forcedGlassDecoration(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return BoxDecoration(
      color: isDark
          ? Colors.white.withValues(alpha: 0.04)
          : Colors.white.withValues(alpha: 0.45),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color: isDark
            ? Colors.white.withValues(alpha: 0.08)
            : Colors.white.withValues(alpha: 0.35),
        width: 1,
      ),
      boxShadow: [
        BoxShadow(
          color: isDark
              ? Colors.black.withValues(alpha: 0.15)
              : Colors.black.withValues(alpha: 0.04),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  Widget _sectionTitle(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primaryText,
        ),
      ),
    );
  }

  Widget _buildThemeSelector(BuildContext context) {
    return Container(
      decoration: _forcedGlassDecoration(context),
      child: Material(
        color: Colors.transparent,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle(context, '主題設定'),
            _themeRow(context, ThemeMode.system, '系統'),
            _themeRow(context, ThemeMode.light, '淺色模式'),
            _themeRow(context, ThemeMode.dark, '深色模式'),
          ],
        ),
      ),
    );
  }

  Widget _themeRow(BuildContext context, ThemeMode mode, String label) {
    final selected = ThemeNotifier.instance.value == mode;
    return ListTile(
      leading: Icon(
        selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
        color: selected ? Theme.of(context).colorScheme.accentBlue : null,
      ),
      title: Text(label),
      onTap: () {
        ThemeNotifier.instance.setThemeMode(mode);
        setState(() {});
      },
    );
  }

  Widget _buildLayoutSelector(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: _forcedGlassDecoration(context),
      child: Material(
        color: Colors.transparent,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle(context, '主頁面外觀設定'),

            // 提示說明
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 4.0,
              ),
              child: Text(
                "💡 建議首次使用先嘗試「流體玻璃導覽」感受全新視覺。若覺得滑動不夠流暢，之後隨時能到「設定」換回經典流暢的簡單樣式喔！",
                style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.subtitleText,
                  height: 1.4,
                ),
              ),
            ),
            const Divider(height: 16, indent: 16, endIndent: 16),

            // 特效組
            Padding(
              padding: const EdgeInsets.only(left: 16.0, top: 4, bottom: 4),
              child: Text(
                "✨ 華麗特效 (效能負載較高)",
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.accentBlue,
                ),
              ),
            ),
            _layoutRow(
              context,
              'liquid_glass',
              '流體玻璃導覽',
              subtitle: '磨砂玻璃質感搭配精緻底部導覽列，整合四大分類與選單，極致優雅 (⚠️ 較吃效能)',
              isHighlight: true,
            ),
            _layoutRow(
              context,
              'aurora',
              '極光毛玻璃',
              subtitle: '全螢幕極光流體與毛玻璃面板，呈現立體折射視差',
            ),
            _layoutRow(
              context,
              'bento',
              '炫彩 Bento',
              subtitle: '非對稱式幾何卡片排版，主次分明色彩豐富',
            ),

            const Divider(height: 16, indent: 16, endIndent: 16),

            // 簡單組
            Padding(
              padding: const EdgeInsets.only(left: 16.0, top: 4, bottom: 4),
              child: Text(
                "⚡ 簡單流暢 (省電且極速)",
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.subtitleText,
                ),
              ),
            ),
            _layoutRow(
              context,
              'default',
              '經典列表',
              subtitle: '標準列表樣式，展示圖標與完整說明文字',
            ),
            _layoutRow(
              context,
              'compact',
              '緊湊列表',
              subtitle: '隱藏詳細說明，以緊密列表呈現，適合小螢幕',
            ),
            _layoutRow(context, 'grid', '雙排棋盤', subtitle: '乾淨俐落的對稱網格圖標按鈕'),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _layoutRow(
    BuildContext context,
    String value,
    String label, {
    String? subtitle,
    bool isHighlight = false,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final selected = _selectedLayout == value;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Padding(
        padding: const EdgeInsets.only(top: 4.0),
        child: Icon(
          selected ? Icons.check_circle : Icons.radio_button_unchecked,
          color: selected ? colorScheme.accentBlue : null,
        ),
      ),
      title: Text(
        label,
        style: TextStyle(
          fontSize: 14,
          fontWeight: selected || isHighlight
              ? FontWeight.bold
              : FontWeight.normal,
          color: selected
              ? colorScheme.accentBlue
              : (isHighlight
                    ? colorScheme.primaryText
                    : colorScheme.primaryText.withValues(alpha: 0.85)),
        ),
      ),
      subtitle: subtitle != null
          ? Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Text(
                subtitle,
                style: TextStyle(
                  fontSize: 11,
                  color: selected
                      ? colorScheme.accentBlue.withValues(alpha: 0.8)
                      : colorScheme.subtitleText,
                  height: 1.3,
                ),
              ),
            )
          : null,
      onTap: () {
        LayoutStyleNotifier.instance.set(value);
        setState(() => _selectedLayout = value);
      },
    );
  }

  Widget _buildEnterButton(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (_currentStep == 1) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          key: const ValueKey('enterMainButton'),
          onPressed: () {
            setState(() {
              _currentStep = 2;
            });
          },
          style: ElevatedButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text('下一步', style: TextStyle(fontSize: 16)),
          ),
        ),
      );
    }

    // 步驟 2：增加「上一頁」按鈕與主按鈕組成的 Row
    return Row(
      children: [
        OutlinedButton(
          onPressed: () {
            setState(() {
              _currentStep = 1;
            });
          },
          style: OutlinedButton.styleFrom(
            foregroundColor: colorScheme.primary,
            side: BorderSide(color: colorScheme.primary.withValues(alpha: 0.5)),
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: const Text(
            '上一頁',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ValueListenableBuilder<double>(
            valueListenable: _progress,
            builder: (context, progress, _) {
              // 按鈕啟用判斷：當強制預覽模式時，或背景下載進度達到 100% (1.0) 時啟用
              final enabled = widget.forceModeA || progress >= 1.0;
              return ElevatedButton(
                key: const ValueKey('enterMainButton'),
                onPressed: enabled ? _completeAndProceed : null,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  widget.forceModeA ? '完成設定' : '進入主頁面',
                  style: const TextStyle(fontSize: 16),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _progressIndicator() {
    if (widget.forceModeA) {
      return const SizedBox.shrink(); // 重新設定模式下不需要顯示下載進度條
    }
    return ValueListenableBuilder<double>(
      valueListenable: _progress,
      builder: (context, progress, _) {
        final percent = (progress * 100).toInt();
        final isDone = progress >= 1.0;
        final statusText = isDone ? "初始化完成" : "初始化中...";

        if (_isModeA) {
          // 在設定主題的 Mode A (下方)：Row 佈局，[狀態文字] - [進度條] - [%]
          return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                statusText,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(
                    context,
                  ).colorScheme.primaryText.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 160,
                height: 4,
                child: LinearProgressIndicator(
                  value: progress,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 38, // 固定寬度避免百分比字數變化時抖動
                child: Text(
                  '$percent%',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          );
        } else {
          // 不用設定主題的 Mode B (畫面中央)：維持原本大尺寸進度條 Column 佈局，不重複顯示狀態文字
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$percent%',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: 240,
                height: 8,
                child: LinearProgressIndicator(
                  value: progress,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ],
          );
        }
      },
    );
  }
}
