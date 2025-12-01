import 'package:flutter_riverpod/flutter_riverpod.dart';

class AccountFilter {
  final bool showClosed;
  final String searchQuery;

  const AccountFilter({this.showClosed = false, this.searchQuery = ''});

  AccountFilter copyWith({bool? showClosed, String? searchQuery}) {
    return AccountFilter(
      showClosed: showClosed ?? this.showClosed,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }
}

final accountFilterProvider = StateProvider<AccountFilter>((ref) {
  return const AccountFilter();
});
