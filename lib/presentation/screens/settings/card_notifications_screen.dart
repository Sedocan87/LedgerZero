import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ledger_zero/core/time/calendar_date.dart';
import 'package:ledger_zero/core/utils/logger.dart';
import 'package:ledger_zero/domain/entities/account.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/providers/data_providers.dart';
import 'package:ledger_zero/presentation/providers/formatter_provider.dart';
import 'package:ledger_zero/presentation/providers/notification_capture_providers.dart';
import 'package:ledger_zero/presentation/screens/settings/widgets/settings_section.dart';
import 'package:ledger_zero/presentation/screens/transactions/form/transaction_draft.dart';
import 'package:ledger_zero/services/notification_capture/card_notification_parser.dart';
import 'package:ledger_zero/services/notification_capture/notification_capture_channel.dart';
import 'package:ledger_zero/services/notification_capture/notification_capture_service.dart';

/// The transaction form's draft for captured notification [n]: what was
/// read, the notification text as memo, and the app's account.
TransactionDraft captureDraft(
  WidgetRef ref,
  CapturedNotification n,
  CardNotificationParse parse,
  String? accountId,
) {
  final amount = parse.amount;
  return TransactionDraft(
    amountText: amount == null
        ? ''
        : ref.read(appFormatterProvider).formatAmountForInput(amount),
    memo: [
      n.title,
      n.text,
    ].whereType<String>().where((s) => s.trim().isNotEmpty).join(': '),
    date: CalendarDate.normalize(n.postedAt),
    accountId: accountId,
    payeeName: parse.merchant,
    formType: parse.isInflow
        ? TransactionFormType.income
        : TransactionFormType.expense,
  );
}

/// A line of error text at the top of a card notification screen.
class CaptureErrorBanner extends StatelessWidget {
  const CaptureErrorBanner({super.key, required this.text, this.onDismiss});

  final String text;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      key: const Key('cardNotifications.errorBanner'),
      color: scheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 8, 12),
        child: Row(
          children: [
            Expanded(
              child: Text(
                text,
                style: TextStyle(color: scheme.onErrorContainer),
              ),
            ),
            if (onDismiss != null)
              IconButton(
                icon: const Icon(Icons.close),
                color: scheme.onErrorContainer,
                tooltip: AppLocalizations.of(context)!.ok,
                onPressed: onDismiss,
              ),
          ],
        ),
      ),
    );
  }
}

/// Settings > Card notifications (Android only): notification access, the
/// watched apps with their accounts, captured notifications that could
/// not be booked, and the way to the log of the last 30 days.
class CardNotificationsScreen extends ConsumerStatefulWidget {
  const CardNotificationsScreen({super.key});

  @override
  ConsumerState<CardNotificationsScreen> createState() =>
      _CardNotificationsScreenState();
}

class _CardNotificationsScreenState
    extends ConsumerState<CardNotificationsScreen>
    with WidgetsBindingObserver {
  bool _loading = true;
  bool _accessGranted = false;
  bool _listenerConnected = true;
  DateTime? _storageReset;
  String? _error;
  List<CaptureSource> _sources = const [];
  List<HeldCapture> _held = const [];

  /// Logged payments held as duplicates / whose booking failed (the log
  /// has the details).
  int _duplicates = 0;
  int _failed = 0;
  StreamSubscription<void>? _capturedSubscription;

  NotificationCaptureChannel get _channel =>
      ref.read(notificationCaptureChannelProvider);
  NotificationCaptureService get _service =>
      ref.read(notificationCaptureServiceProvider);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _capturedSubscription = _channel.captured.listen((_) => _reload());
    unawaited(_reload(process: true));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _capturedSubscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Back from the system's notification access screen.
    if (state == AppLifecycleState.resumed) {
      unawaited(_reload());
    }
  }

  /// Reads access, sources and held captures; with [process], books what
  /// can be booked first and reports it.
  Future<void> _reload({bool process = false}) async {
    String? error;
    var run = const CaptureRunResult();
    if (process) {
      try {
        run = await _service.processPending();
      } catch (e, stackTrace) {
        // The settings must still show; the error is shown with them.
        Logger.error('Booking captured notifications failed', e, stackTrace);
        error = NotificationCaptureService.describeError(e);
      }
    }
    try {
      final granted = await _channel.isAccessGranted();
      final connected = !granted || await _channel.isListenerConnected();
      final storageReset = await _channel.storageResetAt();
      final sources = await _channel.getSources();
      final held = await _service.held();
      final log = await _channel.log();
      if (!mounted) {
        return;
      }
      setState(() {
        _accessGranted = granted;
        _listenerConnected = connected;
        _storageReset = storageReset;
        _sources = sources;
        _held = held;
        _duplicates = log
            .where((n) => n.status == CaptureStatus.duplicate)
            .length;
        _failed = log.where((n) => n.status == CaptureStatus.failed).length;
      });
    } catch (e, stackTrace) {
      Logger.error('Loading card notification settings failed', e, stackTrace);
      error ??= NotificationCaptureService.describeError(e);
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _error = error;
      _loading = false;
    });
    // What this screen shows need not be announced on Home again.
    final attention = ref.read(captureAttentionProvider.notifier);
    unawaited(
      attention
          .refresh(run: process ? run : null, error: error)
          .then((_) => attention.markSeen()),
    );
    final l10n = AppLocalizations.of(context)!;
    final lines = [
      if (run.added > 0) l10n.cardNotificationsAdded(run.added),
      // Held as possible duplicates: the user decides in the log.
      if (run.duplicates > 0)
        l10n.cardNotificationsDuplicatesHeld(run.duplicates),
    ];
    if (lines.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(lines.join('\n')),
          action: run.duplicates > 0
              ? SnackBarAction(
                  key: const Key('cardNotifications.reviewDuplicates'),
                  label: l10n.cardNotificationsReview,
                  onPressed: _openLog,
                )
              : null,
        ),
      );
    }
  }

  Future<void> _acknowledgeStorageReset() async {
    await _channel.acknowledgeStorageReset();
    if (mounted) {
      setState(() => _storageReset = null);
    }
  }

  Future<void> _grantAccess() async {
    final l10n = AppLocalizations.of(context)!;
    final proceed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.cardNotificationsDisclosureTitle),
        content: SingleChildScrollView(
          child: Text(l10n.cardNotificationsDisclosureBody),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.cardNotificationsContinue),
          ),
        ],
      ),
    );
    if (proceed == true) {
      await _channel.openAccessSettings();
    }
  }

  Future<void> _addApp(List<Account> accounts) async {
    final l10n = AppLocalizations.of(context)!;
    final watched = {for (final s in _sources) s.packageName};
    final candidates = (await _channel.candidateApps())
        .where((a) => !watched.contains(a.packageName))
        .toList();
    if (!mounted) {
      return;
    }
    final app = await showModalBottomSheet<CandidateApp>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.75,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 4),
                child: Text(
                  l10n.cardNotificationsPickAppTitle,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                child: Text(
                  candidates.isEmpty
                      ? l10n.cardNotificationsNoCandidates
                      : l10n.cardNotificationsPickAppHint,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final candidate in candidates)
                      ListTile(
                        leading: const Icon(Icons.apps),
                        title: Text(candidate.label),
                        subtitle: Text(switch (candidate.origin) {
                          CandidateAppOrigin.active =>
                            l10n.cardNotificationsOriginActive,
                          CandidateAppOrigin.recent =>
                            l10n.cardNotificationsOriginRecent,
                          CandidateAppOrigin.known =>
                            l10n.cardNotificationsOriginKnown,
                        }),
                        onTap: () => Navigator.pop(context, candidate),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (app == null || !mounted) {
      return;
    }
    final accountId = await _pickAccount(app.label, accounts);
    await _channel.setSources([
      ..._sources,
      CaptureSource(
        packageName: app.packageName,
        label: app.label,
        accountId: accountId,
      ),
    ]);
    // Payments that came before the app was watched are offered, not
    // booked: the user may have entered them already.
    final found = await _service.captureShowing(app.packageName);
    await _reload(process: true);
    if (found > 0 && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(
              context,
            )!.cardNotificationsShowingFound(found, app.label),
          ),
          action: SnackBarAction(
            label: AppLocalizations.of(context)!.cardNotificationsReview,
            onPressed: () => _openLog(app.packageName),
          ),
        ),
      );
    }
  }

  Future<void> _openLog([String? packageName]) async {
    await context.pushNamed('card-notification-log', extra: packageName);
    await _reload();
  }

  /// Asks for the account payments of [appLabel] are booked to.
  Future<String?> _pickAccount(String appLabel, List<Account> accounts) async {
    final l10n = AppLocalizations.of(context)!;
    final open = accounts.where((a) => !a.isClosed && !a.isPartners).toList();
    return showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(l10n.cardNotificationsPickAccountTitle(appLabel)),
        children: [
          if (open.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Text(l10n.cardNotificationsNoAccounts),
            ),
          for (final account in open)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, account.id),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(account.name),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _changeAccount(
    CaptureSource source,
    List<Account> accounts,
  ) async {
    final accountId = await _pickAccount(source.label, accounts);
    if (accountId == null) {
      return;
    }
    await _channel.setSources([
      for (final s in _sources)
        s.packageName == source.packageName
            ? s.copyWith(accountId: accountId)
            : s,
    ]);
    await _reload(process: true);
  }

  Future<void> _removeSource(CaptureSource source) async {
    await _service.removeSource(source.packageName);
    await _reload();
  }

  /// Opens the transaction form with what was read; the capture is marked
  /// added once the transaction is saved.
  Future<void> _addManually(HeldCapture held) async {
    final source = _sources
        .where((s) => s.packageName == held.notification.packageName)
        .firstOrNull;
    final saved = await context.pushNamed<bool>(
      'add-transaction',
      extra: captureDraft(
        ref,
        held.notification,
        held.parse,
        source?.accountId,
      ),
    );
    if (saved == true) {
      await _service.markAdded(held.notification.id);
      await _reload();
    }
  }

  Future<void> _dismiss(HeldCapture held) async {
    await _service.dismiss([held.notification.id]);
    await _reload();
  }

  /// Answers whether [held] is the final amount of the authorisation
  /// booked earlier.
  Future<void> _resolveAuthorisation(
    HeldCapture held, {
    required bool replace,
  }) async {
    try {
      await _service.resolveAuthorisation(
        held.notification.id,
        replace: replace,
      );
    } catch (e, stackTrace) {
      Logger.error('Booking a captured notification failed', e, stackTrace);
    }
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final accounts = ref.watch(accountsProvider).value ?? const <Account>[];
    final accountNames = {for (final a in accounts) a.id: a};
    final formatter = ref.watch(appFormatterProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.cardNotifications)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                if (_error != null)
                  CaptureErrorBanner(
                    text: l10n.cardNotificationsProcessError(_error!),
                  ),
                if (_storageReset != null)
                  CaptureErrorBanner(
                    text: l10n.cardNotificationsStorageReset(
                      formatter.formatDate(_storageReset!),
                    ),
                    onDismiss: _acknowledgeStorageReset,
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
                  child: Text(l10n.cardNotificationsIntro),
                ),
                SettingsSection(
                  title: l10n.cardNotificationsAccessTitle,
                  children: [
                    ListTile(
                      key: const Key('cardNotifications.access'),
                      leading: Icon(
                        _accessGranted
                            ? Icons.check_circle
                            : Icons.notifications_off,
                        color: _accessGranted ? scheme.primary : scheme.error,
                      ),
                      title: Text(
                        _accessGranted
                            ? l10n.cardNotificationsAccessGranted
                            : l10n.cardNotificationsAccessMissing,
                      ),
                      trailing: _accessGranted
                          ? null
                          : FilledButton(
                              onPressed: _grantAccess,
                              child: Text(l10n.cardNotificationsGrantAccess),
                            ),
                    ),
                    if (_accessGranted && !_listenerConnected)
                      ListTile(
                        key: const Key('cardNotifications.disconnected'),
                        leading: Icon(Icons.link_off, color: scheme.error),
                        title: Text(
                          l10n.cardNotificationsListenerDisconnected,
                          style: TextStyle(color: scheme.error),
                        ),
                      ),
                    if (_accessGranted)
                      ListTile(
                        leading: const Icon(Icons.settings),
                        title: Text(l10n.cardNotificationsManageAccess),
                        trailing: const Icon(Icons.open_in_new),
                        onTap: _channel.openAccessSettings,
                      ),
                  ],
                ),
                SettingsSection(
                  title: l10n.cardNotificationsAppsTitle,
                  children: [
                    if (_sources.isEmpty)
                      ListTile(title: Text(l10n.cardNotificationsNoApps)),
                    for (final source in _sources)
                      ListTile(
                        leading: const Icon(Icons.credit_card),
                        title: Text(source.label),
                        subtitle: Text(
                          accountNames[source.accountId]?.name ??
                              l10n.cardNotificationsAccountMissing,
                          style: accountNames[source.accountId] == null
                              ? TextStyle(color: scheme.error)
                              : null,
                        ),
                        onTap: () => _changeAccount(source, accounts),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline),
                          tooltip: l10n.cardNotificationsRemoveApp(
                            source.label,
                          ),
                          onPressed: () => _removeSource(source),
                        ),
                      ),
                    ListTile(
                      key: const Key('cardNotifications.addApp'),
                      leading: const Icon(Icons.add),
                      title: Text(l10n.cardNotificationsAddApp),
                      onTap: () => _addApp(accounts),
                    ),
                  ],
                ),
                if (_held.isNotEmpty)
                  SettingsSection(
                    title: l10n.cardNotificationsHeldTitle,
                    children: [
                      for (final held in _held)
                        _HeldTile(
                          held: held,
                          amountText: held.parse.amount == null
                              ? null
                              : formatter.formatMoney(
                                  held.parse.signedAmount ?? held.parse.amount!,
                                  // The notification's currency when it
                                  // named one ("$" could be several).
                                  currencyCode: held.parse.currency?.length == 3
                                      ? held.parse.currency
                                      : null,
                                ),
                          reason: switch (held.reason) {
                            CaptureHoldReason.unreadable =>
                              l10n.cardNotificationsHeldUnreadable,
                            CaptureHoldReason.noAccount =>
                              l10n.cardNotificationsHeldNoAccount,
                            CaptureHoldReason.foreignCurrency =>
                              l10n.cardNotificationsHeldForeignCurrency,
                            CaptureHoldReason.unclear =>
                              l10n.cardNotificationsHeldUnclear,
                            CaptureHoldReason.severalAmounts =>
                              l10n.cardNotificationsHeldSeveralAmounts,
                            CaptureHoldReason.replacesAuthorisation =>
                              l10n.cardNotificationsHeldReplaces(
                                formatter.formatMoney(
                                  (held.replaces?.amount ?? 0).abs(),
                                  currencyCode: held.parse.currency?.length == 3
                                      ? held.parse.currency
                                      : null,
                                ),
                              ),
                          },
                          onAdd: () => _addManually(held),
                          onDismiss: () => _dismiss(held),
                          onReplace:
                              held.reason ==
                                  CaptureHoldReason.replacesAuthorisation
                              ? () => _resolveAuthorisation(held, replace: true)
                              : null,
                          onAddSeparately:
                              held.reason ==
                                  CaptureHoldReason.replacesAuthorisation
                              ? () =>
                                    _resolveAuthorisation(held, replace: false)
                              : null,
                        ),
                    ],
                  ),
                if (_sources.isNotEmpty)
                  SettingsSection(
                    title: l10n.cardNotificationsLogTitle,
                    children: [
                      // Payments that were not added; the log says which.
                      if (_duplicates > 0)
                        ListTile(
                          key: const Key('cardNotifications.duplicates'),
                          leading: Icon(
                            Icons.content_copy_outlined,
                            color: scheme.error,
                          ),
                          title: Text(
                            l10n.cardNotificationsDuplicatesHeld(_duplicates),
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: _openLog,
                        ),
                      if (_failed > 0)
                        ListTile(
                          key: const Key('cardNotifications.failed'),
                          leading: Icon(
                            Icons.error_outline,
                            color: scheme.error,
                          ),
                          title: Text(
                            l10n.cardNotificationsAttentionFailed(_failed),
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: _openLog,
                        ),
                      ListTile(
                        key: const Key('cardNotifications.log'),
                        leading: const Icon(Icons.history),
                        title: Text(l10n.cardNotificationsLogTitle),
                        subtitle: Text(l10n.cardNotificationsLogSubtitle),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: _openLog,
                      ),
                    ],
                  ),
                SettingsSection(
                  title: l10n.cardNotificationsHowItWorksTitle,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(l10n.cardNotificationsHowItWorks),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
              ],
            ),
    );
  }
}

class _HeldTile extends StatelessWidget {
  const _HeldTile({
    required this.held,
    required this.amountText,
    required this.reason,
    required this.onAdd,
    required this.onDismiss,
    this.onReplace,
    this.onAddSeparately,
  });

  final HeldCapture held;
  final String? amountText;
  final String reason;
  final VoidCallback onAdd;
  final VoidCallback onDismiss;

  /// For a payment that may be the final amount of an authorisation:
  /// change that transaction, or book this one next to it. They take the
  /// place of "Add".
  final VoidCallback? onReplace;
  final VoidCallback? onAddSeparately;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final n = held.notification;
    final heading = [n.appLabel, ?amountText, ?held.parse.merchant].join(' · ');
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(heading, style: theme.textTheme.titleSmall),
          const SizedBox(height: 2),
          Text(
            reason,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            [n.title, n.text].whereType<String>().join('\n'),
            style: theme.textTheme.bodySmall,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          Align(
            alignment: Alignment.centerRight,
            child: Wrap(
              alignment: WrapAlignment.end,
              children: [
                TextButton(
                  onPressed: onDismiss,
                  child: Text(l10n.cardNotificationsDismiss),
                ),
                if (onAddSeparately != null)
                  TextButton(
                    key: Key('cardNotifications.addSeparately.${n.id}'),
                    onPressed: onAddSeparately,
                    child: Text(l10n.cardNotificationsAddSeparately),
                  ),
                if (onReplace != null)
                  TextButton(
                    key: Key('cardNotifications.replace.${n.id}'),
                    onPressed: onReplace,
                    child: Text(l10n.cardNotificationsReplace),
                  ),
                if (onReplace == null && onAddSeparately == null)
                  TextButton(
                    onPressed: onAdd,
                    child: Text(l10n.cardNotificationsAddManually),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
