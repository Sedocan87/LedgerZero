import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledger_zero/domain/entities/account.dart';
import 'package:ledger_zero/presentation/providers/repository_providers.dart';
import 'package:ledger_zero/presentation/screens/accounts/providers/account_sort_provider.dart';
import 'package:ledger_zero/presentation/screens/accounts/providers/account_filter_provider.dart';

final accountListProvider = StreamProvider.autoDispose<List<Account>>((ref) {
  final repository = ref.watch(accountRepositoryProvider);
  final sortOption = ref.watch(accountSortProvider);
  final filter = ref.watch(accountFilterProvider);

  return repository.watchAllAccounts().map((accounts) {
    var filtered = accounts.where((a) {
      if (!filter.showClosed && a.isClosed) return false;
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
        filtered.sort((a, b) => a.currentBalance.compareTo(b.currentBalance));
        break;
      case AccountSortOption.balanceDesc:
        filtered.sort((a, b) => b.currentBalance.compareTo(a.currentBalance));
        break;
      case AccountSortOption.type:
        filtered.sort((a, b) {
          final typeCompare = a.type.index.compareTo(b.type.index);
          if (typeCompare != 0) return typeCompare;
          return a.name.compareTo(b.name);
        });
        break;
    }
    return filtered;
  });
});
