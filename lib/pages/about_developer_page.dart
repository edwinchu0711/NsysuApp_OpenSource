import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';
import '../theme/layout_style_notifier.dart';
import '../widgets/glass/glass_page_scaffold.dart';
import '../widgets/glass/glass_card.dart';

class AboutDeveloperPage extends StatelessWidget {
  const AboutDeveloperPage({Key? key}) : super(key: key);

  Future<void> _launchGitHubUrl() async {
    final Uri url = Uri.parse(
      'https://github.com/edwinchu0711/NsysuApp_OpenSource',
    );
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isWide = MediaQuery.of(context).size.width >= 800;
    final isLiquidGlass = LayoutStyleNotifier.instance.isLiquidGlass;

    if (isWide) {
      return GlassPageScaffold(
        appBar: AppBar(
          title: const Text(
            "關於開發者",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
          backgroundColor:
              isLiquidGlass ? Colors.transparent : colorScheme.cardBackground,
          foregroundColor: colorScheme.primaryText,
          elevation: 0,
          iconTheme: IconThemeData(color: colorScheme.primaryText),
        ),
        body: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            40.0,
            24.0,
            40.0,
            LayoutStyleNotifier.instance.isLiquidGlass ? 100 : 24.0,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left Column: Developer Card & GitHub Button
                  Expanded(
                    flex: 4,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildDeveloperCard(context, colorScheme),
                        const SizedBox(height: 20),
                        _buildGitHubButton(context, colorScheme),
                      ],
                    ),
                  ),
                  const SizedBox(width: 24),
                  // Right Column: Special Thanks, Credits & MIT License
                  Expanded(
                    flex: 6,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildSpecialThanksCard(context, colorScheme),
                        const SizedBox(height: 20),
                        _buildCreditsCard(context, colorScheme),
                        const SizedBox(height: 20),
                        _buildLicenseCard(context, colorScheme),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // Mobile layout: EXACTLY as original
    return GlassPageScaffold(
      appBar: AppBar(
        title: const Text(
          "關於開發者",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor:
            isLiquidGlass ? Colors.transparent : colorScheme.cardBackground,
        foregroundColor: colorScheme.primaryText,
        elevation: 0,
        iconTheme: IconThemeData(color: colorScheme.primaryText),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          20.0,
          16.0,
          20.0,
          LayoutStyleNotifier.instance.isLiquidGlass ? 100 : 16.0,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Developer Profile Card
            _buildDeveloperCard(context, colorScheme),
            const SizedBox(height: 16),

            // 2. Special Thanks Card
            _buildSpecialThanksCard(context, colorScheme),
            const SizedBox(height: 16),

            // 3. Credits Card
            _buildCreditsCard(context, colorScheme),
            const SizedBox(height: 16),

            // 4. MIT License Card
            _buildLicenseCard(context, colorScheme),
            const SizedBox(height: 24),

            // 5. GitHub Repository Link Button
            _buildGitHubButton(context, colorScheme),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildDeveloperCard(BuildContext context, ColorScheme colorScheme) {
    final isDark = colorScheme.brightness == Brightness.dark;
    final isLiquidGlass = LayoutStyleNotifier.instance.isLiquidGlass;
    return Container(
      decoration: isLiquidGlass
          ? glassCardDecoration(context, borderRadius: 24)
          : BoxDecoration(
              color: colorScheme.cardBackground,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: colorScheme.borderColor, width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  spreadRadius: 1,
                  blurRadius: 6,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Column(
          children: [
            // Top Gradient Cover
            Container(
              height: 90,
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? [const Color(0xFF1E2D4A), const Color(0xFF0D47A1)]
                      : [const Color(0xFFE3F2FD), const Color(0xFF90CAF9)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
            // Content
            Transform.translate(
              offset: const Offset(0, -38),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Column(
                  children: [
                    // Avatar with glowing border
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: colorScheme.cardBackground,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 8,
                            spreadRadius: 2,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: CircleAvatar(
                        radius: 36,
                        backgroundColor: colorScheme.accentBlue.withValues(alpha: 
                          0.12,
                        ),
                        child: Icon(
                          Icons.code_rounded,
                          size: 38,
                          color: colorScheme.accentBlue,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      "Danial",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.primaryText,
                        letterSpacing: 1.1,
                      ),
                    ),

                    const SizedBox(height: 16),
                    // Tagline quote box
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.secondaryCardBackground,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: colorScheme.borderColor.withValues(alpha: 0.5),
                          width: 0.5,
                        ),
                      ),
                      child: Column(
                        children: [
                          const SizedBox(height: 4),
                          Text(
                            "Just for fun.",
                            style: TextStyle(
                              fontSize: 13.5,
                              color: colorScheme.bodyText,
                              height: 1.5,
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Divider(
                            color: colorScheme.borderColor.withValues(alpha: 0.5),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "如有問題或版權疑慮，歡迎來信詢問：",
                            style: TextStyle(
                              fontSize: 12,
                              color: colorScheme.subtitleText,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 4),
                          SelectableText(
                            "nsysu.review.prude496@slmails.com",
                            style: TextStyle(
                              fontSize: 13,
                              color: colorScheme.accentBlue,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSpecialThanksCard(
    BuildContext context,
    ColorScheme colorScheme,
  ) {
    return Container(
      padding: const EdgeInsets.all(20.0),
      decoration: LayoutStyleNotifier.instance.isLiquidGlass
          ? glassCardDecoration(context, borderRadius: 20)
          : BoxDecoration(
              color: colorScheme.cardBackground,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: colorScheme.borderColor, width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  spreadRadius: 1,
                  blurRadius: 5,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.favorite_rounded, color: Colors.redAccent, size: 20),
              const SizedBox(width: 8),
              Text(
                "特別感謝",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.primaryText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildThanksItem(
            context,
            colorScheme,
            title: "NSYSU Open Development Community\n中山大學開源社群",
            subtitle: "特別感謝社群內許多熱心開源的夥伴，無私地貢獻了精湛的程式碼架構與核心模組，為本專案奠定了無可替代的穩健基石。",
            icon: Icons.people_outline_rounded,
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8.0),
            child: Divider(),
          ),
          _buildThanksItem(
            context,
            colorScheme,
            title: "中山大學 GDG on Campus x 程式設計社",
            subtitle: "感謝技術社群與社團夥伴慷慨提供了專業且具建設性的產品、設計方向及資訊安全建議。",
            icon: Icons.tips_and_updates_outlined,
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8.0),
            child: Divider(),
          ),
          _buildThanksItem(
            context,
            colorScheme,
            title: "ClearGrad. 畢經之路",
            subtitle:
                "本專案部分創意靈感源於「© 2026 ClearGrad. 畢經之路」（由 葉峻銓 創作，邱俊博 搭配色彩）。並特別感謝 葉峻銓 為本專案提供寶貴的想法與功能建議。",
            icon: Icons.palette_outlined,
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8.0),
            child: Divider(),
          ),
          _buildThanksItem(
            context,
            colorScheme,
            title: "Sunny Fan",
            subtitle:
                "特別感謝他長期擔任本專案的專屬測試員，無論大小 Bug 均在第一時間詳盡回報，協助系統穩定度把關，更給予了開發者無比的溫暖與前行動力。",
            icon: Icons.person_outline_rounded,
          ),
        ],
      ),
    );
  }

  Widget _buildThanksItem(
    BuildContext context,
    ColorScheme colorScheme, {
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: colorScheme.accentBlue.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 22, color: colorScheme.accentBlue),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.primaryText,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.subtitleText,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCreditsCard(BuildContext context, ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(20.0),
      decoration: LayoutStyleNotifier.instance.isLiquidGlass
          ? glassCardDecoration(context, borderRadius: 20)
          : BoxDecoration(
              color: colorScheme.cardBackground,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: colorScheme.borderColor, width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  spreadRadius: 1,
                  blurRadius: 5,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.info_outline_rounded,
                color: colorScheme.accentBlue,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                "素材與開源宣告",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.primaryText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            "本應用程式部分圖示與視覺素材來自於開源社群與平台，在此致謝：\n\n"
            "• Icon 'ic_school' designed by lutfix from Flaticon",
            style: TextStyle(
              fontSize: 13,
              color: colorScheme.bodyText.withValues(alpha: 0.9),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLicenseCard(BuildContext context, ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(20.0),
      decoration: LayoutStyleNotifier.instance.isLiquidGlass
          ? glassCardDecoration(context, borderRadius: 20)
          : BoxDecoration(
              color: colorScheme.cardBackground,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: colorScheme.borderColor, width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  spreadRadius: 1,
                  blurRadius: 5,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.description_outlined,
                color: colorScheme.accentBlue,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                "開源授權條款 (MIT)",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.primaryText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14.0),
            decoration: BoxDecoration(
              color: colorScheme.secondaryCardBackground,
              borderRadius: BorderRadius.circular(12),
            ),
            child: SelectableText(
              "MIT License\n\n"
              "Copyright (c) 2026 Edwin Chu\n\n"
              "Permission is hereby granted, free of charge, to any person obtaining a copy "
              "of this software and associated documentation files (the \"Software\"), to deal "
              "in the Software without restriction, including without limitation the rights "
              "to use, copy, modify, merge, publish, distribute, sublicense, and/or sell "
              "copies of the Software, and to permit persons to whom the Software is "
              "furnished to do so, subject to the following conditions:\n\n"
              "The above copyright notice and this permission notice shall be included in all "
              "copies or substantial portions of the Software.\n\n"
              "THE SOFTWARE IS PROVIDED \"AS IS\", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR "
              "IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, "
              "FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE "
              "AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER "
              "LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, "
              "OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE "
              "SOFTWARE.",
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.bodyText.withValues(alpha: 0.9),
                height: 1.55,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGitHubButton(BuildContext context, ColorScheme colorScheme) {
    final isLiquidGlass = LayoutStyleNotifier.instance.isLiquidGlass;
    final isDark = colorScheme.isDark;
    return ElevatedButton.icon(
      onPressed: _launchGitHubUrl,
      icon: const Icon(Icons.launch_rounded, size: 18),
      label: const Text(
        "GitHub 開源網址",
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: isLiquidGlass
            ? (isDark
                ? Colors.white.withValues(alpha: 0.10)
                : Colors.white.withValues(alpha: 0.5))
            : colorScheme.accentBlue,
        foregroundColor: isLiquidGlass ? colorScheme.primaryText : Colors.white,
        side: isLiquidGlass
            ? BorderSide(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.14)
                    : Colors.white.withValues(alpha: 0.4),
              )
            : null,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 0,
      ),
    );
  }
}
