import 'dart:async';

import 'package:ledger_zero/core/time/calendar_date.dart';
import 'package:ledger_zero/core/utils/logger.dart';
import 'package:ledger_zero/domain/entities/account.dart';
import 'package:ledger_zero/domain/entities/transaction.dart';
import 'package:ledger_zero/domain/repositories/account_repository.dart';
import 'package:ledger_zero/domain/repositories/payee_repository.dart';
import 'package:ledger_zero/domain/repositories/transaction_repository.dart';
import 'package:ledger_zero/domain/services/transaction_service.dart';
import 'package:ledger_zero/services/notification_capture/card_notification_parser.dart';
import 'package:ledger_zero/services/notification_capture/notification_capture_channel.dart';

/// Why a captured notification did not become a transaction yet.
enum CaptureHoldReason {
  /// No amount could be read.
  unreadable,

  /// The app has no (open) account linked.
  noAccount,

  /// The amount is in another currency than the linked account.
  foreignCurrency,

  /// It has an amount, but nothing says a payment was made or money came
  /// in ([CaptureKind.unclear]).
  unclear,

  /// It lists several amounts that could not be told apart
  /// ([CaptureKind.several] without parts).
  severalAmounts,

  /// It may be the final amount of an authorisation booked earlier
  /// ([HeldCapture.replaces]); the user says whether it replaces that
  /// transaction ([NotificationCaptureService.resolveAuthorisation]).
  replacesAuthorisation,
}

/// A captured notification waiting for the user.
class HeldCapture {
  const HeldCapture(
    this.notification,
    this.parse,
    this.reason, {
    this.replaces,
  });

  final CapturedNotification notification;
  final CardNotificationParse parse;
  final CaptureHoldReason reason;

  /// For [CaptureHoldReason.replacesAuthorisation]: the transaction booked
  /// from the authorisation.
  final Transaction? replaces;
}

/// A notification in the capture log (see
/// [NotificationCaptureService.history]).
class LoggedCapture {
  const LoggedCapture(
    this.notification,
    this.parse, {
    this.blocker,
    this.likelyDuplicate = false,
    this.transactionDeleted = false,
  });

  final CapturedNotification notification;
  final CardNotificationParse parse;

  /// Why it cannot be added in one tap (it then opens in the transaction
  /// form); `null` when it can.
  final CaptureHoldReason? blocker;

  /// A transaction in the linked account looks like the same payment (see
  /// [NotificationCaptureService.isSamePayment]).
  final bool likelyDuplicate;

  /// It was added, but that transaction no longer exists.
  final bool transactionDeleted;

  CaptureStatus get status => notification.status;

  /// Whether [NotificationCaptureService.addAgain] can book it. Pending
  /// ones are booked (or held) by [NotificationCaptureService.processPending];
  /// an added one whose transaction still exists would only be doubled.
  bool get canAdd =>
      blocker == null &&
      status != CaptureStatus.pending &&
      !(status == CaptureStatus.added && !transactionDeleted);

  /// Whether [NotificationCaptureService.retry] runs it through the
  /// pipeline again.
  bool get canRetry => status == CaptureStatus.failed;
}

/// What one [NotificationCaptureService.processPending] run did.
class CaptureRunResult {
  const CaptureRunResult({
    this.added = 0,
    this.ignored = 0,
    this.held = 0,
    this.failed = 0,
    this.duplicates = 0,
  });

  final int added;
  final int ignored;
  final int held;

  /// Entries whose booking threw; they are marked
  /// [CaptureStatus.failed] with the error and can be retried from the log.
  final int failed;

  /// Entries not booked because a transaction that looks like the same
  /// payment already existed, and bookings taken back because the other
  /// household phone captured the same payment ([CaptureStatus.duplicate]);
  /// the user can still add them from the log ("Add anyway").
  final int duplicates;
}

/// What the user should know about card capture without opening its
/// settings (see [NotificationCaptureService.attention]).
class CaptureAttention {
  const CaptureAttention({
    this.watching = false,
    this.accessMissing = false,
    this.listenerDisconnected = false,
    this.storageResetAt,
    this.waiting = const [],
    this.failed = const [],
    this.duplicates = const [],
  });

  /// Whether any app is watched; everything else is empty when not.
  final bool watching;

  /// Notification access was revoked: nothing is captured.
  final bool accessMissing;

  /// Access is granted but Android has not bound the listener: nothing is
  /// captured.
  final bool listenerDisconnected;

  /// When the native log was started over (see
  /// [NotificationCaptureChannel.storageResetAt]).
  final DateTime? storageResetAt;

  /// Ids of the notifications waiting for the user.
  final List<String> waiting;

  /// Ids of the notifications whose booking failed.
  final List<String> failed;

  /// Ids of the notifications held as duplicates.
  final List<String> duplicates;

  /// Whether capture itself is not working or lost data.
  bool get hasProblem =>
      accessMissing || listenerDisconnected || storageResetAt != null;
}

/// Turns captured card notifications into transactions.
///
/// Each notification of a watched app is parsed with
/// [CardNotificationParser]. Only what positively is a payment (or incoming
/// money) with an amount in the currency of the app's linked account
/// becomes an **unapproved**, uncleared transaction on the day the
/// notification arrived: the payee is the merchant (existing payee by name,
/// else created), the category comes from the user's rules or the payee's
/// last category. The transaction list marks it as not approved until the
/// user approves (swipe) or edits it. Declined payments, codes, balance
/// notices, summaries and promotions are skipped; an amount that is not
/// clearly a payment, and anything else that cannot be booked, is held for
/// the user (see [held]) in the native queue.
///
/// A notification that lists several payments, one per line, is booked
/// line by line; lines an earlier notification of the app already showed
/// are not booked again.
///
/// A payment that looks like one already in the linked account (the wallet
/// app and the bank both notified, an authorisation was followed by the
/// booking, or it was entered by hand; see [isSamePayment]) is logged as
/// [CaptureStatus.duplicate] instead of booked; the user can add it anyway
/// from the log. A repeat purchase at the same merchant (the daily lunch)
/// and a second purchase of the same amount at another merchant are
/// booked.
///
/// An authorisation ("vorgemerkt", "pending") is booked and marked with a
/// memo. A release notice removes its transaction, a correction that names
/// the old amount changes it, and a later payment of another amount at the
/// same merchant is held with the question whether it replaces the
/// authorisation ([CaptureHoldReason.replacesAuthorisation]).
///
/// When both household phones capture the same payment before they sync,
/// each run takes this phone's unreviewed copy back if the other copy wins
/// (see [_reconcile]).
///
/// Every entry is handled on its own: when booking one throws, it is
/// marked [CaptureStatus.failed] with the error (and the error is written
/// to the diagnostic log) and the run goes on with the next one.
///
/// Handled notifications stay in the native log for 30 days with their
/// status, so the user can add a skipped or deleted payment again
/// ([history], [addAgain]) or retry a failed one ([retry]).
///
/// Captured transactions are not added to the undo stack.
class NotificationCaptureService {
  NotificationCaptureService({
    required this._channel,
    required this._transactions,
    required this._transactionRepository,
    required this._accounts,
    required this._payees,
    this._parser = const CardNotificationParser(),
    this._authorisationMemo,
    this._listenerGrace = const Duration(seconds: 2),
    this._now = DateTime.now,
  });

  final NotificationCaptureChannel _channel;
  final TransactionService _transactions;
  final TransactionRepository _transactionRepository;
  final AccountRepository _accounts;
  final PayeeRepository _payees;
  final CardNotificationParser _parser;

  /// Memo of a transaction booked from an authorisation that names a
  /// merchant (localised; without a merchant the notification text is the
  /// memo and says so itself).
  final String? _authorisationMemo;

  /// How long [attention] waits before it reports the listener as not
  /// connected: right after the process starts Android has not bound it
  /// yet.
  final Duration _listenerGrace;

  final DateTime Function() _now;

  /// Apps that post many notifications that are not payments (Google Play
  /// services carries Google Wallet's tap-to-pay notifications on Pixels,
  /// but also everything else): their notifications without an amount
  /// are dropped instead of waiting for the user or filling the log. The
  /// native store has the same list (`CaptureStore.NOISY_PACKAGES`).
  static const noisyPackages = {'com.google.android.gms'};

  Future<CaptureRunResult>? _running;
  bool _runAgain = false;

  /// Parses by notification id and account currency (the text of a logged
  /// notification never changes).
  final _parses = <String, CardNotificationParse>{};

  bool get isSupported => _channel.isSupported;

  /// Books every pending notification that can be booked. Concurrent calls
  /// share the running pass, which then runs once more for captures that
  /// arrived meanwhile.
  Future<CaptureRunResult> processPending() {
    final running = _running;
    if (running != null) {
      _runAgain = true;
      return running;
    }
    final run = _process().whenComplete(() {
      _running = null;
      if (_runAgain) {
        _runAgain = false;
        unawaited(processPending());
      }
    });
    _running = run;
    return run;
  }

  /// Pending notifications that could not be booked, oldest first.
  Future<List<HeldCapture>> held() async {
    if (!_channel.isSupported) {
      return const [];
    }
    final pending = await _channel.pending();
    if (pending.isEmpty) {
      return const [];
    }
    final sources = await _sourcesByPackage();
    final accounts = await _accountsById();
    final nearby = await _duplicateIndex(
      pending,
      await _channel.log(),
      sources,
      accounts,
    );
    final result = <HeldCapture>[];
    for (final n in pending) {
      final account = _accountFor(sources[n.packageName], accounts);
      final parse = _parse(n, account);
      if (_isNoise(n, parse)) {
        continue;
      }
      final reason = _holdReason(parse, account);
      if (reason != null) {
        result.add(HeldCapture(n, parse, reason));
      } else if (account != null &&
          parse.isBooking &&
          !_hasDuplicate(n, parse, account, nearby)) {
        final authorisation = await _authorisationToReplace(
          n,
          parse,
          account,
          nearby,
        );
        if (authorisation != null) {
          result.add(
            HeldCapture(
              n,
              parse,
              CaptureHoldReason.replacesAuthorisation,
              replaces: authorisation,
            ),
          );
        }
      }
    }
    return result;
  }

  /// What needs the user's attention: capture not working (access revoked,
  /// listener not connected, storage reset) and the notifications that are
  /// waiting, failed or were held as duplicates. Empty while no app is
  /// watched.
  Future<CaptureAttention> attention() async {
    if (!_channel.isSupported) {
      return const CaptureAttention();
    }
    if ((await _channel.getSources()).isEmpty) {
      return const CaptureAttention();
    }
    final granted = await _channel.isAccessGranted();
    var connected = granted && await _channel.isListenerConnected();
    if (granted && !connected && _listenerGrace > Duration.zero) {
      await Future<void>.delayed(_listenerGrace);
      connected = await _channel.isListenerConnected();
    }
    final log = await _channel.log();
    return CaptureAttention(
      watching: true,
      accessMissing: !granted,
      listenerDisconnected: granted && !connected,
      storageResetAt: await _channel.storageResetAt(),
      waiting: [for (final h in await held()) h.notification.id],
      failed: [
        for (final n in log)
          if (n.status == CaptureStatus.failed) n.id,
      ],
      duplicates: [
        for (final n in log)
          if (n.status == CaptureStatus.duplicate) n.id,
      ],
    );
  }

  /// Takes held notifications off the waiting list (the user does not
  /// want them); they stay in the log.
  Future<void> dismiss(Iterable<String> ids) =>
      _channel.setStatus(ids, CaptureStatus.dismissed);

  /// Records that the user added [id] by hand (transaction form).
  Future<void> markAdded(String id) =>
      _channel.setStatus([id], CaptureStatus.added, byUser: true);

  /// Answers a capture held with [CaptureHoldReason.replacesAuthorisation]:
  /// with [replace] the authorisation's transaction gets the new amount
  /// (and stays one transaction), otherwise the capture is booked as a
  /// payment of its own.
  Future<void> resolveAuthorisation(String id, {required bool replace}) async {
    final n = (await _channel.pending()).where((n) => n.id == id).firstOrNull;
    if (n == null) {
      return;
    }
    final sources = await _sourcesByPackage();
    final accounts = await _accountsById();
    final account = _accountFor(sources[n.packageName], accounts);
    final parse = _parse(n, account);
    if (account == null ||
        !parse.isBooking ||
        _blocker(parse, account) != null) {
      return;
    }
    if (replace) {
      final nearby = await _duplicateIndex(
        [n],
        await _channel.log(),
        sources,
        accounts,
      );
      final authorisation = await _authorisationToReplace(
        n,
        parse,
        account,
        nearby,
      );
      if (authorisation != null) {
        await _replaceAmount(authorisation, n, parse, nearby);
        return;
      }
    }
    final transaction = await _book(n, parse, account);
    await _channel.setStatus(
      [n.id],
      CaptureStatus.added,
      transactionId: transaction.id,
      byUser: true,
    );
  }

  /// Logs the notifications of [packageName] that are showing now (they
  /// came before the app was watched); returns how many.
  Future<int> captureShowing(String packageName) =>
      _channel.captureShowing(packageName);

  /// Stops watching [packageName]. Its notifications still waiting are
  /// dropped; handled ones stay in the log (see [deleteHistory]).
  Future<void> removeSource(String packageName) async {
    final sources = await _channel.getSources();
    await _channel.setSources([
      for (final s in sources)
        if (s.packageName != packageName) s,
    ]);
    final pending = await _channel.pending();
    await _channel.remove([
      for (final n in pending)
        if (n.packageName == packageName) n.id,
    ]);
  }

  /// Deletes the logged (handled) notifications [ids]; pending ones stay.
  Future<void> deleteHistory(Iterable<String> ids) async {
    final wanted = ids.toSet();
    final log = await _channel.log();
    await _channel.remove([
      for (final n in log)
        if (wanted.contains(n.id) && n.status != CaptureStatus.pending) n.id,
    ]);
  }

  /// The logged notifications posted in `[from, toExclusive)` (all when
  /// `null`), of [packageName] or of every app, newest first.
  Future<List<LoggedCapture>> history({
    DateTime? from,
    DateTime? toExclusive,
    String? packageName,
  }) async {
    if (!_channel.isSupported) {
      return const [];
    }
    final log = await _channel.log();
    final entries = [
      for (final n in log)
        if ((packageName == null || n.packageName == packageName) &&
            (from == null || !n.postedAt.isBefore(from)) &&
            (toExclusive == null || n.postedAt.isBefore(toExclusive)))
          n,
    ];
    if (entries.isEmpty) {
      return const [];
    }
    final sources = await _sourcesByPackage();
    final accounts = await _accountsById();
    final nearby = await _duplicateIndex(entries, log, sources, accounts);
    final result = <LoggedCapture>[];
    for (final n in entries.reversed) {
      final account = _accountFor(sources[n.packageName], accounts);
      final parse = _parse(n, account);
      result.add(
        LoggedCapture(
          n,
          parse,
          blocker: _blocker(parse, account),
          likelyDuplicate:
              account != null &&
              _bookable(
                parse,
              ).any((part) => _hasDuplicate(n, part, account, nearby)),
          transactionDeleted:
              n.status == CaptureStatus.added && !await _anyExists(n),
        ),
      );
    }
    return result;
  }

  /// Books the logged notifications [ids] that can be booked (see
  /// [LoggedCapture.canAdd]), also skipped ones and likely duplicates ("add
  /// anyway"), as unapproved transactions. Returns how many notifications
  /// were added.
  Future<int> addAgain(Iterable<String> ids) async {
    final wanted = ids.toSet();
    final sources = await _sourcesByPackage();
    final accounts = await _accountsById();
    var added = 0;
    for (final n in await _channel.log()) {
      if (!wanted.contains(n.id) || n.status == CaptureStatus.pending) {
        continue;
      }
      if (n.status == CaptureStatus.added && await _anyExists(n)) {
        // Its transaction still exists; adding would double it.
        continue;
      }
      final account = _accountFor(sources[n.packageName], accounts);
      final parse = _parse(n, account);
      if (_blocker(parse, account) != null) {
        continue;
      }
      final booked = <String>[];
      for (final part in _bookable(parse)) {
        booked.add((await _book(n, part, account!)).id);
      }
      await _channel.setStatus(
        [n.id],
        CaptureStatus.added,
        transactionId: booked.join(','),
        byUser: true,
      );
      added++;
    }
    return added;
  }

  /// Runs the failed notifications [ids] through the pipeline again.
  Future<CaptureRunResult> retry(Iterable<String> ids) async {
    final wanted = ids.toSet();
    final log = await _channel.log();
    await _channel.setStatus([
      for (final n in log)
        if (wanted.contains(n.id) && n.status == CaptureStatus.failed) n.id,
    ], CaptureStatus.pending);
    return processPending();
  }

  Future<CaptureRunResult> _process() async {
    if (!_channel.isSupported) {
      return const CaptureRunResult();
    }
    final pending = await _channel.pending();
    var log = await _channel.log();
    if (log.isEmpty) {
      return const CaptureRunResult();
    }
    final sources = await _sourcesByPackage();
    final accounts = await _accountsById();
    log = await _dropLoggedNoise(log, sources, accounts);
    final takenBack = await _reconcile(log, sources, accounts);
    if (pending.isEmpty) {
      return CaptureRunResult(duplicates: takenBack);
    }
    final nearby = await _duplicateIndex(pending, log, sources, accounts);
    var added = 0;
    var ignored = 0;
    var held = 0;
    var failed = 0;
    var duplicates = takenBack;
    for (final n in pending) {
      try {
        switch (await _handle(n, sources, accounts, nearby, log)) {
          case _Outcome.added:
            added++;
          case _Outcome.ignored:
            ignored++;
          case _Outcome.held:
            held++;
          case _Outcome.duplicate:
            duplicates++;
        }
      } catch (e, stackTrace) {
        // One bad entry must not stop the others, and the user must be
        // able to see what happened (log screen) and why (diagnostics).
        failed++;
        Logger.error(
          'Card notification ${n.id} from ${n.packageName} '
          '(${_breadcrumb(_parse(n))}) could not be booked',
          e,
          stackTrace,
        );
        try {
          await _channel.setStatus(
            [n.id],
            CaptureStatus.failed,
            error: describeError(e),
          );
        } catch (e2, stackTrace2) {
          Logger.error(
            'Card notification ${n.id} could not be marked as failed',
            e2,
            stackTrace2,
          );
        }
      }
    }
    if (added > 0 || ignored > 0 || failed > 0 || duplicates > 0) {
      Logger.info(
        'Card notifications: $added booked, $ignored skipped, $held held, '
        '$duplicates duplicates, $failed failed',
      );
    }
    return CaptureRunResult(
      added: added,
      ignored: ignored,
      held: held,
      failed: failed,
      duplicates: duplicates,
    );
  }

  Future<_Outcome> _handle(
    CapturedNotification n,
    Map<String, CaptureSource> sources,
    Map<String, Account> accounts,
    _DuplicateIndex nearby,
    List<CapturedNotification> log,
  ) async {
    final source = sources[n.packageName];
    final account = _accountFor(source, accounts);
    final parse = _parse(n, account);
    if (_isNoise(n, parse)) {
      // Not kept: the app posts far more than payments.
      await _channel.remove([n.id]);
      return _Outcome.ignored;
    }
    if (parse.kind == CaptureKind.ignored) {
      if (parse.isRelease && account != null) {
        await _releaseAuthorisation(n, parse, account, nearby);
      }
      await _channel.setStatus([n.id], CaptureStatus.skipped);
      return _Outcome.ignored;
    }
    if (source == null) {
      // The app is no longer watched; its captures are not wanted.
      await _channel.remove([n.id]);
      return _Outcome.ignored;
    }
    if (account == null || _holdReason(parse, account) != null) {
      return _Outcome.held;
    }
    if (parse.kind == CaptureKind.several) {
      return _handleParts(n, parse, account, nearby, log);
    }
    if (parse.replacesAmount != null) {
      // "62,31 € statt 150,00 €": the notification names what it replaces.
      final replaced = parse.isInflow
          ? parse.replacesAmount!
          : -parse.replacesAmount!;
      final authorisation = await _openAuthorisation(
        n,
        parse,
        account,
        nearby,
        amountFits: (t) => t.amount == replaced,
        needsMerchant: false,
      );
      if (authorisation != null) {
        await _replaceAmount(authorisation, n, parse, nearby);
        return _Outcome.added;
      }
    }
    if (_hasDuplicate(n, parse, account, nearby)) {
      await _channel.setStatus([n.id], CaptureStatus.duplicate);
      nearby.confirm(n, parse);
      return _Outcome.duplicate;
    }
    if (await _authorisationToReplace(n, parse, account, nearby) != null) {
      // The user says whether it is the authorisation's final amount.
      return _Outcome.held;
    }
    final transaction = await _book(n, parse, account);
    // Marked right after the save, so a crash in between can at worst
    // book this one notification twice.
    await _channel.setStatus(
      [n.id],
      CaptureStatus.added,
      transactionId: transaction.id,
    );
    // The next entry of this run may be the same payment from another app.
    await _remember(nearby, transaction, n, parse);
    return _Outcome.added;
  }

  /// Books the payments of a notification that lists several, one per
  /// line. A line that an earlier notification of the app already showed
  /// (apps add lines to a notification that is still showing) is not
  /// booked again, and neither is one that looks like a transaction that
  /// exists.
  Future<_Outcome> _handleParts(
    CapturedNotification n,
    CardNotificationParse parse,
    Account account,
    _DuplicateIndex nearby,
    List<CapturedNotification> log,
  ) async {
    final shownBefore = <String, int>{};
    for (final earlier in log) {
      final age = n.postedAt.difference(earlier.postedAt);
      if (earlier.id == n.id ||
          earlier.packageName != n.packageName ||
          age.isNegative ||
          age > shownAgainWindow) {
        continue;
      }
      final counts = <String, int>{};
      for (final line in earlier.text.split('\n')) {
        counts.update(line.trim(), (c) => c + 1, ifAbsent: () => 1);
      }
      counts.forEach((line, count) {
        if (count > (shownBefore[line] ?? 0)) {
          shownBefore[line] = count;
        }
      });
    }
    final booked = <String>[];
    for (final part in parse.parts) {
      final line = part.line?.trim();
      final left = shownBefore[line] ?? 0;
      if (line != null && left > 0) {
        shownBefore[line] = left - 1;
        continue;
      }
      if (_hasDuplicate(n, part, account, nearby)) {
        continue;
      }
      final transaction = await _book(n, part, account);
      booked.add(transaction.id);
      await _remember(nearby, transaction, n, part);
    }
    if (booked.isEmpty) {
      await _channel.setStatus([n.id], CaptureStatus.duplicate);
      return _Outcome.duplicate;
    }
    await _channel.setStatus(
      [n.id],
      CaptureStatus.added,
      transactionId: booked.join(','),
    );
    return _Outcome.added;
  }

  /// Records a transaction booked during the run for its later entries.
  Future<void> _remember(
    _DuplicateIndex nearby,
    Transaction transaction,
    CapturedNotification n,
    CardNotificationParse parse,
  ) async {
    final payeeId = transaction.payeeId;
    final payeeName = payeeId == null
        ? null
        : nearby.payeeNames[payeeId] ??
              (await _payees.getPayeeById(payeeId))?.name;
    nearby.add(
      transaction,
      _CaptureOrigin(
        n,
        parse.merchant,
        isAuthorisation: parse.isAuthorisation,
        amount: parse.signedAmount,
      ),
      payeeName: payeeName,
    );
  }

  /// Saves [parse] of [n] as an unapproved transaction.
  Future<Transaction> _book(
    CapturedNotification n,
    CardNotificationParse parse,
    Account account,
  ) async {
    final date = CalendarDate.normalize(n.postedAt);
    final amount = parse.signedAmount!;
    final merchant = parse.merchant;
    final suggested = await _transactions.suggestWithRules(
      Transaction(
        id: 'notification-capture',
        accountId: account.id,
        date: date,
        amount: amount,
        // Without a merchant the notification text tells the user what
        // the transaction was; an authorisation says that its amount may
        // still change.
        memo: merchant == null
            ? _memoFrom(n, parse)
            : parse.isAuthorisation
            ? _authorisationMemo
            : null,
      ),
      payeeName: merchant,
    );
    final payeeId =
        suggested.payeeId ?? await _transactions.resolvePayee(name: merchant);
    var categoryId = suggested.categoryId;
    if (categoryId == null && payeeId != null) {
      categoryId = (await _payees.getPayeeById(payeeId))?.autoCategoryId;
    }
    final saved = await _transactions.save(
      TransactionInput(
        accountId: account.id,
        date: date,
        amount: amount,
        payeeId: payeeId,
        categoryId: categoryId,
        memo: suggested.memo,
        approved: false,
      ),
      recordUndo: false,
    );
    return (await _transactionRepository.getTransactionById(saved.id)) ??
        Transaction(
          id: saved.id,
          accountId: account.id,
          date: date,
          amount: amount,
          approved: false,
        );
  }

  // -------------------------------------------------------------------
  // Authorisations
  // -------------------------------------------------------------------

  /// How long after an authorisation its booking, its final amount or its
  /// release is matched to it.
  static const authorisationWindow = Duration(days: 5);

  /// The transaction booked from an open authorisation of the app of [n]
  /// (same account, [amountFits], merchants match; without a merchant on
  /// one side only when [needsMerchant] is false), the latest one;
  /// `null` when there is none or the user made it a split.
  Future<Transaction?> _openAuthorisation(
    CapturedNotification n,
    CardNotificationParse parse,
    Account account,
    _DuplicateIndex nearby, {
    required bool Function(Transaction t) amountFits,
    required bool needsMerchant,
  }) async {
    Transaction? latest;
    DateTime? latestAt;
    for (final t in nearby.transactions) {
      final origin = nearby.origins[t.id];
      if (origin == null ||
          origin.entry.id == n.id ||
          origin.entry.packageName != n.packageName ||
          t.accountId != account.id ||
          t.transferAccountId != null ||
          !amountFits(t) ||
          !nearby.isOpenAuthorisation(origin, t)) {
        continue;
      }
      final age = n.postedAt.difference(origin.entry.postedAt);
      if (age.isNegative || age > authorisationWindow) {
        continue;
      }
      final merchant = parse.merchant;
      final other = origin.merchant;
      if (merchant != null && other != null
          ? !merchantsMatch(merchant, other)
          : needsMerchant) {
        continue;
      }
      if (latestAt == null || origin.entry.postedAt.isAfter(latestAt)) {
        latest = t;
        latestAt = origin.entry.postedAt;
      }
    }
    if (latest == null ||
        (await _transactionRepository.getSplitTransactions(
          latest.id,
        )).isNotEmpty) {
      return null;
    }
    return latest;
  }

  /// The open authorisation that the payment [parse] (not itself an
  /// authorisation) may be the final amount of: same app and merchant,
  /// another amount.
  Future<Transaction?> _authorisationToReplace(
    CapturedNotification n,
    CardNotificationParse parse,
    Account account,
    _DuplicateIndex nearby,
  ) async {
    final amount = parse.signedAmount;
    if (amount == null || parse.isAuthorisation) {
      return null;
    }
    return _openAuthorisation(
      n,
      parse,
      account,
      nearby,
      amountFits: (t) => t.amount != amount && t.amount.sign == amount.sign,
      needsMerchant: true,
    );
  }

  /// Gives the authorisation's transaction the amount of [parse] and logs
  /// [n] as added with it.
  Future<void> _replaceAmount(
    Transaction authorisation,
    CapturedNotification n,
    CardNotificationParse parse,
    _DuplicateIndex nearby,
  ) async {
    await _transactions.save(
      TransactionInput(
        id: authorisation.id,
        accountId: authorisation.accountId,
        date: authorisation.date,
        amount: parse.signedAmount!,
        payeeId: authorisation.payeeId,
        categoryId: authorisation.categoryId,
        // The amount is final now.
        memo: authorisation.memo == _authorisationMemo
            ? null
            : authorisation.memo,
        cleared: authorisation.cleared,
        approved: authorisation.approved,
      ),
      recordUndo: false,
    );
    await _channel.setStatus(
      [n.id],
      CaptureStatus.added,
      transactionId: authorisation.id,
    );
    nearby.remove(authorisation.id);
    final updated = await _transactionRepository.getTransactionById(
      authorisation.id,
    );
    if (updated != null) {
      await _remember(nearby, updated, n, parse);
    }
  }

  /// A release notice ("Vormerkung aufgehoben: 150,00 € bei Aral"): the
  /// transaction booked from that authorisation is removed.
  Future<void> _releaseAuthorisation(
    CapturedNotification n,
    CardNotificationParse parse,
    Account account,
    _DuplicateIndex nearby,
  ) async {
    final amount = parse.signedAmount;
    if (amount == null) {
      return;
    }
    final authorisation = await _openAuthorisation(
      n,
      parse,
      account,
      nearby,
      amountFits: (t) => t.amount == amount,
      needsMerchant: false,
    );
    if (authorisation == null) {
      return;
    }
    await _transactions.deleteMany([authorisation.id], recordUndo: false);
    nearby.remove(authorisation.id);
  }

  // -------------------------------------------------------------------
  // Duplicates
  // -------------------------------------------------------------------

  /// What the duplicate checks of [entries] need: the transactions around
  /// their days, the notification each of those was booked from (from
  /// [log]) and the payee names.
  Future<_DuplicateIndex> _duplicateIndex(
    List<CapturedNotification> entries,
    List<CapturedNotification> log,
    Map<String, CaptureSource> sources,
    Map<String, Account> accounts,
  ) async {
    final dates = entries.map((n) => CalendarDate.normalize(n.postedAt));
    final earliest = dates.reduce((a, b) => a.isBefore(b) ? a : b);
    final latest = dates.reduce((a, b) => a.isAfter(b) ? a : b);
    final transactions =
        (await _transactionRepository.getTransactionsByDateRange(
          earliest.subtract(authorisationWindow + const Duration(days: 1)),
          latest.add(const Duration(days: 2)),
          excludeSplitChildren: true,
        )).where((t) => !t.isDeleted).toList();
    final origins = <String, _CaptureOrigin>{};
    final confirmations = <(CapturedNotification, CardNotificationParse)>[];
    for (final n in log) {
      final parse = _parse(n, _accountFor(sources[n.packageName], accounts));
      if (n.status == CaptureStatus.duplicate) {
        confirmations.add((n, parse));
      }
      if (n.status != CaptureStatus.added) {
        continue;
      }
      // What a list of payments booked is known by its payees only.
      final single = parse.kind != CaptureKind.several;
      for (final id in n.transactionIds) {
        origins[id] = _CaptureOrigin(
          n,
          single ? parse.merchant : null,
          isAuthorisation: single && parse.isAuthorisation,
          amount: single ? parse.signedAmount : null,
        );
      }
    }
    return _DuplicateIndex(transactions, origins, {
      for (final p in await _payees.getAllPayees()) p.id: p.name,
    }, confirmations);
  }

  /// How far apart two notifications of one app report the same payment
  /// (a notification posted again with other words). Later ones are
  /// another purchase: the daily lunch, the second coffee.
  static const repostWindow = Duration(minutes: 5);

  /// How far apart the wallet app and the bank app notify one payment that
  /// both name alike.
  static const samePaymentWindow = Duration(hours: 24);

  /// How far apart the wallet app and the bank app notify one payment when
  /// they name its merchant differently.
  static const otherAppWindow = Duration(hours: 2);

  /// How long a notification that lists payments may repeat the lines of
  /// an earlier one of the same app.
  static const shownAgainWindow = Duration(hours: 12);

  /// Whether [account] holds a transaction that looks like the payment
  /// [parse] of [n] ([isSamePayment]); an added entry's own transactions
  /// do not count.
  bool _hasDuplicate(
    CapturedNotification n,
    CardNotificationParse parse,
    Account account,
    _DuplicateIndex nearby,
  ) {
    final amount = parse.signedAmount;
    if (amount == null) {
      return false;
    }
    final own = n.transactionIds;
    return nearby.transactions.any((t) {
      if (t.accountId != account.id ||
          t.amount != amount ||
          own.contains(t.id)) {
        return false;
      }
      final origin = nearby.origins[t.id];
      if (origin?.entry.id == n.id) {
        // Another line of the same notification.
        return false;
      }
      return isSamePayment(
        notification: n,
        merchant: parse.merchant,
        isAuthorisation: parse.isAuthorisation,
        existingDate: t.date,
        existingMerchants: [?nearby.payeeNames[t.payeeId], ?origin?.merchant],
        existingPackage: origin?.entry.packageName,
        existingPostedAt: origin?.entry.postedAt,
        existingIsOpenAuthorisation:
            origin != null &&
            nearby.isOpenAuthorisation(origin, t, except: n.id),
      );
    });
  }

  /// Whether [notification] (merchant [merchant], an authorisation when
  /// [isAuthorisation]) reports the payment of an existing transaction
  /// with the same amount in the same account: dated [existingDate], with
  /// the payee / captured merchant names [existingMerchants], and, when it
  /// was booked from a notification, that notification's app
  /// [existingPackage] and time [existingPostedAt]
  /// ([existingIsOpenAuthorisation] when it was an authorisation that no
  /// booking has confirmed yet).
  ///
  /// * Booked from a notification of the **same app**: another merchant is
  ///   another purchase. Otherwise it is the same payment only when the
  ///   two are at most [repostWindow] apart, or when the existing one is an
  ///   open authorisation and this is its booking, at most
  ///   [authorisationWindow] later. A repeat purchase at the same merchant
  ///   hours or a day later is booked.
  /// * Booked from a notification of **another app** (Google Wallet and
  ///   the bank app): at most [samePaymentWindow] apart; when both name a
  ///   merchant and the names do not match ([merchantsMatch]), at most
  ///   [otherAppWindow].
  /// * Entered otherwise (by hand, import, the other household phone):
  ///   dated the same day, and when both name a merchant the names must
  ///   match.
  static bool isSamePayment({
    required CapturedNotification notification,
    required String? merchant,
    bool isAuthorisation = false,
    required DateTime existingDate,
    required List<String> existingMerchants,
    String? existingPackage,
    DateTime? existingPostedAt,
    bool existingIsOpenAuthorisation = false,
  }) {
    final namesAgree = _namesAgree(merchant, existingMerchants);
    if (existingPostedAt == null) {
      return namesAgree &&
          CalendarDate.normalize(
            existingDate,
          ).isAtSameMomentAs(CalendarDate.normalize(notification.postedAt));
    }
    final gap = existingPostedAt.difference(notification.postedAt).abs();
    if (existingPackage != notification.packageName) {
      return gap <= (namesAgree ? samePaymentWindow : otherAppWindow);
    }
    if (!namesAgree) {
      return false;
    }
    return gap <= repostWindow ||
        (existingIsOpenAuthorisation &&
            !isAuthorisation &&
            !notification.postedAt.isBefore(existingPostedAt) &&
            gap <= authorisationWindow);
  }

  /// Whether [merchant] can be one of [others]: a name is missing on one
  /// side, or two names match ([merchantsMatch]).
  static bool _namesAgree(String? merchant, List<String> others) =>
      merchant == null ||
      others.isEmpty ||
      others.any((m) => merchantsMatch(m, merchant));

  /// How far back [_reconcile] looks.
  static const reconcileWindow = Duration(days: 3);

  /// Takes back this phone's booking of a payment that the other household
  /// phone booked too. Both phones book a shared account's notification
  /// before they sync; afterwards each sees its own transaction (in its
  /// log) and a second one it did not book, on the same day with the same
  /// amount and a matching merchant ([merchantsMatch], so the two phones
  /// may have read the merchant differently). Exactly one of the two
  /// phones gives way: the one whose copy is not approved while the other
  /// is, else the one with the greater transaction id. Its transaction is
  /// deleted and the notification logged as [CaptureStatus.duplicate], so
  /// the user is told and can add it anyway. Only an unapproved, unchanged
  /// transaction this service booked on its own is ever taken back, and
  /// only when the pair is unambiguous (one of each). Returns how many.
  Future<int> _reconcile(
    List<CapturedNotification> log,
    Map<String, CaptureSource> sources,
    Map<String, Account> accounts,
  ) async {
    final now = _now();
    final recent = [
      for (final n in log)
        if (n.status == CaptureStatus.added &&
            !n.byUser &&
            n.transactionIds.length == 1 &&
            now.difference(n.postedAt) <= reconcileWindow)
          n,
    ];
    if (recent.isEmpty) {
      return 0;
    }
    final nearby = await _duplicateIndex(recent, log, sources, accounts);
    var takenBack = 0;
    for (final n in recent) {
      try {
        final account = _accountFor(sources[n.packageName], accounts);
        final parse = _parse(n, account);
        final own = nearby.byId(n.transactionIds.single);
        if (account == null ||
            !parse.isBooking ||
            own == null ||
            own.approved ||
            own.accountId != account.id ||
            own.amount != parse.signedAmount ||
            own.transferAccountId != null) {
          continue;
        }
        final names = [?nearby.payeeNames[own.payeeId], ?parse.merchant];
        bool samePayment(Transaction t) {
          if (t.id == own.id ||
              t.accountId != own.accountId ||
              t.amount != own.amount ||
              t.transferAccountId != null ||
              !t.date.isAtSameMomentAs(own.date)) {
            return false;
          }
          final others = [
            ?nearby.payeeNames[t.payeeId],
            ?nearby.origins[t.id]?.merchant,
          ];
          return names.isEmpty ||
              others.isEmpty ||
              others.any((name) => _namesAgree(name, names));
        }

        final twins = nearby.transactions.where(samePayment).toList();
        if (twins.length != 1 || nearby.origins.containsKey(twins.single.id)) {
          continue;
        }
        final other = twins.single;
        if (!other.approved && other.id.compareTo(own.id) > 0) {
          // The other phone gives way.
          continue;
        }
        if ((await _transactionRepository.getSplitTransactions(
          own.id,
        )).isNotEmpty) {
          continue;
        }
        await _transactions.deleteMany([own.id], recordUndo: false);
        await _channel.setStatus([n.id], CaptureStatus.duplicate);
        nearby.remove(own.id);
        takenBack++;
      } catch (e, stackTrace) {
        Logger.error(
          'Card notification ${n.id}: checking for the other phone\'s '
          'booking failed',
          e,
          stackTrace,
        );
      }
    }
    return takenBack;
  }

  /// Words that do not tell merchants apart.
  static const _merchantNoise = {
    'gmbh', 'ag', 'kg', 'ohg', 'ug', 'ev', 'co', 'ltd', 'inc', 'llc', //
    'sa', 'se', 'bv', 'the', 'und', 'and', 'sagt', 'danke', 'www', 'com',
    'de', 'net', 'org', 'pos', 'ec', 'pay', 'payment', 'zahlung', 'card',
    'karte', 'filiale', 'store', 'shop', 'markt', 'market', 'center',
  };

  static final _accents = <RegExp, String>{
    RegExp('[àáâ]'): 'a',
    RegExp('[èéê]'): 'e',
    RegExp('[ìíî]'): 'i',
    RegExp('[òóô]'): 'o',
    RegExp('[ùúû]'): 'u',
  };

  static List<String> _merchantWords(String name) {
    var folded = name
        .toLowerCase()
        .replaceAll('ä', 'ae')
        .replaceAll('ö', 'oe')
        .replaceAll('ü', 'ue')
        .replaceAll('ß', 'ss');
    _accents.forEach((pattern, plain) {
      folded = folded.replaceAll(pattern, plain);
    });
    return [
      for (final w in folded.split(RegExp('[^a-z0-9]+')))
        if (w.length >= 2 &&
            !_merchantNoise.contains(w) &&
            !RegExp(r'^\d+$').hasMatch(w))
          w,
    ];
  }

  /// Whether two merchant names (payee names or what notifications called
  /// the merchant) plausibly name the same merchant: "REWE" and "REWE SAGT
  /// DANKE 4711", "Bäckerei Schmidt" and "BAECKEREI SCHMIDT", "Starbucks"
  /// and "SumUp *Starbucks". The first significant word of one must appear
  /// in the other, or one name must contain the other.
  static bool merchantsMatch(String a, String b) {
    final wordsA = _merchantWords(a);
    final wordsB = _merchantWords(b);
    if (wordsA.isEmpty || wordsB.isEmpty) {
      return a.trim().toLowerCase() == b.trim().toLowerCase();
    }
    if (wordsB.contains(wordsA.first) || wordsA.contains(wordsB.first)) {
      return true;
    }
    final compactA = wordsA.join();
    final compactB = wordsB.join();
    final (shorter, longer) = compactA.length <= compactB.length
        ? (compactA, compactB)
        : (compactB, compactA);
    return shorter.length >= 4 && longer.contains(shorter);
  }

  // -------------------------------------------------------------------
  // Parsing and holds
  // -------------------------------------------------------------------

  /// The parse of [n], reading amounts in the currency of [account] when
  /// the notification names two.
  CardNotificationParse _parse(CapturedNotification n, [Account? account]) {
    if (_parses.length > 2000) {
      _parses.clear();
    }
    return _parses['${n.id}\u0000${account?.currency}'] ??= _parser.parse(
      title: n.title,
      text: n.text,
      appLabel: n.appLabel,
      accountCurrency: account?.currency,
    );
  }

  /// The payments of [parse]: its parts when it lists several, else
  /// itself.
  static List<CardNotificationParse> _bookable(CardNotificationParse parse) =>
      parse.parts.isEmpty ? [parse] : parse.parts;

  /// A notification without an amount from a [noisyPackages] app.
  static bool _isNoise(CapturedNotification n, CardNotificationParse parse) =>
      noisyPackages.contains(n.packageName) &&
      parse.amount == null &&
      (parse.kind == CaptureKind.unreadable ||
          parse.kind == CaptureKind.ignored);

  /// Removes the skipped notifications without an amount of
  /// [noisyPackages] from the log (older versions kept them for 30 days);
  /// returns the log without them.
  Future<List<CapturedNotification>> _dropLoggedNoise(
    List<CapturedNotification> log,
    Map<String, CaptureSource> sources,
    Map<String, Account> accounts,
  ) async {
    final noise = {
      for (final n in log)
        if (n.status == CaptureStatus.skipped &&
            _isNoise(
              n,
              _parse(n, _accountFor(sources[n.packageName], accounts)),
            ))
          n.id,
    };
    if (noise.isEmpty) {
      return log;
    }
    await _channel.remove(noise);
    return [
      for (final n in log)
        if (!noise.contains(n.id)) n,
    ];
  }

  /// Why [parse] waits for the user instead of being booked to [account];
  /// `null` when it can be booked (or is skipped).
  static CaptureHoldReason? _holdReason(
    CardNotificationParse parse,
    Account? account,
  ) {
    if (parse.kind == CaptureKind.ignored) {
      return null;
    }
    return _blocker(parse, account) ??
        (parse.kind == CaptureKind.unclear ? CaptureHoldReason.unclear : null);
  }

  /// Why [parse] cannot be booked to [account] (the open account linked
  /// to its app), ignoring whether it looked like a booking.
  static CaptureHoldReason? _blocker(
    CardNotificationParse parse,
    Account? account,
  ) {
    if (parse.kind == CaptureKind.several && parse.parts.isEmpty) {
      return CaptureHoldReason.severalAmounts;
    }
    final payments = _bookable(parse);
    if (payments.any((p) => p.amount == null)) {
      return CaptureHoldReason.unreadable;
    }
    if (account == null) {
      return CaptureHoldReason.noAccount;
    }
    if (payments.any((p) => !currencyMatches(p.currency, account.currency))) {
      return CaptureHoldReason.foreignCurrency;
    }
    return null;
  }

  /// The account [source] books to, unless missing, closed or the
  /// partner's.
  static Account? _accountFor(
    CaptureSource? source,
    Map<String, Account> accounts,
  ) {
    final account = source?.accountId == null
        ? null
        : accounts[source!.accountId];
    if (account == null || account.isClosed || account.isPartners) {
      return null;
    }
    return account;
  }

  /// Whether a notification [currency] (code, symbol or `null`) can be
  /// booked to an account in [accountCurrency].
  static bool currencyMatches(String? currency, String accountCurrency) =>
      CardNotificationParser.currencyMatches(currency, accountCurrency);

  /// Whether a transaction of the added notification [n] still exists.
  Future<bool> _anyExists(CapturedNotification n) async {
    for (final id in n.transactionIds) {
      if (await _transactionRepository.getTransactionById(id) != null) {
        return true;
      }
    }
    // Added by hand in the form: the transaction is not known.
    return n.transactionIds.isEmpty;
  }

  /// What the parser made of a notification, without its text.
  static String _breadcrumb(CardNotificationParse parse) =>
      '${parse.kind.name}, amount ${parse.amount ?? '-'} '
      '${parse.currency ?? ''}, merchant ${parse.merchant == null ? 'no' : 'yes'}'
      '${parse.parts.isEmpty ? '' : ', ${parse.parts.length} parts'}'
      '${parse.ignoredPhrase == null ? '' : ', phrase "${parse.ignoredPhrase}"'}';

  /// The error class and message, short enough for the log entry.
  static String describeError(Object error) {
    final text = error.toString();
    final type = error.runtimeType.toString();
    final described = text.startsWith(type) ? text : '$type: $text';
    return described.length <= 200
        ? described
        : '${described.substring(0, 199)}…';
  }

  /// The memo of a transaction without a merchant: the line of a list of
  /// payments, else title and text.
  static String _memoFrom(CapturedNotification n, CardNotificationParse parse) {
    final text =
        (parse.line ??
                [n.title, n.text]
                    .whereType<String>()
                    .where((s) => s.trim().isNotEmpty)
                    .join(': '))
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim();
    return text.length <= 120 ? text : '${text.substring(0, 119)}…';
  }

  Future<Map<String, CaptureSource>> _sourcesByPackage() async => {
    for (final s in await _channel.getSources()) s.packageName: s,
  };

  Future<Map<String, Account>> _accountsById() async => {
    for (final a in await _accounts.getAllAccounts()) a.id: a,
  };
}

enum _Outcome { added, ignored, held, duplicate }

/// The notification a transaction was booked from.
class _CaptureOrigin {
  const _CaptureOrigin(
    this.entry,
    this.merchant, {
    required this.isAuthorisation,
    required this.amount,
  });

  final CapturedNotification entry;

  /// What the notification called the merchant; `null` when it named none
  /// or listed several payments.
  final String? merchant;

  /// Whether it announced an authorisation.
  final bool isAuthorisation;

  /// The signed amount it booked.
  final int? amount;
}

/// Input of the duplicate checks of one run (see
/// [NotificationCaptureService.isSamePayment]).
class _DuplicateIndex {
  _DuplicateIndex(
    this.transactions,
    this.origins,
    this.payeeNames,
    this._confirmations,
  );

  /// Non-deleted transactions around the notifications' days (split lines
  /// excluded).
  final List<Transaction> transactions;

  /// Transaction id -> the notification it was booked from.
  final Map<String, _CaptureOrigin> origins;

  /// Payee id -> name.
  final Map<String, String> payeeNames;

  /// Notifications held as duplicates (a booking notice confirms the
  /// authorisation before it).
  final List<(CapturedNotification, CardNotificationParse)> _confirmations;

  Transaction? byId(String id) =>
      transactions.where((t) => t.id == id).firstOrNull;

  /// Records a transaction booked during the run.
  void add(Transaction t, _CaptureOrigin origin, {String? payeeName}) {
    transactions.add(t);
    origins[t.id] = origin;
    if (payeeName != null && t.payeeId != null) {
      payeeNames[t.payeeId!] = payeeName;
    }
  }

  /// Forgets a transaction deleted or replaced during the run.
  void remove(String id) => transactions.removeWhere((t) => t.id == id);

  /// Records that [n] was held as a duplicate during the run.
  void confirm(CapturedNotification n, CardNotificationParse parse) =>
      _confirmations.add((n, parse));

  /// Whether [t], booked from [origin], is an authorisation whose amount
  /// is still the authorised one and that no later booking notice of the
  /// same app, amount and merchant has confirmed.
  ///
  /// [except] is the notification being checked: it may be that booking
  /// notice itself (the log shows it as a likely duplicate).
  bool isOpenAuthorisation(
    _CaptureOrigin origin,
    Transaction t, {
    String? except,
  }) {
    if (!origin.isAuthorisation || t.amount != origin.amount) {
      return false;
    }
    return !_confirmations.any((confirmation) {
      final (n, parse) = confirmation;
      final later = n.postedAt.difference(origin.entry.postedAt);
      final merchant = parse.merchant;
      final other = origin.merchant;
      return n.id != except &&
          n.packageName == origin.entry.packageName &&
          !parse.isAuthorisation &&
          parse.signedAmount == origin.amount &&
          !later.isNegative &&
          later <= NotificationCaptureService.authorisationWindow &&
          (merchant == null ||
              other == null ||
              NotificationCaptureService.merchantsMatch(merchant, other));
    });
  }
}
