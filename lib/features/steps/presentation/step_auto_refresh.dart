import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'home_controller.dart';

/// Re-reads today's steps while the app is open and when it returns to the
/// foreground. The health store is the source of truth; this only asks again.
class StepAutoRefresh extends ConsumerStatefulWidget {
  const StepAutoRefresh({
    required this.child,
    this.interval = const Duration(seconds: 30),
    super.key,
  });

  final Widget child;
  final Duration interval;

  @override
  ConsumerState<StepAutoRefresh> createState() => _StepAutoRefreshState();
}

class _StepAutoRefreshState extends ConsumerState<StepAutoRefresh>
    with WidgetsBindingObserver {
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

  void _start() {
    _timer?.cancel();
    _timer = Timer.periodic(widget.interval, (_) => _refresh());
  }

  void _refresh() {
    ref.read(homeControllerProvider.notifier).refreshSilently();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
