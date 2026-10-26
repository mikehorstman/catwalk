import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../daily_goal/domain/shop.dart';
import 'home_controller.dart';

/// Opens the shop: what the candy buys. For now that is the toys; cat beds
/// come with more cats.
void showShopSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => const _ShopSheet(),
  );
}

class _ShopSheet extends ConsumerWidget {
  const _ShopSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final home = ref.watch(homeControllerProvider).value;
    if (home == null) return const SizedBox(height: 120);
    final inventory = home.inventory;
    final muted = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final forSale = toysForSale(inventory);
    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        children: [
          Text('Shop', style: theme.textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(
            'You have ${inventory.candy} candy. '
            'Walk to your goal to earn more.',
            style: muted,
          ),
          const SizedBox(height: 16),
          if (forSale.isEmpty)
            Text(
              'You own every toy. Cat beds come with more cats.',
              style: muted,
            )
          else
            for (final id in forSale)
              _ToyRow(
                toyId: id,
                affordable: inventory.candy >= AppConstants.toyPriceCandy,
                onBuy: () =>
                    ref.read(homeControllerProvider.notifier).buyToy(id),
              ),
          const SizedBox(height: 16),
          _BedRow(
            price: bedPrice(inventory.beds),
            candy: inventory.candy,
            freeBeds: home.freeBeds,
            waiting: home.arrival != null,
            onBuy: () => ref.read(homeControllerProvider.notifier).buyBed(),
          ),
          const SizedBox(height: 12),
          Text(
            'Toys you own: ${inventory.toys.isEmpty ? 'none yet' : inventory.toys.join(', ')}.',
            style: muted,
          ),
        ],
      ),
    );
  }
}

/// The cat bed for sale: each bed holds one more cat, and costs more than the
/// last.
class _BedRow extends StatelessWidget {
  const _BedRow({
    required this.price,
    required this.candy,
    required this.freeBeds,
    required this.waiting,
    required this.onBuy,
  });

  /// What the next bed costs.
  final int price;

  /// How much candy the player has.
  final int candy;

  /// Beds with nobody in them.
  final int freeBeds;

  /// Whether a cat is already waiting on the map.
  final bool waiting;

  /// Called when the player taps Buy.
  final VoidCallback onBuy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final String note;
    if (waiting) {
      note = 'A cat is waiting for you on the map.';
    } else if (freeBeds > 0) {
      note = 'You have an empty bed. Fill it first.';
    } else {
      note = 'Buy a bed and a new cat appears on the map tomorrow.';
    }
    final canBuy = !waiting && freeBeds == 0 && candy >= price;
    return Container(
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
                Text('Cat bed', style: theme.textTheme.bodyLarge),
                Text(
                  note,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            key: const Key('buy-bed'),
            onPressed: canBuy ? onBuy : null,
            child: Text('$price candy'),
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
              child: Text('$name toy', style: theme.textTheme.bodyLarge),
            ),
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
