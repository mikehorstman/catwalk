import 'package:flutter/material.dart';

import '../data/sprite_library.dart';
import '../domain/cat_action.dart';
import 'sprite_manifest.dart';

/// Placeholder fur is drawn in mid greys. Multiplying by the cat's colour would
/// darken everything by that grey, so the tint is lifted back up by this much.
const double furGreyGain = 1.5;

/// A colour matrix that turns the grey fur sheet into [tint].
///
/// Light greys (belly, highlights) come out lighter than the base colour and
/// dark greys (the far legs) darker, so the shading survives. A small lift keeps
/// very dark coats from collapsing into a silhouette.
ColorFilter furTint(Color tint) {
  final r = tint.r * furGreyGain;
  final g = tint.g * furGreyGain;
  final b = tint.b * furGreyGain;
  final luminance = 0.2126 * tint.r + 0.7152 * tint.g + 0.0722 * tint.b;
  final lift = (1 - luminance) * 0.12 * 255 * (luminance < 0.25 ? 1 : 0);
  return ColorFilter.matrix(<double>[
    r, 0, 0, 0, lift, //
    0, g, 0, 0, lift,
    0, 0, b, 0, lift,
    0, 0, 0, 1, 0,
  ]);
}

/// One frame of a sprite action, tinted and standing on the box's bottom edge.
///
/// The box is square and the room puts its bottom edge on the floor, so the
/// paint moves the art by the foot anchor: the cat stands on the floor line
/// whatever pose the frame is in.
class SpriteCatFrame extends StatelessWidget {
  /// [elapsed] is time since the action began; [size] is the box side in
  /// logical pixels.
  const SpriteCatFrame({
    required this.sheet,
    required this.manifest,
    required this.tint,
    required this.facing,
    required this.elapsed,
    required this.size,
    super.key,
  });

  /// The decoded sheets and manifest entry to draw.
  final SpriteSheet sheet;

  /// Supplies the frame size and foot anchor in sheet pixels.
  final SpriteManifest manifest;

  /// The cat's coat colour, applied to the fur strip through [furTint].
  final Color tint;

  /// Art faces right; [CatFacing.left] mirrors it.
  final CatFacing facing;

  /// Time since the action started. Picks the frame via [spriteFrameAt].
  final Duration elapsed;

  /// Side of the square box, in logical pixels. The frame is scaled to the box
  /// width.
  final double size;

  @override
  Widget build(BuildContext context) {
    final frame = spriteFrameAt(sheet.action, elapsed.inMilliseconds / 1000.0);
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _SpritePainter(
          sheet: sheet,
          frame: frame,
          frameSize: Size(manifest.frameSize[0], manifest.frameSize[1]),
          footAnchor: Offset(manifest.footAnchor[0], manifest.footAnchor[1]),
          tint: tint,
          flipped: facing == CatFacing.left,
        ),
      ),
    );
  }
}

/// Paints one frame of the fur strip (tinted) and the details strip (untinted)
/// into the box.
class _SpritePainter extends CustomPainter {
  _SpritePainter({
    required this.sheet,
    required this.frame,
    required this.frameSize,
    required this.footAnchor,
    required this.tint,
    required this.flipped,
  });

  /// The decoded sheets to draw.
  final SpriteSheet sheet;

  /// Index of the frame to cut out of the strips, counting from 0.
  final int frame;

  /// Size of one frame in sheet pixels.
  final Size frameSize;

  /// The feet inside a frame, in sheet pixels.
  final Offset footAnchor;

  /// The cat's coat colour, passed to [furTint].
  final Color tint;

  /// True to mirror the cat so it faces left.
  final bool flipped;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / frameSize.width;
    final src = Rect.fromLTWH(
      frame * frameSize.width,
      0,
      frameSize.width,
      frameSize.height,
    );
    final dst = Rect.fromLTWH(
      0,
      0,
      frameSize.width * scale,
      frameSize.height * scale,
    );

    canvas.save();
    // Art faces right; left is the same frame mirrored about the box centre.
    if (flipped) {
      canvas.translate(size.width, 0);
      canvas.scale(-1, 1);
    }
    // Put the feet on the bottom edge, centred on the box.
    canvas.translate(
      size.width / 2 - footAnchor.dx * scale,
      size.height - footAnchor.dy * scale,
    );

    final fur = Paint()
      ..filterQuality = FilterQuality.medium
      ..colorFilter = furTint(tint);
    canvas.drawImageRect(sheet.fur, src, dst, fur);

    final details = sheet.details;
    if (details != null) {
      canvas.drawImageRect(
        details,
        src,
        dst,
        Paint()..filterQuality = FilterQuality.medium,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_SpritePainter old) =>
      old.frame != frame ||
      old.sheet != sheet ||
      old.tint != tint ||
      old.flipped != flipped ||
      old.frameSize != frameSize;
}
