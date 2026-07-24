import 'package:flutter/material.dart';

class MainMenuItem {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final String section;
  final WidgetBuilder? pageBuilder;
  final VoidCallback onTap;

  MainMenuItem({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.section,
    this.pageBuilder,
    required this.onTap,
  });
}
