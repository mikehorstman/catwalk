import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/format.dart';
import '../../cat/domain/cat_appearance.dart';
import '../../cat/domain/cat_mood.dart';
import '../../cat/presentation/widgets/cat_art.dart';
import '../../map/domain/toy_perks.dart';
import '../application/social_controller.dart';
import '../domain/social_models.dart';

/// A friend's room, read only: their cats, toys and numbers. A wave is the one
/// thing you can do here.
class FriendRoomScreen extends ConsumerWidget {
  const FriendRoomScreen({super.key, required this.profile});

  /// The friend.
  final PublicProfile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final nudged =
        ref
            .watch(socialControllerProvider)
            .value
            ?.nudgedToday
            .contains(profile.uid) ??
        false;
    return Scaffold(
      appBar: AppBar(title: Text('${profile.displayName}\'s room')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
          children: [
            Text(
              '${profile.streak} day streak · best ${profile.bestStreak}',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              '${formatNumber(profile.totalSteps)} steps walked in total · '
              '${formatNumber(profile.weekSteps)} this week',
              style: muted,
            ),
            const SizedBox(height: 4),
            Text(
              profile.todayGoalMet
                  ? 'Today\'s goal is reached.'
                  : '${formatNumber(profile.todaySteps)} of '
                        '${formatNumber(profile.dailyGoal)} steps today.',
              style: muted,
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                for (final cat in profile.cats)
                  SizedBox(
                    width: 140,
                    child: Column(
                      children: [
                        if (cat.away)
                          const SizedBox(
                            height: 110,
                            child: Center(child: Icon(Icons.pets_outlined)),
                          )
                        else
                          CatArt(
                            appearance: CatAppearance.values.firstWhere(
                              (a) => a.name == cat.appearance,
                              orElse: () => CatAppearance.cream,
                            ),
                            mood: CatMood.values.firstWhere(
                              (m) => m.name == cat.mood,
                              orElse: () => CatMood.neutral,
                            ),
                            size: 110,
                          ),
                        const SizedBox(height: 4),
                        Text(
                          cat.away ? '${cat.name} (away)' : cat.name,
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              '${profile.cats.length} of ${profile.rooms * 3} places in use, '
              '${profile.rooms} ${profile.rooms == 1 ? 'room' : 'rooms'}.',
              style: muted,
            ),
            if (profile.toys.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text('Toys', style: theme.textTheme.titleMedium),
              for (final id in profile.toys)
                Text(
                  '${id[0].toUpperCase()}${id.substring(1)}: '
                  '${toyPerkText[id] ?? ''}',
                  style: muted,
                ),
            ],
            const SizedBox(height: 24),
            if (!profile.todayGoalMet)
              FilledButton.icon(
                key: const Key('wave'),
                onPressed: nudged
                    ? null
                    : () async {
                        final sent = await ref
                            .read(socialControllerProvider.notifier)
                            .nudge(profile);
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              sent
                                  ? 'You waved at ${profile.displayName}.'
                                  : 'You already waved today.',
                            ),
                          ),
                        );
                      },
                icon: const Icon(Icons.waving_hand_outlined),
                label: Text(nudged ? 'Waved today' : 'Wave: time for a walk?'),
              ),
          ],
        ),
      ),
    );
  }
}
