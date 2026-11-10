import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledger_zero/app/licenses.dart';
import 'package:ledger_zero/core/constants/app_constants.dart';
import 'package:ledger_zero/core/constants/app_links.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/providers/app_info_providers.dart';
import 'package:ledger_zero/presentation/providers/review_provider.dart';
import 'package:ledger_zero/presentation/screens/settings/legal_document_screen.dart';
import 'package:ledger_zero/services/legal/legal_documents.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:ledger_zero/presentation/screens/settings/external_links.dart';
import 'package:ledger_zero/presentation/screens/settings/widgets/settings_section.dart';
import 'package:ledger_zero/presentation/screens/settings/widgets/settings_icon.dart';

/// The app's version as About shows it: version, build number and, for a
/// build made by tool/release.sh, the commit it was built from.
String? appVersionLabel(AppLocalizations l10n, PackageInfo? info) {
  if (info == null) {
    return null;
  }
  final label = l10n.aboutVersion(info.version, info.buildNumber);
  return gitCommit.isEmpty ? label : '$label · $gitCommit';
}

/// The commit a release was built from (`--dart-define=GIT_COMMIT=…`, set by
/// tool/release.sh); empty otherwise.
const String gitCommit = String.fromEnvironment('GIT_COMMIT');

/// The section at the end of Settings: About (with the version), rating the
/// app, the legal pages and the open-source licences.
class AboutSettingsSection extends ConsumerWidget {
  const AboutSettingsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final version = appVersionLabel(
      l10n,
      ref.watch(packageInfoProvider).valueOrNull,
    );
    return SettingsSection(
      title: l10n.aboutTitle,
      children: [
        ListTile(
          key: const Key('settings.about'),
          leading: const SettingsIcon(
            Icons.info_outline,
            color: Colors.blueGrey,
          ),
          title: Text(l10n.aboutApp(AppConstants.appName)),
          subtitle: Text(version ?? l10n.aboutSubtitle),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => AboutScreen.show(context),
        ),
        ListTile(
          key: const Key('settings.rate'),
          leading: const SettingsIcon(Icons.star_outline, color: Colors.amber),
          title: Text(l10n.rateApp),
          subtitle: Text(l10n.rateAppSubtitle),
          trailing: const Icon(Icons.open_in_new),
          onTap: () => rateApp(context, ref),
        ),
        ..._legalTiles(context, ref, l10n, keyPrefix: 'settings'),
        ListTile(
          key: const Key('settings.licenses'),
          leading: const SettingsIcon(
            Icons.description_outlined,
            color: Colors.grey,
          ),
          title: Text(l10n.aboutLicenses),
          subtitle: Text(l10n.aboutLicensesSubtitle),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => showLicenses(context, ref),
        ),
      ],
    );
  }
}

/// "Rate LedgerZero": the app's page in the Play Store.
Future<void> rateApp(BuildContext context, WidgetRef ref) async {
  final messenger = ScaffoldMessenger.of(context);
  final failed = AppLocalizations.of(context)!.rateAppFailed;
  if (!await ref.read(reviewPrompterProvider).openStoreListing()) {
    messenger.showSnackBar(SnackBar(content: Text(failed)));
  }
}

/// The licence page of the app and everything it is built with.
void showLicenses(BuildContext context, WidgetRef ref) {
  final l10n = AppLocalizations.of(context)!;
  final info = ref.read(packageInfoProvider).valueOrNull;
  registerBundledLicenses();
  showLicensePage(
    context: context,
    applicationName: _appName(info),
    applicationVersion: appVersionLabel(l10n, info),
    useRootNavigator: true,
  );
}

String _appName(PackageInfo? info) =>
    // The flavor's own label ("LedgerZero Dev") where the platform has it.
    (info == null || info.appName.isEmpty)
    ? AppConstants.appName
    : info.appName;

/// Privacy policy, terms of use and, once the publisher is filled in, the
/// imprint.
List<Widget> _legalTiles(
  BuildContext context,
  WidgetRef ref,
  AppLocalizations l10n, {
  required String keyPrefix,
}) {
  final publisher = ref.watch(publisherProvider).valueOrNull;
  Widget tile(LegalDocument document, IconData icon, MaterialColor color) =>
      ListTile(
        key: Key('$keyPrefix.${document.name}'),
        leading: SettingsIcon(icon, color: color),
        title: Text(LegalDocumentScreen.titleOf(document, l10n)),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => LegalDocumentScreen.show(context, document),
      );
  return [
    tile(LegalDocument.privacy, Icons.privacy_tip_outlined, Colors.green),
    tile(LegalDocument.terms, Icons.gavel_outlined, Colors.indigo),
    if (publisher?.isComplete ?? false)
      tile(LegalDocument.imprint, Icons.business_outlined, Colors.brown),
  ];
}

/// Settings > About: app name, version and build number, the support
/// contact, rating the app, the legal pages and the open-source licences.
class AboutScreen extends ConsumerWidget {
  const AboutScreen({super.key});

  /// Opens the screen above the bottom navigation.
  static Future<void> show(BuildContext context) => Navigator.of(
    context,
    rootNavigator: true,
  ).push(MaterialPageRoute<void>(builder: (_) => const AboutScreen()));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final info = ref.watch(packageInfoProvider).valueOrNull;
    final version = appVersionLabel(l10n, info);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.aboutApp(AppConstants.appName))),
      body: ListView(
        children: [
          ListTile(
            key: const Key('about.version'),
            leading: const Icon(Icons.info_outline),
            title: Text(_appName(info)),
            subtitle: version == null ? null : Text(version),
          ),
          const Divider(),
          ListTile(
            key: const Key('about.support'),
            leading: const Icon(Icons.email),
            title: Text(l10n.contactSupport),
            subtitle: const Text(AppLinks.supportEmail),
            onTap: () => contactSupport(context, ref),
          ),
          ListTile(
            key: const Key('about.rate'),
            leading: const Icon(Icons.star_outline),
            title: Text(l10n.rateApp),
            trailing: const Icon(Icons.open_in_new),
            onTap: () => rateApp(context, ref),
          ),
          const Divider(),
          ..._legalTiles(context, ref, l10n, keyPrefix: 'about'),
          ListTile(
            key: const Key('about.licenses'),
            leading: const Icon(Icons.description_outlined),
            title: Text(l10n.aboutLicenses),
            subtitle: Text(l10n.aboutLicensesSubtitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => showLicenses(context, ref),
          ),
        ],
      ),
    );
  }
}
