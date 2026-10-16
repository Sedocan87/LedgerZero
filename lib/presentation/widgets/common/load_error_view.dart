import 'package:flutter/material.dart';
import 'package:ledger_zero/core/utils/error_message_mapper.dart';
import 'package:ledger_zero/core/utils/logger.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/widgets/common/error_view.dart';

/// The error state of a screen or section that failed to load.
///
/// Shows a localised, friendly message (never the exception text) and logs
/// the details once through [Logger] (off in release builds).
class LoadErrorView extends StatefulWidget {
  const LoadErrorView({
    super.key,
    required this.error,
    this.stackTrace,
    this.onRetry,
    this.compact = false,
  });

  final Object error;
  final StackTrace? stackTrace;
  final VoidCallback? onRetry;

  /// A single line of text (inside cards and list sections) instead of the
  /// full-screen [ErrorView].
  final bool compact;

  @override
  State<LoadErrorView> createState() => _LoadErrorViewState();
}

class _LoadErrorViewState extends State<LoadErrorView> {
  @override
  void initState() {
    super.initState();
    _log();
  }

  @override
  void didUpdateWidget(LoadErrorView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.error, widget.error)) {
      _log();
    }
  }

  void _log() => Logger.error('Load failed', widget.error, widget.stackTrace);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final message = ErrorMessageMapper.mapType(context, widget.error);
    if (widget.compact) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Semantics(
          liveRegion: true,
          child: Text(
            message,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
      );
    }
    return ErrorView(
      title: l10n.error,
      message: message,
      onRetry: widget.onRetry,
      retryLabel: l10n.retry,
    );
  }
}
