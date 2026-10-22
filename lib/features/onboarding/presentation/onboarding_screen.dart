import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/format.dart';
import '../../../services/health/step_repository_provider.dart';
import '../../cat/domain/cat_appearance.dart';
import '../../daily_goal/data/goal_suggestion_service.dart';
import '../../daily_goal/domain/goal_suggestion.dart';
import '../../settings/presentation/daily_goal_field.dart';
import 'onboarding_controller.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _pageController = PageController();
  final _nameController = TextEditingController();
  final _goalController = TextEditingController(
    text: '${AppConstants.defaultDailyStepGoal}',
  );
  int _page = 0;
  bool _saving = false;
  bool _suggesting = false;
  String? _permissionNote;

  static const _pageCount = 5;

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    _goalController.dispose();
    super.dispose();
  }

  /// Asks the phone for the last week and fills the goal from it.
  Future<void> _suggestGoal() async {
    if (_suggesting) return;
    setState(() => _suggesting = true);
    final repository = ref.read(stepRepositoryProvider);
    try {
      await repository.requestPermissions();
    } catch (_) {
      // A refusal is not an error: there is just nothing to suggest from.
    }
    final suggestion = await ref
        .read(goalSuggestionServiceProvider)
        .fromPhone();
    if (!mounted) return;
    setState(() {
      _suggesting = false;
      if (suggestion != null) {
        _goalController.text = '${suggestion.goal}';
        ref
            .read(onboardingControllerProvider.notifier)
            .setDailyStepGoal(suggestion.goal);
      }
    });
    final message = suggestion == null
        ? 'Not enough step history yet. ${formatNumber(AppConstants.defaultDailyStepGoal)} is a good start.'
        : 'You averaged about ${formatNumber(suggestion.medianSteps)} steps on '
              '${suggestion.daysUsed} days, so ${formatNumber(suggestion.goal)} '
              'gives you something to reach for.';
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  bool get _canContinue {
    final draft = ref.read(onboardingControllerProvider);
    return switch (_page) {
      2 => draft.name.trim().isNotEmpty,
      3 =>
        draft.dailyStepGoal >= AppConstants.minDailyStepGoal &&
            draft.dailyStepGoal <= AppConstants.maxDailyStepGoal,
      _ => true,
    };
  }

  Future<void> _next() async {
    if (!_canContinue || _saving) return;
    if (_page == 3) {
      await _askPermission();
    }
    if (_page < _pageCount - 1) {
      await _pageController.nextPage(
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOut,
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(onboardingControllerProvider.notifier).complete();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _askPermission() async {
    final granted = await ref
        .read(onboardingControllerProvider.notifier)
        .requestHealthPermission();
    if (!mounted) return;
    setState(() {
      _permissionNote = granted ? 'Step access is on.' : 'Step access is not available yet. You can continue, and turn it on later in Settings.';
    });
  }

  void _back() {
    _pageController.previousPage(
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(onboardingControllerProvider);
    final theme = Theme.of(context);
    final lastPage = _page == _pageCount - 1;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Step ${_page + 1} of $_pageCount',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  onPageChanged: (page) => setState(() => _page = page),
                  children: [
                    const _WelcomeStep(),
                    _ChooseCatStep(
                      selected: draft.appearance,
                      onSelected: (appearance) {
                        ref
                            .read(onboardingControllerProvider.notifier)
                            .selectAppearance(appearance);
                      },
                    ),
                    _NameStep(
                      controller: _nameController,
                      onChanged: (value) {
                        ref
                            .read(onboardingControllerProvider.notifier)
                            .setName(value);
                        setState(() {});
                      },
                    ),
                    _GoalStep(
                      controller: _goalController,
                      goal:
                          int.tryParse(_goalController.text) ??
                          AppConstants.defaultDailyStepGoal,
                      suggesting: _suggesting,
                      onSuggest: _suggestGoal,
                      onChanged: (value) {
                        final goal = int.tryParse(value);
                        if (goal != null) {
                          ref
                              .read(onboardingControllerProvider.notifier)
                              .setDailyStepGoal(goal);
                        }
                        setState(() {});
                      },
                    ),
                    _PermissionStep(
                      catName: draft.name.trim(),
                      note: _permissionNote,
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  if (_page > 0)
                    TextButton(
                      onPressed: _saving ? null : _back,
                      child: const Text('Back'),
                    )
                  else
                    const SizedBox(width: 64),
                  const Spacer(),
                  FilledButton(
                    onPressed: _canContinue && !_saving ? _next : null,
                    child: Text(
                      _saving
                          ? 'Saving'
                          : lastPage
                          ? 'Start walking'
                          : 'Continue',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WelcomeStep extends StatelessWidget {
  const _WelcomeStep();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Catwalk', style: theme.textTheme.headlineMedium),
        const SizedBox(height: 12),
        Text(
          'A small cat who needs your daily walk.',
          style: theme.textTheme.titleLarge,
        ),
        const SizedBox(height: 16),
        Text(
          'Choose a companion, set a step goal, and keep them company by walking.',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _ChooseCatStep extends StatelessWidget {
  const _ChooseCatStep({required this.selected, required this.onSelected});

  final CatAppearance selected;
  final ValueChanged<CatAppearance> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Choose a cat', style: theme.textTheme.headlineMedium),
        const SizedBox(height: 8),
        Text(
          'This is a placeholder. Real artwork can replace it later.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            for (final appearance in CatAppearance.values) ...[
              Expanded(
                child: _CatChoice(
                  appearance: appearance,
                  selected: appearance == selected,
                  onTap: () => onSelected(appearance),
                ),
              ),
              if (appearance != CatAppearance.values.last)
                const SizedBox(width: 12),
            ],
          ],
        ),
      ],
    );
  }
}

class _CatChoice extends StatelessWidget {
  const _CatChoice({
    required this.appearance,
    required this.selected,
    required this.onTap,
  });

  final CatAppearance appearance;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? theme.colorScheme.secondary
                : theme.colorScheme.outlineVariant,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(Icons.pets, size: 36, color: appearance.color),
            const SizedBox(height: 10),
            Text(appearance.label, style: theme.textTheme.labelLarge),
          ],
        ),
      ),
    );
  }
}

class _NameStep extends StatelessWidget {
  const _NameStep({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Name your cat',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 20),
        TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          maxLength: 24,
          decoration: const InputDecoration(
            labelText: 'Name',
            hintText: 'Mimi',
            border: OutlineInputBorder(),
          ),
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _GoalStep extends StatelessWidget {
  const _GoalStep({
    required this.controller,
    required this.goal,
    required this.suggesting,
    required this.onSuggest,
    required this.onChanged,
  });

  final TextEditingController controller;
  final int goal;
  final bool suggesting;
  final VoidCallback onSuggest;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Daily step goal', style: theme.textTheme.headlineMedium),
        const SizedBox(height: 8),
        Text(
          'Most of the health benefit sits around '
          '${formatNumber(AppConstants.benefitReferenceSteps)} steps a day. '
          'You can change it later.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 20),
        DailyGoalField(controller: controller, onChanged: onChanged),
        const SizedBox(height: 6),
        Text(
          'About ${goalInMinutes(goal)} minutes of walking a day.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 14),
        OutlinedButton.icon(
          onPressed: suggesting ? null : onSuggest,
          icon: const Icon(Icons.auto_awesome, size: 18),
          label: Text(
            suggesting ? 'Looking at your week…' : 'Not sure? Use my last week',
          ),
        ),
      ],
    );
  }
}

class _PermissionStep extends StatelessWidget {
  const _PermissionStep({required this.catName, required this.note});

  final String catName;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = catName.isEmpty ? 'Your cat' : catName;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Step access', style: theme.textTheme.headlineMedium),
        const SizedBox(height: 12),
        Text(
          '$name needs your daily step count. Catwalk reads steps from Apple Health on iPhone and Health Connect on Android.',
          style: theme.textTheme.bodyLarge,
        ),
        if (note != null) ...[
          const SizedBox(height: 16),
          Text(
            note!,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}
