import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../core/utils/format.dart';
import '../../steps/presentation/home_controller.dart';
import '../domain/cat_status.dart';
import '../domain/xp_curve.dart';
import 'cat_voice.dart';
import 'widgets/cat_art.dart';

/// The Cats tab is the room where the cat lives.
class CatScreen extends ConsumerWidget {
  const CatScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final home = ref.watch(homeControllerProvider);
    return Scaffold(
      body: home.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) =>
            const Center(child: Text('Could not load your cat.')),
        data: (state) => _Room(state: state),
      ),
    );
  }
}

class _Room extends StatelessWidget {
  const _Room({required this.state});

  final HomeState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cat = state.cat;
    final gone = cat.status == CatStatus.runaway;
    final levelStart = xpToReachLevel(cat.level);
    final levelEnd = xpToReachLevel(cat.level + 1);
    final span = levelEnd - levelStart;
    final progress = span == 0
        ? 0.0
        : ((cat.xp - levelStart) / span).clamp(0.0, 1.0);

    return Column(
      children: [
        Expanded(
          flex: 5,
          child: _RoomScene(
            child: gone
                ? const EmptyCushion(size: 220)
                : CatArt(appearance: cat.appearance, mood: cat.mood, size: 240),
          ),
        ),
        Expanded(
          flex: 4,
          child: SafeArea(
            top: false,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        cat.name,
                        style: theme.textTheme.headlineMedium,
                      ),
                    ),
                    Text(
                      cat.appearance.label,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  catSound(mood: cat.mood, status: cat.status),
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontStyle: FontStyle.italic,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 20),
                _Row(label: 'Mood', value: moodLabel(cat.mood)),
                _Row(label: 'Status', value: statusLabel(cat.status)),
                if (cat.consecutiveMissedDays > 0)
                  _Row(
                    label: 'Missed days',
                    value: '${cat.consecutiveMissedDays}',
                  ),
                const SizedBox(height: 16),
                Text('Level ${cat.level}', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(value: progress, minHeight: 8),
                ),
                const SizedBox(height: 6),
                Text(
                  '${formatNumber(cat.xp)} / ${formatNumber(levelEnd)} XP · '
                  '${formatNumber(xpUntilNextLevel(cat.xp))} to level '
                  '${cat.level + 1}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 20),
                const _Hint(
                  text:
                      'More cats, toys, and a scratching post will '
                      'show up in this room.',
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// A simple room: wall, window, floor, rug.
class _RoomScene extends StatelessWidget {
  const _RoomScene({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [CatwalkColors.orangeSoft, CatwalkColors.cream],
          stops: [0.0, 0.62],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            Positioned(top: 24, right: 28, child: _Window()),
            // Floor.
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 64,
              child: const ColoredBox(color: Color(0xFFEAC9A3)),
            ),
            // Rug.
            Positioned(
              left: 40,
              right: 40,
              bottom: 12,
              height: 36,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: CatwalkColors.teal,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            Align(alignment: const Alignment(0, 0.55), child: child),
          ],
        ),
      ),
    );
  }
}

class _Window extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 84,
      height: 100,
      decoration: BoxDecoration(
        color: const Color(0xFFD3ECEA),
        border: Border.all(color: Colors.white, width: 6),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Center(
        child: Icon(Icons.wb_sunny_outlined, color: Colors.white, size: 30),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          Text(value, style: theme.textTheme.titleMedium),
        ],
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: CatwalkColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: CatwalkColors.line),
      ),
      child: Row(
        children: [
          const Icon(Icons.chair_outlined, color: CatwalkColors.teal),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
