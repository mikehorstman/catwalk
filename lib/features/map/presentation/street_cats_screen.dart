import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../cat/presentation/widgets/cat_head_icon.dart';
import '../data/street_cat_repository.dart';
import '../domain/street_cat.dart';

/// Opens the street cats you have met.
Future<void> openStreetCats(BuildContext context) => Navigator.of(context)
    .push(MaterialPageRoute<void>(builder: (_) => const StreetCatsScreen()));

/// Every street cat you have photographed, with your photos and how many more
/// it takes before it will join. The photos live on this phone only.
class StreetCatsScreen extends ConsumerWidget {
  const StreetCatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cats = ref.watch(streetCatsProvider).value ?? const <StreetCat>[];
    return Scaffold(
      appBar: AppBar(title: const Text('Street cats')),
      body: cats.isEmpty
          ? const Padding(
              padding: EdgeInsets.all(32),
              child: Center(
                child: Text(
                  'No street cats yet. When one stands on your map, walk up '
                  'to it and take a photo. Three photos and it may join you.',
                  key: Key('street-cats-empty'),
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                for (final cat in cats) ...[
                  _StreetCatTile(cat: cat),
                  const SizedBox(height: 12),
                ],
                Text(
                  'Photos stay on this phone. They are never uploaded.',
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: CatwalkColors.inkMuted),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
    );
  }
}

class _StreetCatTile extends StatelessWidget {
  const _StreetCatTile({required this.cat});

  final StreetCat cat;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = cat.joined
        ? 'Lives in your room'
        : cat.ready
        ? 'Ready to join. Needs a free place.'
        : '${cat.sightings} of $sightingsToJoin photos';
    return Card(
      key: Key('street-cat-${cat.id}'),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: cat.appearance.color,
                  child: const CatHeadIcon(size: 22, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(cat.name, style: theme.textTheme.titleMedium),
                      Text(
                        status,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: CatwalkColors.inkMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (cat.photos.isNotEmpty) ...[
              const SizedBox(height: 12),
              SizedBox(
                height: 96,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    for (final path in cat.photos)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.file(
                            File(path.split('#').first),
                            width: 96,
                            height: 96,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => Container(
                              width: 96,
                              height: 96,
                              color: CatwalkColors.card,
                              child: const Icon(Icons.photo_outlined),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
