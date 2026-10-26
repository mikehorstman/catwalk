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
    final inventory = ref.watch(homeControllerProvider).value?.inventory;
    if (inventory == null) return const SizedBox(height: 120);
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
          const SizedBox(height: 8),
          Text(
            'Toys you own: ${inventory.toys.isEmpty ? 'none yet' : inventory.toys.join(', ')}.',
            style: muted,
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
