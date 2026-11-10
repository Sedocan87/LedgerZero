import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// Name, version and build number of the installed app.
final packageInfoProvider = FutureProvider<PackageInfo>(
  (ref) => PackageInfo.fromPlatform(),
);

/// Hands a link (`mailto:`, `https:`) to another app. Completes with false
/// when no app took it.
typedef ExternalLinkOpener = Future<bool> Function(Uri uri);

final externalLinkOpenerProvider = Provider<ExternalLinkOpener>(
  (ref) => (uri) async {
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      // No activity for the link, or the platform refused: same answer.
      return false;
    }
  },
);
