import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledger_zero/presentation/providers/formatter_provider.dart';
import 'package:ledger_zero/presentation/providers/repository_providers.dart';
import 'package:ledger_zero/presentation/providers/service_providers.dart';
import 'package:ledger_zero/services/notification_capture/card_notification_parser.dart';
import 'package:ledger_zero/services/notification_capture/notification_capture_channel.dart';
import 'package:ledger_zero/services/notification_capture/notification_capture_service.dart';

/// The native card notification listener (Android only).
final notificationCaptureChannelProvider = Provider<NotificationCaptureChannel>(
  (ref) => PlatformNotificationCaptureChannel(),
);

/// Books captured card notifications when the app starts or resumes (see
/// [NotificationCaptureService]).
final notificationCaptureServiceProvider = Provider<NotificationCaptureService>(
  (ref) => NotificationCaptureService(
    channel: ref.watch(notificationCaptureChannelProvider),
    transactions: ref.watch(transactionServiceProvider),
    accounts: ref.watch(accountRepositoryProvider),
    payees: ref.watch(payeeRepositoryProvider),
    parser: CardNotificationParser(
      amountParser: ref.watch(appFormatterProvider).parser,
    ),
  ),
);
