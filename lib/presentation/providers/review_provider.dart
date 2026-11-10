import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledger_zero/core/providers/shared_preferences_provider.dart';
import 'package:ledger_zero/services/review/review_service.dart';

/// Google Play's rating dialog on Android; nothing elsewhere (and in tests).
final reviewClientProvider = Provider<ReviewClient>(
  (ref) =>
      Platform.isAndroid ? const PlayReviewClient() : const NoReviewClient(),
);

final reviewPrompterProvider = Provider<ReviewPrompter>(
  (ref) => ReviewPrompter(
    prefs: ref.watch(sharedPreferencesProvider),
    client: ref.watch(reviewClientProvider),
  ),
);
