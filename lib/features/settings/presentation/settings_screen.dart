import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../services/storage/local_store_provider.dart';
import '../../history/presentation/history_controller.dart';
import '../../onboarding/presentation/onboarding_controller.dart';
import '../../steps/presentation/home_controller.dart';
import '../data/profile_repository.dart';
import 'daily_goal_field.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _goalController = TextEditingController();
  bool _loaded = false;
  bool _saving = false;

  @override
  void dispose() {
    _goalController.dispose();
    super.dispose();
  }

  bool get _goalValid {
    final goal = int.tryParse(_goalController.text);
    return goal != null && goal >= 1000 && goal <= 30000;
  }

  Future<void> _saveGoal() async {
    final goal = int.tryParse(_goalController.text);
    if (goal == null || !_goalValid || _saving) return;
    setState(() => _saving = true);
    try {
      final repository = ref.read(profileRepositoryProvider);
      final profile = await repository.read();
      await repository.write(profile.copyWith(dailyStepGoal: goal));
      ref.invalidate(profileProvider);
      ref.invalidate(homeControllerProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('New goal applies from tomorrow.')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _requestStepAccess() async {
    final granted = await ref
        .read(homeControllerProvider.notifier)
        .requestStepAccess();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          granted
              ? 'Step access is on.'
              : 'Step access was not granted. You can try again here.',
        ),
      ),
    );
  }

  Future<void> _reset() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Start over?'),
        content: const Text(
          'This deletes your cat, your history, and your goal. '
          'You will go back to the start.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete everything'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(localStoreProvider).clear();
    ref.invalidate(profileProvider);
    ref.invalidate(historyViewProvider);
    ref.invalidate(homeControllerProvider);
    ref.invalidate(onboardingCompletedProvider);
    if (!mounted) return;
    context.go('/onboarding');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final profile = ref.watch(profileProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: profile.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) =>
            const Center(child: Text('Could not load your settings.')),
        data: (value) {
          if (!_loaded) {
            _goalController.text = '${value.dailyStepGoal}';
            _loaded = true;
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
            children: [
              Text('Daily step goal', style: theme.textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(
                'Between ${_format(1000)} and ${_format(30000)} steps. '
                'A higher goal earns more XP each day.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              DailyGoalField(
                controller: _goalController,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton(
                  onPressed: _goalValid && !_saving ? _saveGoal : null,
                  child: const Text('Save goal'),
                ),
              ),
              const SizedBox(height: 40),
              Text('Step access', style: theme.textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(
                'Catwalk reads your steps from Apple Health on iPhone and '
                'Health Connect on Android. It never counts steps itself.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton(
                  onPressed: _requestStepAccess,
                  child: const Text('Allow step access'),
                ),
              ),
              const SizedBox(height: 40),
              Text('Start over', style: theme.textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(
                'Delete your cat, history, and goal, and return to the start.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton(
                  onPressed: _reset,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: theme.colorScheme.error,
                  ),
                  child: const Text('Reset Catwalk'),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

String _format(int value) {
  final text = value.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < text.length; i++) {
    final fromEnd = text.length - i;
    if (i > 0 && fromEnd % 3 == 0) buffer.write(',');
    buffer.write(text[i]);
  }
  return buffer.toString();
}
