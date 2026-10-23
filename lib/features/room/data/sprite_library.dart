import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../cat/domain/cat_mood.dart';
import '../domain/cat_action.dart';
import '../presentation/sprite_manifest.dart';

/// Where the cat sheets and their manifest live.
const String catSpriteFolder = 'assets/cats/';

/// The decoded sprite sheets for every action, ready to paint.
///
/// Sheets are decoded once and shared by every cat; the cat's colour is applied
/// when drawing, so one neutral pair serves cream, charcoal and ginger.
class SpriteLibrary {
  /// Both arguments come from [loadSpriteLibrary].
  const SpriteLibrary({required this.manifest, required this.images});

  /// What the manifest says: frame size, foot anchor, and the sheet and frame
  /// count for each action and mood.
  final SpriteManifest manifest;

  /// Decoded sheets by file name.
  final Map<String, ui.Image> images;

  /// What to draw for [action] in [mood], or null when no art covers it. The
  /// room then falls back to the placeholder for just that action.
  SpriteSheet? lookup(CatAction action, CatMood mood) {
    final sprite = manifest.lookup(action, mood);
    if (sprite == null) return null;
    final fur = images[sprite.fur];
    if (fur == null) return null;
    final detailsName = sprite.details;
    return SpriteSheet(
      action: sprite,
      fur: fur,
      details: detailsName == null ? null : images[detailsName],
    );
  }
}

/// One action's decoded sheets.
class SpriteSheet {
  /// Pairs one manifest entry with its decoded images.
  const SpriteSheet({required this.action, required this.fur, this.details});

  /// The manifest entry: frame count, fps and loop flag.
  final SpriteAction action;

  /// The grey fur strip: frames laid side by side, left to right. Painted
  /// tinted with the cat's colour.
  final ui.Image fur;

  /// Eyes, nose and whiskers, painted untinted on top of [fur]. Null when the
  /// action has no details sheet or it failed to load.
  final ui.Image? details;
}

/// Reads `manifest.json` and every sheet it names.
///
/// A sheet that is missing or will not decode is skipped, not fatal: that action
/// keeps using the placeholder. Only an unreadable manifest fails the whole load.
///
/// [bundle] is where assets are read from (tests pass a fake). [folder] must
/// end in a slash; the manifest is `manifest.json` inside it.
Future<SpriteLibrary> loadSpriteLibrary(
  AssetBundle bundle, {
  String folder = catSpriteFolder,
}) async {
  final manifest = SpriteManifest.parse(
    await bundle.loadString('${folder}manifest.json'),
  );
  final names = <String>{
    for (final byMood in manifest.actions.values)
      for (final sprite in byMood.values) ...[
        sprite.fur,
        if (sprite.details != null) sprite.details!,
      ],
  };
  final images = <String, ui.Image>{};
  for (final name in names) {
    try {
      final data = await bundle.load('$folder$name');
      final codec = await ui.instantiateImageCodec(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      );
      final frame = await codec.getNextFrame();
      images[name] = frame.image;
    } catch (_) {
      // Leave it out. The action falls back to the placeholder.
    }
  }
  return SpriteLibrary(manifest: manifest, images: images);
}

/// The loaded cat art, or null when there is none to use.
///
/// Null is a normal answer, not an error: the room keeps working on the
/// placeholder, which is also what shows during the first frames of the load.
final spriteLibraryProvider = FutureProvider<SpriteLibrary?>((ref) async {
  try {
    return await loadSpriteLibrary(rootBundle);
  } catch (_) {
    return null;
  }
});
