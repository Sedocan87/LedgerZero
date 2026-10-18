import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ledger_zero/core/constants/app_icons.dart';
import 'package:ledger_zero/core/money/currency.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/l10n/enum_labels.dart';
import 'package:ledger_zero/presentation/providers/settings_provider.dart';
import 'package:ledger_zero/presentation/providers/theme_provider.dart';
import 'package:ledger_zero/presentation/providers/data_providers.dart';
import 'package:ledger_zero/presentation/providers/settings_defaults_guard.dart';
import 'package:ledger_zero/presentation/providers/factory_reset_provider.dart';
import 'package:ledger_zero/presentation/providers/notification_capture_providers.dart';
import 'package:ledger_zero/presentation/screens/settings/widgets/settings_section.dart';
import 'package:ledger_zero/presentation/screens/settings/accessibility_settings_screen.dart'; // Import
import 'dart:async';
import 'package:path_provider/path_provider.dart';
import 'package:ledger_zero/core/utils/logger.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final settings = ref.watch(settingsProvider);
    final themeState = ref.watch(themeProvider);

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
        final cacheDir = await getTemporaryDirectory();
        if (cacheDir.existsSync()) {
          cacheDir.deleteSync(recursive: true);
        }
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

    Future<void> factoryReset(BuildContext context, WidgetRef ref) async {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l10n.factoryResetTitle),
          content: Text(l10n.factoryResetConfirmation),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l10n.cancel),
            ),
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
              ),
              onPressed: () => Navigator.pop(context, true),
              child: Text(l10n.factoryReset),
            ),
          ],
        ),
      );

      if (confirmed == true) {
        await ref.read(factoryResetServiceProvider).reset();

        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(l10n.factoryResetSuccess)));
          context.go('/onboarding');
        }
      }
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settings)),
      body: ListView(
        children: [
          // General Settings
          SettingsSection(
            title: l10n.generalSettings,
            children: [
              // Currency
              ListTile(
                leading: const Icon(Icons.attach_money),
                title: Text(l10n.currency),
                subtitle: Text(settings.currency),
                onTap: () async {
                  final selected = await showDialog<String>(
                    context: context,
                    builder: (context) => SimpleDialog(
                      title: Text(l10n.currency),
                      children: supportedCurrencyCodes
                          .map((c) => buildOption(context, c, c))
                          .toList(),
                    ),
                  );
                  if (selected != null) {
                    unawaited(
                      ref.read(settingsProvider.notifier).setCurrency(selected),
                    );
                  }
                },
              ),
              // Date Format
              ListTile(
                leading: const Icon(Icons.calendar_today),
                title: Text(l10n.dateFormat),
                subtitle: Text(settings.dateFormat.pattern),
                onTap: () async {
                  final selected = await showDialog<AppDateFormat>(
                    context: context,
                    builder: (context) => SimpleDialog(
                      title: Text(l10n.dateFormat),
                      children: AppDateFormat.values
                          .map((f) => buildOption(context, f.pattern, f))
                          .toList(),
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
                leading: const Icon(Icons.numbers),
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
              // First Day of Week
              ListTile(
                leading: const Icon(Icons.today),
                title: Text(l10n.firstDayOfWeek),
                subtitle: Text(switch (settings.firstDayOfWeek) {
                  AppFirstDayOfWeek.sunday => l10n.sunday,
                  AppFirstDayOfWeek.monday => l10n.monday,
                  AppFirstDayOfWeek.saturday => l10n.saturday,
                }),
                onTap: () async {
                  final selected = await showDialog<AppFirstDayOfWeek>(
                    context: context,
                    builder: (context) => SimpleDialog(
                      title: Text(l10n.firstDayOfWeek),
                      children: [
                        buildOption(
                          context,
                          l10n.sunday,
                          AppFirstDayOfWeek.sunday,
                        ),
                        buildOption(
                          context,
                          l10n.monday,
                          AppFirstDayOfWeek.monday,
                        ),
                        buildOption(
                          context,
                          l10n.saturday,
                          AppFirstDayOfWeek.saturday,
                        ),
                      ],
                    ),
                  );
                  if (selected != null) {
                    unawaited(
                      ref
                          .read(settingsProvider.notifier)
                          .setFirstDayOfWeek(selected),
                    );
                  }
                },
              ),
              // Theme
              ListTile(
                leading: const Icon(Icons.brightness_6),
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
                leading: const Icon(Icons.accessibility),
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
                secondary: const Icon(Icons.animation),
                title: Text(l10n.reducedMotion),
                value: themeState.reducedMotion,
                onChanged: (value) {
                  ref.read(themeProvider.notifier).toggleReducedMotion(value);
                },
              ),
              // Language
              ListTile(
                leading: const Icon(Icons.language),
                title: Text(l10n.language),
                subtitle: Text(
                  kLanguageEndonyms[Localizations.localeOf(
                        context,
                      ).languageCode] ??
                      Localizations.localeOf(context).languageCode,
                ),
                onTap: () async {
                  final selected = await showDialog<Locale>(
                    context: context,
                    builder: (context) => SimpleDialog(
                      title: Text(l10n.language),
                      children: [
                        for (final entry in kLanguageEndonyms.entries)
                          buildOption(context, entry.value, Locale(entry.key)),
                      ],
                    ),
                  );
                  if (selected != null) {
                    unawaited(
                      ref.read(settingsProvider.notifier).setLanguage(selected),
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
                      leading: const Icon(Icons.account_balance_wallet),
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
                      leading: const Icon(Icons.category),
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
                secondary: const Icon(Icons.event_note),
                title: Text(l10n.scheduledTransactionNotifications),
                value: settings.scheduledTransactionNotifications,
                onChanged: (value) => unawaited(
                  ref
                      .read(settingsProvider.notifier)
                      .setScheduledTransactionNotifications(value),
                ),
              ),
              SwitchListTile(
                secondary: const Icon(Icons.warning_amber),
                title: Text(l10n.budgetAlertNotifications),
                value: settings.budgetAlertNotifications,
                onChanged: (value) => unawaited(
                  ref
                      .read(settingsProvider.notifier)
                      .setBudgetAlertNotifications(value),
                ),
              ),
              SwitchListTile(
                secondary: const Icon(Icons.sync),
                title: Text(l10n.syncStatusNotifications),
                value: settings.syncStatusNotifications,
                onChanged: (value) => unawaited(
                  ref
                      .read(settingsProvider.notifier)
                      .setSyncStatusNotifications(value),
                ),
              ),
            ],
          ),

          // Security, Sync & Backup
          SettingsSection(
            title: l10n.securityAndData,
            children: [
              ListTile(
                leading: const Icon(Icons.help),
                title: Text(l10n.helpAndSupport),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.pushNamed('help'),
              ),
              ListTile(
                leading: const Icon(Icons.lock),
                title: Text(l10n.securitySettings),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/settings/security'),
              ),
              ListTile(
                leading: const Icon(Icons.sync),
                title: Text(l10n.syncSettings),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/settings/sync'),
              ),
              ListTile(
                leading: const Icon(Icons.backup),
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
                leading: const Icon(Icons.upload_file),
                title: Text(l10n.importCsv),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/settings/import-csv'),
              ),
              ListTile(
                key: const Key('settings.importYnab'),
                leading: const Icon(Icons.move_down),
                title: Text(l10n.ynabImportTitle),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/settings/import-ynab'),
              ),
              // Android only: iOS gives apps no access to other apps'
              // notifications.
              if (ref.watch(notificationCaptureChannelProvider).isSupported)
                ListTile(
                  key: const Key('settings.cardNotifications'),
                  leading: const Icon(Icons.credit_card),
                  title: Text(l10n.cardNotifications),
                  subtitle: Text(l10n.cardNotificationsSubtitle),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/settings/card-notifications'),
                ),
              ListTile(
                key: const Key('settings.rules'),
                leading: const Icon(Icons.rule),
                title: Text(l10n.rules),
                subtitle: Text(l10n.rulesSettingsSubtitle),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/settings/rules'),
              ),
              ListTile(
                leading: const Icon(Icons.people),
                title: Text(l10n.payees),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/settings/payees'),
              ),
              ListTile(
                leading: const Icon(Icons.attach_money),
                title: Text(l10n.incomeAndSalaries),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/settings/income'),
              ),
              ListTile(
                leading: const Icon(AppIcons.calendar),
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
                leading: const Icon(Icons.cleaning_services),
                title: Text(l10n.clearCache),
                onTap: () => clearCache(context),
              ),
              ListTile(
                leading: Icon(
                  Icons.delete_forever,
                  color: Theme.of(context).colorScheme.error,
                ),
                title: Text(
                  l10n.factoryReset,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                onTap: () => factoryReset(context, ref),
              ),
            ],
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _SelectionWrapper {
  final String? value;
  const _SelectionWrapper(this.value);
}
