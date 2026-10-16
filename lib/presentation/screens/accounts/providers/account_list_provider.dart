import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledger_zero/domain/entities/account.dart';
import 'package:ledger_zero/presentation/providers/data_providers.dart';
import 'package:ledger_zero/presentation/screens/accounts/providers/account_sort_provider.dart';
import 'package:ledger_zero/presentation/screens/accounts/providers/account_filter_provider.dart';

/// The Accounts tab's list: [accountsProvider] filtered and sorted.
final accountListProvider = Provider.autoDispose<AsyncValue<List<Account>>>((
  ref,
) {
  final sortOption = ref.watch(accountSortProvider);
  final filter = ref.watch(accountFilterProvider);

  return ref.watch(accountsProvider).whenData((accounts) {
    final filtered = accounts.where((a) {
      if (!filter.showClosed && a.isClosed) {
        return false;
      }
      if (filter.searchQuery.isNotEmpty) {
        if (!a.name.toLowerCase().contains(filter.searchQuery.toLowerCase())) {
          return false;
        }
      }
      return true;
    }).toList();

    switch (sortOption) {
      case AccountSortOption.nameAsc:
        filtered.sort((a, b) => a.name.compareTo(b.name));
        break;
      case AccountSortOption.nameDesc:
        filtered.sort((a, b) => b.name.compareTo(a.name));
        break;
      case AccountSortOption.balanceAsc:
        filtered.sort((a, b) => a.balance.compareTo(b.balance));
        break;
      case AccountSortOption.balanceDesc:
        filtered.sort((a, b) => b.balance.compareTo(a.balance));
        break;
      case AccountSortOption.type:
        filtered.sort((a, b) {
          final typeCompare = a.type.index.compareTo(b.type.index);
          if (typeCompare != 0) {
            return typeCompare;
          }
          return a.name.compareTo(b.name);
        });
        break;
    }
    return filtered;
  });
});
