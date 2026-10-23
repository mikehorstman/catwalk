import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'home_controller.dart';

/// Re-reads today's steps while the app is open and when it returns to the
/// foreground. The health store is the source of truth; this only asks again.
///
/// Wrap the screen that shows steps in this widget. It draws nothing itself.
class StepAutoRefresh extends ConsumerStatefulWidget {
  const StepAutoRefresh({
    required this.child,
    this.interval = const Duration(seconds: 30),
    super.key,
  });

  /// The screen to show. Returned unchanged from [build].
  final Widget child;

  /// How often to ask again while the app is in the foreground.
  final Duration interval;

  @override
  ConsumerState<StepAutoRefresh> createState() => _StepAutoRefreshState();
}

/// Owns the timer and listens for the app going to the background or coming
/// back, so the phone is only polled while the user can see the app.
class _StepAutoRefreshState extends ConsumerState<StepAutoRefresh>
    with WidgetsBindingObserver {
  /// The repeating refresh timer, or null while the app is in the background.
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _start();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  /// On return to the foreground: refresh at once and restart the timer.
  /// On leaving it: stop the timer so nothing runs in the background.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refresh();
      _start();
    } else {
      _timer?.cancel();
      _timer = null;
    }
  }

  /// (Re)starts the periodic timer, cancelling any previous one first.
  void _start() {
    _timer?.cancel();
    _timer = Timer.periodic(widget.interval, (_) => _refresh());
  }

  /// Asks Home to reload quietly, with no loading spinner.
  void _refresh() {
    ref.read(homeControllerProvider.notifier).refreshSilently();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
