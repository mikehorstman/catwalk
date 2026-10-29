import 'package:catwalk/services/health/dev_step_repository.dart';
import 'package:catwalk/services/health/composite_step_repository.dart';
import 'package:catwalk/services/health/mock_step_repository.dart';
import 'package:catwalk/services/health/step_repository_provider.dart';
import 'package:catwalk/services/storage/local_store.dart';
import 'package:catwalk/services/storage/local_store_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Mock steps exist for development. A release build must read the phone.
///
/// These run in either mode: they assert the rule rather than one fixed
/// answer, so both `flutter test` and `flutter test --release` hold it to
/// account.
void main() {
  const productBuild = bool.fromEnvironment('dart.vm.product');

  test('mock steps are chosen only when the build is not a product build', () {
    expect(useMockSteps, !productBuild);
  });

  test('the provider matches the mode', () {
    final container = ProviderContainer(
      overrides: [localStoreProvider.overrideWithValue(_MemoryStore())],
    );
    addTearDown(container.dispose);

    // Developer mode wraps the real source; look at what it wraps.
    final wrapper = container.read(stepRepositoryProvider);
    expect(wrapper, isA<DevStepRepository>());
    final repository = (wrapper as DevStepRepository).inner;
    if (productBuild) {
      expect(repository, isA<CompositeStepRepository>());
    } else {
      expect(repository, isA<MockStepRepository>());
    }
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
