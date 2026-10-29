import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/calendar_date.dart';
import '../../core/utils/format.dart';
import '../settings/data/profile_repository.dart';
import 'dev_actions.dart';
import 'dev_settings.dart';

/// The developer mode switch and, while it is on, the tools to try every part
/// of the game without waiting for days of walking.
class DevSection extends ConsumerStatefulWidget {
  const DevSection({super.key});

  @override
  ConsumerState<DevSection> createState() => _DevSectionState();
}

class _DevSectionState extends ConsumerState<DevSection> {
  final TextEditingController _steps = TextEditingController();
  int _daysAgo = 0;
  String? _message;

  @override
  void dispose() {
    _steps.dispose();
    super.dispose();
  }

  void _say(String text) => setState(() => _message = text);

  String _dayLabel(int daysAgo) => switch (daysAgo) {
    0 => 'Today',
    1 => 'Yesterday',
    _ => '$daysAgo days ago',
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dev = ref.watch(devSettingsProvider).value ?? const DevSettings();
    final actions = ref.read(devActionsProvider);
    final goal = ref.watch(profileProvider).value?.dailyStepGoal ?? 6000;
    final typed =
        dev.steps[CalendarDate.today().addDays(-_daysAgo).toIsoDate()];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile(
          key: const Key('dev-switch'),
          contentPadding: EdgeInsets.zero,
          title: const Text('Developer mode'),
          subtitle: const Text(
            'Type in steps, get endless candy and try every part of the '
            'game. For testing only.',
          ),
          value: dev.enabled,
          onChanged: actions.setEnabled,
        ),
        if (dev.enabled)
          Card(
            key: const Key('dev-panel'),
            margin: const EdgeInsets.only(top: 8),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Steps', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(
                    typed == null
                        ? '${_dayLabel(_daysAgo)}: the real count is used.'
                        : '${_dayLabel(_daysAgo)}: ${formatNumber(typed)} '
                              'steps, typed in.',
                    key: const Key('dev-steps-state'),
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                  DropdownButton<int>(
                    key: const Key('dev-day'),
                    value: _daysAgo,
                    items: [
                      for (var d = 0; d < 7; d++)
                        DropdownMenuItem(value: d, child: Text(_dayLabel(d))),
                    ],
                    onChanged: (d) => setState(() => _daysAgo = d ?? 0),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          key: const Key('dev-steps-field'),
                          controller: _steps,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          decoration: const InputDecoration(
                            labelText: 'Steps',
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        key: const Key('dev-steps-set'),
                        onPressed: () async {
                          final n = int.tryParse(_steps.text);
                          if (n == null) return;
                          await actions.setSteps(_daysAgo, n);
                          _say('Set ${_dayLabel(_daysAgo)} to $n steps.');
                        },
                        child: const Text('Set'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      ActionChip(
                        key: const Key('dev-steps-goal'),
                        label: Text('Reach goal (${formatNumber(goal)})'),
                        onPressed: () async {
                          await actions.setSteps(_daysAgo, goal);
                          _say('Goal reached for ${_dayLabel(_daysAgo)}.');
                        },
                      ),
                      ActionChip(
                        key: const Key('dev-steps-miss'),
                        label: const Text('Miss the day (0)'),
                        onPressed: () async {
                          await actions.setSteps(_daysAgo, 0);
                          _say('${_dayLabel(_daysAgo)} set to 0 steps.');
                        },
                      ),
                      ActionChip(
                        key: const Key('dev-steps-more'),
                        label: const Text('+1,000'),
                        onPressed: () async {
                          await actions.setSteps(_daysAgo, (typed ?? 0) + 1000);
                          _say('Added 1,000 steps.');
                        },
                      ),
                      ActionChip(
                        key: const Key('dev-steps-clear'),
                        label: const Text('Use real steps'),
                        onPressed: () async {
                          await actions.setSteps(_daysAgo, null);
                          _say('${_dayLabel(_daysAgo)}: real count again.');
                        },
                      ),
                    ],
                  ),
                  const Divider(height: 28),
                  Text('Candy and freezes', style: theme.textTheme.titleMedium),
                  SwitchListTile(
                    key: const Key('dev-unlimited'),
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Unlimited candy'),
                    value: dev.unlimitedCandy,
                    onChanged: actions.setUnlimitedCandy,
                  ),
                  Wrap(
                    spacing: 8,
                    children: [
                      ActionChip(
                        key: const Key('dev-candy-100'),
                        label: const Text('+100 candy'),
                        onPressed: () async {
                          await actions.addCandy(100);
                          _say('Added 100 candy.');
                        },
                      ),
                      ActionChip(
                        key: const Key('dev-candy-1000'),
                        label: const Text('+1,000 candy'),
                        onPressed: () async {
                          await actions.addCandy(1000);
                          _say('Added 1,000 candy.');
                        },
                      ),
                      ActionChip(
                        key: const Key('dev-freezes'),
                        label: const Text('+3 freezes'),
                        onPressed: () async {
                          await actions.addFreezes(3);
                          _say('Added 3 streak freezes.');
                        },
                      ),
                    ],
                  ),
                  const Divider(height: 28),
                  Text('The house', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      ActionChip(
                        key: const Key('dev-rooms'),
                        label: const Text('Unlock all rooms'),
                        onPressed: () async {
                          await actions.unlockAllRooms();
                          _say('All four rooms are yours.');
                        },
                      ),
                      ActionChip(
                        key: const Key('dev-items'),
                        label: const Text('Own all items'),
                        onPressed: () async {
                          await actions.ownAllItems();
                          _say('All 60 items are yours, every tier buyable.');
                        },
                      ),
                      ActionChip(
                        key: const Key('dev-cat'),
                        label: const Text('Add a cat'),
                        onPressed: () async {
                          final ok = await actions.addCat();
                          _say(
                            ok
                                ? 'A new cat moved in.'
                                : 'No free place. Unlock a room first.',
                          );
                        },
                      ),
                      ActionChip(
                        key: const Key('dev-gifts'),
                        label: const Text('Give gifts'),
                        onPressed: () async {
                          await actions.giveGifts();
                          _say('Up to 3 cats hold a gift. See the Cats tab.');
                        },
                      ),
                      ActionChip(
                        key: const Key('dev-wishes'),
                        label: const Text('Wishes now'),
                        onPressed: () async {
                          await actions.wishesNow();
                          _say('Cats without a wish make one.');
                        },
                      ),
                      ActionChip(
                        key: const Key('dev-walk-wish'),
                        label: const Text('Walk wish now'),
                        onPressed: () async {
                          final ok = await actions.walkWishNow();
                          _say(
                            ok
                                ? 'The first cat wishes for a walk. Open '
                                      'the Map for its star.'
                                : 'A walk wish is open already.',
                          );
                        },
                      ),
                    ],
                  ),
                  if (_message != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _message!,
                      key: const Key('dev-message'),
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
          ),
      ],
    );
  }
}
