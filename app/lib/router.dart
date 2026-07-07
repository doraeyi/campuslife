import 'package:go_router/go_router.dart';

import 'features/auto_bookkeeping/auto_bookkeeping_hub_page.dart';
import 'features/bank_notify/screenshot_import_page.dart';
import 'features/einvoice/einvoice_import_page.dart';
import 'features/settings/credit_account_detail_page.dart';
import 'features/settings/profile_page.dart';
import 'features/settings/settings_page.dart';
import 'screens/app_scaffold.dart';
import 'screens/forgot_password_screen.dart';
import 'screens/friend_schedule_screen.dart';
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
    final isAuthRoute = loc == '/login' || loc == '/register' || loc == '/forgot-password';

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
    GoRoute(
      path: '/forgot-password',
      builder: (_, __) => const ForgotPasswordScreen(),
    ),

    // ── Full-screen routes (no shell) ───────────────────────────────────
    GoRoute(
      path: '/settings/profile',
      builder: (_, __) => const ProfilePage(),
    ),
    GoRoute(
      path: '/settings/einvoice-import',
      builder: (_, __) => const EinvoiceImportPage(),
    ),
    GoRoute(
      path: '/settings/bank-notify',
      builder: (_, __) => const ScreenshotImportPage(),
    ),
    GoRoute(
      path: '/settings/credit-accounts/:accountId',
      builder: (_, state) => CreditAccountDetailPage(
        accountId: int.parse(state.pathParameters['accountId']!),
      ),
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
          path: '/friends',
          pageBuilder: (_, __) => const NoTransitionPage(child: FriendsScreen()),
          routes: [
            GoRoute(
              path: ':friendId/schedule',
              pageBuilder: (context, state) {
                final friendId = int.parse(state.pathParameters['friendId']!);
                final friendName = state.extra as String? ?? '好友';
                return NoTransitionPage(
                  child: FriendScheduleScreen(friendId: friendId, friendName: friendName),
                );
              },
            ),
          ],
        ),
        GoRoute(
          path: '/wallet',
          pageBuilder: (_, state) => NoTransitionPage(
            child: WalletScreen(filter: state.extra as WalletFilter?),
          ),
        ),
        GoRoute(
          path: '/statements',
          pageBuilder: (_, __) => const NoTransitionPage(child: IncomeTab()),
        ),
        GoRoute(
          path: '/settings',
          pageBuilder: (_, __) => const NoTransitionPage(child: SettingsPage()),
        ),
        GoRoute(
          path: '/auto-bookkeeping',
          pageBuilder: (_, __) => const NoTransitionPage(child: AutoBookkeepingHubPage()),
        ),
      ],
    ),
  ],
);
