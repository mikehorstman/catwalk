import 'package:catwalk/app/app.dart';
import 'package:catwalk/core/utils/calendar_date.dart';
import 'package:catwalk/features/daily_goal/domain/side_quest.dart';
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
  _WalkingSteps({this.today = 6000, this.yesterday = 100});

  final int today;
  final int yesterday;

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<bool> hasPermissions() async => true;

  @override
  Future<bool> requestPermissions() async => true;

  @override
  Future<StepReading> getTodaySteps() async =>
      StepReading.health(today);

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
  testWidgets('Home shows the goal as minutes, and one optional quest', (
    tester,
  ) async {
    final store = _MemoryStore();
    await store.write(
      OnboardingRepository.profileKey,
      '{"dailyStepGoal":6000,"onboardingCompleted":true,"soundEnabled":false}',
    );
    final created = DateTime.now();
    await store.write(
      OnboardingRepository.catKey,
      '{"id":"1","name":"Jip","appearance":"ginger","level":1,"xp":0,'
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

    expect(find.text('about 60 min of walking'), findsOneWidget);

    // The quest the same trace picks on a first day of walking, so the test
    // does not depend on which day it runs.
    final quest = pickQuest(
      trace: DayTrace(
        date: CalendarDate.today(),
        steps: 6000,
        goal: 6000,
        hourly: [
          for (var hour = 0; hour < 24; hour++)
            switch (hour) {
              8 => 1300,
              9 => 900,
              19 => 1100,
              _ => 0,
            },
        ],
        yesterdaySteps: 100,
      ),
      daysWalking: 1,
    );
    expect(quest, SideQuest.twoWalks);

    // The card sits below the ring; drag the list up to it.
    await tester.drag(find.byType(ListView).first, const Offset(0, -560));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    expect(find.text(sideQuestInfo[quest]!.title), findsOneWidget);
    // The quest was met by the steps the phone counted, and paid once.
    expect(find.textContaining('+3 XP'), findsWidgets);
  });
}
