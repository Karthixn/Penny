import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../screens/splash/splash_screen.dart';
import '../../screens/auth/login_screen.dart';
import '../../screens/auth/signup_screen.dart';
import '../../screens/auth/otp_screen.dart';
import '../../screens/home/home_screen.dart';
import '../../screens/home/main_shell.dart';
import '../../screens/expenses/add_expense_screen.dart';
import '../../screens/expenses/expense_detail_screen.dart';
import '../../screens/groups/groups_screen.dart';
import '../../screens/groups/group_detail_screen.dart';
import '../../screens/settlements/settlement_screen.dart';
import '../../screens/reminders/reminders_screen.dart';
import '../../screens/insights/insights_screen.dart';
import '../../screens/settings/settings_screen.dart';
import '../../screens/onboarding/onboarding_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authProvider);

  return GoRouter(
    initialLocation: '/splash',
    redirect: (context, state) {
      final loc = state.matchedLocation;
      final isAuth = authState.status == AuthStatus.authenticated;

      // Allow splash screen to show initial loading animation
      if (loc == '/splash') return null;

      final isPublicAuthRoute = loc == '/login' ||
          loc == '/signup' ||
          loc == '/onboarding' ||
          loc.startsWith('/verify-otp');

      // Non-authenticated users cannot access main application
      if (!isAuth && !isPublicAuthRoute) return '/login';

      // Authenticated users shouldn't access login/signup screens
      if (isAuth &&
          (loc == '/login' || loc == '/signup' || loc == '/onboarding')) {
        return '/home';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/signup',
        builder: (context, state) => const SignupScreen(),
      ),
      GoRoute(
        path: '/verify-otp',
        builder: (context, state) {
          final email = state.uri.queryParameters['email'] ?? '';
          return OtpScreen(email: email);
        },
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            MainShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/home',
              builder: (context, state) => const HomeScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/groups',
              builder: (context, state) => const GroupsScreen(),
              routes: [
                GoRoute(
                  path: ':id',
                  builder: (context, state) => GroupDetailScreen(
                    groupId: state.pathParameters['id']!,
                  ),
                ),
              ],
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/insights',
              builder: (context, state) => const InsightsScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/reminders',
              builder: (context, state) => const RemindersScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/settings',
              builder: (context, state) => const SettingsScreen(),
            ),
          ]),
        ],
      ),
      GoRoute(
        path: '/add-expense',
        builder: (context, state) => AddExpenseScreen(groupId: state.extra as String?),
      ),
      GoRoute(
        path: '/expenses/:id',
        builder: (context, state) => ExpenseDetailScreen(
          expenseId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/settle/:groupId',
        builder: (context, state) => SettlementScreen(
          groupId: state.pathParameters['groupId']!,
        ),
      ),
    ],
  );
});
