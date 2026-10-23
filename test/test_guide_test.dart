import 'package:catwalk/features/history/presentation/test_guide.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('the guide is collapsed, and opens to the steps to try', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: SingleChildScrollView(child: TestGuide())),
      ),
    );

    expect(find.text('How to test this build'), findsOneWidget);
    expect(find.text('Steps'), findsNothing);

    await tester.tap(find.byKey(const Key('test-guide')));
    await tester.pumpAndSettle();

    expect(find.text('Steps'), findsOneWidget);
    expect(find.text('Not in this build yet'), findsWidgets);
  });

  test('every entry says what to do and what to expect', () {
    for (final item in testGuideItems) {
      expect(item.feature, isNotEmpty);
      expect(item.how, isNotEmpty);
      expect(item.check, isNotEmpty);
    }
  });

  test('the guide does not promise rules that were removed', () {
    final text = testGuideItems.map((i) => '${i.how} ${i.check}').join(' ');
    expect(text.toLowerCase(), isNot(contains('weekly walk')));
    expect(text, isNot(contains('84,000')));
    expect(text, isNot(contains('× 14')));
  });
}
