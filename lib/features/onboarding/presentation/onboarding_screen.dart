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

/// The five-page first-run flow: welcome, choose a cat, name it, set a daily
/// step goal, then ask for step access. Paging is by buttons only (no swiping).
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

/// State for [OnboardingScreen]: page position, text fields and busy flags.
class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  /// Drives the page view.
  final _pageController = PageController();

  /// Text field for the cat's name.
  final _nameController = TextEditingController();

  /// Text field for the goal; starts at the default goal.
  final _goalController = TextEditingController(
    text: '${AppConstants.defaultDailyStepGoal}',
  );

  /// Zero-based index of the visible page.
  int _page = 0;

  /// True while the final save runs, so buttons cannot be pressed twice.
  bool _saving = false;

  /// True while a goal suggestion is being fetched from the phone.
  bool _suggesting = false;

  /// Message shown on the permission page after asking. Null until asked.
  String? _permissionNote;

  /// Total pages: welcome, cat, name, goal, step access.
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

  /// Whether the current page is filled in well enough to move on: the name page
  /// needs a non-blank name, the goal page needs a goal within the allowed range.
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

  /// Goes to the next page. Leaving the goal page asks for step access first; on
  /// the last page it saves everything and finishes onboarding.
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

  /// Asks for step access and sets a note. A "no" never blocks the player.
  Future<void> _askPermission() async {
    final granted = await ref
        .read(onboardingControllerProvider.notifier)
        .requestHealthPermission();
    if (!mounted) return;
    setState(() {
      _permissionNote = granted ? 'Step access is on.' : 'Step access is not available yet. You can continue, and turn it on later in Settings.';
    });
  }

  /// Goes back one page.
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

/// Page 1: what Catwalk is.
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

/// Page 2: pick a cat look from the available appearances.
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

/// One tappable cat card; the selected one gets a thicker border.
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

/// Page 3: text field for the cat's name (up to 24 characters).
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

/// Page 4: daily step goal field, a minutes-of-walking hint and a button that
/// suggests a goal from the last week.
class _GoalStep extends StatelessWidget {
  const _GoalStep({
    required this.controller,
    required this.goal,
    required this.suggesting,
    required this.onSuggest,
    required this.onChanged,
  });

  final TextEditingController controller;

  /// The goal currently typed, in steps; used for the minutes hint.
  final int goal;

  /// True while the suggestion is loading (disables the button).
  final bool suggesting;

  /// Called when the player asks for a suggestion.
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

/// Page 5: explains why step access is needed and shows the result note.
class _PermissionStep extends StatelessWidget {
  const _PermissionStep({required this.catName, required this.note});

  /// The cat's name; blank falls back to "Your cat".
  final String catName;

  /// Result of the permission request, or null before it was asked.
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
