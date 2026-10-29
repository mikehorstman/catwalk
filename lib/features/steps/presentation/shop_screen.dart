import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../daily_goal/domain/shop.dart';
import '../../map/domain/toy_perks.dart';
import '../../rooms/domain/room_constants.dart';
import '../../rooms/domain/room_type.dart';
import 'home_controller.dart';

/// Opens the shop as a full screen: what the candy buys.
Future<void> openShop(BuildContext context) =>
    Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => const ShopScreen()));

/// The shop: rooms, and toys with what each one does. Candy is the only
/// currency.
class ShopScreen extends ConsumerWidget {
  const ShopScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final home = ref.watch(homeControllerProvider).value;
    final muted = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Shop')),
      body: SafeArea(
        child: home == null
            ? const Center(child: CircularProgressIndicator())
            : _body(context, ref, home, theme, muted),
      ),
    );
  }

  Widget _body(
    BuildContext context,
    WidgetRef ref,
    HomeState home,
    ThemeData theme,
    TextStyle? muted,
  ) {
    final inventory = home.inventory;
    final forSale = toysForSale(inventory);
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
      children: [
        Text(
          'You have ${inventory.candy} candy. '
          'Walk to your goal to earn more.',
          style: muted,
        ),
        const SizedBox(height: 24),
        Text('Rooms', style: theme.textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(
          'Each room holds three cats. Buy a room and a new cat arrives on '
          'the map tomorrow.',
          style: muted,
        ),
        const SizedBox(height: 12),
        for (final room in RoomType.values)
          _RoomRow(
            room: room,
            owned: home.rooms.contains(room),
            price: RoomType.priceForNext(home.rooms.length),
            candy: inventory.candy,
            cats: home.cats.where((c) => c.roomId == room).length,
            onBuy: () =>
                ref.read(homeControllerProvider.notifier).buyRoom(room),
          ),
        const SizedBox(height: 28),
        Text('Toys', style: theme.textTheme.titleMedium),
        const SizedBox(height: 12),
        if (forSale.isEmpty)
          Text('You own every toy.', style: muted)
        else
          for (final id in forSale)
            _ToyRow(
              toyId: id,
              affordable: inventory.candy >= AppConstants.toyPriceCandy,
              onBuy: () => ref.read(homeControllerProvider.notifier).buyToy(id),
            ),
        if (inventory.toys.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text('Toys you own', style: muted),
          const SizedBox(height: 4),
          for (final id in inventory.toys)
            Text('${_titleCase(id)}: ${toyPerkText[id] ?? ''}', style: muted),
        ],
      ],
    );
  }
}

String _titleCase(String id) =>
    id.isEmpty ? id : id[0].toUpperCase() + id.substring(1);

/// One room in the shop: owned (with its places used), or for sale.
class _RoomRow extends StatelessWidget {
  const _RoomRow({
    required this.room,
    required this.owned,
    required this.price,
    required this.candy,
    required this.cats,
    required this.onBuy,
  });

  /// The room.
  final RoomType room;

  /// Whether the player owns it already.
  final bool owned;

  /// What the next room costs, or null when every room is owned.
  final int? price;

  /// How much candy the player has.
  final int candy;

  /// Cats living in this room.
  final int cats;

  /// Called when the player taps Buy.
  final VoidCallback onBuy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canBuy = !owned && price != null && candy >= price!;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: CatwalkColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: CatwalkColors.line),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(room.label, style: theme.textTheme.bodyLarge),
                Text(
                  owned
                      ? 'Yours. $cats of ${RoomConstants.placesPerRoom} '
                            'places used.'
                      : 'For cats that like '
                            '${room.baseLike.label.toLowerCase()}.',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          if (!owned)
            FilledButton(
              key: Key('buy-room-${room.name}'),
              onPressed: canBuy ? onBuy : null,
              child: Text(price == null ? 'Sold out' : '$price candy'),
            ),
        ],
      ),
    );
  }
}

class _ToyRow extends StatelessWidget {
  const _ToyRow({
    required this.toyId,
    required this.affordable,
    required this.onBuy,
  });

  /// The toy sold in this row.
  final String toyId;

  /// Whether the player has enough candy for it.
  final bool affordable;

  /// Called when the player taps Buy.
  final VoidCallback onBuy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = toyId.isEmpty
        ? toyId
        : toyId[0].toUpperCase() + toyId.substring(1);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: CatwalkColors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: CatwalkColors.line),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$name toy', style: theme.textTheme.bodyLarge),
                  if (toyPerkText[toyId] case final perk?)
                    Text(
                      perk,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: affordable ? onBuy : null,
              child: Text('${AppConstants.toyPriceCandy} candy'),
            ),
          ],
        ),
      ),
    );
  }
}
