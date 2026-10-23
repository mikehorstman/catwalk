import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/app_constants.dart';
import '../features/onboarding/presentation/onboarding_controller.dart';
import 'router.dart';
import 'theme.dart';

/// Root widget. Shows a spinner until we know whether onboarding is done, then
/// hands over to the router (which sends new users to onboarding).
class CatwalkApp extends ConsumerWidget {
  const CatwalkApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final onboarding = ref.watch(onboardingCompletedProvider);
    if (onboarding.isLoading) {
      return MaterialApp(
        title: AppConstants.appName,
        theme: buildCatwalkTheme(),
        debugShowCheckedModeBanner: false,
        home: const Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }

    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: AppConstants.appName,
      theme: buildCatwalkTheme(),
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
