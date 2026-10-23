import 'package:flutter/material.dart';

/// One feature the tester can try, how to try it, and what to look for.
class TestGuideItem {
  const TestGuideItem({
    required this.feature,
    required this.how,
    required this.check,
  });

  /// The feature, in a few words.
  final String feature;

  /// What to do on the phone to try it.
  final String how;

  /// What should happen, so the tester can tell it works.
  final String check;
}

/// Everything that works in this build and can be tried on a real phone.
///
/// Keep this in step with the app: when a rule changes or a feature ships,
/// change its entry here so the guide never promises something that is gone.
const List<TestGuideItem> testGuideItems = [
  TestGuideItem(
    feature: 'Steps',
    how: 'Open Home, walk about 100 steps, then reopen the app or wait a moment.',
    check:
        'The count roughly matches Health Connect or Google Fit and updates '
        'without restarting the app.',
  ),
  TestGuideItem(
    feature: 'Goal ring and minutes',
    how: 'Look at Home.',
    check:
        'The default goal is 6,000 and Home says “about 60 min of walking”. '
        'The ring fills as you walk.',
  ),
  TestGuideItem(
    feature: 'Halfway bonus',
    how: 'Walk to half your goal (3,000 at the default).',
    check: '“Halfway there: +XP” appears once. It does not make the day count.',
  ),
  TestGuideItem(
    feature: 'Reaching the goal',
    how: 'Walk the whole goal, then close and reopen the app.',
    check:
        'The cat turns happy, XP is paid once, and the streak shows 1. '
        'Reopening does not pay again.',
  ),
  TestGuideItem(
    feature: 'Suggested goal',
    how: 'Settings, or onboarding: “use my last week”.',
    check:
        'Needs 4 days of steps already in Health Connect. The number should '
        'be a bit above your usual day and a multiple of 500.',
  ),
  TestGuideItem(
    feature: 'Changing the goal',
    how: 'Settings, change the daily goal.',
    check:
        'Today’s goal stays as it was. The new goal starts tomorrow. '
        'Tip: 3,000 is the smallest goal and makes testing cheaper.',
  ),
  TestGuideItem(
    feature: 'Map pickups',
    how: 'Go outside, allow location, open Map.',
    check:
        'Up to 5 pins appear 250 to 900 m away. Walk to within 30 m of one '
        'to collect XP, a streak freeze or a toy. The map needs internet.',
  ),
  TestGuideItem(
    feature: 'The room',
    how: 'Open Cats.',
    check:
        'The cat walks, sits, sleeps and plays. Toys you found lie on the '
        'floor. The art is a placeholder.',
  ),
  TestGuideItem(
    feature: 'A missed day',
    how:
        'Do not reach the whole goal one day. Half a goal counts as missed. '
        'Open the app the next day.',
    check:
        '1 missed day: sad. 2: neglected. 3: the cat runs away. A held '
        'streak freeze covers one missed day.',
  ),
  TestGuideItem(
    feature: 'A runaway cat',
    how: 'After 3 missed days, open Home and Map.',
    check:
        'You get 7 days to walk 10 times your goal. Home and Map show the '
        'steps to go and days left. When you reach it, the cat appears on the '
        'map: walk to within 30 m. Without location it comes home at once.',
  ),
  TestGuideItem(
    feature: 'A lost cat',
    how: 'Let the 7 days run out without reaching the target.',
    check:
        'The cat is gone, a stray kitten at level 1 arrives, and Home says so '
        'once.',
  ),
  TestGuideItem(
    feature: 'Me tab',
    how: 'Open Me after a day or two.',
    check:
        'Streak, best streak, days met, this week, totals and every saved '
        'day. The numbers should match what you walked.',
  ),
];

/// What is not in this build, so a missing feature is not mistaken for a bug.
const List<String> testGuideNotBuilt = [
  'First-week ramp and the free first toy',
  'Streak prizes, the weekly freeze and the daily draw',
  'The lost cat coming back on the map',
  'More than one cat, street cats and photos',
  'Reminders and the weekly recap',
  'Friends, leaderboard and visiting rooms',
  'Daily side quests (built, but switched off)',
];

/// The “How to test” section at the bottom of Me.
///
/// Collapsed by default so it does not crowd the stats; tap to open it.
class TestGuide extends StatelessWidget {
  const TestGuide({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Theme(
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          key: const Key('test-guide'),
          leading: const Icon(Icons.fact_check_outlined),
          title: Text(
            'How to test this build',
            style: theme.textTheme.titleMedium,
          ),
          subtitle: const Text('What works, and how to try it'),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final item in testGuideItems) _GuideRow(item: item),
            const SizedBox(height: 8),
            Text('Not in this build yet', style: theme.textTheme.titleSmall),
            const SizedBox(height: 6),
            for (final line in testGuideNotBuilt)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '• $line',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// One feature: its name, what to do, and what should happen.
class _GuideRow extends StatelessWidget {
  const _GuideRow({required this.item});

  final TestGuideItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(item.feature, style: theme.textTheme.titleSmall),
          const SizedBox(height: 2),
          Text.rich(
            TextSpan(
              children: [
                const TextSpan(
                  text: 'Do: ',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                TextSpan(text: item.how),
              ],
            ),
            style: theme.textTheme.bodyMedium?.copyWith(color: muted),
          ),
          const SizedBox(height: 2),
          Text.rich(
            TextSpan(
              children: [
                const TextSpan(
                  text: 'Expect: ',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                TextSpan(text: item.check),
              ],
            ),
            style: theme.textTheme.bodyMedium?.copyWith(color: muted),
          ),
        ],
      ),
    );
  }
}
