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
        'Home says “about N min of walking” for today’s goal. The ring fills '
        'as you walk. In the first week the goal is lower, see below.',
  ),
  TestGuideItem(
    feature: 'Gentle first week',
    how: 'Finish onboarding with the suggested 6,000 goal, then use Home.',
    check:
        'Days 1 to 3 the goal is 3,000, days 4 to 7 it is 4,500, then 6,000. '
        'Home says which day it is. Picking your own goal in onboarding '
        'skips this.',
  ),
  TestGuideItem(
    feature: 'Reaching the goal',
    how: 'Walk the whole goal, then close and reopen the app.',
    check:
        'The cat turns happy, “+6 candy” shows under the steps (1 candy per '
        '1,000 steps of your goal, at least 3), and the streak shows 1. '
        'Reopening does not pay again.',
  ),
  TestGuideItem(
    feature: 'The daily gift',
    how:
        'Before the goal, look at the grey gift button on Home. Then reach '
        'the goal and tap “Open your gift”.',
    check:
        'The button is grey until the goal is reached, then it turns on. '
        'Opening it shows what was inside, once. An unopened gift waits, '
        'also after you close the app.',
  ),
  TestGuideItem(
    feature: 'First goal gift',
    how: 'Open the gift of your very first goal day.',
    check:
        'It holds a free toy and a free streak freeze. It never pays a '
        'second time.',
  ),
  TestGuideItem(
    feature: 'Daily draw',
    how: 'Reach the goal on any day.',
    check:
        'One surprise is in the gift: 1 to 3 candy, a streak freeze or a toy. '
        'It cannot be rerolled by closing the app. At least every fifth goal day '
        'gives a toy or freeze.',
  ),
  TestGuideItem(
    feature: 'Streak prizes',
    how: 'Reach the goal 3 days in a row, then 7.',
    check:
        '3 days: 5 candy. 7 days: 15 candy and a toy. 14: 30 candy. 30: 60 '
        'candy and a toy. 100: 200 candy. The “Next” line on Home names the '
        'next one. Total steps of 10,000, 100,000, 500,000 and 1,000,000 pay '
        'candy too.',
  ),
  TestGuideItem(
    feature: 'Candy and the shop',
    how: 'Tap the candy chip on Home.',
    check:
        'The shop lists the toys you do not own, 8 candy each. Buying one '
        'takes the candy and puts the toy in the room. The button is grey '
        'when you cannot pay.',
  ),
  TestGuideItem(
    feature: 'Weekly freeze',
    how: 'Keep the app for a full week.',
    check:
        'On day 8, and every 7 days after, you get a free streak freeze if '
        'you hold fewer than 2.',
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
        'to collect candy (2 to 4), a streak freeze or a toy. The map needs internet.',
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
        'The cat is gone, a stray kitten arrives, and Home says so '
        'once.',
  ),
  TestGuideItem(
    feature: 'Me tab',
    how: 'Open Me after a day or two.',
    check:
        'Total steps at the top, then streak, best streak, days met, this week '
        'and every saved day. The total should match the sum of your days.',
  ),
  TestGuideItem(
    feature: 'Shop and cat beds',
    how:
        'Tap the shop icon at the top right of Home. Buy a bed when you have '
        'the candy (the second bed costs 40).',
    check:
        'Candy drops, a bed is added, and the next morning a cat waits on '
        'the Map. Walk to it (within 30 m) and it joins your room. Only one '
        'bed can be waiting at a time.',
  ),
  TestGuideItem(
    feature: 'Toy perks',
    how: 'Buy a toy for 8 candy and read its line in the shop.',
    check:
        'Ball: +1 candy on goal days. Mouse: 6 pins on the Map. Feather: +1 '
        'candy in the daily draw.',
  ),
  TestGuideItem(
    feature: 'Reminders',
    how:
        'Open your first gift and allow notifications. Settings has the '
        'Reminders switch.',
    check:
        'At about your usual walking time you get a nudge from '
        'your cat, at most three a day, none once the goal is reached. Off '
        'in Settings means none.',
  ),
  TestGuideItem(
    feature: 'Friends',
    how:
        'On Me, open Friends and leaderboard. Sign in with Google, then share '
        'your code with a second person who also has the app.',
    check:
        'They type your code, you accept the request, and both of you show on '
        'the leaderboard with this week\'s steps. Tap a friend to see their '
        'cats and send a wave. Delete my online data removes it all.',
  ),
];

/// What is not in this build, so a missing feature is not mistaken for a bug.
const List<String> testGuideNotBuilt = ['Street cats and photos'];

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
