import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledger_zero/app/licenses.dart';
import 'package:ledger_zero/core/constants/app_constants.dart';
import 'package:ledger_zero/core/constants/app_links.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/providers/app_info_providers.dart';
import 'package:ledger_zero/presentation/screens/settings/external_links.dart';
import 'package:ledger_zero/presentation/screens/settings/widgets/settings_section.dart';
import 'package:ledger_zero/presentation/screens/settings/widgets/settings_icon.dart';

/// The "About" entry at the end of Settings: opens [AboutScreen].
class AboutSettingsSection extends StatelessWidget {
  const AboutSettingsSection({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
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
          subtitle: Text(l10n.aboutSubtitle),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => AboutScreen.show(context),
        ),
      ],
    );
  }
}

/// Settings > About: app name, version and build number, the open-source
/// licences, the support contact and, once they exist, the privacy policy
/// and the imprint.
class AboutScreen extends ConsumerWidget {
  const AboutScreen({
    super.key,
    this.privacyPolicyUrl = AppLinks.privacyPolicyUrl,
    this.imprintUrl = AppLinks.imprintUrl,
  });

  /// The legal pages; an entry is shown only for a URL that is set.
  final String? privacyPolicyUrl;
  final String? imprintUrl;

  /// Opens the screen above the bottom navigation.
  static Future<void> show(BuildContext context) => Navigator.of(
    context,
    rootNavigator: true,
  ).push(MaterialPageRoute<void>(builder: (_) => const AboutScreen()));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final info = ref.watch(packageInfoProvider).valueOrNull;
    // The flavor's own label ("LedgerZero Dev") where the platform has it.
    final appName = (info == null || info.appName.isEmpty)
        ? AppConstants.appName
        : info.appName;
    final version = info == null
        ? null
        : l10n.aboutVersion(info.version, info.buildNumber);
    final privacyPolicyUrl = this.privacyPolicyUrl;
    final imprintUrl = this.imprintUrl;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.aboutApp(AppConstants.appName))),
      body: ListView(
        children: [
          ListTile(
            key: const Key('about.version'),
            leading: const Icon(Icons.info_outline),
            title: Text(appName),
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
          if (privacyPolicyUrl != null)
            ListTile(
              key: const Key('about.privacyPolicy'),
              leading: const Icon(Icons.privacy_tip_outlined),
              title: Text(l10n.aboutPrivacyPolicy),
              trailing: const Icon(Icons.open_in_new),
              onTap: () => openWebPage(context, ref, privacyPolicyUrl),
            ),
          if (imprintUrl != null)
            ListTile(
              key: const Key('about.imprint'),
              leading: const Icon(Icons.business_outlined),
              title: Text(l10n.aboutImprint),
              trailing: const Icon(Icons.open_in_new),
              onTap: () => openWebPage(context, ref, imprintUrl),
            ),
          const Divider(),
          ListTile(
            key: const Key('about.licenses'),
            leading: const Icon(Icons.description_outlined),
            title: Text(l10n.aboutLicenses),
            subtitle: Text(l10n.aboutLicensesSubtitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              registerBundledLicenses();
              showLicensePage(
                context: context,
                applicationName: appName,
                applicationVersion: version,
                useRootNavigator: true,
              );
            },
          ),
        ],
      ),
    );
  }
}
