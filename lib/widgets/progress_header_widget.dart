import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/program_model.dart';
import '../theme/app_theme.dart';
import 'credit_badge_widget.dart';
import 'progress_ring.dart';

class ProgressHeaderWidget extends StatelessWidget {
  final EligibilityResult result;
  final double completionRate;
  final CompletionRange completionRange;
  final bool isFavorite;
  final VoidCallback? onFavoriteToggle;
  final String? pdfLink;

  const ProgressHeaderWidget({
    super.key,
    required this.result,
    required this.completionRate,
    required this.completionRange,
    this.isFavorite = false,
    this.onFavoriteToggle,
    this.pdfLink,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final showButtons = MediaQuery.of(context).size.width >= 900;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ProgressRing(
                progress: completionRate,
                size: 100,
                strokeWidth: 8,
                rangeMax: completionRange.hasRange
                    ? completionRange.maxRate
                    : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            result.programName,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: colorScheme.primaryText,
                            ),
                          ),
                        ),
                        if (showButtons && pdfLink != null && pdfLink!.isNotEmpty)
                          IconButton(
                            icon: const Icon(Icons.picture_as_pdf_rounded),
                            tooltip: '查看 PDF 詳細資料',
                            onPressed: () => _launchUrl(pdfLink!),
                            constraints: const BoxConstraints(),
                            padding: const EdgeInsets.all(4),
                          ),
                        if (showButtons && onFavoriteToggle != null)
                          IconButton(
                            icon: Icon(
                              isFavorite ? Icons.star_rounded : Icons.star_outline_rounded,
                              color: isFavorite ? Colors.amber[600] : colorScheme.primaryText,
                            ),
                            tooltip: isFavorite ? '移除最愛' : '加入最愛',
                            onPressed: onFavoriteToggle,
                            constraints: const BoxConstraints(),
                            padding: const EdgeInsets.all(4),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${result.academicYear} 學年度',
                      style: TextStyle(
                        fontSize: 13,
                        color: colorScheme.subtitleText,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 16,
                      runSpacing: 8,
                      children: [
                        CreditBadgeWidget(
                          label: '總學分',
                          value:
                              '${result.totalCreditsEarned} / ${result.totalCreditsRequired}',
                          colorScheme: colorScheme,
                        ),
                        CreditBadgeWidget(
                          label: '外系學分',
                          value:
                              '${result.externalCreditsEarned} / ${result.externalCreditsRequired}',
                          colorScheme: colorScheme,
                        ),
                        ...result.tagDetails.map(
                          (td) => CreditBadgeWidget(
                            label: td.tag == 'starred' ? '＊號選修' : td.tag,
                            value: '${td.earned} / ${td.required}',
                            colorScheme: colorScheme,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _buildDisclaimerBanner(context, colorScheme),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDisclaimerBanner(BuildContext context, ColorScheme colorScheme) {
    const ctdrUrl = 'https://ctdr.nsysu.edu.tw/class2.php';
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: colorScheme.isDark
            ? const Color(0xFF1A2540)
            : const Color(0xFFEBF5FF),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: colorScheme.accentBlue.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 16, color: colorScheme.accentBlue),
          const SizedBox(width: 8),
          Expanded(child: _buildDisclaimerText(context, colorScheme, ctdrUrl)),
        ],
      ),
    );
  }

  Widget _buildDisclaimerText(BuildContext context, ColorScheme colorScheme, String ctdrUrl) {
    final themeFontFamily = Theme.of(context).textTheme.bodyMedium?.fontFamily;
    final style = TextStyle(
      fontFamily: themeFontFamily,
      fontSize: 12,
      color: colorScheme.subtitleText,
    );
    final linkStyle = TextStyle(
      fontFamily: themeFontFamily,
      fontSize: 12,
      color: colorScheme.accentBlue,
      decoration: TextDecoration.underline,
    );

    if (pdfLink != null) {
      return Text.rich(
        TextSpan(
          style: style,
          children: [
            const TextSpan(text: '以下資訊僅供參考，請到中山大學'),
            WidgetSpan(
              child: GestureDetector(
                onTap: () => _launchUrl(ctdrUrl),
                child: Text('學程專區', style: linkStyle),
              ),
            ),
            const TextSpan(text: '查詢，或查看'),
            WidgetSpan(
              child: GestureDetector(
                onTap: () => _launchUrl(pdfLink!),
                child: Text('PDF詳細資料', style: linkStyle),
              ),
            ),
          ],
        ),
      );
    }

    return Text.rich(
      TextSpan(
        style: style,
        children: [
          const TextSpan(text: '以下資訊僅供參考，請到中山大學'),
          WidgetSpan(
            child: GestureDetector(
              onTap: () => _launchUrl(ctdrUrl),
              child: Text('學程專區', style: linkStyle),
            ),
          ),
          const TextSpan(text: '查詢'),
        ],
      ),
    );
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
