import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../cat/domain/cat_appearance.dart';
import '../../cat/domain/cat_mood.dart';
import '../../cat/presentation/widgets/cat_art.dart';
import '../data/sprite_library.dart';
import '../domain/cat_action.dart';
import 'sprite_cat.dart';

/// Turns "this cat is doing this, facing that" into pixels.
///
/// The room knows nothing about how a cat is drawn. Swapping the placeholder
/// for your sprite sheets means implementing this once, not touching the room.
abstract interface class CatAnimationSet {
  /// A frame of [action] for a [mood], [elapsed] into the action.
  ///
  /// [appearance] picks the coat colour. [facing] is which way the cat looks;
  /// art is drawn facing right and mirrored for left. [elapsed] is time since
  /// this action began, so a looping animation can pick its frame. [size] is
  /// the side of the square the cat is drawn in, in logical pixels, with the
  /// feet on the bottom edge.
  Widget frame(
    BuildContext context, {
    required CatAppearance appearance,
    required CatAction action,
    required CatMood mood,
    required CatFacing facing,
    required Duration elapsed,
    required double size,
  });
}

/// The drawn-in-code cat, posed per action. A stand-in until real art exists.
///
/// Every pose is a transform of the same vector cat, so it looks rough for the
/// actions the cat was never drawn for (climbing, sleeping). That is the point:
/// it is a placeholder, and the sprite set replaces it without touching the room.
class PlaceholderCatAnimations implements CatAnimationSet {
  const PlaceholderCatAnimations();

  @override
  Widget frame(
    BuildContext context, {
    required CatAppearance appearance,
    required CatAction action,
    required CatMood mood,
    required CatFacing facing,
    required Duration elapsed,
    required double size,
  }) {
    final t = elapsed.inMilliseconds / 1000.0;
    final cat = CatArt(appearance: appearance, mood: mood, size: size);
    final posed = _pose(cat, action, t);
    return facing == CatFacing.right ? posed : _mirror(posed);
  }

  /// Applies a simple transform (bob, squash, tilt) to the vector cat to
  /// suggest [action]. [t] is seconds into the action, which drives the wobble.
  Widget _pose(Widget cat, CatAction action, double t) {
    return switch (action) {
      // A walk bob: two small hops a second.
      CatAction.walk => Transform.translate(
        offset: Offset(0, -2.5 * math.sin(t * 9)),
        child: cat,
      ),
      // Flattened and wider, pressed to the floor.
      CatAction.sleep => Transform.scale(
        scaleX: 1.25,
        scaleY: 0.72,
        alignment: Alignment.bottomCenter,
        child: cat,
      ),
      // Nose down to a paw.
      CatAction.groom => Transform.rotate(
        angle: 0.16 + 0.04 * math.sin(t * 6),
        alignment: Alignment.bottomCenter,
        child: Transform.scale(
          scaleY: 0.95,
          alignment: Alignment.bottomCenter,
          child: cat,
        ),
      ),
      CatAction.perch => Transform.scale(
        scaleX: 1.1,
        scaleY: 0.85,
        alignment: Alignment.bottomCenter,
        child: cat,
      ),
      CatAction.climbUp => Transform.rotate(angle: -0.12, child: cat),
      CatAction.climbDown => Transform.rotate(angle: 0.12, child: cat),
      CatAction.sit => Transform.scale(
        scaleY: 0.92,
        alignment: Alignment.bottomCenter,
        child: cat,
      ),
      // A pounce: a quick bounce and a lean towards the toy.
      CatAction.play => Transform.translate(
        offset: Offset(0, -6 * math.sin(t * 7).abs()),
        child: Transform.rotate(
          angle: 0.10 * math.sin(t * 7),
          alignment: Alignment.bottomCenter,
          child: cat,
        ),
      ),
      CatAction.idle => cat,
    };
  }

  /// Art is drawn facing right, so left is the same art flipped.
  Widget _mirror(Widget child) {
    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.diagonal3Values(-1, 1, 1),
      child: child,
    );
  }
}

/// Draws cats from the sprite sheets in `assets/cats/`.
///
/// An action with no sheet keeps using the placeholder, so art can arrive one
/// action at a time and nothing in the room changes.
class SpriteCatAnimations implements CatAnimationSet {
  const SpriteCatAnimations(
    this.library, {
    this.fallback = const PlaceholderCatAnimations(),
  });

  /// The decoded sheets to draw from.
  final SpriteLibrary library;

  /// Used for any action the [library] has no art for.
  final CatAnimationSet fallback;

  @override
  Widget frame(
    BuildContext context, {
    required CatAppearance appearance,
    required CatAction action,
    required CatMood mood,
    required CatFacing facing,
    required Duration elapsed,
    required double size,
  }) {
    final sheet = library.lookup(action, mood);
    if (sheet == null) {
      return fallback.frame(
        context,
        appearance: appearance,
        action: action,
        mood: mood,
        facing: facing,
        elapsed: elapsed,
        size: size,
      );
    }
    return SpriteCatFrame(
      sheet: sheet,
      manifest: library.manifest,
      tint: appearance.color,
      facing: facing,
      elapsed: elapsed,
      size: size,
    );
  }
}

/// The animation set the app draws with: the sprite sheets once they are
/// loaded, the placeholder before that and whenever there is no art.
final catAnimationsProvider = Provider<CatAnimationSet>((ref) {
  final library = ref.watch(spriteLibraryProvider).value;
  if (library == null) return const PlaceholderCatAnimations();
  return SpriteCatAnimations(library);
});
