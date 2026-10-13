import 'package:catwalk/core/utils/calendar_date.dart';
import 'package:catwalk/features/cat/domain/cat.dart';
import 'package:catwalk/features/cat/domain/cat_appearance.dart';
import 'package:catwalk/features/cat/domain/cat_mood.dart';
import 'package:catwalk/features/cat/domain/cat_status.dart';
import 'package:catwalk/features/daily_goal/domain/daily_progress.dart';
import 'package:catwalk/features/daily_goal/domain/day_evaluation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final today = CalendarDate(2026, 10, 5);
  final cat = Cat(
    id: '1',
    name: 'Mimi',
    appearance: CatAppearance.cream,
    level: 1,
    xp: 0,
    mood: CatMood.neutral,
    status: CatStatus.active,
    consecutiveMissedDays: 0,
    createdAt: DateTime(2026, 10, 5),
  );

  test('reaching the goal awards 50 XP once', () {
    final first = evaluateDay(
      cat: cat,
      dailyStepGoal: 6000,
      stepsToday: 6000,
      today: today,
      history: const [],
    );
    expect(first.today.goalCompleted, isTrue);
    expect(first.xpGainedToday, 50);
    expect(first.cat.xp, 50);
    expect(first.cat.mood, CatMood.happy);

    final second = evaluateDay(
      cat: first.cat,
      dailyStepGoal: 6000,
      stepsToday: 6000,
      today: today,
      history: [first.today],
      lastEvaluated: today,
    );
    expect(second.xpGainedToday, 0);
    expect(second.cat.xp, 50);
  });

  test('three missed full days make the cat run away', () {
    final older = cat.copyWith();
    final createdEarlier = Cat(
      id: cat.id,
      name: cat.name,
      appearance: cat.appearance,
      level: cat.level,
      xp: cat.xp,
      mood: cat.mood,
      status: cat.status,
      consecutiveMissedDays: 0,
      createdAt: DateTime(2026, 10, 2),
    );
    final result = evaluateDay(
      cat: createdEarlier,
      dailyStepGoal: 6000,
      stepsToday: 0,
      today: today,
      history: const [],
    );
    expect(result.cat.status, CatStatus.runaway);
    expect(result.cat.consecutiveMissedDays, 3);
    expect(older.name, 'Mimi');
  });

  test('walking brings a runaway cat back without awarding XP', () {
    final runaway = Cat(
      id: cat.id,
      name: cat.name,
      appearance: cat.appearance,
      level: 2,
      xp: 100,
      mood: CatMood.sad,
      status: CatStatus.runaway,
      consecutiveMissedDays: 3,
      createdAt: DateTime(2026, 10, 1),
    );
    final result = evaluateDay(
      cat: runaway,
      dailyStepGoal: 6000,
      stepsToday: 12,
      today: today,
      history: [
        DailyProgress(
          date: CalendarDate(2026, 10, 4),
          stepGoal: 6000,
          steps: 0,
          goalCompleted: false,
          xpAwarded: false,
        ),
      ],
      lastEvaluated: CalendarDate(2026, 10, 4),
    );
    expect(result.cat.status, CatStatus.active);
    expect(result.recoveredToday, isTrue);
    expect(result.xpGainedToday, 0);
    expect(result.cat.xp, 100);
  });

  test('enough XP raises the level', () {
    final experienced = Cat(
      id: cat.id,
      name: cat.name,
      appearance: cat.appearance,
      level: 1,
      xp: 60,
      mood: cat.mood,
      status: cat.status,
      consecutiveMissedDays: 0,
      createdAt: cat.createdAt,
    );
    final result = evaluateDay(
      cat: experienced,
      dailyStepGoal: 6000,
      stepsToday: 6000,
      today: today,
      history: const [],
    );
    expect(result.cat.xp, 110);
    expect(result.cat.level, 2);
  });
}
