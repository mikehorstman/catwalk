import 'dart:math' as math;

import '../../../core/constants/app_constants.dart';

/// Only used when side quests are on (currently off).
///
/// What a quest pays: a small share of the day's reward, never the day itself.
int questXpFor(int goalXp) =>
    math.max(2, (goalXp * AppConstants.questXpShare).round());

/// The most XP a single day may pay out, as a share of the day's goal reward.
///
/// The point is not to cap effort, it is to keep the extra bonuses small enough
/// that the goal is still what the day is about.
int dailyXpCeiling(int goalXp) =>
    (goalXp * AppConstants.dailyXpCeilingShare).round();

/// True when [paid] (goal XP plus bonuses) stays inside the ceiling for
/// [goalXp].
bool withinDailyCeiling({required int goalXp, required int paid}) =>
    paid <= dailyXpCeiling(goalXp);
