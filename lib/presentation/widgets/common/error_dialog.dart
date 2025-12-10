import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/core/utils/error_message_mapper.dart';
import 'package:ledger_zero/presentation/widgets/common/platform_widget.dart';

class ErrorDialog extends PlatformWidget {
  final String title;
  final String message;
  final VoidCallback? onRetry;
  final VoidCallback? onDismiss;
  final Object? error;

  const ErrorDialog({
    super.key,
    required this.title,
    required this.message,
    this.onRetry,
    this.onDismiss,
    this.error,
  });

  factory ErrorDialog.fromError(
    BuildContext context, {
    required Object error,
    VoidCallback? onRetry,
    VoidCallback? onDismiss,
  }) {
    return ErrorDialog(
      title: ErrorMessageMapper.mapType(context, error),
      message: ErrorMessageMapper.map(context, error),
      onRetry: onRetry,
      onDismiss: onDismiss,
      error: error,
    );
  }

  static Future<void> show(
    BuildContext context, {
    required Object error,
    VoidCallback? onRetry,
    VoidCallback? onDismiss,
  }) {
    return showDialog(
      context: context,
      builder: (context) => ErrorDialog.fromError(
        context,
        error: error,
        onRetry: () {
          Navigator.of(context).pop();
          onRetry?.call();
        },
        onDismiss: () {
          Navigator.of(context).pop();
          onDismiss?.call();
        },
      ),
    );
  }

  @override
  Widget buildMaterialWidget(BuildContext context) {
    return AlertDialog(
      title: Text(title),
      content: SingleChildScrollView(
        child: Text(message),
      ),
      actions: [
        if (onRetry != null)
          TextButton(
            onPressed: onRetry,
            child: Text(AppLocalizations.of(context)!.retry),
          ),
        TextButton(
          onPressed: onDismiss ?? () => Navigator.of(context).pop(),
          child: Text(onRetry != null ? AppLocalizations.of(context)!.cancel : AppLocalizations.of(context)!.ok),
        ),
      ],
    );
  }

  @override
  Widget buildCupertinoWidget(BuildContext context) {
    return CupertinoAlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        if (onRetry != null)
          CupertinoDialogAction(
            onPressed: onRetry,
            child: Text(AppLocalizations.of(context)!.retry),
          ),
        CupertinoDialogAction(
          isDefaultAction: true,
          onPressed: onDismiss ?? () => Navigator.of(context).pop(),
          child: Text(onRetry != null ? AppLocalizations.of(context)!.cancel : AppLocalizations.of(context)!.ok),
        ),
      ],
    );
  }
}
