import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../analytics/analytics_service.dart';
import '../../reminders/application/reminder_scheduler.dart';
import '../../reminders/data/notification_service.dart';
import '../../reminders/data/prefs_repository.dart';
import '../../steps/presentation/home_controller.dart';

/// The Reminders and Privacy switches in Settings.
class PrefsSection extends ConsumerStatefulWidget {
  const PrefsSection({super.key});

  @override
  ConsumerState<PrefsSection> createState() => _PrefsSectionState();
}

class _PrefsSectionState extends ConsumerState<PrefsSection> {
  AppPrefs? _prefs;

  @override
  void initState() {
    super.initState();
    ref.read(prefsRepositoryProvider).read().then((value) {
      if (mounted) setState(() => _prefs = value);
    });
  }

  Future<void> _save(AppPrefs next) async {
    setState(() => _prefs = next);
    await ref.read(prefsRepositoryProvider).write(next);
  }

  Future<void> _setReminders(bool on) async {
    final prefs = _prefs;
    if (prefs == null) return;
    await _save(prefs.copyWith(remindersEnabled: on, permissionAsked: true));
    final state = ref.read(homeControllerProvider).value;
    if (on) {
      await ref.read(notificationServiceProvider).requestPermission();
      if (state != null) {
        await ref.read(reminderSchedulerProvider).reschedule(state);
      }
    } else {
      await ref.read(notificationServiceProvider).replaceAll(const []);
    }
  }

  Future<void> _setAnalytics(bool on) async {
    final prefs = _prefs;
    if (prefs == null) return;
    await _save(prefs.copyWith(analyticsEnabled: on));
    await ref.read(analyticsProvider).setEnabled(on);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final prefs = _prefs;
    if (prefs == null) return const SizedBox.shrink();
    final muted = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Reminders', style: theme.textTheme.titleLarge),
        const SizedBox(height: 8),
        Text(
          'Your cat nudges you at about the time you usually walk. At most '
          'three a day, and none once you have reached your goal.',
          style: muted,
        ),
        SwitchListTile(
          key: const Key('reminders-switch'),
          contentPadding: EdgeInsets.zero,
          title: const Text('Reminders from your cat'),
          value: prefs.remindersEnabled,
          onChanged: _setReminders,
        ),
        const SizedBox(height: 24),
        Text('Privacy', style: theme.textTheme.titleLarge),
        const SizedBox(height: 8),
        Text(
          'Catwalk counts which screens get used, anonymously. It never '
          'sends your steps, places, name or photos.',
          style: muted,
        ),
        SwitchListTile(
          key: const Key('analytics-switch'),
          contentPadding: EdgeInsets.zero,
          title: const Text('Share anonymous usage'),
          value: prefs.analyticsEnabled,
          onChanged: _setAnalytics,
        ),
      ],
    );
  }
}
