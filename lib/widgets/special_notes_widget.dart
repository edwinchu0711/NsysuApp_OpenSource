import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class SpecialNotesWidget extends StatelessWidget {
  final List<String> notes;

  const SpecialNotesWidget({
    super.key,
    required this.notes,
  });

  @override
  Widget build(BuildContext context) {
    if (notes.isEmpty) return const SizedBox.shrink();

    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.isDark
            ? const Color(0xFF1A2540)
            : const Color(0xFFF5F0E8),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: colorScheme.isDark
              ? Colors.orange.withValues(alpha: 0.3)
              : const Color(0xFFD4A84B).withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.note_outlined,
                size: 16,
                color: colorScheme.isDark
                    ? const Color(0xFFFFCA28)
                    : const Color(0xFF856404),
              ),
              const SizedBox(width: 8),
              Text(
                '備註',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: colorScheme.isDark
                      ? const Color(0xFFFFCA28)
                      : const Color(0xFF856404),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...notes.map(
            (note) => Padding(
              padding: const EdgeInsets.only(bottom: 4, left: 24),
              child: Text(
                '• $note',
                style: TextStyle(
                  fontSize: 13,
                  color: colorScheme.isDark
                      ? const Color(0xFFFFCA28)
                      : const Color(0xFF856404),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}