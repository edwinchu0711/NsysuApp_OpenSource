import 'dart:math' as math show pi;
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// A circular progress ring that displays a percentage in the center.
///
/// [progress] is a value between 0.0 and 1.0.
/// [size] is the diameter of the ring.
class ProgressRing extends StatefulWidget {
  final double progress;
  final double size;
  final double strokeWidth;
  final double? rangeMax;

  const ProgressRing({
    super.key,
    required this.progress,
    this.size = 200,
    this.strokeWidth = 8,
    this.rangeMax,
  });

  @override
  State<ProgressRing> createState() => _ProgressRingState();
}

class _ProgressRingState extends State<ProgressRing>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    _controller.forward();
  }

  @override
  void didUpdateWidget(ProgressRing oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.progress != widget.progress) {
      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ListenableBuilder(
      listenable: _animation,
      builder: (context, child) {
        final animatedProgress = _animation.value * widget.progress;
        final percentage = (animatedProgress * 100).round();
        final percentageForColor = (widget.progress * 100).round();
        final progressColor = _progressColor(percentageForColor, colorScheme);

        return SizedBox(
          width: widget.size,
          height: widget.size,
          child: CustomPaint(
            size: Size(widget.size, widget.size),
            painter: _ProgressRingPainter(
              progress: animatedProgress.clamp(0.0, 1.0),
              progressColor: progressColor,
              backgroundColor: colorScheme.isDark
                  ? const Color(0xFF2A3040)
                  : const Color(0xFFE0E0E0),
              strokeWidth: widget.strokeWidth,
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$percentage%',
                    style: TextStyle(
                      fontSize: widget.size * 0.25,
                      fontWeight: FontWeight.w700,
                      color: progressColor,
                    ),
                  ),
                  Text(
                    '完成度',
                    style: TextStyle(
                      fontSize: widget.size * 0.1,
                      color: colorScheme.subtitleText,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Color _progressColor(int percentage, ColorScheme colorScheme) {
    if (percentage >= 70) {
      return colorScheme.isDark ? Colors.green[300]! : Colors.green[700]!;
    } else if (percentage >= 30) {
      return colorScheme.isDark ? Colors.orange[300]! : Colors.orange[700]!;
    } else {
      return colorScheme.isDark ? Colors.red[300]! : Colors.red[700]!;
    }
  }
}

class _ProgressRingPainter extends CustomPainter {
  final double progress;
  final Color progressColor;
  final Color backgroundColor;
  final double strokeWidth;

  _ProgressRingPainter({
    required this.progress,
    required this.progressColor,
    required this.backgroundColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    // Background circle
    final bgPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawCircle(center, radius, bgPaint);

    // Progress arc
    final progressPaint = Paint()
      ..color = progressColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final startAngle = -math.pi / 2;
    final sweepAngle = 2 * math.pi * progress;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _ProgressRingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.progressColor != progressColor ||
        oldDelegate.backgroundColor != backgroundColor ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}