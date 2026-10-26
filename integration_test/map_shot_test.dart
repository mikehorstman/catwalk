import 'package:catwalk/app/app.dart';
import 'package:catwalk/features/map/data/location_service.dart';
import 'package:catwalk/features/map/domain/geo.dart';
import 'package:catwalk/services/storage/local_store_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';

import '../test/map_controller_test.dart' show amsterdam, fixAt, seededStore;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('map screenshots', (tester) async {
    final location = FakeLocationService(start: fixAt(amsterdam));
    final store = await seededStore();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localStoreProvider.overrideWithValue(store),
          locationServiceProvider.overrideWithValue(location),
        ],
        child: const CatwalkApp(),
      ),
    );
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    GoRouter.of(tester.element(find.byType(Scaffold).first)).go('/map');
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    await binding.convertFlutterSurfaceToImage();
    await tester.pump();
    await binding.takeScreenshot('map_1');
    location.move(fixAt(GeoPoint(amsterdam.lat + 0.0003, amsterdam.lon)));
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    await binding.takeScreenshot('map_2');
  });
}
