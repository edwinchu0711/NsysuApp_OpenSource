import 'package:flutter/material.dart';

import '../../../models/course_assistant_models.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/layout_style_notifier.dart';
import '../course_assistant_constants.dart';
import '../course_assistant_utils.dart';
import '../widgets/detail_row.dart';

/// 自訂行程詳情對話框（原 _showCustomEventDetail 的 dialog 內容）
class CustomEventDetailDialog extends StatelessWidget {
  final CustomEvent event;
  final Future<void> Function(String eventId) onRemove;

  const CustomEventDetailDialog({
    super.key,
    required this.event,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth >= 750;
    String timeStr =
        "星期${kFullWeekDays[event.day - 1]} (${event.periods.join(', ')}節)";
    final colorScheme = Theme.of(context).colorScheme;
    final eventColor = getCourseColor(event.title);

    final gradient = LinearGradient(
      colors: [
        eventColor,
        HSVColor.fromColor(eventColor)
            .withValue(
              (HSVColor.fromColor(eventColor).value * 0.82).clamp(0.0, 1.0),
            )
            .toColor(),
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    final List<Widget> detailRows = [];

    // 1. 時間
    detailRows.add(
      ModernDetailRow(
        icon: Icons.access_time_filled_rounded,
        iconColor: Colors.deepPurpleAccent,
        label: "行程時間",
        content: Text(
          timeStr,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: colorScheme.primaryText,
          ),
        ),
      ),
    );

    // 2. 位置
    if (event.location.isNotEmpty) {
      detailRows.add(
        ModernDetailRow(
          icon: Icons.location_on_rounded,
          iconColor: Colors.redAccent,
          label: "行程地點",
          content: Text(
            event.location,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: colorScheme.primaryText,
            ),
          ),
        ),
      );
    }

    // 3. 詳細內容
    if (event.details.isNotEmpty) {
      detailRows.add(
        ModernDetailRow(
          icon: Icons.notes_rounded,
          iconColor: Colors.orange,
          label: "詳細內容",
          content: Text(
            event.details,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: colorScheme.primaryText,
            ),
          ),
        ),
      );
    }

    final isLiquidGlass = LayoutStyleNotifier.instance.isLiquidGlass;

    final contentWidget = Container(
      width: isTablet ? 450 : double.maxFinite,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (detailRows.isNotEmpty) ...[
              for (int i = 0; i < detailRows.length; i++) ...[
                detailRows[i],
                if (i < detailRows.length - 1) const Divider(height: 1),
              ],
            ],
          ],
        ),
      ),
    );

    if (isLiquidGlass) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      return Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        child: Container(
          width: isTablet ? 450 : double.maxFinite,
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF1C2333).withValues(alpha: 0.92)
                : Colors.white.withValues(alpha: 0.94),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.18)
                  : Colors.white.withValues(alpha: 0.70),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.15),
                blurRadius: 28,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(19),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Title
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 20,
                  ),
                  decoration: BoxDecoration(gradient: gradient),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          "其他行程",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        event.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                // Content
                Flexible(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
                    child: contentWidget,
                  ),
                ),
                // Actions
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                  child: Row(
                    children: [
                      TextButton(
                        onPressed: () async {
                          Navigator.pop(context);
                          await onRemove(event.id);
                        },
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.red,
                        ),
                        child: const Text("刪除此行程"),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(
                          "關閉",
                          style: TextStyle(color: colorScheme.subtitleText),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      clipBehavior: Clip.antiAlias,
      titlePadding: EdgeInsets.zero,
      title: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        decoration: BoxDecoration(gradient: gradient),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                "其他行程",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              event.title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
      contentPadding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
      content: contentWidget,
      actions: [
        TextButton(
          onPressed: () async {
            Navigator.pop(context);
            await onRemove(event.id);
          },
          style: TextButton.styleFrom(foregroundColor: Colors.red),
          child: const Text("刪除此行程"),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text("關閉", style: TextStyle(color: colorScheme.subtitleText)),
        ),
      ],
    );
  }
}
