import 'package:flutter_riverpod/flutter_riverpod.dart';

enum AccountSortOption { nameAsc, nameDesc, balanceAsc, balanceDesc, type }

final accountSortProvider = StateProvider<AccountSortOption>((ref) {
  return AccountSortOption.nameAsc;
});
