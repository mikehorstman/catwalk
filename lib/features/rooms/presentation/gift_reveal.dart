import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../reminders/application/reminder_scheduler.dart';
import '../../steps/presentation/home_controller.dart';

/// Opens the gift [catId] holds and shows what was inside. Offers reminders
/// once, after the first gift.
Future<void> openGiftOf(
  BuildContext context,
  WidgetRef ref,
  String catId,
) async {
  final lines = await ref
      .read(homeControllerProvider.notifier)
      .openCatGift(catId);
  if (lines.isEmpty || !context.mounted) return;
  await showDialog<void>(
    context: context,
    builder: (context) => GiftReveal(lines: lines),
  );
  final state = ref.read(homeControllerProvider).value;
  if (state != null) {
    await ref.read(reminderSchedulerProvider).askOnce(state);
  }
}

/// What a gift held, one line per thing.
class GiftReveal extends StatelessWidget {
  /// Creates the reveal.
  const GiftReveal({required this.lines, super.key});

  /// What the gift held.
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      icon: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.4, end: 1),
        duration: const Duration(milliseconds: 450),
        curve: Curves.elasticOut,
        builder: (context, scale, child) =>
            Transform.scale(scale: scale, child: child),
        child: const Icon(
          Icons.card_giftcard,
          size: 48,
          color: CatwalkColors.teal,
        ),
      ),
      title: const Text('Your gift'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final line in lines)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Text(
                line,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium,
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Nice'),
        ),
      ],
    );
  }
}
