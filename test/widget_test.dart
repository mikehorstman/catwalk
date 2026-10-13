import 'package:catwalk/app/app.dart';
import 'package:catwalk/services/storage/local_store.dart';
import 'package:catwalk/services/storage/local_store_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('first launch opens onboarding', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [localStoreProvider.overrideWithValue(_MemoryStore())],
        child: const CatwalkApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Catwalk'), findsOneWidget);
    expect(find.text('Continue'), findsOneWidget);
  });
}

class _MemoryStore implements LocalStore {
  @override
  Future<void> clear() async {}

  @override
  Future<void> delete(String key) async {}

  @override
  Future<String?> read(String key) async => null;

  @override
  Future<void> write(String key, String value) async {}
}
