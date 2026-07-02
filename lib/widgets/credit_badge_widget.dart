import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class CreditBadgeWidget extends StatelessWidget {
  final String label;
  final String value;
  final ColorScheme colorScheme;

  const CreditBadgeWidget({
    super.key,
    required this.label,
    required this.value,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 12, color: colorScheme.subtitleText),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: colorScheme.primaryText,
          ),
        ),
      ],
    );
  }
}