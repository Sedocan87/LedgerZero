import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledger_zero/domain/entities/account.dart';
import 'package:ledger_zero/domain/entities/category.dart';
import 'package:ledger_zero/presentation/providers/data_providers.dart';
import 'package:ledger_zero/presentation/providers/settings_provider.dart';

/// An account the transaction form may preselect: open, and not the
/// partner's personal account (this phone never books into it).
bool isEligibleDefaultAccount(Account account) =>
    !account.isClosed && !account.isPartners;

/// A category the transaction form may preselect: not hidden.
bool isEligibleDefaultCategory(Category category) => !category.isHidden;

/// Clears a stored default account or category that no longer qualifies
/// (deleted, closed, became the partner's; deleted or hidden), so the
/// transaction form never preselects it. Kept alive by `MyApp`.
final settingsDefaultsGuardProvider = Provider<void>((ref) {
  final settings = ref.watch(settingsProvider);
  final accounts = ref.watch(accountsProvider).valueOrNull;
  final categories = ref.watch(categoriesProvider).valueOrNull;

  final accountId = settings.defaultAccountId;
  if (accountId != null && accounts != null) {
    final account = accounts.where((a) => a.id == accountId).firstOrNull;
    if (account == null || !isEligibleDefaultAccount(account)) {
      unawaited(
        Future.microtask(
          () => ref.read(settingsProvider.notifier).setDefaultAccountId(null),
        ),
      );
    }
  }

  final categoryId = settings.defaultCategoryId;
  if (categoryId != null && categories != null) {
    final category = categories.where((c) => c.id == categoryId).firstOrNull;
    if (category == null || !isEligibleDefaultCategory(category)) {
      unawaited(
        Future.microtask(
          () => ref.read(settingsProvider.notifier).setDefaultCategoryId(null),
        ),
      );
    }
  }
});
