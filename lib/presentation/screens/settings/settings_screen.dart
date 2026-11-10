import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ledger_zero/core/constants/pro_features.dart';
import 'package:ledger_zero/presentation/providers/pro_provider.dart';
import 'package:ledger_zero/presentation/widgets/common/pro_gate.dart';
import 'package:ledger_zero/core/constants/app_icons.dart';
import 'package:ledger_zero/core/money/currency.dart';
import 'package:ledger_zero/domain/services/budget_currency.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/l10n/enum_labels.dart';
import 'package:ledger_zero/presentation/providers/budget_currency_provider.dart';
import 'package:ledger_zero/presentation/providers/settings_provider.dart';
import 'package:ledger_zero/presentation/providers/theme_provider.dart';
import 'package:ledger_zero/presentation/providers/data_providers.dart';
import 'package:ledger_zero/presentation/providers/settings_defaults_guard.dart';
import 'package:ledger_zero/presentation/providers/backup_providers.dart';
import 'package:ledger_zero/presentation/providers/factory_reset_provider.dart';
import 'package:ledger_zero/presentation/providers/notification_capture_providers.dart';
import 'package:ledger_zero/presentation/providers/notification_providers.dart';
import 'package:ledger_zero/presentation/screens/settings/app_cache.dart';
import 'package:ledger_zero/presentation/screens/settings/widgets/settings_section.dart';
import 'package:ledger_zero/presentation/screens/settings/widgets/settings_icon.dart';
import 'package:ledger_zero/presentation/screens/settings/accessibility_settings_screen.dart'; // Import
import 'package:ledger_zero/presentation/widgets/budget_currency_dialogs.dart';
import 'package:ledger_zero/presentation/widgets/security/reset_app_dialog.dart';
import 'dart:async';
import 'package:path_provider/path_provider.dart';
import 'package:ledger_zero/core/utils/logger.dart';
import 'package:ledger_zero/presentation/screens/settings/about_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final settings = ref.watch(settingsProvider);
    final themeState = ref.watch(themeProvider);

    final languageCode = Localizations.localeOf(context).languageCode;
    final languageName = kLanguageEndonyms[languageCode] ?? languageCode;

    String dateFormatLabel(AppDateFormat format) =>
        format.pattern ??
        l10n.dateFormatFollowLanguage(
          datePatternFor(
            languageCode,
            deviceRegionFor(languageCode, ref.watch(deviceLocalesProvider)),
          ),
        );

    Widget buildOption<T>(BuildContext context, String label, T value) {
      return SimpleDialogOption(
        onPressed: () => Navigator.pop(context, value),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Text(label, style: const TextStyle(fontSize: 16)),
        ),
      );
    }

    Future<void> clearCache(BuildContext context) async {
      try {
        // Only the app's own files, not the whole temporary directory.
        await clearAppCache(
          tempDir: await getTemporaryDirectory(),
          exports: ref.read(exportFileServiceProvider),
        );
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(l10n.cacheCleared)));
        }
      } catch (e, st) {
        Logger.error('Clearing the cache failed', e, st);
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(l10n.clearCacheFailed)));
        }
      }
    }

    // First the warning with a way to back up, then the typed confirmation
    // the lock-screen reset uses: a stray second tap must not wipe it all.
    Future<void> factoryReset(BuildContext context, WidgetRef ref) async {
      final step = await showDialog<_ResetStep>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l10n.factoryResetTitle),
          content: Text(
            '${l10n.factoryResetConfirmation}\n\n'
            '${l10n.factoryResetBackupOffer}',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.cancel),
            ),
            TextButton(
              key: const Key('settings.factoryResetBackUpFirst'),
              onPressed: () => Navigator.pop(context, _ResetStep.backUp),
              child: Text(l10n.factoryResetBackUpFirst),
            ),
            TextButton(
              key: const Key('settings.factoryResetContinue'),
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
              ),
              onPressed: () => Navigator.pop(context, _ResetStep.reset),
              child: Text(l10n.continueAction),
            ),
          ],
        ),
      );
      if (!context.mounted) {
        return;
      }
      if (step == _ResetStep.backUp) {
        unawaited(context.push('/settings/backup'));
        return;
      }
      if (step != _ResetStep.reset) {
        return;
      }
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (_) => ResetAppDialog(
          l10n: l10n,
          title: l10n.factoryResetTitle,
          body: l10n.factoryResetTypeToConfirm(l10n.loginResetConfirmWord),
          confirmLabel: l10n.factoryReset,
        ),
      );
      if (confirmed != true) {
        return;
      }
      try {
        await ref.read(factoryResetServiceProvider).reset();
      } catch (e, st) {
        Logger.error('Factory reset failed', e, st);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              key: const Key('settings.factoryResetFailed'),
              content: Text(l10n.factoryResetFailed),
            ),
          );
        }
        return;
      }
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.factoryResetSuccess)));
        context.go('/onboarding');
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.settings),
        // Settings as the only page (a restored or redirected location):
        // a way back to the tabs instead of leaving the app.
        leading: (ModalRoute.of(context)?.isFirst ?? false)
            ? const _BackHomeButton()
            : null,
      ),
      body: ListView(
        children: [
          const _ProTile(),
          // General Settings
          SettingsSection(
            title: l10n.generalSettings,
            children: [
              // Currency: free while no account is in the budget, then
              // the currency of the accounts in it.
              const _BudgetCurrencyTile(),
              // Date Format
              ListTile(
                leading: const SettingsIcon(
                  Icons.calendar_today,
                  color: Colors.blue,
                ),
                title: Text(l10n.dateFormat),
                subtitle: Text(dateFormatLabel(settings.dateFormat)),
                onTap: () async {
                  final selected = await showDialog<AppDateFormat>(
                    context: context,
                    builder: (context) => SimpleDialog(
                      title: Text(l10n.dateFormat),
                      children: [
                        // "Follow language" first: the default.
                        for (final f in [
                          AppDateFormat.system,
                          ...AppDateFormat.values.where(
                            (f) => f != AppDateFormat.system,
                          ),
                        ])
                          buildOption(context, dateFormatLabel(f), f),
                      ],
                    ),
                  );
                  if (selected != null) {
                    unawaited(
                      ref
                          .read(settingsProvider.notifier)
                          .setDateFormat(selected),
                    );
                  }
                },
              ),
              // Number Format
              ListTile(
                leading: const SettingsIcon(
                  Icons.numbers,
                  color: Colors.indigo,
                ),
                title: Text(l10n.numberFormat),
                subtitle: Text(switch (settings.numberFormat) {
                  AppNumberFormat.system => l10n.numberFormatSystem,
                  AppNumberFormat.dot => l10n.dot,
                  AppNumberFormat.comma => l10n.comma,
                }),
                onTap: () async {
                  final selected = await showDialog<AppNumberFormat>(
                    context: context,
                    builder: (context) => SimpleDialog(
                      title: Text(l10n.numberFormat),
                      children: [
                        buildOption(
                          context,
                          l10n.numberFormatSystem,
                          AppNumberFormat.system,
                        ),
                        buildOption(context, l10n.dot, AppNumberFormat.dot),
                        buildOption(context, l10n.comma, AppNumberFormat.comma),
                      ],
                    ),
                  );
                  if (selected != null) {
                    unawaited(
                      ref
                          .read(settingsProvider.notifier)
                          .setNumberFormat(selected),
                    );
                  }
                },
              ),
              // No "First day of week": the date pickers start the week
              // as the app language does (Monday in German), and nothing
              // else in the app is week-based.
              // Theme
              ListTile(
                leading: const SettingsIcon(
                  Icons.brightness_6,
                  color: Colors.deepPurple,
                ),
                title: Text(l10n.theme),
                subtitle: Text(switch (themeState.mode) {
                  ThemeMode.system => l10n.systemTheme,
                  ThemeMode.light => l10n.lightTheme,
                  ThemeMode.dark => l10n.darkTheme,
                }),
                onTap: () async {
                  final selected = await showDialog<ThemeMode>(
                    context: context,
                    builder: (context) => SimpleDialog(
                      title: Text(l10n.theme),
                      children: [
                        buildOption(
                          context,
                          l10n.systemTheme,
                          ThemeMode.system,
                        ),
                        buildOption(context, l10n.lightTheme, ThemeMode.light),
                        buildOption(context, l10n.darkTheme, ThemeMode.dark),
                      ],
                    ),
                  );
                  if (selected != null) {
                    ref.read(themeProvider.notifier).setTheme(selected);
                  }
                },
              ),
              // Accessibility
              ListTile(
                leading: const SettingsIcon(
                  Icons.accessibility,
                  color: Colors.teal,
                ),
                title: Text(l10n.accessibility),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const AccessibilitySettingsScreen(),
                    ),
                  );
                },
              ),
              SwitchListTile(
                secondary: const SettingsIcon(
                  Icons.animation,
                  color: Colors.pink,
                ),
                title: Text(l10n.reducedMotion),
                value: themeState.reducedMotion,
                onChanged: (value) {
                  ref.read(themeProvider.notifier).toggleReducedMotion(value);
                },
              ),
              // Language
              ListTile(
                leading: const SettingsIcon(
                  Icons.language,
                  color: Colors.lightBlue,
                ),
                title: Text(l10n.language),
                subtitle: Text(
                  settings.language == null
                      ? l10n.languagePhoneCurrent(languageName)
                      : languageName,
                ),
                onTap: () async {
                  // Wrapped: "phone language" is a null choice, a
                  // dismissed dialog no choice.
                  final selected = await showDialog<Wrapped<Locale?>>(
                    context: context,
                    builder: (context) => SimpleDialog(
                      title: Text(l10n.language),
                      children: [
                        buildOption(
                          context,
                          l10n.languagePhone,
                          const Wrapped<Locale?>(null),
                        ),
                        for (final entry in kLanguageEndonyms.entries)
                          buildOption(
                            context,
                            entry.value,
                            Wrapped<Locale?>(Locale(entry.key)),
                          ),
                      ],
                    ),
                  );
                  if (selected != null) {
                    unawaited(
                      ref
                          .read(settingsProvider.notifier)
                          .setLanguage(selected.value),
                    );
                  }
                },
              ),
              // Default Account: the accounts the transaction form may
              // preselect (open, not the partner's personal account).
              Consumer(
                builder: (context, ref, _) {
                  final accountsAsync = ref
                      .watch(writableAccountsProvider)
                      .whenData(
                        (all) => all.where(isEligibleDefaultAccount).toList(),
                      );
                  return accountsAsync.when(
                    data: (accounts) => ListTile(
                      leading: const SettingsIcon(
                        Icons.account_balance_wallet,
                        color: Colors.cyan,
                      ),
                      title: Text(l10n.defaultAccount),
                      subtitle: Text(
                        accounts
                                .where((a) => a.id == settings.defaultAccountId)
                                .firstOrNull
                                ?.name ??
                            l10n.none,
                      ),
                      onTap: () async {
                        // Using a wrapper object to distinguish null (None) from null (Dismissed)
                        final selectedWrapper =
                            await showDialog<_SelectionWrapper>(
                              context: context,
                              builder: (context) => SimpleDialog(
                                title: Text(l10n.defaultAccount),
                                children: [
                                  SimpleDialogOption(
                                    onPressed: () => Navigator.pop(
                                      context,
                                      const _SelectionWrapper(null),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 8.0,
                                      ),
                                      child: Text(l10n.none),
                                    ),
                                  ),
                                  ...accounts.map(
                                    (a) => SimpleDialogOption(
                                      onPressed: () => Navigator.pop(
                                        context,
                                        _SelectionWrapper(a.id),
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 8.0,
                                        ),
                                        child: Text(a.name),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );

                        if (selectedWrapper != null) {
                          unawaited(
                            ref
                                .read(settingsProvider.notifier)
                                .setDefaultAccountId(selectedWrapper.value),
                          );
                        }
                      },
                    ),
                    loading: () => ListTile(title: Text(l10n.loadingAccounts)),
                    error: (_, _) => const SizedBox.shrink(),
                  );
                },
              ),
              // Default Category (hidden ones are not offered).
              Consumer(
                builder: (context, ref, _) {
                  final categoriesAsync = ref
                      .watch(categoriesProvider)
                      .whenData(
                        (all) => all.where(isEligibleDefaultCategory).toList(),
                      );
                  return categoriesAsync.when(
                    data: (categories) => ListTile(
                      leading: const SettingsIcon(
                        Icons.category,
                        color: Colors.orange,
                      ),
                      title: Text(l10n.defaultCategory),
                      subtitle: Text(
                        categories
                                .where(
                                  (c) => c.id == settings.defaultCategoryId,
                                )
                                .firstOrNull
                                ?.name ??
                            l10n.none,
                      ),
                      onTap: () async {
                        final selectedWrapper =
                            await showDialog<_SelectionWrapper>(
                              context: context,
                              builder: (context) => SimpleDialog(
                                title: Text(l10n.defaultCategory),
                                children: [
                                  SimpleDialogOption(
                                    onPressed: () => Navigator.pop(
                                      context,
                                      const _SelectionWrapper(null),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 8.0,
                                      ),
                                      child: Text(l10n.none),
                                    ),
                                  ),
                                  ...categories.map(
                                    (c) => SimpleDialogOption(
                                      onPressed: () => Navigator.pop(
                                        context,
                                        _SelectionWrapper(c.id),
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 8.0,
                                        ),
                                        child: Text(c.name),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                        if (selectedWrapper != null) {
                          unawaited(
                            ref
                                .read(settingsProvider.notifier)
                                .setDefaultCategoryId(selectedWrapper.value),
                          );
                        }
                      },
                    ),
                    loading: () => const SizedBox.shrink(),
                    error: (_, _) => const SizedBox.shrink(),
                  );
                },
              ),
            ],
          ),

          // Notification Settings
          SettingsSection(
            title: l10n.notificationSettings,
            children: [
              SwitchListTile(
                secondary: const SettingsIcon(
                  Icons.event_note,
                  color: Colors.deepOrange,
                ),
                title: Text(l10n.scheduledTransactionNotifications),
                value: settings.scheduledTransactionNotifications,
                onChanged: (value) => unawaited(
                  ref
                      .read(notificationTogglesProvider)
                      .setScheduledReminders(value),
                ),
              ),
              SwitchListTile(
                secondary: const SettingsIcon(
                  Icons.warning_amber,
                  color: Colors.amber,
                ),
                title: Text(l10n.budgetAlertNotifications),
                value: settings.budgetAlertNotifications,
                onChanged: (value) => unawaited(
                  ref.read(notificationTogglesProvider).setBudgetAlerts(value),
                ),
              ),
              SwitchListTile(
                secondary: const SettingsIcon(
                  Icons.sync,
                  color: Colors.lightBlue,
                ),
                title: Text(l10n.syncStatusNotifications),
                value: settings.syncStatusNotifications,
                onChanged: (value) => unawaited(
                  ref.read(notificationTogglesProvider).setSyncStatus(value),
                ),
              ),
            ],
          ),

          // Security, Sync & Backup
          SettingsSection(
            title: l10n.securityAndData,
            children: [
              ListTile(
                leading: const SettingsIcon(Icons.help, color: Colors.blue),
                title: Text(l10n.helpAndSupport),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.pushNamed('help'),
              ),
              ListTile(
                leading: const SettingsIcon(Icons.lock, color: Colors.red),
                title: Text(l10n.securitySettings),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/settings/security'),
              ),
              ListTile(
                leading: const SettingsIcon(
                  Icons.sync,
                  color: Colors.lightBlue,
                ),
                title: Text(l10n.syncSettings),
                trailing: const ProTrailing(
                  feature: ProFeature.wifiSync,
                  child: Icon(Icons.chevron_right),
                ),
                onTap: () => context.push('/settings/sync'),
              ),
              ListTile(
                leading: const SettingsIcon(Icons.backup, color: Colors.green),
                title: Text(l10n.backupAndExport),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/settings/backup'),
              ),
            ],
          ),

          // Data management
          SettingsSection(
            title: l10n.settingsManageSection,
            children: [
              ListTile(
                leading: const SettingsIcon(
                  Icons.upload_file,
                  color: Colors.teal,
                ),
                title: Text(l10n.importCsv),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/settings/import-csv'),
              ),
              ListTile(
                key: const Key('settings.importYnab'),
                leading: const SettingsIcon(
                  Icons.move_down,
                  color: Colors.indigo,
                ),
                title: Text(l10n.ynabImportTitle),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/settings/import-ynab'),
              ),
              // Android only: iOS gives apps no access to other apps'
              // notifications.
              if (ref.watch(notificationCaptureChannelProvider).isSupported)
                ListTile(
                  key: const Key('settings.cardNotifications'),
                  leading: const SettingsIcon(
                    Icons.credit_card,
                    color: Colors.purple,
                  ),
                  title: Text(l10n.cardNotifications),
                  subtitle: Text(l10n.cardNotificationsSubtitle),
                  // Capture that stopped, and payments that wait.
                  trailing: ProTrailing(
                    feature: ProFeature.cardCapture,
                    child: switch (ref
                        .watch(captureAttentionProvider)
                        .badgeCount) {
                      0 => const Icon(Icons.chevron_right),
                      final count => Badge(
                        key: const Key('settings.cardNotifications.badge'),
                        label: Text(
                          '$count',
                          semanticsLabel: l10n.cardNotificationsAttentionBadge(
                            count,
                          ),
                        ),
                        child: const Icon(Icons.chevron_right),
                      ),
                    },
                  ),
                  onTap: () => context.push('/settings/card-notifications'),
                ),
              ListTile(
                key: const Key('settings.rules'),
                leading: const SettingsIcon(
                  Icons.rule,
                  color: Colors.deepPurple,
                ),
                title: Text(l10n.rules),
                subtitle: Text(l10n.rulesSettingsSubtitle),
                trailing: const ProTrailing(
                  feature: ProFeature.rules,
                  child: Icon(Icons.chevron_right),
                ),
                onTap: () => context.push('/settings/rules'),
              ),
              ListTile(
                leading: const SettingsIcon(Icons.people, color: Colors.orange),
                title: Text(l10n.payees),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/settings/payees'),
              ),
              ListTile(
                leading: const SettingsIcon(
                  Icons.attach_money,
                  color: Colors.lightGreen,
                ),
                title: Text(l10n.incomeAndSalaries),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/settings/income'),
              ),
              ListTile(
                leading: const SettingsIcon(
                  AppIcons.calendar,
                  color: Colors.blue,
                ),
                title: Text(l10n.scheduledTransactions),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/settings/scheduled-transactions'),
              ),
            ],
          ),

          // Advanced Settings
          SettingsSection(
            title: l10n.advancedSettings,
            children: [
              ListTile(
                leading: const SettingsIcon(
                  Icons.cleaning_services,
                  color: Colors.brown,
                ),
                title: Text(l10n.clearCache),
                onTap: () => clearCache(context),
              ),
              ListTile(
                leading: const SettingsIcon(
                  Icons.delete_forever,
                  color: Colors.red,
                ),
                title: Text(
                  l10n.factoryReset,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                onTap: () => factoryReset(context, ref),
              ),
            ],
          ),

          // About: version, licences, contact, legal pages.
          const AboutSettingsSection(),

          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

/// The back arrow of Settings when it is the only page: it and the system
/// back button lead Home, with the tab bar.
class _BackHomeButton extends StatelessWidget {
  const _BackHomeButton();

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          context.go('/');
        }
      },
      child: BackButton(
        key: const Key('settings.backHome'),
        onPressed: () => context.go('/'),
      ),
    );
  }
}

/// Settings > Currency. While no open account is in the budget it picks
/// the stored currency (the first account in the budget then proposes it).
/// Once accounts are in the budget it shows their currency and offers one
/// action, "Change the budget currency": after a confirmation that amounts
/// are not converted, it relabels the accounts in the budget.
class _BudgetCurrencyTile extends ConsumerWidget {
  const _BudgetCurrencyTile();

  Future<String?> _pickCurrency(
    BuildContext context,
    String title, {
    String? except,
  }) {
    return showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        key: const Key('settings.currency.picker'),
        title: Text(title),
        children: [
          for (final c in supportedCurrencyCodes)
            if (c != except)
              SimpleDialogOption(
                onPressed: () => Navigator.pop(context, c),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Text(c, style: const TextStyle(fontSize: 16)),
                ),
              ),
        ],
      ),
    );
  }

  Future<void> _change(
    BuildContext context,
    WidgetRef ref,
    BudgetCurrency budget,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final change = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        key: const Key('settings.currency.fixed'),
        title: Text(l10n.budgetCurrencyLabel),
        content: Text(l10n.budgetCurrencyFixedBody(budget.currency)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.close),
          ),
          FilledButton(
            key: const Key('settings.currency.change'),
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.budgetCurrencyChangeAction),
          ),
        ],
      ),
    );
    if (change != true || !context.mounted) {
      return;
    }
    // In a mixed budget every currency is offered (relabelling to the
    // budget currency fixes it too).
    final selected = await _pickCurrency(
      context,
      l10n.budgetCurrencyChangeAction,
      except: budget.isMixed ? null : budget.currency,
    );
    if (selected == null || !context.mounted) {
      return;
    }
    final from = budget.onBudgetCurrencies.where((c) => c != selected);
    if (!await confirmBudgetCurrencyChange(
          context,
          from: from.join(', '),
          to: selected,
        ) ||
        !context.mounted) {
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    try {
      await changeBudgetCurrency(ref, selected);
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.budgetCurrencyChanged(selected))),
      );
    } catch (e, st) {
      Logger.error('Changing the budget currency failed', e, st);
      messenger.showSnackBar(SnackBar(content: Text(l10n.errorOccurred)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final budget = ref.watch(budgetCurrencyProvider);
    return ListTile(
      key: const Key('settings.currency'),
      leading: const SettingsIcon(Icons.attach_money, color: Colors.green),
      title: Text(l10n.currency),
      subtitle: Text(
        budget.isFixed
            ? l10n.budgetCurrencyFixedSubtitle(budget.currency)
            : budget.currency,
      ),
      onTap: () async {
        if (budget.isFixed) {
          await _change(context, ref, budget);
          return;
        }
        final selected = await _pickCurrency(context, l10n.currency);
        if (selected != null) {
          unawaited(ref.read(settingsProvider.notifier).setCurrency(selected));
        }
      },
    );
  }
}

/// The answer to the first factory-reset dialog.
enum _ResetStep { backUp, reset }

class _SelectionWrapper {
  final String? value;
  const _SelectionWrapper(this.value);
}

/// LedgerZero Pro: what it unlocks, or a thank-you once bought.
class _ProTile extends ConsumerWidget {
  const _ProTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final unlocked = ref.watch(proUnlockedProvider);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Material(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          key: const Key('settings.pro'),
          leading: const SettingsIcon(
            Icons.workspace_premium,
            color: Colors.amber,
          ),
          title: Text(l10n.proTitle),
          subtitle: Text(
            unlocked ? l10n.proUnlocked : l10n.proSettingsSubtitle,
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push(proLocation()),
        ),
      ),
    );
  }
}
