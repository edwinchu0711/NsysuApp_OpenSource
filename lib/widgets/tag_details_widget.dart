import 'package:flutter/material.dart';
import '../models/program_model.dart';

class TagDetailsWidget extends StatelessWidget {
  final List<TagDetail> tagDetails;
  final ColorScheme colorScheme;

  const TagDetailsWidget({
    super.key,
    required this.tagDetails,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    // 暫時隱藏：直接回傳一個空的 Widget
    return const SizedBox.shrink();
  }
}
