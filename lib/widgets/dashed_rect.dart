import 'package:flutter/material.dart';

/// A widget that paints a dashed rectangle border around its child.
class DashedRect extends StatelessWidget {
  final Widget child;
  final Color dashColor;
  final double dashLength;
  final double gapLength;
  final double strokeWidth;
  final double borderRadius;

  const DashedRect({
    super.key,
    required this.child,
    this.dashColor = Colors.grey,
    this.dashLength = 5,
    this.gapLength = 3,
    this.strokeWidth = 1,
    this.borderRadius = 6,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedRectPainter(
        dashColor: dashColor,
        dashLength: dashLength,
        gapLength: gapLength,
        strokeWidth: strokeWidth,
        borderRadius: borderRadius,
      ),
      child: child,
    );
  }
}

class _DashedRectPainter extends CustomPainter {
  final Color dashColor;
  final double dashLength;
  final double gapLength;
  final double strokeWidth;
  final double borderRadius;

  _DashedRectPainter({
    required this.dashColor,
    required this.dashLength,
    required this.gapLength,
    required this.strokeWidth,
    required this.borderRadius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = dashColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(borderRadius));

    final path = Path()..addRRect(rrect);

    final dashedPath = _dashPath(path, dashLength, gapLength);
    canvas.drawPath(dashedPath, paint);
  }

  Path _dashPath(Path source, double dashLen, double gapLen) {
    final metrics = source.computeMetrics();
    final path = Path();
    for (final metric in metrics) {
      double distance = 0;
      bool draw = true;
      while (distance < metric.length) {
        final len = draw ? dashLen : gapLen;
        if (distance + len > metric.length) {
          if (draw) {
            path.addPath(metric.extractPath(distance, metric.length), Offset.zero);
          }
          break;
        }
        if (draw) {
          path.addPath(metric.extractPath(distance, distance + len), Offset.zero);
        }
        distance += len;
        draw = !draw;
      }
    }
    return path;
  }

  @override
  bool shouldRepaint(covariant _DashedRectPainter oldDelegate) {
    return dashColor != oldDelegate.dashColor ||
        dashLength != oldDelegate.dashLength ||
        gapLength != oldDelegate.gapLength ||
        strokeWidth != oldDelegate.strokeWidth ||
        borderRadius != oldDelegate.borderRadius;
  }
}