import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ledger_zero/presentation/providers/auth_provider.dart';
import 'package:ledger_zero/presentation/screens/accounts/accounts_screen.dart';
import 'package:ledger_zero/presentation/screens/accounts/account_detail_screen.dart';
import 'package:ledger_zero/presentation/screens/accounts/add_edit_account_screen.dart';
import 'package:ledger_zero/presentation/screens/accounts/reconciliation_screen.dart';
import 'package:ledger_zero/presentation/screens/budget/budget_screen.dart';
import 'package:ledger_zero/presentation/screens/categories/add_edit_category_screen.dart';
import 'package:ledger_zero/presentation/screens/categories/categories_screen.dart';
import 'package:ledger_zero/presentation/screens/categories/reorder_categories_screen.dart';
import 'package:ledger_zero/presentation/screens/categories/reorder_groups_screen.dart';
import 'package:ledger_zero/presentation/screens/home_screen.dart';
import 'package:ledger_zero/presentation/screens/login_screen.dart';
import 'package:ledger_zero/presentation/screens/onboarding_screen.dart';
import 'package:ledger_zero/presentation/screens/transactions/add_edit_transaction_screen.dart';
import 'package:ledger_zero/presentation/screens/transactions/transactions_screen.dart';
import 'package:ledger_zero/presentation/widgets/scaffold_with_navbar.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authProvider);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/',
    redirect: (context, state) {
      final isOnboarded = authState.isOnboarded;
      final isAuthenticated = authState.isAuthenticated;
      final isGoingToOnboarding = state.matchedLocation == '/onboarding';
      final isGoingToLogin = state.matchedLocation == '/login';

      if (!isOnboarded) {
        return isGoingToOnboarding ? null : '/onboarding';
      }

      if (!isAuthenticated) {
        return isGoingToLogin ? null : '/login';
      }

      if (isGoingToOnboarding || isGoingToLogin) {
        return '/';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/onboarding',
        name: 'onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/add-transaction',
        name: 'add-transaction',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final accountId = state.uri.queryParameters['accountId'];
          return AddEditTransactionScreen(initialAccountId: accountId);
        },
      ),
      GoRoute(
        path: '/edit-transaction/:id',
        name: 'edit-transaction',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final id = state.pathParameters['id'];
          return AddEditTransactionScreen(transactionId: id);
        },
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return ScaffoldWithNavBar(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/',
                name: 'home',
                pageBuilder: (context, state) => CustomTransitionPage(
                  key: state.pageKey,
                  child: const HomeScreen(),
                  transitionsBuilder: (context, animation, secondaryAnimation, child) {
                    return FadeTransition(opacity: animation, child: child);
                  },
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/budget',
                name: 'budget',
                pageBuilder: (context, state) => CustomTransitionPage(
                  key: state.pageKey,
                  child: const BudgetScreen(),
                  transitionsBuilder: (context, animation, secondaryAnimation, child) {
                    return FadeTransition(opacity: animation, child: child);
                  },
                ),
                routes: [
                  GoRoute(
                    path: 'categories',
                    name: 'categories',
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (context, state) => const CategoriesScreen(),
                    routes: [
                      GoRoute(
                        path: 'add',
                        name: 'add-category',
                        parentNavigatorKey: _rootNavigatorKey,
                        builder: (context, state) => const AddEditCategoryScreen(),
                      ),
                      GoRoute(
                        path: ':id',
                        name: 'edit-category',
                        parentNavigatorKey: _rootNavigatorKey,
                        builder: (context, state) {
                          final id = state.pathParameters['id'];
                          return AddEditCategoryScreen(categoryId: id);
                        },
                      ),
                      GoRoute(
                        path: 'reorder-groups',
                        name: 'reorder-groups',
                        parentNavigatorKey: _rootNavigatorKey,
                        builder: (context, state) => const ReorderGroupsScreen(),
                      ),
                      GoRoute(
                        path: 'reorder-categories/:groupId',
                        name: 'reorder-categories',
                        parentNavigatorKey: _rootNavigatorKey,
                        builder: (context, state) {
                          final groupId = state.pathParameters['groupId']!;
                          return ReorderCategoriesScreen(groupId: groupId);
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/accounts',
                name: 'accounts',
                pageBuilder: (context, state) => CustomTransitionPage(
                  key: state.pageKey,
                  child: const AccountsScreen(),
                  transitionsBuilder: (context, animation, secondaryAnimation, child) {
                    return FadeTransition(opacity: animation, child: child);
                  },
                ),
                routes: [
                  GoRoute(
                    path: 'add',
                    name: 'add-account',
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (context, state) => const AddEditAccountScreen(),
                  ),
                  GoRoute(
                    path: ':id',
                    name: 'account-detail',
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (context, state) {
                      final id = state.pathParameters['id']!;
                      return AccountDetailScreen(accountId: id);
                    },
                    routes: [
                      GoRoute(
                        path: 'edit',
                        name: 'edit-account',
                        parentNavigatorKey: _rootNavigatorKey,
                        builder: (context, state) {
                          final id = state.pathParameters['id']!;
                          return AddEditAccountScreen(accountId: id);
                        },
                      ),
                      GoRoute(
                        path: 'reconcile',
                        name: 'reconcile-account',
                        parentNavigatorKey: _rootNavigatorKey,
                        builder: (context, state) {
                          final id = state.pathParameters['id']!;
                          return ReconciliationScreen(accountId: id);
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/transactions',
                name: 'transactions',
                pageBuilder: (context, state) => CustomTransitionPage(
                  key: state.pageKey,
                  child: const TransactionsScreen(),
                  transitionsBuilder: (context, animation, secondaryAnimation, child) {
                    return FadeTransition(opacity: animation, child: child);
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});
