import 'package:flutter/material.dart';

import '../../rooms/domain/decorations.dart' show ItemRefusal;
import '../../rooms/domain/wishes.dart';
import '../../rooms/presentation/gift_reveal.dart';
import '../../rooms/presentation/like_icons.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../cat/presentation/cat_voice.dart';
import '../../cat/data/cat_repository.dart';
import '../../rooms/domain/placement.dart';
import '../../steps/presentation/home_controller.dart';
import '../domain/room_cat.dart';

/// Tapping a cat opens this: who she is and how she is doing.
///
/// The room is a picture, not a dashboard. The numbers live here so the room can
/// stay full screen.
class CatDetailsSheet extends ConsumerWidget {
  const CatDetailsSheet({required this.cat, super.key});

  /// The cat to describe.
  final RoomCat cat;

  /// Opens the sheet over the room for [cat].
  static Future<void> show(BuildContext context, RoomCat cat) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: CatwalkColors.card,
      showDragHandle: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => CatDetailsSheet(cat: cat),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final home = ref.watch(homeControllerProvider).value;
    final moves = [
      if (home != null)
        for (final room in home.rooms)
          if (room != cat.cat.roomId && placesFree(room, home.cats) > 0) room,
    ];
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(cat.name, style: theme.textTheme.headlineMedium),
                ),
                Text(
                  cat.cat.appearance.label,
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
            const SizedBox(height: 18),
            _Row(label: 'Mood', value: moodLabel(cat.mood)),
            _Row(label: 'Status', value: statusLabel(cat.status)),
            if (cat.cat.consecutiveMissedDays > 0)
              _Row(
                label: 'Missed days',
                value: '${cat.cat.consecutiveMissedDays}',
              ),
            _Row(label: 'Lives in', value: cat.cat.roomId.label),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final like in cat.cat.likes)
                  Chip(
                    key: Key('like-${like.name}'),
                    avatar: Icon(
                      iconOfLike(like),
                      size: 18,
                      color: cat.likesMet.contains(like)
                          ? CatwalkColors.teal
                          : theme.disabledColor,
                    ),
                    label: Text(like.label),
                    backgroundColor: cat.likesMet.contains(like)
                        ? CatwalkColors.orangeSoft
                        : null,
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              key: const Key('comfort-hearts'),
              children: [
                for (var i = 0; i < 2; i++)
                  Icon(
                    i < cat.comfort.hearts
                        ? Icons.favorite
                        : Icons.favorite_border,
                    size: 18,
                    color: CatwalkColors.teal,
                  ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    likesLine(cat),
                    key: const Key('likes-line'),
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
            ),
            if (cat.hasGift) ...[
              const SizedBox(height: 12),
              FilledButton.icon(
                key: const Key('open-gift'),
                onPressed: () async {
                  await openGiftOf(context, ref, cat.id);
                  if (context.mounted) Navigator.of(context).pop();
                },
                icon: const Icon(Icons.card_giftcard),
                label: Text('Open ${cat.name}\'s gift'),
              ),
            ],
            if (cat.wish case final wish?) ...[
              const SizedBox(height: 12),
              _WishCard(cat: cat, wish: wish),
            ],
            if (cat.wishesGranted > 0)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Wishes granted: ${cat.wishesGranted}',
                  key: const Key('wishes-granted'),
                  style: theme.textTheme.bodySmall,
                ),
              ),
            if (moves.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  for (final room in moves)
                    OutlinedButton(
                      key: Key('move-to-${room.name}'),
                      onPressed: () async {
                        await ref
                            .read(catRepositoryProvider)
                            .moveCat(cat.id, room);
                        await ref
                            .read(homeControllerProvider.notifier)
                            .refreshSilently();
                        if (context.mounted) Navigator.of(context).pop();
                      },
                      child: Text('Move to ${room.label}'),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// One line of the sheet: a grey label on the left, a bold value on the right.
class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// One sentence on what the cat likes and whether its room gives it.
String likesLine(RoomCat cat) {
  final room = cat.cat.roomId.label.toLowerCase();
  final likes = cat.cat.likes.map((l) => l.label.toLowerCase()).toList();
  if (likes.isEmpty) return '';
  final liked = likes.length == 1 ? likes.first : '${likes[0]} and ${likes[1]}';
  final met = [
    for (final l in cat.cat.likes)
      if (cat.likesMet.contains(l)) l.label.toLowerCase(),
  ];
  if (met.isEmpty) return 'Likes $liked. The $room has none of it.';
  if (met.length == likes.length) return 'Likes $liked. The $room has both.';
  return 'Likes $liked. The $room has ${met.first}.';
}

/// The cat's open wish, with what the player can do about it.
class _WishCard extends ConsumerWidget {
  const _WishCard({required this.cat, required this.wish});

  final RoomCat cat;
  final Wish wish;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final item = wish.item;
    final house = ref.watch(homeControllerProvider).value?.house;
    final candy = ref.watch(homeControllerProvider).value?.inventory.candy ?? 0;
    Widget? action;
    if (item != null && house != null) {
      final inRoom = cat.cat.roomId == item.room;
      if (!house.owns(item.room)) {
        action = Text(
          'Needs the ${item.room.label.toLowerCase()}.',
          style: theme.textTheme.bodySmall,
        );
      } else if (house.hasItem(item)) {
        action = OutlinedButton(
          key: const Key('wish-place'),
          onPressed: () async {
            await ref.read(homeControllerProvider.notifier).placeItem(item);
          },
          child: Text(
            inRoom
                ? 'Place it'
                : 'Place it in the ${item.room.label.toLowerCase()}',
          ),
        );
      } else {
        action = FilledButton(
          key: const Key('wish-buy'),
          onPressed: candy < item.price
              ? null
              : () async {
                  final why = await ref
                      .read(homeControllerProvider.notifier)
                      .buyItem(item);
                  if (why == ItemRefusal.notEnoughCandy && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Not enough candy yet.')),
                    );
                  }
                },
          child: Text('Buy and place · ${item.price} candy'),
        );
      }
    } else if (wish.kind == WishKind.walk) {
      action = Text(
        wish.hasPlace
            ? 'Look for the star on the map.'
            : 'Open the map to see where.',
        key: const Key('walk-wish-hint'),
        style: theme.textTheme.bodySmall,
      );
    }
    return DecoratedBox(
      key: const Key('wish-card'),
      decoration: BoxDecoration(
        color: CatwalkColors.orangeSoft,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '“${wishText(cat.cat, wish)}”',
              key: const Key('wish-text'),
              style: theme.textTheme.titleSmall,
            ),
            if (item != null)
              Text(
                'In the ${item.room.label.toLowerCase()}: ${item.name}',
                style: theme.textTheme.bodySmall,
              ),
            ?action,
          ],
        ),
      ),
    );
  }
}
