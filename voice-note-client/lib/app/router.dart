import 'package:animations/animations.dart';
import 'package:flutter/cupertino.dart' show CupertinoPage;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../shared/widgets/app_shell.dart';
import '../features/home/presentation/screens/home_screen.dart';
import '../features/transaction/presentation/screens/transaction_form_screen.dart';
import '../features/transaction/presentation/screens/transaction_list_screen.dart';
import '../features/settings/presentation/screens/settings_screen.dart';
import '../features/account/presentation/screens/account_manage_screen.dart';
import '../features/category/presentation/screens/category_manage_screen.dart';
import '../features/voice/presentation/voice_recording_screen.dart';
import '../features/statistics/presentation/screens/statistics_screen.dart';
import '../features/budget/presentation/screens/budget_overview_screen.dart';
import '../features/budget/presentation/screens/budget_edit_screen.dart';
import '../features/settings/presentation/screens/set_gesture_screen.dart';
import '../features/settings/presentation/screens/set_password_screen.dart';
import '../features/settings/presentation/screens/unlock_screen.dart';
import '../features/settings/presentation/providers/security_settings_provider.dart';
import 'design_tokens.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

/// Route paths for programmatic navigation (avoids hardcoding strings).
abstract final class AppRoutes {
  static const String statistics = '/statistics';
}

/// FadeThrough transition page for tab switches.
Page<void> _fadeThroughPage(Widget child, GoRouterState state) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: AppDuration.normal,
    reverseTransitionDuration: AppDuration.normal,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return FadeThroughTransition(
        animation: animation,
        secondaryAnimation: secondaryAnimation,
        child: child,
      );
    },
  );
}

/// Cupertino-style page: enables iOS edge-swipe-back gesture.
Page<void> _cupertinoPage(Widget child, GoRouterState state) {
  return CupertinoPage<void>(key: state.pageKey, child: child);
}

/// No-swipe page: no interactive pop. Use for voice recording and unlock (password/gesture).
Page<void> _noSwipePage(Widget child, GoRouterState state) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: AppDuration.pageTransition,
    reverseTransitionDuration: AppDuration.pageTransition,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return SharedAxisTransition(
        animation: animation,
        secondaryAnimation: secondaryAnimation,
        transitionType: SharedAxisTransitionType.vertical,
        child: child,
      );
    },
  );
}

final GoRouter appRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/home',
  routes: [
    ShellRoute(
      navigatorKey: _shellNavigatorKey,
      builder: (context, state, child) {
        return Consumer(
          builder: (context, ref, _) {
            final security = ref.watch(
              securitySettingsProvider,
            );
            final path = state.matchedLocation;
            final isVerifyDisable = path.startsWith('/settings/verify-disable');
            // Require unlock for all routes when lock is on; only verify-disable is exempt
            // so user can enter credential to disable. gesture-set/password-set must NOT
            // bypass: otherwise deep-link could overwrite lock without verifying.
            final lockRequired = security.isLockEnabled &&
                !security.isUnlockedThisSession &&
                !isVerifyDisable;
            if (lockRequired) {
              return UnlockScreen(redirectUri: path);
            }
            return AppShell(child: child);
          },
        );
      },
      routes: [
        GoRoute(
          path: '/home',
          pageBuilder: (context, state) =>
              _fadeThroughPage(const HomeScreen(), state),
        ),
        GoRoute(
          path: '/transactions',
          pageBuilder: (context, state) {
            final categoryId = state.uri.queryParameters['categoryId'];
            final dateFrom = state.uri.queryParameters['dateFrom'];
            final dateTo = state.uri.queryParameters['dateTo'];
            return _fadeThroughPage(
              TransactionListScreen(
                filterCategoryId: categoryId,
                filterDateFrom: dateFrom,
                filterDateTo: dateTo,
              ),
              state,
            );
          },
        ),
        GoRoute(
          path: '/statistics',
          pageBuilder: (context, state) =>
              _fadeThroughPage(const StatisticsScreen(), state),
        ),
        GoRoute(
          path: '/settings',
          pageBuilder: (context, state) =>
              _fadeThroughPage(const SettingsScreen(), state),
          routes: [
            GoRoute(
              path: 'accounts',
              parentNavigatorKey: _rootNavigatorKey,
              pageBuilder: (context, state) =>
                  _cupertinoPage(const AccountManageScreen(), state),
            ),
            GoRoute(
              path: 'categories',
              parentNavigatorKey: _rootNavigatorKey,
              pageBuilder: (context, state) =>
                  _cupertinoPage(const CategoryManageScreen(), state),
            ),
            GoRoute(
              path: 'budget',
              parentNavigatorKey: _rootNavigatorKey,
              pageBuilder: (context, state) =>
                  _cupertinoPage(const BudgetOverviewScreen(), state),
              routes: [
                GoRoute(
                  path: 'edit',
                  parentNavigatorKey: _rootNavigatorKey,
                  pageBuilder: (context, state) =>
                      _cupertinoPage(const BudgetEditScreen(), state),
                ),
              ],
            ),
            GoRoute(
              path: 'gesture-set',
              parentNavigatorKey: _rootNavigatorKey,
              pageBuilder: (context, state) =>
                  _cupertinoPage(const SetGestureScreen(), state),
            ),
            GoRoute(
              path: 'password-set',
              parentNavigatorKey: _rootNavigatorKey,
              pageBuilder: (context, state) =>
                  _cupertinoPage(const SetPasswordScreen(), state),
            ),
            GoRoute(
              path: 'verify-disable',
              parentNavigatorKey: _rootNavigatorKey,
              pageBuilder: (context, state) {
                final target = state.uri.queryParameters['target'];
                return _noSwipePage(
                  UnlockScreen(
                    redirectUri: '/settings',
                    disableTarget: target,
                  ),
                  state,
                );
              },
            ),
          ],
        ),
      ],
    ),
    GoRoute(
      path: '/voice-recording',
      parentNavigatorKey: _rootNavigatorKey,
      pageBuilder: (context, state) =>
          _noSwipePage(const VoiceRecordingScreen(), state),
    ),
    GoRoute(
      path: '/record',
      parentNavigatorKey: _rootNavigatorKey,
      pageBuilder: (context, state) =>
          _cupertinoPage(const TransactionFormScreen(), state),
    ),
    GoRoute(
      path: '/record/:id',
      parentNavigatorKey: _rootNavigatorKey,
      pageBuilder: (context, state) {
        final id = state.pathParameters['id'];
        if (id == null || id.isEmpty) {
          return _cupertinoPage(const TransactionFormScreen(), state);
        }
        return _cupertinoPage(
          TransactionFormScreen(transactionId: id),
          state,
        );
      },
    ),
  ],
);
