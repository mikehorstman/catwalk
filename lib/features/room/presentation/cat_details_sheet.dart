import 'package:flutter/material.dart';
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
      child: Padding(
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
