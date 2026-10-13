import 'package:catwalk/features/cat/domain/cat_appearance.dart';
import 'package:catwalk/features/onboarding/data/onboarding_repository.dart';
import 'package:catwalk/features/onboarding/domain/onboarding_draft.dart';
import 'package:catwalk/services/storage/local_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('completing onboarding is remembered', () async {
    final store = _MemoryStore();
    final repository = OnboardingRepository(store);

    expect(await repository.isCompleted(), isFalse);
    await repository.complete(
      const OnboardingDraft(
        appearance: CatAppearance.ginger,
        name: '  Mimi  ',
        dailyStepGoal: 6000,
        healthPermissionGranted: false,
      ),
    );

    expect(await repository.isCompleted(), isTrue);
    expect(store.values[OnboardingRepository.catKey], contains('Mimi'));
    expect(
      store.values[OnboardingRepository.catKey],
      isNot(contains('  Mimi')),
    );
  });
}

class _MemoryStore implements LocalStore {
  final values = <String, String>{};

  @override
  Future<void> clear() async => values.clear();

  @override
  Future<void> delete(String key) async => values.remove(key);

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;
}
