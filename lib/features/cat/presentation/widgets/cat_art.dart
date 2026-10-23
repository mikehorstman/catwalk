import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../app/theme.dart';
import '../../domain/cat_appearance.dart';
import '../../domain/cat_mood.dart';

/// A flat cat drawn in code. A stand-in until final artwork exists.
///
/// Mood shows in the eyes, ears, and mouth, never in colour alone.
class CatArt extends StatefulWidget {
  const CatArt({
    required this.appearance,
    required this.mood,
    this.size = 200,
    super.key,
  });

  /// Coat colour set to draw.
  final CatAppearance appearance;

  /// Drives the face: happy = closed smiling eyes, neutral = round eyes, sad = drooping
  /// ears, worried brows and a frown.
  final CatMood mood;

  /// Width and height of the drawing, in logical pixels.
  final double size;

  @override
  State<CatArt> createState() => _CatArtState();
}

/// Holds the looping animation (tail sway, breathing, blink) and pauses it when the
/// system asks for reduced motion.
class _CatArtState extends State<CatArt> with SingleTickerProviderStateMixin {
  /// Runs 0 to 1 over 4 seconds, forever; the painter turns it into movement.
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Cat, ${_moodWord(widget.mood)}',
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: CustomPaint(
          painter: _CatPainter(
            animation: _controller,
            appearance: widget.appearance,
            mood: widget.mood,
          ),
        ),
      ),
    );
  }
}

/// Plain word for the screen reader label.
String _moodWord(CatMood mood) => switch (mood) {
  CatMood.happy => 'happy',
  CatMood.neutral => 'content',
  CatMood.sad => 'sad',
};

/// Paints the cat on a 200 x 200 design grid, scaled to the widget size. [animation]
/// is 0 to 1 and repeats; it moves the tail and body and makes the blink.
class _CatPainter extends CustomPainter {
  _CatPainter({
    required this.animation,
    required this.appearance,
    required this.mood,
  }) : super(repaint: animation);

  final Animation<double> animation;
  final CatAppearance appearance;
  final CatMood mood;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 200);
    final t = animation.value;
    final wave = math.sin(t * 2 * math.pi);

    final coat = Paint()..color = appearance.color;
    final shade = Paint()
      ..color = Color.lerp(appearance.color, Colors.black, 0.2)!;
    final dark = appearance.color.computeLuminance() < 0.25;
    final faceColor = dark ? CatwalkColors.cream : CatwalkColors.ink;
    final line = Paint()
      ..color = faceColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;

    // Tail sways.
    canvas.save();
    canvas.translate(138, 172);
    canvas.rotate(0.14 * wave);
    final tail = Path()
      ..moveTo(0, 0)
      ..cubicTo(40, -4, 54, -52, 30, -80);
    canvas.drawPath(
      tail,
      Paint()
        ..color = appearance.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 15
        ..strokeCap = StrokeCap.round,
    );
    canvas.restore();

    // Body breathes.
    canvas.save();
    canvas.translate(100, 192);
    canvas.scale(1, 1 + 0.012 * wave);
    canvas.translate(-100, -192);
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(100, 144), width: 98, height: 108),
      coat,
    );
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(78, 191), width: 36, height: 18),
      shade,
    );
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(122, 191), width: 36, height: 18),
      shade,
    );
    canvas.restore();

    // Ears: they droop when sad.
    final droop = mood == CatMood.sad ? 1.0 : 0.0;
    for (final m in [-1.0, 1.0]) {
      final outer = Path()
        ..moveTo(100 + m * 38, 76)
        ..lineTo(100 + m * (34 + droop * 16), 28 + droop * 20)
        ..lineTo(100 + m * 8, 52)
        ..close();
      canvas.drawPath(outer, coat);
      final inner = Path()
        ..moveTo(100 + m * 32, 70)
        ..lineTo(100 + m * (31 + droop * 13), 40 + droop * 17)
        ..lineTo(100 + m * 15, 54)
        ..close();
      canvas.drawPath(inner, shade);
    }

    // Head.
    canvas.drawCircle(const Offset(100, 92), 42, coat);

    // Eyes.
    final blink = (t > 0.9 && t < 0.95);
    for (final m in [-1.0, 1.0]) {
      final x = 100 + m * 16;
      const y = 88.0;
      if (mood == CatMood.happy) {
        canvas.drawArc(
          Rect.fromCenter(center: Offset(x, y + 3), width: 15, height: 13),
          math.pi,
          math.pi,
          false,
          line,
        );
      } else if (blink) {
        canvas.drawLine(Offset(x - 6, y), Offset(x + 6, y), line);
      } else {
        canvas.drawCircle(Offset(x, y), 4.6, Paint()..color = faceColor);
      }
      if (mood == CatMood.sad) {
        canvas.drawLine(
          Offset(100 + m * 25, 79),
          Offset(100 + m * 8, 74),
          line..strokeWidth = 2.6,
        );
        line.strokeWidth = 3.5;
      }
    }

    // Nose and mouth.
    final nose = Path()
      ..moveTo(95, 99)
      ..lineTo(105, 99)
      ..lineTo(100, 105)
      ..close();
    canvas.drawPath(nose, Paint()..color = const Color(0xFFE88A8A));

    final mouth = line..strokeWidth = 2.6;
    if (mood == CatMood.sad) {
      canvas.drawArc(
        Rect.fromCenter(center: const Offset(100, 117), width: 18, height: 10),
        math.pi + 0.3,
        math.pi - 0.6,
        false,
        mouth,
      );
    } else {
      final w = mood == CatMood.happy ? 22.0 : 14.0;
      canvas.drawArc(
        Rect.fromCenter(center: const Offset(100, 108), width: w, height: 12),
        0.25,
        math.pi - 0.5,
        false,
        mouth,
      );
    }
    line.strokeWidth = 3.5;

    // Whiskers.
    final whisker = Paint()
      ..color = faceColor.withValues(alpha: 0.55)
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    for (final m in [-1.0, 1.0]) {
      canvas.drawLine(
        Offset(100 + m * 30, 104),
        Offset(100 + m * 56, 98),
        whisker,
      );
      canvas.drawLine(
        Offset(100 + m * 30, 109),
        Offset(100 + m * 58, 110),
        whisker,
      );
    }
  }

  @override
  bool shouldRepaint(_CatPainter old) =>
      old.mood != mood || old.appearance != appearance;
}

/// What the room shows while the cat has run away: an empty cushion instead of
/// the cat.
class EmptyCushion extends StatelessWidget {
  const EmptyCushion({this.size = 200, super.key});

  /// Width and height, in logical pixels.
  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Empty cushion. The cat is away.',
      child: SizedBox(
        width: size,
        height: size,
        child: Align(
          alignment: const Alignment(0, 0.55),
          child: Container(
            width: size * 0.7,
            height: size * 0.26,
            decoration: BoxDecoration(
              color: CatwalkColors.orangeSoft,
              borderRadius: BorderRadius.circular(size),
              border: Border.all(color: CatwalkColors.orange, width: 3),
            ),
          ),
        ),
      ),
    );
  }
}
