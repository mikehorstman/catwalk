import 'package:catwalk/app/app.dart';
import 'package:catwalk/core/utils/calendar_date.dart';
import 'package:catwalk/core/utils/format.dart';
import 'package:catwalk/features/onboarding/data/onboarding_repository.dart';
import 'package:catwalk/features/steps/domain/step_reading.dart';
import 'package:catwalk/services/health/step_repository.dart';
import 'package:catwalk/services/health/step_repository_provider.dart';
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

  testWidgets('no reading says so instead of showing zero', (tester) async {
    await _pumpHome(
      tester,
      _FakeStepRepository(
        available: true,
        permission: true,
        reading: const StepReading.unavailable(),
      ),
    );

    expect(
      find.text('The phone did not give a step count for today.'),
      findsOneWidget,
    );
    expect(find.text('0'), findsNothing);
  });

  testWidgets('a denied permission offers to ask again', (tester) async {
    await _pumpHome(
      tester,
      _FakeStepRepository(available: true, permission: false),
    );

    expect(find.text('Allow step access'), findsOneWidget);
  });

  testWidgets('a real reading is shown as the count', (tester) async {
    await _pumpHome(
      tester,
      _FakeStepRepository(
        available: true,
        permission: true,
        reading: const StepReading.health(2500),
      ),
    );

    expect(find.text(formatNumber(2500)), findsOneWidget);
  });

  testWidgets('the sensor reading is labelled as such', (tester) async {
    await _pumpHome(
      tester,
      _FakeStepRepository(
        available: true,
        permission: true,
        reading: const StepReading.sensor(1200),
      ),
    );

    expect(find.text(formatNumber(1200)), findsOneWidget);
    expect(
      find.text('Since Catwalk last anchored the step sensor.'),
      findsOneWidget,
    );
  });
}

/// Boots the app on Home and lets the daily load finish. It never settles:
/// Home refreshes on a timer, so `pumpAndSettle` would spin forever.
Future<void> _pumpHome(WidgetTester tester, StepRepository repository) async {
  final store = _MemoryStore();
  await store.write(
    OnboardingRepository.profileKey,
    '{"dailyStepGoal":8000,"onboardingCompleted":true,"soundEnabled":false}',
  );
  await store.write(OnboardingRepository.catKey, _catJson());

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        localStoreProvider.overrideWithValue(store),
        stepRepositoryProvider.overrideWithValue(repository),
      ],
      child: const CatwalkApp(),
    ),
  );
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 20));
  }
}

/// A cat created today, so no day counts as missed and Home is the plain case.
String _catJson() {
  final created = DateTime.now();
  return '{"id":"1","name":"Jip","appearance":"ginger",'
      '"level":1,"xp":0,"mood":"neutral","status":"active",'
      '"consecutiveMissedDays":0,"createdAt":"${created.toIso8601String()}"}';
}

class _FakeStepRepository implements StepRepository {
  _FakeStepRepository({
    required this.available,
    required this.permission,
    this.reading = const StepReading.unavailable(),
  });

  final bool available;
  final bool permission;
  final StepReading reading;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<bool> hasPermissions() async => permission;

  @override
  Future<bool> requestPermissions() async => permission;

  @override
  Future<StepReading> getStepsForDate(CalendarDate date) async => reading;

  @override
  Future<StepReading> getTodaySteps() async => reading;
}

class _MemoryStore implements LocalStore {
  final Map<String, String> values = {};

  @override
  Future<void> clear() async => values.clear();

  @override
  Future<void> delete(String key) async => values.remove(key);

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;
}
