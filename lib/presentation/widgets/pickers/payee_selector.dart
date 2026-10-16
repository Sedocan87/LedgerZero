import 'dart:async';

import 'package:flutter/material.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledger_zero/domain/entities/payee.dart';
import 'package:ledger_zero/presentation/providers/data_providers.dart';
import 'package:ledger_zero/services/nlp/payee_matcher.dart';
import 'package:ledger_zero/presentation/widgets/common/load_error_view.dart';

class PayeeSelector extends ConsumerStatefulWidget {
  final ValueChanged<Payee> onSelected;
  final String? initialQuery;

  const PayeeSelector({super.key, required this.onSelected, this.initialQuery});

  @override
  ConsumerState<PayeeSelector> createState() => _PayeeSelectorState();

  static void show(
    BuildContext context,
    ValueChanged<Payee> onSelected, {
    String? initialQuery,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) =>
          PayeeSelector(onSelected: onSelected, initialQuery: initialQuery),
    );
  }
}

class _PayeeSelectorState extends ConsumerState<PayeeSelector> {
  final _searchController = TextEditingController();
  Timer? _debounce;
  List<Payee> _filteredPayees = [];
  List<(Payee, double)> _fuzzySuggestions = [];
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialQuery != null) {
      _searchController.text = widget.initialQuery!;
      _onSearchChanged(widget.initialQuery!);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    // Debounce search
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      if (!mounted) {
        return;
      }

      if (query.isEmpty) {
        setState(() {
          _filteredPayees = [];
          _fuzzySuggestions = [];
          _isSearching = false;
        });
        return;
      }

      setState(() => _isSearching = true);

      final payeesAsync = ref.read(payeesProvider);
      final allPayees = payeesAsync.valueOrNull ?? [];

      // First, exact substring matches
      final exactMatches = allPayees
          .where((p) => p.name.toLowerCase().contains(query.toLowerCase()))
          .toList();

      // Then, fuzzy matches for non-exact matches
      final payeeMatcher = ref.read(payeeMatcherProvider);
      final fuzzyMatches = await payeeMatcher.getSuggestions(query, limit: 5);

      // Filter out exact matches from fuzzy results
      final exactIds = exactMatches.map((p) => p.id).toSet();
      final filteredFuzzy = fuzzyMatches
          .where((match) => !exactIds.contains(match.$1.id))
          .toList();

      if (mounted) {
        setState(() {
          _filteredPayees = exactMatches;
          _fuzzySuggestions = filteredFuzzy;
          _isSearching = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final payeesAsync = ref.watch(payeesProvider);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.9,
      builder: (context, scrollController) => Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              AppLocalizations.of(context)!.pickerSelectPayee,
              style: theme.textTheme.titleLarge,
            ),
          ),

          // Search field
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: TextField(
              controller: _searchController,
              autofocus: true,
              decoration: InputDecoration(
                hintText: AppLocalizations.of(context)!.searchPayees,
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        tooltip: AppLocalizations.of(context)!.clearSearch,
                        onPressed: () {
                          _searchController.clear();
                          _onSearchChanged('');
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: _onSearchChanged,
            ),
          ),

          const SizedBox(height: 8),

          // Results
          Expanded(
            child: _isSearching
                ? const Center(child: CircularProgressIndicator())
                : _buildResultsList(payeesAsync, scrollController),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsList(
    AsyncValue<List<Payee>> payeesAsync,
    ScrollController scrollController,
  ) {
    final query = _searchController.text;
    final theme = Theme.of(context);

    if (query.isEmpty) {
      // Show all payees sorted alphabetically
      return payeesAsync.when(
        data: (payees) {
          final sorted = List<Payee>.from(payees)
            ..sort(
              (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
            );

          return ListView.builder(
            controller: scrollController,
            itemCount: sorted.length,
            itemBuilder: (context, index) => _buildPayeeTile(sorted[index]),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) =>
            LoadErrorView(error: err, stackTrace: stack, compact: true),
      );
    }

    // Show search results with fuzzy suggestions
    return ListView(
      controller: scrollController,
      children: [
        // Exact matches section
        if (_filteredPayees.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text(
              AppLocalizations.of(context)!.payeeMatchesSection,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
          ),
          ..._filteredPayees.map(_buildPayeeTile),
        ],

        // Fuzzy suggestions section
        if (_fuzzySuggestions.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text(
              AppLocalizations.of(context)!.payeeSimilarSection,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.secondary,
              ),
            ),
          ),
          ..._fuzzySuggestions.map(
            (match) => _buildPayeeTile(
              match.$1,
              subtitle: AppLocalizations.of(
                context,
              )!.payeeSimilarity((match.$2 * 100).toInt()),
            ),
          ),
        ],

        // No results
        if (_filteredPayees.isEmpty && _fuzzySuggestions.isEmpty)
          Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              children: [
                Icon(
                  Icons.search_off,
                  size: 48,
                  color: theme.colorScheme.outline,
                ),
                const SizedBox(height: 16),
                Text(
                  AppLocalizations.of(context)!.payeeNoResults(query),
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildPayeeTile(Payee payee, {String? subtitle}) {
    return ListTile(
      title: Text(payee.name),
      subtitle: subtitle != null ? Text(subtitle) : null,
      leading: const Icon(Icons.store),
      onTap: () {
        widget.onSelected(payee);
        Navigator.pop(context);
      },
    );
  }
}
