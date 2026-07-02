import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class OwnDepartmentsInfoWidget extends StatelessWidget {
  final List<String> ownDepartments;

  const OwnDepartmentsInfoWidget({
    super.key,
    required this.ownDepartments,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: colorScheme.secondaryCardBackground,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 16, color: colorScheme.accentBlue),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '外系學分排除：${ownDepartments.join('、')}',
              style: TextStyle(fontSize: 13, color: colorScheme.subtitleText),
            ),
          ),
        ],
      ),
    );
  }
}