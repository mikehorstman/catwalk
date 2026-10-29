import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../room/data/room_layout_provider.dart';
import '../../steps/presentation/home_controller.dart'
    show homeControllerProvider;
import '../data/home_state_repository.dart';
import '../domain/decoration_catalogue.dart';
import '../domain/home_state.dart';
import '../domain/room_type.dart';

/// The sheet for one slot of a room: the three decorations that can stand
/// there, with what you own, what you can buy and what is still locked.
class SlotSheet extends ConsumerWidget {
  /// Creates the sheet.
  const SlotSheet({required this.room, required this.slot, super.key});

  /// The room.
  final RoomType room;

  /// The slot.
  final Slot slot;

  /// Opens the sheet.
  static Future<void> show(BuildContext context, RoomType room, Slot slot) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: CatwalkColors.card,
      showDragHandle: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SlotSheet(room: room, slot: slot),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final home = ref.watch(homeStateProvider).value ?? const HomeState();
    final candy = ref.watch(inventoryProvider).value?.candy ?? 0;
    final standing = home.itemAt(room, slot);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${room.label}: ${slot.name}',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            Text(
              standing == null ? 'Nothing here yet.' : 'Now: ${standing.name}.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            for (final item in itemsForSlot(room, slot))
              _ItemRow(
                item: item,
                home: home,
                candy: candy,
                standing: standing?.id == item.id,
              ),
          ],
        ),
      ),
    );
  }
}

class _ItemRow extends ConsumerWidget {
  const _ItemRow({
    required this.item,
    required this.home,
    required this.candy,
    required this.standing,
  });

  final ItemSpec item;
  final HomeState home;
  final int candy;
  final bool standing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final owned = home.hasItem(item);
    final buyable = home.canBuy(item);
    Widget action;
    if (standing) {
      action = const Text('Standing here', key: Key('item-standing'));
    } else if (owned) {
      action = OutlinedButton(
        key: Key('item-place-${item.id}'),
        onPressed: () async {
          await ref.read(homeControllerProvider.notifier).placeItem(item);
        },
        child: const Text('Place'),
      );
    } else if (buyable) {
      action = FilledButton(
        key: Key('item-buy-${item.id}'),
        onPressed: candy < item.price
            ? null
            : () async {
                await ref.read(homeControllerProvider.notifier).buyItem(item);
                ref.invalidate(inventoryProvider);
              },
        child: Text('${item.price} candy'),
      );
    } else {
      action = Text(
        'Locked',
        key: Key('item-locked-${item.id}'),
        style: theme.textTheme.bodySmall,
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        key: Key('item-row-${item.id}'),
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.name, style: theme.textTheme.titleMedium),
                Text(
                  [for (final like in item.tags) like.label].join(' · ') +
                      (owned || buyable ? '' : '  ·  a cat may bring this'),
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          action,
        ],
      ),
    );
  }
}
