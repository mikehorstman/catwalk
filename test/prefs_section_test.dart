import 'package:catwalk/features/analytics/analytics_service.dart';
import 'package:catwalk/features/map/data/location_service.dart';
import 'package:catwalk/features/reminders/data/notification_service.dart';
import 'package:catwalk/features/reminders/data/prefs_repository.dart';
import 'package:catwalk/features/settings/presentation/prefs_section.dart';
import 'package:catwalk/services/health/mock_step_repository.dart';
import 'package:catwalk/services/health/step_repository_provider.dart';
import 'package:catwalk/services/storage/local_store_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'map_controller_test.dart' show seededStore;

void main() {
  testWidgets('the switches change the saved prefs, the phone and analytics', (
    tester,
  ) async {
    final store = await seededStore();
    final notifications = FakeNotificationService();
    final analytics = FakeAnalytics();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localStoreProvider.overrideWithValue(store),
          stepRepositoryProvider.overrideWithValue(
            MockStepRepository(stepsByDate: {}),
          ),
          locationServiceProvider.overrideWithValue(FakeLocationService()),
          notificationServiceProvider.overrideWithValue(notifications),
          analyticsProvider.overrideWithValue(analytics),
        ],
        child: const MaterialApp(
          home: Scaffold(body: SingleChildScrollView(child: PrefsSection())),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Reminders from your cat'), findsOneWidget);
    expect(find.text('Share anonymous usage'), findsOneWidget);

    await tester.tap(find.byKey(const Key('reminders-switch')));
    await tester.pump();
    await tester.pump();
    var prefs = await PrefsRepository(store).read();
    expect(prefs.remindersEnabled, isFalse);
    expect(notifications.scheduled, isEmpty);

    await tester.tap(find.byKey(const Key('reminders-switch')));
    await tester.pump();
    await tester.pump();
    prefs = await PrefsRepository(store).read();
    expect(prefs.remindersEnabled, isTrue);
    expect(notifications.asked, 1);

    await tester.tap(find.byKey(const Key('analytics-switch')));
    await tester.pump();
    await tester.pump();
    prefs = await PrefsRepository(store).read();
    expect(prefs.analyticsEnabled, isFalse);
    expect(analytics.enabled, isFalse);
  });
}
