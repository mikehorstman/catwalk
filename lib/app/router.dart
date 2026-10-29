import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/widgets/placeholder_screen.dart';
import '../features/history/presentation/history_screen.dart';
import '../features/map/presentation/map_screen.dart';
import '../features/onboarding/presentation/onboarding_controller.dart';
import '../features/onboarding/presentation/onboarding_screen.dart';
import '../features/room/presentation/room_screen.dart';
import '../features/settings/presentation/settings_screen.dart';
import '../features/steps/presentation/home_controller.dart'
    show homeControllerProvider;
import '../features/steps/presentation/home_screen.dart';

/// Navigator above the tab bar, so screens like Settings cover it fully.
final _rootNavigatorKey = GlobalKey<NavigatorState>();

/// The app's routes. A user who has not finished onboarding is always sent to
/// `/onboarding`; a finished one is kept out of it. The four tabs (home, cats,
/// map, history) keep their own state when you switch between them.
final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _RouterRefresh(ref);
  ref.onDispose(refresh.dispose);
  final onboarding = ref.watch(onboardingCompletedProvider);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/home',
    refreshListenable: refresh,
    redirect: (context, state) {
      if (onboarding.isLoading) return null;
      final completed = onboarding.value ?? false;
      final onOnboarding = state.matchedLocation == '/onboarding';
      if (!completed && !onOnboarding) return '/onboarding';
      if (completed && onOnboarding) return '/home';
      return null;
    },
    routes: [
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return AppShell(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home',
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/cat',
                builder: (context, state) => const RoomScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/map',
                builder: (context, state) => const MapScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/history',
                builder: (context, state) => const HistoryScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/settings',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const SettingsScreen(),
      ),
    ],
  );
});

/// Makes the router re-run its redirect when onboarding completes or resets.
class _RouterRefresh extends ChangeNotifier {
  _RouterRefresh(this._ref) {
    _ref.listen(onboardingCompletedProvider, (previous, next) {
      notifyListeners();
    });
  }

  /// The provider reference used to listen for onboarding changes.
  final Ref _ref;
}

/// Frame around the four tabs: the bottom navigation bar plus the current tab.
class AppShell extends ConsumerWidget {
  const AppShell({required this.navigationShell, super.key});

  /// Router-owned state that knows the current tab and can switch tabs.
  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gifts =
        ref.watch(homeControllerProvider).value?.giftCatIds.isNotEmpty ?? false;
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: navigationShell.goBranch,
        destinations: [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Badge(
              key: const Key('cats-gift-dot'),
              isLabelVisible: gifts,
              child: const Icon(Icons.pets_outlined),
            ),
            selectedIcon: Badge(
              key: const Key('cats-gift-dot-selected'),
              isLabelVisible: gifts,
              child: const Icon(Icons.pets),
            ),
            label: 'Cats',
          ),
          NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map),
            label: 'Map',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Me',
          ),
        ],
      ),
    );
  }
}

/// Stand-in screen that says a page is not built yet.
class FoundationNote extends StatelessWidget {
  const FoundationNote({required this.title, super.key});

  /// Title shown in the app bar.
  final String title;

  @override
  Widget build(BuildContext context) {
    return PlaceholderScreen(
      title: title,
      message: 'Foundation only. This screen is filled in a later phase.',
    );
  }
}
