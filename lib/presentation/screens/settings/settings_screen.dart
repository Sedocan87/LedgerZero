import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ledger_zero/core/constants/app_icons.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/providers/settings_provider.dart';
import 'package:ledger_zero/presentation/providers/theme_provider.dart';
import 'package:ledger_zero/presentation/providers/data_providers.dart';
import 'package:ledger_zero/presentation/screens/settings/widgets/settings_section.dart';
import 'package:ledger_zero/presentation/screens/settings/accessibility_settings_screen.dart'; // Import
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:ledger_zero/presentation/providers/service_providers.dart';
import 'package:ledger_zero/data/database/database.dart';

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
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.cacheCleared)),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error clearing cache: $e')),
          );
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
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              onPressed: () => Navigator.pop(context, true),
              child: Text(l10n.factoryReset),
            ),
          ],
        ),
      );

      if (confirmed == true) {
        // Close database connection
        await AppDatabase.instance.close();

        // Delete database file
        final dbFolder = await getApplicationDocumentsDirectory();
        final file = File('${dbFolder.path}/db.sqlite');
        if (await file.exists()) {
          await file.delete();
        }

        // Clear shared preferences
        final prefs = ref.read(sharedPreferencesProvider);
        await prefs.clear();

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.factoryResetSuccess)),
          );
          // Force app restart or navigate to onboarding would be ideal here
          // For now, we'll navigate to initial route if possible, or just let the user restart
        }
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.settings),
      ),
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
                      children: ['USD', 'EUR', 'GBP', 'JPY', 'CHF', 'CAD', 'AUD']
                          .map((c) => buildOption(context, c, c))
                          .toList(),
                    ),
                  );
                  if (selected != null) {
                    ref.read(settingsProvider.notifier).setCurrency(selected);
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
                    ref.read(settingsProvider.notifier).setDateFormat(selected);
                  }
                },
              ),
              // Number Format
              ListTile(
                leading: const Icon(Icons.numbers),
                title: Text(l10n.numberFormat),
                subtitle: Text(settings.numberFormat == AppNumberFormat.dot ? l10n.dot : l10n.comma),
                onTap: () async {
                  final selected = await showDialog<AppNumberFormat>(
                    context: context,
                    builder: (context) => SimpleDialog(
                      title: Text(l10n.numberFormat),
                      children: [
                        buildOption(context, l10n.dot, AppNumberFormat.dot),
                        buildOption(context, l10n.comma, AppNumberFormat.comma),
                      ],
                    ),
                  );
                  if (selected != null) {
                    ref.read(settingsProvider.notifier).setNumberFormat(selected);
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
                  _ => l10n.sunday,
                }),
                onTap: () async {
                  final selected = await showDialog<AppFirstDayOfWeek>(
                    context: context,
                    builder: (context) => SimpleDialog(
                      title: Text(l10n.firstDayOfWeek),
                      children: [
                        buildOption(context, l10n.sunday, AppFirstDayOfWeek.sunday),
                        buildOption(context, l10n.monday, AppFirstDayOfWeek.monday),
                        buildOption(context, l10n.saturday, AppFirstDayOfWeek.saturday),
                      ],
                    ),
                  );
                  if (selected != null) {
                    ref.read(settingsProvider.notifier).setFirstDayOfWeek(selected);
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
                        buildOption(context, l10n.systemTheme, ThemeMode.system),
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
                title: const Text('Accessibility'), // TODO: l10n
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const AccessibilitySettingsScreen()),
                  );
                },
              ),
              // Language
              ListTile(
                leading: const Icon(Icons.language),
                title: Text(l10n.language),
                subtitle: Text(settings.language?.languageCode == 'de' ? 'Deutsch' : 'English'),
                onTap: () async {
                  final selected = await showDialog<Locale>(
                    context: context,
                    builder: (context) => SimpleDialog(
                      title: Text(l10n.language),
                      children: [
                        buildOption(context, 'English', const Locale('en')),
                        buildOption(context, 'Deutsch', const Locale('de')),
                      ],
                    ),
                  );
                  if (selected != null) {
                    ref.read(settingsProvider.notifier).setLanguage(selected);
                  }
                },
              ),
              // Default Account
              Consumer(builder: (context, ref, _) {
                final accountsAsync = ref.watch(accountsProvider);
                return accountsAsync.when(
                  data: (accounts) => ListTile(
                    leading: const Icon(Icons.account_balance_wallet),
                    title: Text(l10n.defaultAccount),
                    subtitle: Text(
                      accounts.where((a) => a.id == settings.defaultAccountId).firstOrNull?.name ?? l10n.none,
                    ),
                    onTap: () async {
                      // Using a wrapper object to distinguish null (None) from null (Dismissed)
                      final selectedWrapper = await showDialog<_SelectionWrapper>(
                        context: context,
                        builder: (context) => SimpleDialog(
                          title: Text(l10n.defaultAccount),
                          children: [
                            SimpleDialogOption(
                                onPressed: () => Navigator.pop(context, const _SelectionWrapper(null)),
                                child: Padding(padding: const EdgeInsets.symmetric(vertical: 8.0), child: Text(l10n.none)),
                            ),
                            ...accounts.map((a) => SimpleDialogOption(
                                onPressed: () => Navigator.pop(context, _SelectionWrapper(a.id)),
                                child: Padding(padding: const EdgeInsets.symmetric(vertical: 8.0), child: Text(a.name)),
                            )),
                          ],
                        ),
                      );

                      if (selectedWrapper != null) {
                         ref.read(settingsProvider.notifier).setDefaultAccountId(selectedWrapper.value);
                      }
                    },
                  ),
                  loading: () => ListTile(title: Text(l10n.loadingAccounts)),
                  error: (_, __) => const SizedBox.shrink(),
                );
              }),
              // Default Category
              Consumer(builder: (context, ref, _) {
                final categoriesAsync = ref.watch(categoriesProvider);
                return categoriesAsync.when(
                  data: (categories) => ListTile(
                    leading: const Icon(Icons.category),
                    title: Text(l10n.defaultCategory),
                    subtitle: Text(
                      categories.where((c) => c.id == settings.defaultCategoryId).firstOrNull?.name ?? l10n.none,
                    ),
                    onTap: () async {
                       final selectedWrapper = await showDialog<_SelectionWrapper>(
                        context: context,
                        builder: (context) => SimpleDialog(
                          title: Text(l10n.defaultCategory),
                          children: [
                             SimpleDialogOption(
                                onPressed: () => Navigator.pop(context, const _SelectionWrapper(null)),
                                child: Padding(padding: const EdgeInsets.symmetric(vertical: 8.0), child: Text(l10n.none)),
                            ),
                            ...categories.map((c) => SimpleDialogOption(
                                onPressed: () => Navigator.pop(context, _SelectionWrapper(c.id)),
                                child: Padding(padding: const EdgeInsets.symmetric(vertical: 8.0), child: Text(c.name)),
                            )),
                          ],
                        ),
                      );
                      if (selectedWrapper != null) {
                         ref.read(settingsProvider.notifier).setDefaultCategoryId(selectedWrapper.value);
                      }
                    },
                  ),
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                );
              }),
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
                onChanged: (value) => ref.read(settingsProvider.notifier).setScheduledTransactionNotifications(value),
              ),
              SwitchListTile(
                secondary: const Icon(Icons.warning_amber),
                title: Text(l10n.budgetAlertNotifications),
                value: settings.budgetAlertNotifications,
                onChanged: (value) => ref.read(settingsProvider.notifier).setBudgetAlertNotifications(value),
              ),
              SwitchListTile(
                secondary: const Icon(Icons.sync),
                title: Text(l10n.syncStatusNotifications),
                value: settings.syncStatusNotifications,
                onChanged: (value) => ref.read(settingsProvider.notifier).setSyncStatusNotifications(value),
              ),
            ],
          ),

          // Security, Sync & Backup
          SettingsSection(
            title: l10n.securityAndData,
            children: [
              ListTile(
                leading: const Icon(Icons.help),
                title: const Text('Help & Support'), // TODO: l10n
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
                title: Text(l10n.backupAndRestore),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/settings/backup'),
              ),
            ],
          ),

          // Management
          SettingsSection(
            title: l10n.manageCategories,
            children: [
               ListTile(
                leading: const Icon(Icons.upload_file),
                title: Text(l10n.importCsv),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/settings/import-csv'),
              ),
              ListTile(
                leading: const Icon(Icons.import_export),
                title: Text(l10n.importFromMint),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/settings/import-mint'),
              ),
              ListTile(
                leading: const Icon(Icons.people),
                title: Text(l10n.payees),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/settings/payees'),
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
              SwitchListTile(
                secondary: const Icon(Icons.developer_mode),
                title: Text(l10n.developerMode),
                value: settings.developerMode,
                onChanged: (value) => ref.read(settingsProvider.notifier).setDeveloperMode(value),
              ),
              if (settings.developerMode)
                ListTile(
                  leading: const Icon(Icons.data_usage),
                  title: Text(l10n.databaseStatistics),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/settings/database-stats'),
                ),
              ListTile(
                leading: const Icon(Icons.cleaning_services),
                title: Text(l10n.clearCache),
                onTap: () => clearCache(context),
              ),
              ListTile(
                leading: const Icon(Icons.delete_forever, color: Colors.red),
                title: Text(l10n.factoryReset, style: const TextStyle(color: Colors.red)),
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
