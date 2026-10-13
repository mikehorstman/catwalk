import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../../app/theme.dart';
import '../../cat/domain/cat_appearance.dart';
import '../../cat/domain/cat_mood.dart';
import '../domain/cat_action.dart';
import 'cat_animations.dart';

/// Preview one action for every cat colour, looping, with a foot line.
///
/// This is how sprite sheets get checked without waiting for the planner to
/// pick an action: change the action, flip the facing, and see all three tints
/// side by side — which is where a tinted neutral sheet gives itself away.
class AnimationLabSheet extends StatefulWidget {
  const AnimationLabSheet({this.animations = const PlaceholderCatAnimations(), super.key});

  final CatAnimationSet animations;

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: CatwalkColors.card,
      showDragHandle: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => const AnimationLabSheet(),
    );
  }

  @override
  State<AnimationLabSheet> createState() => _AnimationLabSheetState();
}

class _AnimationLabSheetState extends State<AnimationLabSheet>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker((_) => setState(() {}));
  late final DateTime _start = DateTime.now();

  CatAction _action = CatAction.walk;
  CatFacing _facing = CatFacing.right;
  bool _guide = true;

  @override
  void initState() {
    super.initState();
    _ticker.start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  Duration get _elapsed => DateTime.now().difference(_start);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Animation lab', style: theme.textTheme.titleLarge),
            const SizedBox(height: 2),
            Text(
              'Placeholder art. Drop a sprite manifest in to replace it.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final action in CatAction.values)
                  ChoiceChip(
                    label: Text(action.name),
                    selected: _action == action,
                    onSelected: (_) => setState(() => _action = action),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                FilterChip(
                  label: const Text('facing left'),
                  selected: _facing == CatFacing.left,
                  onSelected: (on) => setState(
                    () => _facing = on ? CatFacing.left : CatFacing.right,
                  ),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('foot line'),
                  selected: _guide,
                  onSelected: (on) => setState(() => _guide = on),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 190,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (final appearance in CatAppearance.values)
                    Expanded(
                      child: _Preview(
                        animations: widget.animations,
                        appearance: appearance,
                        action: _action,
                        mood: CatMood.neutral,
                        facing: _facing,
                        elapsed: _elapsed,
                        guide: _guide,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Preview extends StatelessWidget {
  const _Preview({
    required this.animations,
    required this.appearance,
    required this.action,
    required this.mood,
    required this.facing,
    required this.elapsed,
    required this.guide,
  });

  final CatAnimationSet animations;
  final CatAppearance appearance;
  final CatAction action;
  final CatMood mood;
  final CatFacing facing;
  final Duration elapsed;
  final bool guide;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        animations.frame(
          context,
          appearance: appearance,
          action: action,
          mood: mood,
          facing: facing,
          elapsed: elapsed,
          size: 96,
        ),
        if (guide)
          Container(height: 2, width: 96, color: CatwalkColors.teal),
        const SizedBox(height: 6),
        Text(
          appearance.label,
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
