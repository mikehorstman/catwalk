import 'package:catwalk/features/cat/domain/cat_mood.dart';
import 'package:catwalk/features/room/domain/cat_action.dart';
import 'package:catwalk/features/room/presentation/sprite_manifest.dart';
import 'package:flutter_test/flutter_test.dart';

const _source = '''
{
  "frameSize": [256, 256],
  "footAnchor": [128, 236],
  "actions": {
    "walk": {
      "neutral": {"fur": "walk_fur.png", "details": "walk_details.png",
                  "frames": 8, "fps": 10, "loop": true},
      "happy":   {"fur": "walk_happy_fur.png", "frames": 8, "fps": 12}
    },
    "sleep": {
      "neutral": {"fur": "sleep_fur.png", "frames": 4, "fps": 2, "loop": false}
    },
    "teleport": {
      "neutral": {"fur": "nope.png", "frames": 4, "fps": 4}
    }
  }
}
''';

void main() {
  test('a manifest parses into sheets per action and mood', () {
    final manifest = SpriteManifest.parse(_source);

    expect(manifest.frameSize, [256, 256]);
    expect(manifest.footAnchor, [128, 236]);
    expect(manifest.has(CatAction.walk), isTrue);
    expect(manifest.has(CatAction.sleep), isTrue);
    expect(manifest.has(CatAction.perch), isFalse);
  });

  test('an action we do not know is ignored, not an error', () {
    final manifest = SpriteManifest.parse(_source);

    expect(
      manifest.actions.keys,
      containsAll([CatAction.walk, CatAction.sleep]),
    );
    expect(manifest.actions.length, 2);
  });

  test('a mood with no sheet falls back to neutral', () {
    final manifest = SpriteManifest.parse(_source);

    expect(
      manifest.lookup(CatAction.walk, CatMood.happy)?.fur,
      'walk_happy_fur.png',
    );
    expect(manifest.lookup(CatAction.walk, CatMood.sad)?.fur, 'walk_fur.png');
    expect(manifest.lookup(CatAction.perch, CatMood.neutral), isNull);
  });

  test('a missing foot anchor defaults to the bottom middle', () {
    final manifest = SpriteManifest.parse(
      '{"frameSize": [100, 80], "actions": {}}',
    );

    expect(manifest.footAnchor, [50.0, 80.0]);
  });

  test('a bad sheet is rejected with the place it went wrong', () {
    expect(
      () => SpriteManifest.parse(
        '{"frameSize": [10, 10], "actions": {"walk": {"neutral": '
        '{"fur": "a.png", "frames": 0, "fps": 10}}}}',
      ),
      throwsA(isA<FormatException>()),
    );
    expect(
      () => SpriteManifest.parse('{"actions": {}}'),
      throwsA(isA<FormatException>()),
    );
  });

  test('a looping action wraps round', () {
    final manifest = SpriteManifest.parse(_source);
    final walk = manifest.lookup(CatAction.walk, CatMood.neutral)!;

    expect(spriteFrameAt(walk, 0), 0);
    expect(spriteFrameAt(walk, 0.05), 0);
    expect(spriteFrameAt(walk, 0.1), 1);
    expect(spriteFrameAt(walk, 0.75), 7);
    // 8 frames at 10 fps: the ninth tick is back at the start.
    expect(spriteFrameAt(walk, 0.8), 0);
    expect(spriteFrameAt(walk, 3.3), 1);
  });

  test('a one-shot action holds its last frame', () {
    final manifest = SpriteManifest.parse(_source);
    final sleep = manifest.lookup(CatAction.sleep, CatMood.neutral)!;

    expect(spriteFrameAt(sleep, 0), 0);
    expect(spriteFrameAt(sleep, 0.5), 1);
    expect(spriteFrameAt(sleep, 1.5), 3);
    expect(spriteFrameAt(sleep, 60), 3);
  });

  test('a negative elapsed time is still the first frame', () {
    final manifest = SpriteManifest.parse(_source);
    final walk = manifest.lookup(CatAction.walk, CatMood.neutral)!;

    expect(spriteFrameAt(walk, -1), 0);
  });

  test('a sheet without a details layer is allowed', () {
    final manifest = SpriteManifest.parse(_source);
    final happy = manifest.lookup(CatAction.walk, CatMood.happy)!;

    expect(happy.details, isNull);
    expect(happy.loop, isTrue);
  });
}
