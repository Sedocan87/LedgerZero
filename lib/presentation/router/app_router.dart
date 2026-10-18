import 'package:flutter/material.dart';
import 'package:ledger_zero/presentation/screens/settings/income/income_settings_screen.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ledger_zero/presentation/widgets/help/help_topics.dart';
import 'package:ledger_zero/domain/models/import_transaction.dart';
import 'package:ledger_zero/presentation/providers/auth_provider.dart';
import 'package:ledger_zero/presentation/providers/theme_provider.dart';
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
import 'package:ledger_zero/presentation/screens/lock_screen.dart';
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
import 'package:ledger_zero/presentation/screens/settings/settings_screen.dart';
import 'package:ledger_zero/presentation/screens/settings/sync_settings_screen.dart';
import 'package:ledger_zero/presentation/screens/settings/card_notification_log_screen.dart';
import 'package:ledger_zero/presentation/screens/settings/card_notifications_screen.dart';
import 'package:ledger_zero/presentation/screens/settings/security_settings_screen.dart';
import 'package:ledger_zero/presentation/screens/settings/backup_screen.dart';
import 'package:ledger_zero/presentation/screens/settings/diagnostics_screen.dart';
import 'package:ledger_zero/presentation/screens/settings/help_screen.dart';
import 'package:ledger_zero/presentation/screens/settings/faq_screen.dart';
import 'package:ledger_zero/presentation/screens/settings/user_guide_screen.dart';
import 'package:ledger_zero/presentation/screens/onboarding/security_setup_screen.dart';
import 'package:ledger_zero/presentation/screens/settings/budget_basics_screen.dart';
import 'package:ledger_zero/presentation/screens/onboarding_screen.dart';
import 'package:ledger_zero/presentation/screens/transactions/add_edit_transaction_screen.dart';
import 'package:ledger_zero/presentation/screens/transactions/natural_language_input_screen.dart';
import 'package:ledger_zero/presentation/screens/transactions/transactions_screen.dart';
import 'package:ledger_zero/presentation/providers/transactions_provider.dart'
    show FilteredTransactionsArgs;
import 'package:ledger_zero/presentation/widgets/scaffold_with_navbar.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

/// A location the user tried to open while the app was locked (a deep link),
/// opened once after the next unlock. Only the latest one is kept.
class PendingLocation {
  String? value;

  /// Returns the pending location and forgets it.
  String? take() {
    final location = value;
    value = null;
    return location;
  }
}

final pendingLocationProvider = Provider<PendingLocation>(
  (ref) => PendingLocation(),
);

/// The app's router. Rebuilt when onboarding starts or ends and on the first
/// unlock after start-up; that router starts at the pending deep link, if
/// any, else at Home. A later app lock does not rebuild it: `LockOverlay`
/// covers the app, so the navigation stack (tab, open screen, unsaved
/// form) survives the lock.
final routerProvider = Provider<GoRouter>((ref) {
  final (isOnboarded, isAuthenticated) = ref.watch(
    authProvider.select((s) => (s.isOnboarded, s.hasUnlocked)),
  );
  final pending = ref.watch(pendingLocationProvider);
  final initialLocation =
      (isOnboarded && isAuthenticated ? pending.take() : null) ?? '/';

  final router = GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: initialLocation,
    redirect: (context, state) {
      final isGoingToOnboarding = state.matchedLocation.startsWith(
        '/onboarding',
      );
      final isGoingToLogin = state.matchedLocation == '/login';

      if (!isOnboarded) {
        // The step after the security step needs the open database; if it
        // is not open (the app was restarted mid-onboarding), start over.
        final needsSession =
            state.matchedLocation.startsWith('/onboarding/first-account');
        if (needsSession && !isAuthenticated) {
          return '/onboarding';
        }
        return isGoingToOnboarding ? null : '/onboarding';
      }

      if (!isAuthenticated) {
        if (isGoingToLogin) {
          return null;
        }
        // Remember where a deep link wanted to go; Home is the default.
        final location = state.matchedLocation;
        if (location.isNotEmpty &&
            location != '/' &&
            !isGoingToOnboarding &&
            state.extra == null) {
          pending.value = state.uri.toString();
        }
        return '/login';
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

          // Onboarding ends with the first account (its currency is the
          // budget currency); saving it marks onboarding done and opens the
          // budget. The budget explainer lives in Help > Budgeting basics.
          GoRoute(
            path: 'first-account',
            name: 'first-account',
            builder: (context, state) => const AddEditAccountScreen(
              firstAccount: true,
              finishesOnboarding: true,
            ),
          ),
        ],
      ),
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LockScreen(),
      ),
      GoRoute(
        path: '/add-transaction',
        name: 'add-transaction',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final accountId = state.uri.queryParameters['accountId'];
          final extra = state.extra;
          return AddEditTransactionScreen(
            initialAccountId: accountId,
            draft: extra is TransactionDraft ? extra : null,
          );
        },
      ),
      GoRoute(
        path: '/filtered-transactions',
        name: 'filtered-transactions',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final args = state.extra as FilteredTransactionsArgs;
          return TransactionsScreen(fixedFilter: args);
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
            path: 'sync',
            name: 'sync-settings',
            builder: (context, state) => const SyncSettingsScreen(),
          ),
          GoRoute(
            path: 'card-notifications',
            name: 'card-notifications',
            parentNavigatorKey: _rootNavigatorKey,
            builder: (context, state) => const CardNotificationsScreen(),
            routes: [
              GoRoute(
                path: 'log',
                name: 'card-notification-log',
                parentNavigatorKey: _rootNavigatorKey,
                builder: (context, state) => CardNotificationLogScreen(
                  packageName: state.extra as String?,
                ),
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
            path: 'help',
            name: 'help',
            parentNavigatorKey: _rootNavigatorKey,
            builder: (context, state) => const HelpScreen(),
            routes: [
              GoRoute(
                path: 'faq',
                name: 'faq',
                builder: (context, state) => const FaqScreen(),
              ),
              GoRoute(
                path: 'budget-basics',
                name: 'budget-basics',
                builder: (context, state) => const BudgetBasicsScreen(),
              ),
              GoRoute(
                path: 'user-guide',
                name: 'user-guide',
                builder: (context, state) => UserGuideScreen(
                  initialChapter: GuideChapter.tryParse(
                    state.uri.queryParameters['chapter'],
                  ),
                ),
              ),
            ],
          ),
          GoRoute(
            path: 'security',
            name: 'security-settings',
            builder: (context, state) => const SecuritySettingsScreen(),
            routes: [
              GoRoute(
                path: 'diagnostics',
                name: 'diagnostics',
                builder: (context, state) => const DiagnosticsScreen(),
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
                builder: (context, state) =>
                    const AddEditScheduledTransactionScreen(),
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
          GoRoute(
            path: 'income',
            name: 'income-settings',
            builder: (context, state) => const IncomeSettingsScreen(),
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
                  transitionsBuilder:
                      (context, animation, secondaryAnimation, child) {
                        // Reduced motion: switch pages without the fade.
                        if (!animationsEnabledOf(context)) {
                          return child;
                        }
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
                  transitionsBuilder:
                      (context, animation, secondaryAnimation, child) {
                        // Reduced motion: switch pages without the fade.
                        if (!animationsEnabledOf(context)) {
                          return child;
                        }
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
                        builder: (context, state) =>
                            const AddEditCategoryScreen(),
                      ),
                      GoRoute(
                        path: 'reorder-groups',
                        name: 'reorder-groups',
                        parentNavigatorKey: _rootNavigatorKey,
                        builder: (context, state) =>
                            const ReorderGroupsScreen(),
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
                      // Last: go_router takes the first matching route, so a
                      // parameter route must follow its literal siblings
                      // (`/budget/categories/reorder-groups` would otherwise
                      // open the editor with id "reorder-groups").
                      GoRoute(
                        path: ':id',
                        name: 'edit-category',
                        parentNavigatorKey: _rootNavigatorKey,
                        builder: (context, state) {
                          final id = state.pathParameters['id'];
                          return AddEditCategoryScreen(categoryId: id);
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
                  transitionsBuilder:
                      (context, animation, secondaryAnimation, child) {
                        // Reduced motion: switch pages without the fade.
                        if (!animationsEnabledOf(context)) {
                          return child;
                        }
                        return FadeTransition(opacity: animation, child: child);
                      },
                ),
                routes: [
                  GoRoute(
                    path: 'add',
                    name: 'add-account',
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (context, state) => AddEditAccountScreen(
                      firstAccount: state.uri.queryParameters['first'] == '1',
                    ),
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
                  transitionsBuilder:
                      (context, animation, secondaryAnimation, child) {
                        // Reduced motion: switch pages without the fade.
                        if (!animationsEnabledOf(context)) {
                          return child;
                        }
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
                  transitionsBuilder:
                      (context, animation, secondaryAnimation, child) {
                        // Reduced motion: switch pages without the fade.
                        if (!animationsEnabledOf(context)) {
                          return child;
                        }
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
  // A rebuilt router replaces this one: release its listeners and delegates.
  ref.onDispose(router.dispose);
  return router;
});
