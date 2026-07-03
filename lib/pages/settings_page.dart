import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/theme_notifier.dart';
import '../theme/font_notifier.dart';
import '../theme/app_theme.dart';
import '../services/orientation_service.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({Key? key}) : super(key: key);

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  int _selectedSettingIndex = 0;

  Widget _getSelectedSettingsPage() {
    switch (_selectedSettingIndex) {
      case 0:
        return const ThemeSettingsPage(isEmbedded: true);
      case 1:
        return const HomeLayoutSettingsPage(isEmbedded: true);
      case 2:
        return const FontSettingsPage(isEmbedded: true);
      case 3:
        return const OrientationSettingsPage(isEmbedded: true);
      case 4:
        return const FeatureSettingsPage(isEmbedded: true);
      default:
        return const ThemeSettingsPage(isEmbedded: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isWide = MediaQuery.of(context).size.width >= 800;

    if (isWide) {
      return Scaffold(
        appBar: AppBar(
          title: const Text("設定"),
          centerTitle: true,
          backgroundColor: colorScheme.cardBackground,
          foregroundColor: colorScheme.primaryText,
          elevation: 0,
        ),
        backgroundColor: colorScheme.pageBackground,
        body: Row(
          children: [
            // Left settings list
            SizedBox(
              width: 320,
              child: Container(
                decoration: BoxDecoration(
                  border: Border(
                    right: BorderSide(color: colorScheme.borderColor, width: 1),
                  ),
                ),
                child: ListView(
                  children: [
                    _buildSettingsTile(
                      context,
                      index: 0,
                      title: "主題設定",
                      subtitle: "設定深淺色與系統主題模式",
                    ),
                    Divider(
                      height: 1,
                      indent: 16,
                      color: colorScheme.borderColor,
                    ),
                    _buildSettingsTile(
                      context,
                      index: 1,
                      title: "主頁面外觀設定",
                      subtitle: "調整首頁功能選單的排版樣式",
                    ),
                    Divider(
                      height: 1,
                      indent: 16,
                      color: colorScheme.borderColor,
                    ),
                    _buildSettingsTile(
                      context,
                      index: 2,
                      title: "字型設定",
                      subtitle: "字體選擇與管理",
                    ),
                    Divider(
                      height: 1,
                      indent: 16,
                      color: colorScheme.borderColor,
                    ),
                    _buildSettingsTile(
                      context,
                      index: 3,
                      title: "螢幕方向設定",
                      subtitle: "開啟或關閉橫向螢幕使用",
                    ),
                    Divider(
                      height: 1,
                      indent: 16,
                      color: colorScheme.borderColor,
                    ),
                    _buildSettingsTile(
                      context,
                      index: 4,
                      title: "進階功能設定",
                      subtitle: "預覽名次進階功能控制",
                    ),
                    Divider(
                      height: 1,
                      indent: 16,
                      color: colorScheme.borderColor,
                    ),
                  ],
                ),
              ),
            ),
            // Right detail pane
            Expanded(child: _getSelectedSettingsPage()),
          ],
        ),
      );
    }

    // Mobile layout
    return Scaffold(
      appBar: AppBar(title: const Text("設定"), centerTitle: true),
      backgroundColor: colorScheme.pageBackground,
      body: ListView(
        children: [
          _buildMobileSettingsTile(
            context,
            title: "主題設定",
            subtitle: "設定深淺色與系統主題模式",
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ThemeSettingsPage()),
            ),
          ),
          Divider(height: 1, indent: 16, color: colorScheme.borderColor),
          _buildMobileSettingsTile(
            context,
            title: "主頁面外觀設定",
            subtitle: "調整首頁功能選單的排版樣式",
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const HomeLayoutSettingsPage()),
            ),
          ),
          Divider(height: 1, indent: 16, color: colorScheme.borderColor),
          _buildMobileSettingsTile(
            context,
            title: "字型設定",
            subtitle: "字體選擇與管理",
            onTap: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const FontSettingsPage())),
          ),
          Divider(height: 1, indent: 16, color: colorScheme.borderColor),
          _buildMobileSettingsTile(
            context,
            title: "螢幕方向設定",
            subtitle: "開啟或關閉橫向螢幕使用",
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const OrientationSettingsPage(),
              ),
            ),
          ),
          Divider(height: 1, indent: 16, color: colorScheme.borderColor),
          _buildMobileSettingsTile(
            context,
            title: "進階功能設定",
            subtitle: "預覽名次進階功能控制",
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const FeatureSettingsPage()),
            ),
          ),
          Divider(height: 1, indent: 16, color: colorScheme.borderColor),
        ],
      ),
    );
  }

  Widget _buildSettingsTile(
    BuildContext context, {
    required int index,
    required String title,
    required String subtitle,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final isSelected = _selectedSettingIndex == index;

    return Container(
      decoration: BoxDecoration(
        color: isSelected
            ? colorScheme.accentBlue.withOpacity(0.08)
            : Colors.transparent,
        border: Border(
          left: BorderSide(
            color: isSelected ? colorScheme.accentBlue : Colors.transparent,
            width: 4,
          ),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 8,
          ),
          title: Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              color: isSelected
                  ? colorScheme.accentBlue
                  : colorScheme.primaryText,
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              subtitle,
              style: TextStyle(
                fontSize: 13,
                color: isSelected
                    ? colorScheme.accentBlue.withOpacity(0.8)
                    : colorScheme.subtitleText,
              ),
            ),
          ),
          trailing: Icon(
            Icons.arrow_forward_ios_rounded,
            size: 14,
            color: isSelected
                ? colorScheme.accentBlue
                : colorScheme.subtitleText.withOpacity(0.7),
          ),
          onTap: () {
            setState(() {
              _selectedSettingIndex = index;
            });
          },
        ),
      ),
    );
  }

  Widget _buildMobileSettingsTile(
    BuildContext context, {
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: colorScheme.primaryText,
        ),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Text(
          subtitle,
          style: TextStyle(fontSize: 13, color: colorScheme.subtitleText),
        ),
      ),
      trailing: Icon(
        Icons.arrow_forward_ios_rounded,
        size: 14,
        color: colorScheme.subtitleText.withOpacity(0.7),
      ),
      onTap: onTap,
    );
  }
}

// ─────────────────────────────────────────────
// 主題設定子頁面 (Theme Settings Page)
// ─────────────────────────────────────────────
class ThemeSettingsPage extends StatefulWidget {
  final bool isEmbedded;
  const ThemeSettingsPage({Key? key, this.isEmbedded = false})
    : super(key: key);

  @override
  State<ThemeSettingsPage> createState() => _ThemeSettingsPageState();
}

class _ThemeSettingsPageState extends State<ThemeSettingsPage> {
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: widget.isEmbedded
          ? null
          : AppBar(title: const Text("主題設定"), centerTitle: true),
      backgroundColor: colorScheme.pageBackground,
      body: ListView(
        children: [
          _buildThemeOption(context, ThemeMode.system, "系統預設"),
          Divider(height: 1, indent: 16, color: colorScheme.borderColor),
          _buildThemeOption(context, ThemeMode.light, "淺色模式"),
          Divider(height: 1, indent: 16, color: colorScheme.borderColor),
          _buildThemeOption(context, ThemeMode.dark, "深色模式"),
          Divider(height: 1, indent: 16, color: colorScheme.borderColor),
        ],
      ),
    );
  }

  Widget _buildThemeOption(BuildContext context, ThemeMode mode, String label) {
    final colorScheme = Theme.of(context).colorScheme;
    final currentMode = ThemeNotifier.instance.value;
    final isSelected = currentMode == mode;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      title: Text(
        label,
        style: TextStyle(
          fontSize: 15,
          fontWeight: isSelected ? FontWeight.w500 : FontWeight.normal,
          color: isSelected ? colorScheme.accentBlue : colorScheme.primaryText,
        ),
      ),
      trailing: Radio<ThemeMode>(
        value: mode,
        groupValue: currentMode,
        onChanged: (val) {
          if (val != null) {
            ThemeNotifier.instance.setThemeMode(val);
            setState(() {});
          }
        },
        activeColor: colorScheme.accentBlue,
      ),
      onTap: () {
        ThemeNotifier.instance.setThemeMode(mode);
        setState(() {});
      },
    );
  }
}

// ─────────────────────────────────────────────
// 字型設定子頁面 (Font Settings Page)
// ─────────────────────────────────────────────
class FontSettingsPage extends StatefulWidget {
  final bool isEmbedded;
  const FontSettingsPage({Key? key, this.isEmbedded = false}) : super(key: key);

  @override
  State<FontSettingsPage> createState() => _FontSettingsPageState();
}

class _FontSettingsPageState extends State<FontSettingsPage> {
  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: widget.isEmbedded
          ? null
          : AppBar(title: const Text("字型設定"), centerTitle: true),
      backgroundColor: colorScheme.pageBackground,
      body: ListView(
        children: [
          _buildFontOption(context, 'system', "系統預設 (刪除已下載字型)"),
          Divider(height: 1, indent: 16, color: colorScheme.borderColor),
          _buildFontOption(context, 'NotoSansTC', "Noto Sans TC (需聯網下載)"),
          Divider(height: 1, indent: 16, color: colorScheme.borderColor),
        ],
      ),
    );
  }

  Widget _buildFontOption(BuildContext context, String fontVal, String label) {
    final colorScheme = Theme.of(context).colorScheme;
    final currentFont = FontNotifier.instance.value;
    final isSelected = currentFont == fontVal;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      title: Text(
        label,
        style: TextStyle(
          fontSize: 15,
          fontWeight: isSelected ? FontWeight.w500 : FontWeight.normal,
          color: isSelected ? colorScheme.accentBlue : colorScheme.primaryText,
        ),
      ),
      trailing: Radio<String>(
        value: fontVal,
        groupValue: currentFont,
        onChanged: (val) {
          if (val != null) {
            _changeFont(val);
          }
        },
        activeColor: colorScheme.accentBlue,
      ),
      onTap: () => _changeFont(fontVal),
    );
  }

  Future<void> _changeFont(String fontVal) async {
    if (FontNotifier.instance.value == fontVal) return;

    if (fontVal == 'system') {
      await FontNotifier.instance.setFontFamily('system');
      _showSnackBar("已切換至系統預設字型並刪除下載檔案，釋出空間！");
      setState(() {});
    } else {
      _showDownloadDialog();
    }
  }

  void _showDownloadDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return PopScope(
          canPop: false,
          child: AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 16),
                const CircularProgressIndicator(),
                const SizedBox(height: 24),
                Text(
                  "正在下載並套用 Noto Sans TC 字型...",
                  style: TextStyle(
                    fontSize: 15,
                    color: Theme.of(context).colorScheme.primaryText,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  "這可能需要幾秒鐘，請保持網路連線",
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.subtitleText,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );

    FontNotifier.instance
        .setFontFamily('NotoSansTC')
        .then((_) {
          Navigator.of(context).pop(); // 關閉對話框
          _showSnackBar("Noto Sans 繁體中文字型下載並套用成功！");
          setState(() {});
        })
        .catchError((e) {
          Navigator.of(context).pop(); // 關閉對話框
          _showSnackBar("下載字型失敗，請檢查網路連線或稍後再試！", isError: true);
        });
  }
}

// ─────────────────────────────────────────────
// 功能與實驗室子頁面 (Features Settings Page)
// ─────────────────────────────────────────────
class FeatureSettingsPage extends StatefulWidget {
  final bool isEmbedded;
  const FeatureSettingsPage({Key? key, this.isEmbedded = false})
    : super(key: key);

  @override
  State<FeatureSettingsPage> createState() => _FeatureSettingsPageState();
}

class _FeatureSettingsPageState extends State<FeatureSettingsPage> {
  int _previewRankMode = 2; // 1: 關閉, 2: 部分期間開啟, 3: 永久開啟
  bool _experimentalAbnormalEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      if (prefs.containsKey('preview_rank_mode')) {
        _previewRankMode = prefs.getInt('preview_rank_mode') ?? 2;
      } else if (prefs.containsKey('is_preview_rank_enabled')) {
        bool? oldVal = prefs.getBool('is_preview_rank_enabled');
        if (oldVal == false) {
          _previewRankMode = 1;
        } else if (oldVal == true) {
          _previewRankMode = 2;
        }
      } else {
        _previewRankMode = 2;
      }
      _experimentalAbnormalEnabled =
          prefs.getBool('experimental_abnormal_handling_enabled') ?? false;
    });
  }

  Future<void> _updatePreviewRankMode(int value) async {
    setState(() => _previewRankMode = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('preview_rank_mode', value);
    await prefs.setBool('is_preview_rank_enabled', value != 1);
  }

  Future<void> _updateExperimentalAbnormal(bool value) async {
    setState(() => _experimentalAbnormalEnabled = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('experimental_abnormal_handling_enabled', value);
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: widget.isEmbedded
          ? null
          : AppBar(title: const Text("進階功能設定"), centerTitle: true),
      backgroundColor: colorScheme.pageBackground,
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
            child: Text(
              "預覽成績與名次設定",
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: colorScheme.accentBlue,
              ),
            ),
          ),
          _buildRadioOption(
            title: "關閉預覽",
            subtitle: "完全關閉預覽功能，查詢速度最快",
            value: 1,
            colorScheme: colorScheme,
          ),
          Divider(
            height: 1,
            indent: 20,
            endIndent: 20,
            color: colorScheme.borderColor,
          ),
          _buildRadioOption(
            title: "部分期間開啟 (推薦)",
            subtitle:
                "僅在「成績開放查詢期間」開啟預覽以節省系統資源 (春夏季 5/25 ~ 10/10，秋冬季 12/25 ~ 3/20 開啟，其餘時間關閉)",
            value: 2,
            colorScheme: colorScheme,
          ),
          Divider(
            height: 1,
            indent: 20,
            endIndent: 20,
            color: colorScheme.borderColor,
          ),
          _buildRadioOption(
            title: "永久開啟 (不建議)",
            subtitle: "全年無休嘗試抓取名次預覽，但可能導致非期末期間查詢時間顯著變長",
            value: 3,
            colorScheme: colorScheme,
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Text(
              "實驗性功能",
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: colorScheme.accentBlue,
              ),
            ),
          ),
          ListTile(
            title: Text(
              "異常加簽處理 (實驗中)",
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: colorScheme.primaryText,
              ),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                "利用背景網路請求自動化送出異常加簽申請，取得PDF",
                style: TextStyle(fontSize: 13, color: colorScheme.subtitleText),
              ),
            ),
            trailing: Transform.scale(
              scale: 0.8,
              child: CupertinoSwitch(
                value: _experimentalAbnormalEnabled,
                activeColor: colorScheme.accentBlue,
                onChanged: (val) {
                  _updateExperimentalAbnormal(val);
                },
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 8,
            ),
          ),
          const Divider(),
        ],
      ),
    );
  }

  Widget _buildRadioOption({
    required String title,
    required String subtitle,
    required int value,
    required ColorScheme colorScheme,
  }) {
    final isSelected = _previewRankMode == value;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 15,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          color: isSelected ? colorScheme.accentBlue : colorScheme.primaryText,
        ),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(
          subtitle,
          style: TextStyle(
            fontSize: 13,
            color: isSelected
                ? colorScheme.accentBlue.withOpacity(0.8)
                : colorScheme.subtitleText,
          ),
        ),
      ),
      trailing: Radio<int>(
        value: value,
        groupValue: _previewRankMode,
        onChanged: (val) {
          if (val != null) {
            _updatePreviewRankMode(val);
          }
        },
        activeColor: colorScheme.accentBlue,
      ),
      onTap: () => _updatePreviewRankMode(value),
    );
  }
}

// ─────────────────────────────────────────────
// 主頁面外觀設定子頁面 (Home Layout Settings Page)
// ─────────────────────────────────────────────
class HomeLayoutSettingsPage extends StatefulWidget {
  final bool isEmbedded;
  const HomeLayoutSettingsPage({Key? key, this.isEmbedded = false})
    : super(key: key);

  @override
  State<HomeLayoutSettingsPage> createState() => _HomeLayoutSettingsPageState();
}

class _HomeLayoutSettingsPageState extends State<HomeLayoutSettingsPage> {
  String _currentStyle = 'default';
  int _selectedCategoryIndex = 0; // 0 for simple, 1 for premium

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final style = prefs.getString('main_menu_layout_style') ?? 'default';
    setState(() {
      _currentStyle = style;
      if (style == 'bento' || style == 'aurora') {
        _selectedCategoryIndex = 1;
      } else {
        _selectedCategoryIndex = 0;
      }
    });
  }

  Future<void> _changeStyle(String style) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('main_menu_layout_style', style);
    setState(() {
      _currentStyle = style;
    });
  }

  Widget _buildCategorySelector() {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: colorScheme.subtleBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildCategoryTab(
              0,
              "簡單樣式",
              Icons.bolt_rounded,
              Colors.green,
            ),
          ),
          Expanded(
            child: _buildCategoryTab(
              1,
              "精緻特效",
              Icons.auto_awesome_rounded,
              Colors.amber,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryTab(
    int index,
    String label,
    IconData icon,
    MaterialColor activeColor,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final isSelected = _selectedCategoryIndex == index;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedCategoryIndex = index;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? colorScheme.cardBackground : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected
                  ? (isDark
                        ? activeColor.withOpacity(0.9)
                        : activeColor.shade800)
                  : colorScheme.subtitleText,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected
                    ? colorScheme.primaryText
                    : colorScheme.subtitleText,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLeadingIcon(String styleVal) {
    IconData icon;
    MaterialColor color;
    switch (styleVal) {
      case 'default':
        icon = Icons.format_list_bulleted_rounded;
        color = Colors.blue;
        break;
      case 'compact':
        icon = Icons.reorder_rounded;
        color = Colors.teal;
        break;
      case 'grid':
        icon = Icons.grid_view_rounded;
        color = Colors.indigo;
        break;
      case 'bento':
        icon = Icons.dashboard_customize_rounded;
        color = Colors.orange;
        break;
      case 'aurora':
        icon = Icons.blur_on_rounded;
        color = Colors.purple;
        break;
      default:
        icon = Icons.help_outline_rounded;
        color = Colors.grey;
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: isDark ? color.withOpacity(0.15) : color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(
        icon,
        color: isDark ? color.withOpacity(0.9) : color.shade700,
        size: 20,
      ),
    );
  }

  Widget _buildOptionsList() {
    final colorScheme = Theme.of(context).colorScheme;

    List<Widget> options = [];
    if (_selectedCategoryIndex == 0) {
      options = [
        _buildOption("default", "經典列表", "顯示完整的圖標、標題與詳細描述"),
        _buildOption("compact", "緊湊列表", "隱藏描述文字，縮小卡片高度"),
        _buildOption("grid", "雙排棋盤", "採用雙排對稱排列，畫面乾淨俐落"),
      ];
    } else {
      options = [
        _buildOption("bento", "炫彩 Bento", "非對稱式 Bento Box 幾何佈局，主次分明色彩豐富"),
        _buildOption("aurora", "極光毛玻璃", "流體極光與全域毛玻璃，呈現立體折射視差"),
      ];
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: colorScheme.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.borderColor, width: 0.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: options.length,
          separatorBuilder: (context, index) => Divider(
            height: 1,
            indent: 68,
            endIndent: 16,
            color: colorScheme.borderColor,
          ),
          itemBuilder: (context, index) => options[index],
        ),
      ),
    );
  }

  Widget _buildPerformanceTip() {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final isPremium = _selectedCategoryIndex == 1;
    final tipTitle = isPremium ? "精緻特效提示" : "效能友善提示";
    final tipContent = isPremium
        ? "「精緻特效」樣式搭載流體極光、磨砂毛玻璃和不對稱的動態視差面板，視覺體驗極佳，但運算與渲染負載較高，建議中高階裝置使用。"
        : "「簡單樣式」採用靜態列表與對稱排版，完全無動畫特效，極度省電且順暢，適合所有等級的手機使用。";
    final icon = isPremium
        ? Icons.info_outline_rounded
        : Icons.offline_bolt_rounded;
    final iconColor = isPremium ? Colors.amber : Colors.green;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? colorScheme.secondaryCardBackground
            : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.borderColor, width: 0.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: isDark ? iconColor.withOpacity(0.9) : iconColor.shade700,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tipTitle,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primaryText,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  tipContent,
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.subtitleText,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: widget.isEmbedded
          ? null
          : AppBar(title: const Text("主頁面外觀設定"), centerTitle: true),
      backgroundColor: colorScheme.pageBackground,
      body: ListView(
        physics: const BouncingScrollPhysics(),
        children: [
          _buildCategorySelector(),
          _buildOptionsList(),
          _buildPerformanceTip(),
        ],
      ),
    );
  }

  Widget _buildOption(String styleVal, String title, String subtitle) {
    final colorScheme = Theme.of(context).colorScheme;
    final isSelected = _currentStyle == styleVal;

    return Material(
      color: Colors.transparent,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: _buildLeadingIcon(styleVal),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 15,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected
                ? colorScheme.accentBlue
                : colorScheme.primaryText,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            subtitle,
            style: TextStyle(
              fontSize: 12,
              color: colorScheme.subtitleText,
              height: 1.3,
            ),
          ),
        ),
        trailing: Radio<String>(
          value: styleVal,
          groupValue: _currentStyle,
          onChanged: (val) {
            if (val != null) {
              _changeStyle(val);
            }
          },
          activeColor: colorScheme.accentBlue,
        ),
        onTap: () => _changeStyle(styleVal),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// 螢幕方向設定子頁面 (Orientation Settings Page)
// ─────────────────────────────────────────────
class OrientationSettingsPage extends StatefulWidget {
  final bool isEmbedded;
  const OrientationSettingsPage({Key? key, this.isEmbedded = false})
    : super(key: key);

  @override
  State<OrientationSettingsPage> createState() =>
      _OrientationSettingsPageState();
}

class _OrientationSettingsPageState extends State<OrientationSettingsPage> {
  bool _allowLandscape = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final allowed = await OrientationService.isLandscapeAllowed();
    setState(() {
      _allowLandscape = allowed;
    });
  }

  Future<void> _toggleLandscape(bool value) async {
    setState(() {
      _allowLandscape = value;
    });
    await OrientationService.setLandscapeAllowed(value);
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: widget.isEmbedded
          ? null
          : AppBar(title: const Text("螢幕方向設定"), centerTitle: true),
      backgroundColor: colorScheme.pageBackground,
      body: ListView(
        children: [
          ListTile(
            title: Text(
              "允許橫向旋轉",
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: colorScheme.primaryText,
              ),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                "開啟後，旋轉時畫面可同步切換為橫向顯示",
                style: TextStyle(fontSize: 13, color: colorScheme.subtitleText),
              ),
            ),
            trailing: Transform.scale(
              scale: 0.8,
              child: CupertinoSwitch(
                value: _allowLandscape,
                activeColor: colorScheme.accentBlue,
                onChanged: _toggleLandscape,
              ),
            ),

            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 8,
            ),
          ),
          const Divider(),
        ],
      ),
    );
  }
}
