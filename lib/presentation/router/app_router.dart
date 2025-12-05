import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ledger_zero/domain/models/import_transaction.dart';
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
import 'package:ledger_zero/presentation/screens/payees/payee_detail_screen.dart';
import 'package:ledger_zero/presentation/screens/payees/payees_screen.dart';
import 'package:ledger_zero/presentation/screens/rules/add_edit_rule_screen.dart';
import 'package:ledger_zero/presentation/screens/rules/rules_screen.dart';
import 'package:ledger_zero/presentation/screens/scheduled_transactions/scheduled_transactions_screen.dart';
import 'package:ledger_zero/presentation/screens/scheduled_transactions/add_edit_scheduled_transaction_screen.dart';
import 'package:ledger_zero/presentation/screens/reports/reports_screen.dart';
import 'package:ledger_zero/presentation/screens/import/csv_import_screen.dart';
import 'package:ledger_zero/presentation/screens/import/import_confirmation_screen.dart';
import 'package:ledger_zero/presentation/screens/settings/import/ynab/ynab_import_screen.dart';
import 'package:ledger_zero/presentation/screens/settings/import/mint_import_screen.dart';
import 'package:ledger_zero/presentation/screens/settings/settings_screen.dart';
import 'package:ledger_zero/presentation/screens/settings/database_stats_screen.dart';
import 'package:ledger_zero/presentation/screens/settings/sync_settings_screen.dart';
import 'package:ledger_zero/presentation/screens/settings/sync_debug_screen.dart';
import 'package:ledger_zero/presentation/screens/settings/security_settings_screen.dart';
import 'package:ledger_zero/presentation/screens/settings/security/recovery_key_screen.dart';
import 'package:ledger_zero/presentation/screens/settings/security/change_password_screen.dart';
import 'package:ledger_zero/presentation/screens/settings/backup_screen.dart';
import 'package:ledger_zero/presentation/screens/onboarding/security_setup_screen.dart';
import 'package:ledger_zero/presentation/screens/onboarding/account_setup_screen.dart';
import 'package:ledger_zero/presentation/screens/onboarding/budget_setup_screen.dart';
import 'package:ledger_zero/presentation/screens/onboarding/completion_screen.dart';
import 'package:ledger_zero/presentation/screens/onboarding_screen.dart';
import 'package:ledger_zero/presentation/screens/transactions/add_edit_transaction_screen.dart';
import 'package:ledger_zero/presentation/screens/transactions/natural_language_input_screen.dart';
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
      final isGoingToOnboarding = state.matchedLocation.startsWith('/onboarding');
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
        routes: [
          GoRoute(
            path: 'security',
            name: 'security-setup',
            builder: (context, state) => const SecuritySetupScreen(),
          ),
          GoRoute(
            path: 'account-setup',
            name: 'account-setup',
            builder: (context, state) => const AccountSetupScreen(),
          ),
          GoRoute(
            path: 'budget-setup',
            name: 'budget-setup',
            builder: (context, state) => const BudgetSetupScreen(),
          ),
          GoRoute(
            path: 'completion',
            name: 'completion',
            builder: (context, state) => const CompletionScreen(),
          ),
        ],
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
      GoRoute(
        path: '/quick-add',
        name: 'quick-add',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const NaturalLanguageInputScreen(),
      ),
      GoRoute(
        path: '/settings',
        name: 'settings',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const SettingsScreen(),
        routes: [
          GoRoute(
            path: 'database-stats',
            name: 'database-stats',
            builder: (context, state) => const DatabaseStatsScreen(),
          ),
          GoRoute(
            path: 'sync',
            name: 'sync-settings',
            builder: (context, state) => const SyncSettingsScreen(),
            routes: [
              GoRoute(
                path: 'debug',
                name: 'sync-debug',
                builder: (context, state) => const SyncDebugScreen(),
              ),
            ],
          ),
          GoRoute(
            path: 'import-ynab',
            name: 'import-ynab',
            parentNavigatorKey: _rootNavigatorKey,
            builder: (context, state) => const YnabImportScreen(),
          ),
          GoRoute(
            path: 'import-mint',
            name: 'import-mint',
            parentNavigatorKey: _rootNavigatorKey,
            builder: (context, state) => const MintImportScreen(),
          ),
          GoRoute(
            path: 'security',
            name: 'security-settings',
            builder: (context, state) => const SecuritySettingsScreen(),
            routes: [
              GoRoute(
                path: 'recovery-key',
                name: 'recovery-key',
                builder: (context, state) => const RecoveryKeyScreen(),
              ),
              GoRoute(
                path: 'change-password',
                name: 'change-password',
                builder: (context, state) => const ChangePasswordScreen(),
              ),
            ],
          ),
          GoRoute(
            path: 'backup',
            name: 'backup',
            parentNavigatorKey: _rootNavigatorKey,
            builder: (context, state) => const BackupScreen(),
          ),
          GoRoute(
            path: 'import-csv',
            name: 'import-csv',
            parentNavigatorKey: _rootNavigatorKey,
            builder: (context, state) => const CsvImportScreen(),
            routes: [
              GoRoute(
                path: 'confirm',
                name: 'import-confirm',
                parentNavigatorKey: _rootNavigatorKey,
                builder: (context, state) {
                  final transactions = state.extra as List<ImportTransaction>;
                  return ImportConfirmationScreen(transactions: transactions);
                },
              ),
            ],
          ),
          GoRoute(
            path: 'payees',
            name: 'payees',
            builder: (context, state) => const PayeesScreen(),
            routes: [
              GoRoute(
                path: ':id',
                name: 'payee-detail',
                builder: (context, state) {
                  final id = state.pathParameters['id']!;
                  return PayeeDetailScreen(payeeId: id);
                },
              ),
            ],
          ),
          GoRoute(
            path: 'scheduled-transactions',
            name: 'scheduled-transactions',
            builder: (context, state) => const ScheduledTransactionsScreen(),
            routes: [
              GoRoute(
                path: 'add',
                name: 'add-scheduled-transaction',
                builder: (context, state) => const AddEditScheduledTransactionScreen(),
              ),
              GoRoute(
                path: 'edit/:id',
                name: 'edit-scheduled-transaction',
                builder: (context, state) {
                  final id = state.pathParameters['id'];
                  return AddEditScheduledTransactionScreen(transactionId: id);
                },
              ),
            ],
          ),
          GoRoute(
            path: 'rules',
            name: 'rules',
            builder: (context, state) => const RulesScreen(),
            routes: [
              GoRoute(
                path: 'add',
                name: 'add-rule',
                builder: (context, state) => const AddEditRuleScreen(),
              ),
              GoRoute(
                path: 'edit/:id',
                name: 'edit-rule',
                builder: (context, state) {
                   final id = state.pathParameters['id'];
                   return AddEditRuleScreen(ruleId: id);
                },
              ),
            ],
          ),
        ],
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
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/reports',
                name: 'reports',
                pageBuilder: (context, state) => CustomTransitionPage(
                  key: state.pageKey,
                  child: const ReportsScreen(),
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
