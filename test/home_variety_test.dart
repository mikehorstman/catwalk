import 'package:catwalk/app/app.dart';
import 'package:catwalk/core/utils/calendar_date.dart';
import 'package:catwalk/features/map/data/location_service.dart';
import 'package:catwalk/features/onboarding/data/onboarding_repository.dart';
import 'package:catwalk/features/steps/domain/step_reading.dart';
import 'package:catwalk/services/health/step_repository.dart';
import 'package:catwalk/services/health/step_repository_provider.dart';
import 'package:catwalk/services/storage/local_store.dart';
import 'package:catwalk/services/storage/local_store_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Forty minutes of walking, split morning and evening, plus yesterday.
class _WalkingSteps implements StepRepository {
  _WalkingSteps();

  final int today = 6000;
  final int yesterday = 100;

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<bool> hasPermissions() async => true;

  @override
  Future<bool> requestPermissions() async => true;

  @override
  Future<StepReading> getTodaySteps() async => StepReading.health(today);

  @override
  Future<StepReading> getStepsForDate(CalendarDate date) async {
    if (date == CalendarDate.today()) return StepReading.health(today);
    if (date == CalendarDate.today().addDays(-1)) {
      return StepReading.health(yesterday);
    }
    return const StepReading.unavailable();
  }

  @override
  Future<List<int>?> hourlySteps(CalendarDate date) async {
    if (date != CalendarDate.today()) return null;
    return [
      for (var hour = 0; hour < 24; hour++)
        switch (hour) {
          8 => 1300,
          9 => 900,
          19 => 1100,
          _ => 0,
        },
    ];
  }
}

class _MemoryStore implements LocalStore {
  final Map<String, String> _values = {};

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, String value) async => _values[key] = value;

  @override
  Future<void> delete(String key) async => _values.remove(key);

  @override
  Future<void> clear() async => _values.clear();
}

void main() {
  testWidgets(
    'Home keeps the minutes behind the details row and shows candy, not XP',
    (tester) async {
      final store = _MemoryStore();
      await store.write(
        OnboardingRepository.profileKey,
        '{"dailyStepGoal":6000,"onboardingCompleted":true,"soundEnabled":false}',
      );
      final created = DateTime.now();
      await store.write(
        OnboardingRepository.catKey,
        '{"id":"1","name":"Jip","appearance":"ginger",'
        '"mood":"neutral","status":"active","consecutiveMissedDays":0,'
        '"createdAt":"${created.toIso8601String()}"}',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            localStoreProvider.overrideWithValue(store),
            stepRepositoryProvider.overrideWithValue(_WalkingSteps()),
            locationServiceProvider.overrideWithValue(
              FakeLocationService(access_: LocationAccess.blocked),
            ),
          ],
          child: const CatwalkApp(),
        ),
      );
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 20));
      }

      // The minutes line is behind the details row, not on Home itself.
      expect(find.text('about 60 min of walking'), findsNothing);

      // No XP or level any more: 6000 steps today paid the goal's 6 candy.
      expect(find.textContaining('XP'), findsNothing);
      expect(find.textContaining('Level'), findsNothing);
      expect(find.text('+6 candy'), findsOneWidget);
      // The chip counts the goal's candy plus whatever the day's draw added.
      expect(
        find.byWidgetPredicate(
          (w) => w is Text && RegExp(r'^\d+ candy$').hasMatch(w.data ?? ''),
        ),
        findsOneWidget,
      );
    },
  );
}
