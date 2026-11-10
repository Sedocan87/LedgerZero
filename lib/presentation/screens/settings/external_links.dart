import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledger_zero/core/constants/app_links.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/providers/app_info_providers.dart';

/// Opens an e-mail to the support address. Without a mail app the address
/// is copied to the clipboard and a snackbar says so, instead of nothing
/// happening.
Future<void> contactSupport(BuildContext context, WidgetRef ref) {
  final l10n = AppLocalizations.of(context)!;
  return _openOrCopy(
    context,
    ref,
    uri: Uri(scheme: 'mailto', path: AppLinks.supportEmail),
    copy: AppLinks.supportEmail,
    copiedMessage: l10n.supportEmailCopied(AppLinks.supportEmail),
  );
}

/// Opens a web page in the browser. Without a browser its address is
/// copied to the clipboard and a snackbar says so.
Future<void> openWebPage(BuildContext context, WidgetRef ref, String url) {
  final l10n = AppLocalizations.of(context)!;
  return _openOrCopy(
    context,
    ref,
    uri: Uri.parse(url),
    copy: url,
    copiedMessage: l10n.linkCopied,
  );
}

Future<void> _openOrCopy(
  BuildContext context,
  WidgetRef ref, {
  required Uri uri,
  required String copy,
  required String copiedMessage,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final opened = await ref.read(externalLinkOpenerProvider)(uri);
  if (opened) {
    return;
  }
  await Clipboard.setData(ClipboardData(text: copy));
  messenger.showSnackBar(SnackBar(content: Text(copiedMessage)));
}
