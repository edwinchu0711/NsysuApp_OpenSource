import 'package:flutter/material.dart';

/// A widget that animates its child with a fade-in + upward slide,
/// with an optional stagger delay.
class StaggeredAppear extends StatefulWidget {
  final Widget child;
  final int delayMs;
  final Duration duration;

  const StaggeredAppear({
    super.key,
    required this.child,
    this.delayMs = 0,
    this.duration = const Duration(milliseconds: 400),
  });

  @override
  State<StaggeredAppear> createState() => _StaggeredAppearState();
}

class _StaggeredAppearState extends State<StaggeredAppear>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: widget.duration, vsync: this);
    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );
    // 用 double 追蹤 Y 偏移像素，動畫結束時為 0
    _slideAnimation = Tween<double>(
      begin: 12.0,
      end: 0.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    if (widget.delayMs > 0) {
      Future.delayed(Duration(milliseconds: widget.delayMs), () {
        if (mounted) _controller.forward();
      });
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: AnimatedBuilder(
        animation: _slideAnimation,
        builder: (context, child) => Transform.translate(
          // Transform.translate 完全在 paint 層操作
          // 不參與 layout，不影響 ListView 的 contentExtent
          offset: Offset(0, _slideAnimation.value),
          child: child,
        ),
        child: widget.child,
      ),
    );
  }
}