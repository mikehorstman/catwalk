import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme.dart';

/// A ring that fills as [value] goes from 0 to 1, with [child] inside.
class ProgressRing extends StatelessWidget {
  const ProgressRing({
    required this.value,
    required this.child,
    this.size = 280,
    this.strokeWidth = 16,
    super.key,
  });

  /// Progress from 0 to 1. Values outside that range are clamped.
  final double value;

  /// Shown in the middle of the ring.
  final Widget child;

  /// Width and height of the ring, in logical pixels.
  final double size;

  /// Thickness of the ring, in logical pixels.
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    final target = value.clamp(0.0, 1.0);
    final instant = MediaQuery.disableAnimationsOf(context);
    return Semantics(
      label: 'Progress ${(target * 100).round()} percent',
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: target),
        duration: instant ? Duration.zero : const Duration(milliseconds: 700),
        curve: Curves.easeOutCubic,
        builder: (context, v, child) => CustomPaint(
          painter: _RingPainter(value: v, strokeWidth: strokeWidth),
          child: SizedBox(
            width: size,
            height: size,
            child: Center(child: child),
          ),
        ),
        child: child,
      ),
    );
  }
}

/// Draws the pale full circle (track) and the orange arc on top, starting at
/// 12 o'clock.
class _RingPainter extends CustomPainter {
  _RingPainter({required this.value, required this.strokeWidth});

  /// Fraction of the circle to fill, 0 to 1.
  final double value;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final inset = rect.deflate(strokeWidth / 2);
    final track = Paint()
      ..color = CatwalkColors.orangeSoft
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    final bar = Paint()
      ..color = CatwalkColors.orange
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(inset, 0, 2 * math.pi, false, track);
    if (value > 0) {
      canvas.drawArc(inset, -math.pi / 2, 2 * math.pi * value, false, bar);
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.value != value || old.strokeWidth != strokeWidth;
}
