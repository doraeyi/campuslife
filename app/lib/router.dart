import 'package:go_router/go_router.dart';

import 'features/settings/profile_page.dart';
import 'features/settings/settings_page.dart';
import 'screens/app_scaffold.dart';
import 'screens/friends_screen.dart';
import 'screens/home_tab.dart';
import 'screens/income_tab.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/schedule_screen.dart';
import 'screens/wallet_screen.dart';
import 'services/auth_service.dart';

final appRouter = GoRouter(
  initialLocation: '/dashboard',
  debugLogDiagnostics: true,
  redirect: (context, state) async {
    final user = await AuthService().currentUser();
    final isLoggedIn = user != null;
    final loc = state.matchedLocation;
    final isAuthRoute = loc == '/login' || loc == '/register';

    if (!isLoggedIn && !isAuthRoute) return '/login';
    if (isLoggedIn && isAuthRoute) return '/dashboard';
    return null;
  },
  routes: [
    // ── Auth routes (no shell) ──────────────────────────────────────────
    GoRoute(
      path: '/login',
      builder: (_, __) => const LoginScreen(),
    ),
    GoRoute(
      path: '/register',
      builder: (_, __) => const RegisterScreen(),
    ),

    // ── Full-screen routes (no shell) ───────────────────────────────────
    GoRoute(
      path: '/settings/profile',
      builder: (_, __) => const ProfilePage(),
    ),
    GoRoute(
      path: '/friends',
      builder: (_, __) => const FriendsScreen(),
    ),

    // ── Main shell ──────────────────────────────────────────────────────
    ShellRoute(
      builder: (context, state, child) => AppScaffold(child: child),
      routes: [
        GoRoute(
          path: '/dashboard',
          pageBuilder: (_, __) => const NoTransitionPage(child: HomeTab()),
        ),
        GoRoute(
          path: '/schedule',
          pageBuilder: (_, __) => const NoTransitionPage(child: ScheduleScreen()),
        ),
        GoRoute(
          path: '/wallet',
          pageBuilder: (_, __) => const NoTransitionPage(child: WalletScreen()),
        ),
        GoRoute(
          path: '/statements',
          pageBuilder: (_, __) => const NoTransitionPage(child: IncomeTab()),
        ),
        GoRoute(
          path: '/settings',
          pageBuilder: (_, __) => const NoTransitionPage(child: SettingsPage()),
        ),
      ],
    ),
  ],
);
