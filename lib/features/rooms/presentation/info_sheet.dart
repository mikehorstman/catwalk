import 'package:flutter/material.dart';

import '../../../app/theme.dart';

/// A small (i) button that explains something in a few plain sentences.
class InfoButton extends StatelessWidget {
  /// Creates the button. [title] and [body] fill the sheet it opens.
  const InfoButton({required this.title, required this.body, super.key});

  /// The heading of the explanation.
  final String title;

  /// The explanation.
  final String body;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'What is this?',
      visualDensity: VisualDensity.compact,
      iconSize: 20,
      onPressed: () => showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        builder: (context) => SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
            child: Column(
              key: const Key('info-sheet'),
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                Text(body, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
        ),
      ),
      icon: const Icon(Icons.info_outline, color: CatwalkColors.teal),
    );
  }
}

/// The whole house in a few short parts, shown from the Cats tab.
class HouseGuide extends StatelessWidget {
  const HouseGuide({super.key});

  /// Opens the guide as a sheet.
  static Future<void> show(BuildContext context) => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => const HouseGuide(),
  );

  static const List<(String, String)> parts = [
    (
      'The idea',
      'You walk, you earn candy, and candy makes the house nicer. A nicer '
          'house makes your cats happier and brings new cats. Candy is the '
          'only currency.',
    ),
    (
      'Rooms and cats',
      'There are four rooms. Each holds three cats. Swipe to see them. The '
          'living room is yours from the start; buy the others in the Shop. '
          'A new room brings a new cat. Tap a cat to move it to another room.',
    ),
    (
      'Editing a room',
      'Tap the pencil at the top right. Round buttons show up. Tap one to '
          'buy an item for that place, swap it for another you own, or take '
          'it away. Nothing you own is ever lost. Toys can be laid in any '
          'room from the bar at the bottom.',
    ),
    (
      'Tiers',
      'Every place has three items: cheap, nicer and fanciest. The first is '
          'always for sale. The other two only appear in the shop after a cat '
          'brings them to you as a gift or a wish.',
    ),
    (
      'Likes and hearts',
      'Each cat likes two things: sun, heights, toys, quiet, company or '
          'food. Items give a room those things. The hearts on a cat show how '
          'many of its likes the room has. Cats sit more at places they like.',
    ),
    (
      'Mood',
      'Your steps decide how a cat feels, nothing else. Hearts only soften '
          'it: a cat with two hearts looks one step milder after a missed '
          'day. A cat still runs away after three missed days.',
    ),
    (
      'Gifts',
      'When you reach your daily goal, up to three cats hold a gift. Look '
          'for the gift badge, tap the cat, and open it. Small gifts '
          'disappear after a day.',
    ),
    (
      'Wishes',
      'A cat can have one wish. It never runs out and never costs you '
          'anything. An item wish asks for something for the room. A walk '
          'wish puts a star on the map: walk within 30 metres of it. Either '
          'one pays candy and makes the cat\'s next gift better.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
        child: Column(
          key: const Key('house-guide'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'How the house works',
                    style: theme.textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  key: const Key('guide-close'),
                  tooltip: 'Close',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            for (final (title, body) in parts) ...[
              const SizedBox(height: 16),
              Text(title, style: theme.textTheme.titleMedium),
              const SizedBox(height: 2),
              Text(body, style: theme.textTheme.bodyMedium),
            ],
          ],
        ),
      ),
    );
  }
}
