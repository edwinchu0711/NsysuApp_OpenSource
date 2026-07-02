import 'package:flutter/material.dart';
import '../models/program_model.dart';
import '../theme/app_theme.dart';

class EligibilityBannerWidget extends StatelessWidget {
  final EligibilityResult result;

  const EligibilityBannerWidget({
    super.key,
    required this.result,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isEligible = result.eligible;
    final bannerColor = isEligible
        ? (colorScheme.isDark
              ? Colors.green[900]!.withValues(alpha: 0.3)
              : Colors.green[50])
        : (colorScheme.isDark
              ? Colors.red[900]!.withValues(alpha: 0.3)
              : Colors.red[50]);
    final borderColor = isEligible
        ? Colors.green.withValues(alpha: 0.3)
        : Colors.red.withValues(alpha: 0.3);
    final textColor = isEligible
        ? (colorScheme.isDark ? Colors.green[300] : Colors.green[700])
        : (colorScheme.isDark ? Colors.red[300] : Colors.red[700]);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bannerColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                isEligible ? '✓' : '✗',
                style: TextStyle(fontSize: 18, color: textColor),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isEligible ? '目前修課進度符合資格' : '尚未符合資格',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w400,
                    color: textColor,
                  ),
                ),
              ),
            ],
          ),
          if (!isEligible && result.unmetRequirements.isNotEmpty) ...[
            const SizedBox(height: 8),
            ...result.unmetRequirements.map(
              (req) => Padding(
                padding: const EdgeInsets.only(left: 28, bottom: 2),
                child: Text(
                  '• $req',
                  style: TextStyle(fontSize: 13, color: textColor),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}