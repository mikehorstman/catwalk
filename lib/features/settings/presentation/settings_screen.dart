import 'step_source_card.dart';
import '../../dev/dev_section.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/format.dart';
import '../../../services/storage/local_store_provider.dart';
import '../../../services/health/step_repository_provider.dart';
import '../../daily_goal/data/goal_suggestion_service.dart';
import '../../daily_goal/domain/goal_suggestion.dart';
import '../../history/presentation/history_controller.dart';
import '../../onboarding/presentation/onboarding_controller.dart';
import '../../steps/presentation/home_controller.dart';
import '../data/profile_repository.dart';
import 'daily_goal_field.dart';
import 'prefs_section.dart';

/// Settings page: change the daily goal, allow step access, or reset the app.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

/// State for [SettingsScreen]: the goal text field and busy flags.
class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  /// Goal text field. Filled once from the saved profile.
  final _goalController = TextEditingController();

  /// True after the field was filled from the profile, so later rebuilds do not
  /// overwrite what the player is typing.
  bool _loaded = false;

  /// True while saving, so Save cannot be pressed twice.
  bool _saving = false;

  /// True while a goal suggestion is being fetched.
  bool _suggesting = false;

  @override
  void dispose() {
    _goalController.dispose();
    super.dispose();
  }

  /// True when the typed goal is a whole number inside the allowed min/max range.
  bool get _goalValid {
    final goal = int.tryParse(_goalController.text);
    return goal != null &&
        goal >= AppConstants.minDailyStepGoal &&
        goal <= AppConstants.maxDailyStepGoal;
  }

  /// The typed goal in steps, or the default goal while the text is not a number.
  int get _typedGoal =>
      int.tryParse(_goalController.text) ?? AppConstants.defaultDailyStepGoal;

  /// Fills the field from the last week, without saving it.
  Future<void> _suggestGoal() async {
    if (_suggesting) return;
    setState(() => _suggesting = true);
    final repository = ref.read(stepRepositoryProvider);
    try {
      await repository.requestPermissions();
    } catch (_) {
      // Nothing to read is not an error.
    }
    final suggestion = await ref
        .read(goalSuggestionServiceProvider)
        .fromPhone();
    if (!mounted) return;
    setState(() {
      _suggesting = false;
      if (suggestion != null) _goalController.text = '${suggestion.goal}';
    });
    final message = suggestion == null
        ? 'Not enough step history yet. '
              '${formatNumber(AppConstants.defaultDailyStepGoal)} is a safe goal.'
        : 'You averaged about ${formatNumber(suggestion.medianSteps)} steps on '
              '${suggestion.daysUsed} days. Save to keep '
              '${formatNumber(suggestion.goal)}.';
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  /// Saves the typed goal to the profile and refreshes the home screen.
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

  /// Asks the phone for step access again, e.g. after it was refused in onboarding.
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

  /// After confirmation, wipes all local data (cat, history, goal) and returns to
  /// onboarding.
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
                'Between ${formatNumber(AppConstants.minDailyStepGoal)} and '
                '${formatNumber(AppConstants.maxDailyStepGoal)} steps. Most of the '
                'health benefit sits around '
                '${formatNumber(AppConstants.benefitReferenceSteps)} steps, and a '
                'higher goal earns more candy.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              DailyGoalField(
                controller: _goalController,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 6),
              Text(
                'About ${goalInMinutes(_typedGoal)} minutes of walking a day.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: _suggesting ? null : _suggestGoal,
                  icon: const Icon(Icons.auto_awesome, size: 18),
                  label: Text(
                    _suggesting ? 'Looking at your week…' : 'Use my last week',
                  ),
                ),
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
              const PrefsSection(),
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
              const SizedBox(height: 12),
              const StepSourceCard(),
              const SizedBox(height: 32),
              const DevSection(),
              const SizedBox(height: 32),
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
