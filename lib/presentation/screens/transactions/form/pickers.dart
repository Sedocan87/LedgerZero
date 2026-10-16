import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledger_zero/core/utils/logger.dart';
import 'package:ledger_zero/domain/entities/account.dart';
import 'package:ledger_zero/domain/entities/category.dart';
import 'package:ledger_zero/domain/entities/payee.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/l10n/enum_labels.dart';
import 'package:ledger_zero/presentation/providers/data_providers.dart';

/// Key of the search field in every searchable picker sheet.
const pickerSearchFieldKey = Key('picker_search_field');

/// One selectable row of a searchable picker.
class PickerOption<T> {
  const PickerOption({
    required this.value,
    required this.label,
    this.subtitle,
    this.section,
  });

  final T value;
  final String label;
  final String? subtitle;

  /// Heading the option is listed under (e.g. its category group); options
  /// with the same section must be adjacent.
  final String? section;
}

/// Bottom sheet with a search field over [options]; returns the picked
/// value, or `null` when dismissed.
///
/// [options] is evaluated against the sheet's own [WidgetRef], so the list
/// stays live while the sheet is open.
Future<T?> showSearchablePicker<T>(
  BuildContext context, {
  required AsyncValue<List<PickerOption<T>>> Function(WidgetRef ref) options,
  required IconData icon,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        builder: (context, scrollController) => _SearchablePickerSheet<T>(
          options: options,
          icon: icon,
          scrollController: scrollController,
        ),
      ),
    ),
  );
}

class _SearchablePickerSheet<T> extends ConsumerStatefulWidget {
  const _SearchablePickerSheet({
    required this.options,
    required this.icon,
    required this.scrollController,
  });

  final AsyncValue<List<PickerOption<T>>> Function(WidgetRef ref) options;
  final IconData icon;
  final ScrollController scrollController;

  @override
  ConsumerState<_SearchablePickerSheet<T>> createState() =>
      _SearchablePickerSheetState<T>();
}

class _SearchablePickerSheetState<T>
    extends ConsumerState<_SearchablePickerSheet<T>> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _matches(PickerOption<T> option) {
    if (_query.isEmpty) {
      return true;
    }
    return option.label.toLowerCase().contains(_query) ||
        (option.section?.toLowerCase().contains(_query) ?? false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final optionsAsync = widget.options(ref);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: TextField(
            key: pickerSearchFieldKey,
            controller: _searchController,
            decoration: InputDecoration(
              hintText: l10n.search,
              prefixIcon: const Icon(Icons.search),
              border: const OutlineInputBorder(),
              isDense: true,
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear),
                      tooltip: l10n.clear,
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _query = '');
                      },
                    ),
            ),
            textInputAction: TextInputAction.search,
            onChanged: (value) =>
                setState(() => _query = value.trim().toLowerCase()),
          ),
        ),
        Expanded(
          child: optionsAsync.when(
            data: (all) {
              final options = all.where(_matches).toList();
              if (options.isEmpty) {
                return ListView(
                  controller: widget.scrollController,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        l10n.pickerNoMatches,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                  ],
                );
              }
              return ListView.builder(
                controller: widget.scrollController,
                itemCount: options.length,
                itemBuilder: (context, index) {
                  final option = options[index];
                  final tile = ListTile(
                    title: Text(option.label),
                    subtitle: option.subtitle == null
                        ? null
                        : Text(option.subtitle!),
                    leading: Icon(widget.icon),
                    onTap: () => Navigator.pop(context, option.value),
                  );
                  final section = option.section;
                  final startsSection =
                      section != null &&
                      (index == 0 || options[index - 1].section != section);
                  if (!startsSection) {
                    return tile;
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (index > 0) const Divider(),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        child: Text(
                          section,
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      tile,
                    ],
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, stack) {
              Logger.error('Picker options failed to load', err, stack);
              return Center(child: Text(l10n.errorOccurred));
            },
          ),
        ),
      ],
    );
  }
}

/// Searchable sheet listing the open accounts; returns the picked one.
Future<Account?> showAccountPicker(BuildContext context, {String? excludeId}) {
  final l10n = AppLocalizations.of(context)!;
  return showSearchablePicker<Account>(
    context,
    icon: Icons.account_balance,
    options: (ref) => ref
        .watch(accountsProvider)
        .whenData(
          (all) => [
            for (final account in all)
              if (!account.isClosed && account.id != excludeId)
                PickerOption(
                  value: account,
                  label: account.name,
                  subtitle: account.type.label(l10n),
                ),
          ],
        ),
  );
}

/// Searchable sheet listing the visible categories by group; returns the
/// picked one.
Future<Category?> showCategoryPicker(BuildContext context) {
  return showSearchablePicker<Category>(
    context,
    icon: Icons.label_outline,
    options: (ref) => ref
        .watch(categoryHierarchyProvider)
        .whenData(
          (hierarchy) => [
            for (final entry in hierarchy.entries)
              for (final category in entry.value)
                PickerOption(
                  value: category,
                  label: category.name,
                  section: entry.key.name,
                ),
          ],
        ),
  );
}

/// Searchable sheet listing the payees (favourites first, then by name);
/// returns the picked one.
Future<Payee?> showPayeePicker(BuildContext context) {
  return showSearchablePicker<Payee>(
    context,
    icon: Icons.person_outline,
    options: (ref) => ref.watch(payeesProvider).whenData((all) {
      final payees = [...all]
        ..sort((a, b) {
          if (a.isFavorite != b.isFavorite) {
            return a.isFavorite ? -1 : 1;
          }
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        });
      return [
        for (final payee in payees)
          PickerOption(value: payee, label: payee.name),
      ];
    }),
  );
}
