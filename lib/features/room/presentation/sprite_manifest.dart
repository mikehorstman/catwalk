import 'dart:convert';

import '../../cat/domain/cat_mood.dart';
import '../domain/cat_action.dart';

/// One sprite sheet pair for one action in one mood.
///
/// Two sheets, identical frame layout: [fur] is drawn in greys and tinted with
/// the cat's colour, [details] holds eyes, nose and whiskers and is drawn on top
/// untinted. One neutral pair therefore serves every cat colour.
class SpriteAction {
  /// [frames] and [fps] must be above zero. [loop] false holds the last frame.
  const SpriteAction({
    required this.fur,
    required this.details,
    required this.frames,
    required this.fps,
    this.loop = true,
  });

  /// Reads one action entry of the manifest. [where] (like `walk.neutral`)
  /// names the entry in error messages.
  ///
  /// Throws [FormatException] when `frames` or `fps` is not positive or `fur`
  /// is missing. `details` is optional and `loop` defaults to true.
  factory SpriteAction.fromJson(Map<String, dynamic> json, String where) {
    final frames = json['frames'];
    final fps = json['fps'];
    if (frames is! int || frames <= 0) {
      throw FormatException('$where: "frames" must be a positive integer');
    }
    if (fps is! num || fps <= 0) {
      throw FormatException('$where: "fps" must be a positive number');
    }
    final fur = json['fur'];
    if (fur is! String || fur.isEmpty) {
      throw FormatException('$where: "fur" is required');
    }
    final detailsRef = json['details'];
    return SpriteAction(
      fur: fur,
      details: detailsRef is String && detailsRef.isNotEmpty
          ? detailsRef
          : null,
      frames: frames,
      fps: fps.toDouble(),
      loop: json['loop'] != false,
    );
  }

  /// The greyscale sheet that gets tinted.
  final String fur;

  /// The sheet that does not get tinted, when there is one.
  final String? details;

  /// How many frames the strip holds, side by side.
  final int frames;

  /// Playback speed in frames per second.
  final double fps;

  /// When false the last frame holds, for one-shots like lying down.
  final bool loop;

  /// Seconds for one pass through all the frames.
  double get duration => frames / fps;
}

/// Everything the room needs to draw a cat from art.
///
/// Keyed by action, then by mood. A missing mood is not a missing action: the
/// lookup falls back to `neutral`, so art can grow one action and one mood at a
/// time without the app changing.
class SpriteManifest {
  /// [frameSize] and [footAnchor] are `[x, y]` pixel pairs; see [parse].
  const SpriteManifest({
    required this.frameSize,
    required this.footAnchor,
    required this.actions,
  });

  /// Reads the text of `manifest.json`.
  ///
  /// Strict about the size and every entry that is used, which throw
  /// [FormatException]; relaxed about extras: actions or moods this app does
  /// not know are skipped, so art can be added before the code is. `footAnchor`
  /// defaults to the bottom centre of the frame.
  factory SpriteManifest.parse(String source) {
    final decoded = jsonDecode(source);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('A manifest is a JSON object');
    }

    final size = decoded['frameSize'];
    if (size is! List || size.length != 2) {
      throw const FormatException('"frameSize" must be [width, height]');
    }

    final anchor = decoded['footAnchor'];
    final actions = <CatAction, Map<CatMood, SpriteAction>>{};
    final rawActions = decoded['actions'];
    if (rawActions is Map) {
      for (final entry in rawActions.entries) {
        final action = _actionByName('${entry.key}');
        if (action == null) continue; // Extra art is not an error.
        final byMood = <CatMood, SpriteAction>{};
        if (entry.value is Map) {
          for (final moodEntry in (entry.value as Map).entries) {
            final mood = _moodByName('${moodEntry.key}');
            if (mood == null) continue;
            if (moodEntry.value is! Map<String, dynamic>) continue;
            byMood[mood] = SpriteAction.fromJson(
              moodEntry.value as Map<String, dynamic>,
              '${entry.key}.${moodEntry.key}',
            );
          }
        }
        if (byMood.isNotEmpty) actions[action] = byMood;
      }
    }

    return SpriteManifest(
      frameSize: [(size[0] as num).toDouble(), (size[1] as num).toDouble()],
      footAnchor: anchor is List && anchor.length == 2
          ? [(anchor[0] as num).toDouble(), (anchor[1] as num).toDouble()]
          : [(size[0] as num) / 2, (size[1] as num).toDouble()],
      actions: actions,
    );
  }

  /// Width and height of one frame in pixels, as `[width, height]`. Every sheet
  /// uses the same size.
  final List<double> frameSize;

  /// Where the feet are inside a frame, so cats stand on the floor line.
  final List<double> footAnchor;

  /// The sheets for each action, then each mood. Actions without art are
  /// absent.
  final Map<CatAction, Map<CatMood, SpriteAction>> actions;

  /// The sheet for [action] in [mood], or the `neutral` one, or nothing.
  SpriteAction? lookup(CatAction action, CatMood mood) {
    final byMood = actions[action];
    if (byMood == null) return null;
    return byMood[mood] ?? byMood[CatMood.neutral];
  }

  /// True when there is art for [action] in at least one mood.
  bool has(CatAction action) => actions.containsKey(action);
}

/// Which frame of [action] to show [elapsed] seconds in.
///
/// A looping action wraps. A one-shot holds its last frame, which is what makes
/// "lie down and stay down" work with a single sheet.
int spriteFrameAt(SpriteAction action, double elapsed) {
  if (elapsed <= 0) return 0;
  final index = (elapsed * action.fps).floor();
  if (action.loop) return index % action.frames;
  return index.clamp(0, action.frames - 1);
}

/// The [CatAction] called [name] in the manifest, or null if the app has none
/// by that name.
CatAction? _actionByName(String name) {
  for (final action in CatAction.values) {
    if (action.name == name) return action;
  }
  return null;
}

/// The [CatMood] called [name] in the manifest, or null if unknown.
CatMood? _moodByName(String name) {
  for (final mood in CatMood.values) {
    if (mood.name == name) return mood;
  }
  return null;
}
