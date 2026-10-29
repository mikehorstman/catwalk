import 'package:catwalk/app/app.dart';
import 'package:catwalk/services/storage/local_store_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';

import '../test/map_controller_test.dart' show seededStore;

Future<void> settle(WidgetTester tester, [int n = 15]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('developer mode', (tester) async {
    final store = await seededStore();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [localStoreProvider.overrideWithValue(store)],
        child: const CatwalkApp(),
      ),
    );
    await settle(tester);
    GoRouter.of(tester.element(find.byType(Scaffold).first)).go('/settings');
    await settle(tester);
    await tester.scrollUntilVisible(
      find.byKey(const Key('dev-switch')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('dev-switch')));
    await settle(tester, 8);
    await tester.scrollUntilVisible(
      find.byKey(const Key('dev-steps-field')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await binding.convertFlutterSurfaceToImage();
    await tester.pump();
    await binding.takeScreenshot('dev_1');
    await tester.scrollUntilVisible(
      find.byKey(const Key('dev-walk-wish')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await binding.takeScreenshot('dev_2');
  });
}
