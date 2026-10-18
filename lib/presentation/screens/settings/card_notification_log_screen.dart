import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ledger_zero/core/utils/logger.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/providers/formatter_provider.dart';
import 'package:ledger_zero/presentation/providers/notification_capture_providers.dart';
import 'package:ledger_zero/presentation/screens/settings/card_notifications_screen.dart';
import 'package:ledger_zero/services/notification_capture/notification_capture_channel.dart';
import 'package:ledger_zero/services/notification_capture/notification_capture_service.dart';

enum _Range { today, week, month, custom }

/// Settings > Card notifications > Captured notifications: the log of the
/// last 30 days, filtered by app and date, where payments that were skipped,
/// dismissed or deleted can be added again.
class CardNotificationLogScreen extends ConsumerStatefulWidget {
  const CardNotificationLogScreen({super.key, this.packageName});

  /// The app shown first; all apps when `null`.
  final String? packageName;

  @override
  ConsumerState<CardNotificationLogScreen> createState() =>
      _CardNotificationLogScreenState();
}

class _CardNotificationLogScreenState
    extends ConsumerState<CardNotificationLogScreen> {
  bool _loading = true;
  bool _busy = false;

  /// What went wrong on the last load (the list still shows what could be
  /// read).
  String? _error;
  _Range _range = _Range.month;
  DateTimeRange? _custom;
  String? _packageName;
  List<CaptureSource> _sources = const [];
  List<LoggedCapture> _entries = const [];
  final Set<String> _selected = {};

  NotificationCaptureService get _service =>
      ref.read(notificationCaptureServiceProvider);

  @override
  void initState() {
    super.initState();
    _packageName = widget.packageName;
    unawaited(_reload());
  }

  static DateTime get _today {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  /// `[from, toExclusive)` of the chosen range in local time.
  (DateTime, DateTime?) get _bounds => switch (_range) {
    _Range.today => (_today, _today.add(const Duration(days: 1))),
    _Range.week => (_today.subtract(const Duration(days: 6)), null),
    _Range.month => (_today.subtract(const Duration(days: 29)), null),
    _Range.custom => (
      _custom!.start,
      _custom!.end.add(const Duration(days: 1)),
    ),
  };

  Future<void> _reload() async {
    String? error;
    try {
      // Pending ones are booked or held first, so the log shows their
      // outcome. Its failure must not hide the log.
      await _service.processPending();
    } catch (e, stackTrace) {
      Logger.error('Booking captured notifications failed', e, stackTrace);
      error = NotificationCaptureService.describeError(e);
    }
    try {
      final sources = await ref
          .read(notificationCaptureChannelProvider)
          .getSources();
      final (from, toExclusive) = _bounds;
      final entries = await _service.history(
        from: from,
        toExclusive: toExclusive,
        packageName: _packageName,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _sources = sources;
        _entries = entries;
        _selected.retainAll({
          for (final e in entries)
            if (e.canAdd) e.notification.id,
        });
      });
    } catch (e, stackTrace) {
      Logger.error('Loading captured notifications failed', e, stackTrace);
      error ??= NotificationCaptureService.describeError(e);
    }
    if (mounted) {
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  /// Runs a failed entry through the pipeline again, or books a duplicate
  /// the user wants anyway.
  Future<void> _actOn(LoggedCapture entry) async {
    setState(() => _busy = true);
    try {
      if (entry.canRetry) {
        await _service.retry([entry.notification.id]);
      } else {
        await _service.addAgain([entry.notification.id]);
      }
    } catch (e, stackTrace) {
      Logger.error('Retrying a captured notification failed', e, stackTrace);
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
    await _reload();
  }

  /// Deletes the listed (handled) entries after confirmation.
  Future<void> _deleteListed() async {
    final l10n = AppLocalizations.of(context)!;
    final ids = [
      for (final e in _entries)
        if (e.status != CaptureStatus.pending) e.notification.id,
    ];
    if (ids.isEmpty) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(l10n.cardNotificationsLogDeleteConfirm(ids.length)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            key: const Key('cardNotificationLog.deleteConfirm'),
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    await _service.deleteHistory(ids);
    await _reload();
  }

  Future<void> _setRange(_Range range) async {
    if (range == _Range.custom) {
      final picked = await showDateRangePicker(
        context: context,
        firstDate: _today.subtract(const Duration(days: 30)),
        lastDate: _today,
        initialDateRange: _custom,
      );
      if (picked == null) {
        return;
      }
      _custom = picked;
    }
    setState(() => _range = range);
    await _reload();
  }

  /// Selects what is most likely wanted: payments not skipped and not
  /// already in the account.
  void _selectAll() {
    setState(() {
      _selected.addAll([
        for (final e in _entries)
          if (e.canAdd &&
              !e.likelyDuplicate &&
              e.status != CaptureStatus.skipped)
            e.notification.id,
      ]);
    });
  }

  Future<void> _addSelected() async {
    setState(() => _busy = true);
    try {
      final added = await _service.addAgain(_selected);
      _selected.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!.cardNotificationsAdded(added),
            ),
          ),
        );
      }
    } catch (e, stackTrace) {
      Logger.error('Adding captured notifications failed', e, stackTrace);
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
    await _reload();
  }

  /// Opens the transaction form for an entry that cannot be added in one
  /// tap (no amount, no account, other currency).
  Future<void> _addManually(LoggedCapture entry) async {
    final n = entry.notification;
    final accountId = _sources
        .where((s) => s.packageName == n.packageName)
        .firstOrNull
        ?.accountId;
    final saved = await context.pushNamed<bool>(
      'add-transaction',
      extra: captureDraft(ref, n, entry.parse, accountId),
    );
    if (saved == true) {
      await _service.markAdded(n.id);
      await _reload();
    }
  }

  String _status(AppLocalizations l10n, LoggedCapture entry) =>
      switch (entry.status) {
        CaptureStatus.pending => l10n.cardNotificationsHeldTitle,
        CaptureStatus.added =>
          entry.transactionDeleted
              ? l10n.cardNotificationsStatusAddedDeleted
              : l10n.cardNotificationsStatusAdded,
        CaptureStatus.skipped =>
          entry.parse.ignoredPhrase == null
              ? l10n.cardNotificationsStatusSkippedBalance
              : l10n.cardNotificationsStatusSkipped(entry.parse.ignoredPhrase!),
        CaptureStatus.dismissed => l10n.cardNotificationsStatusDismissed,
        CaptureStatus.found => l10n.cardNotificationsStatusFound,
        CaptureStatus.failed => l10n.cardNotificationsStatusFailed(
          entry.notification.error ?? '',
        ),
        CaptureStatus.duplicate => l10n.cardNotificationsStatusDuplicate,
      };

  String? _warning(AppLocalizations l10n, LoggedCapture entry) {
    final blocker = entry.blocker;
    if (blocker != null) {
      return switch (blocker) {
        CaptureHoldReason.unreadable => l10n.cardNotificationsHeldUnreadable,
        CaptureHoldReason.noAccount => l10n.cardNotificationsHeldNoAccount,
        CaptureHoldReason.foreignCurrency =>
          l10n.cardNotificationsHeldForeignCurrency,
      };
    }
    // The status of a duplicate says it already.
    return entry.likelyDuplicate && entry.status != CaptureStatus.duplicate
        ? l10n.cardNotificationsLikelyDuplicate
        : null;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final formatter = ref.watch(appFormatterProvider);
    final chips = {
      _Range.today: l10n.cardNotificationsLogToday,
      _Range.week: l10n.cardNotificationsLogLast7Days,
      _Range.month: l10n.cardNotificationsLogLast30Days,
      _Range.custom: _range == _Range.custom
          ? '${formatter.formatDate(_custom!.start)} – '
                '${formatter.formatDate(_custom!.end)}'
          : l10n.cardNotificationsLogPickDates,
    };

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.cardNotificationsLogTitle),
        actions: [
          if (_entries.any((e) => e.status != CaptureStatus.pending))
            IconButton(
              key: const Key('cardNotificationLog.delete'),
              icon: const Icon(Icons.delete_outline),
              tooltip: l10n.cardNotificationsLogDelete,
              onPressed: _busy ? null : _deleteListed,
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.only(bottom: 16),
              children: [
                if (_error != null)
                  CaptureErrorBanner(
                    text: l10n.cardNotificationsProcessError(_error!),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Text(l10n.cardNotificationsLogIntro),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      for (final MapEntry(key: range, value: label)
                          in chips.entries)
                        ChoiceChip(
                          label: Text(label),
                          selected: _range == range,
                          onSelected: (_) => _setRange(range),
                        ),
                    ],
                  ),
                ),
                if (_sources.length > 1)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: DropdownButton<String?>(
                      key: const Key('cardNotificationLog.app'),
                      value: _packageName,
                      items: [
                        DropdownMenuItem(
                          child: Text(l10n.cardNotificationsLogAllApps),
                        ),
                        for (final s in _sources)
                          DropdownMenuItem(
                            value: s.packageName,
                            child: Text(s.label),
                          ),
                      ],
                      onChanged: (value) {
                        setState(() => _packageName = value);
                        unawaited(_reload());
                      },
                    ),
                  ),
                const Divider(),
                if (_entries.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      l10n.cardNotificationsLogEmpty,
                      textAlign: TextAlign.center,
                    ),
                  ),
                for (final entry in _entries)
                  _LogTile(
                    entry: entry,
                    amountText: entry.parse.signedAmount == null
                        ? null
                        : formatter.formatMoney(
                            entry.parse.signedAmount!,
                            currencyCode: entry.parse.currency?.length == 3
                                ? entry.parse.currency
                                : null,
                          ),
                    time: formatter.formatDateTime(entry.notification.postedAt),
                    status: _status(l10n, entry),
                    warning: _warning(l10n, entry),
                    selected: _selected.contains(entry.notification.id),
                    onChanged: entry.canAdd && !_busy
                        ? (value) => setState(() {
                            if (value) {
                              _selected.add(entry.notification.id);
                            } else {
                              _selected.remove(entry.notification.id);
                            }
                          })
                        : null,
                    onAddManually:
                        entry.blocker != null &&
                            entry.status != CaptureStatus.pending
                        ? () => _addManually(entry)
                        : null,
                    actionLabel: entry.canRetry
                        ? l10n.retry
                        : entry.status == CaptureStatus.duplicate &&
                              entry.canAdd
                        ? l10n.cardNotificationsAddAnyway
                        : null,
                    onAction: _busy ? null : () => _actOn(entry),
                  ),
              ],
            ),
      bottomNavigationBar: _loading || !_entries.any((e) => e.canAdd)
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Row(
                  children: [
                    TextButton(
                      onPressed: _busy ? null : _selectAll,
                      child: Text(l10n.cardNotificationsLogSelectAll),
                    ),
                    const Spacer(),
                    FilledButton(
                      key: const Key('cardNotificationLog.add'),
                      onPressed: _selected.isEmpty || _busy
                          ? null
                          : _addSelected,
                      child: Text(
                        l10n.cardNotificationsLogAddSelected(_selected.length),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

class _LogTile extends StatelessWidget {
  const _LogTile({
    required this.entry,
    required this.amountText,
    required this.time,
    required this.status,
    required this.warning,
    required this.selected,
    required this.onChanged,
    required this.onAddManually,
    this.actionLabel,
    this.onAction,
  });

  final LoggedCapture entry;
  final String? amountText;
  final String time;
  final String status;
  final String? warning;
  final bool selected;
  final ValueChanged<bool>? onChanged;
  final VoidCallback? onAddManually;

  /// "Retry" for a failed entry, "Add anyway" for a duplicate.
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final n = entry.notification;
    final heading = [
      n.appLabel,
      ?amountText,
      ?entry.parse.merchant,
    ].join(' · ');
    return InkWell(
      onTap: onChanged == null ? null : () => onChanged!(!selected),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 8, 8, 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 48,
              child: onChanged == null
                  ? null
                  : Checkbox(
                      value: selected,
                      onChanged: (value) => onChanged!(value ?? false),
                    ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(heading, style: theme.textTheme.titleSmall),
                  const SizedBox(height: 2),
                  Text(
                    '$time · $status',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color:
                          entry.status == CaptureStatus.failed ||
                              entry.status == CaptureStatus.duplicate
                          ? theme.colorScheme.error
                          : theme.colorScheme.primary,
                    ),
                  ),
                  if (warning != null)
                    Text(
                      warning!,
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
                  if (onAddManually != null)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: onAddManually,
                        child: Text(l10n.cardNotificationsAddManually),
                      ),
                    ),
                  if (actionLabel != null)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: onAction,
                        child: Text(actionLabel!),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
