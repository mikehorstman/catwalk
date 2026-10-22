import 'package:catwalk/features/cat/domain/cat_appearance.dart';
import 'package:catwalk/features/cat/domain/cat_mood.dart';
import 'package:catwalk/features/room/data/sprite_library.dart';
import 'package:catwalk/features/room/domain/cat_action.dart';
import 'package:catwalk/features/room/presentation/cat_animations.dart';
import 'package:catwalk/features/room/presentation/sprite_cat.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('the placeholder sprite sheets', () {
    testWidgets('load, and every action has art', (tester) async {
      final library = await tester.runAsync(
        () => loadSpriteLibrary(rootBundle),
      );
      expect(library, isNotNull);
      for (final action in CatAction.values) {
        final sheet = library!.lookup(action, CatMood.neutral);
        expect(sheet, isNotNull, reason: '$action has no sheet');
        expect(sheet!.details, isNotNull, reason: '$action has no details');
        // The strip is one row of equal frames.
        expect(
          sheet.fur.width,
          sheet.action.frames * library.manifest.frameSize[0].round(),
          reason: '$action: strip width is not frames x frame width',
        );
        expect(sheet.fur.height, library.manifest.frameSize[1].round());
        expect(sheet.details!.width, sheet.fur.width);
      }
    });

    testWidgets('a mood without art uses the neutral sheet', (tester) async {
      final library = await tester.runAsync(
        () => loadSpriteLibrary(rootBundle),
      );
      final neutral = library!.lookup(CatAction.walk, CatMood.neutral)!;
      final sad = library.lookup(CatAction.walk, CatMood.sad)!;
      expect(sad.fur, same(neutral.fur));
    });

    testWidgets('a cat is drawn from a sheet, not the placeholder', (
      tester,
    ) async {
      final library = (await tester.runAsync(
        () => loadSpriteLibrary(rootBundle),
      ))!;
      final animations = SpriteCatAnimations(library);
      late Widget built;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              built = animations.frame(
                context,
                appearance: CatAppearance.ginger,
                action: CatAction.walk,
                mood: CatMood.happy,
                facing: CatFacing.left,
                elapsed: const Duration(milliseconds: 250),
                size: 120,
              );
              return Center(child: built);
            },
          ),
        ),
      );
      expect(find.byType(SpriteCatFrame), findsOneWidget);
    });
  });

  group('tint', () {
    test('a dark coat keeps some light so the shading survives', () {
      // The fur sheet is mid grey. Multiplied by charcoal alone it is near
      // black; the lift keeps it readable.
      final dark = furTint(CatAppearance.charcoal.color);
      final ginger = furTint(CatAppearance.ginger.color);
      expect(dark, isNot(equals(ginger)));
    });
  });
}
