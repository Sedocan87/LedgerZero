import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:ledger_zero/core/utils/picked_file.dart';
import 'package:ledger_zero/services/export/export_file_service.dart';
import 'package:ledger_zero/services/security/external_ui_guard.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledger_zero/domain/entities/rule.dart';
import 'package:ledger_zero/domain/entities/rules/rule_action.dart';
import 'package:ledger_zero/domain/entities/rules/rule_condition.dart';
import 'package:ledger_zero/presentation/providers/repository_providers.dart';
import 'package:ledger_zero/core/utils/logger.dart';
import 'package:ledger_zero/presentation/providers/l10n_provider.dart';

/// Outcome of a rule import.
class RuleImportResult {
  const RuleImportResult({
    required this.imported,
    required this.droppedActions,
  });

  /// Rules created or updated.
  final int imported;

  /// Actions dropped because their category, payee or account does not
  /// exist on this phone.
  final int droppedActions;
}

/// Exports the rules as JSON and imports such a file. An imported rule may
/// name ids of another phone: actions whose category, payee or account
/// does not exist here are dropped (a rule left without actions is stored
/// inactive), so later imports and catch-ups never fail on a foreign key.
class RuleImportExportService {
  final Ref ref;

  RuleImportExportService(this.ref);

  Future<void> exportRules() async {
    try {
      final rules = await ref.read(ruleRepositoryProvider).getRules();
      if (rules.isEmpty) {
        throw Exception('No rules to export');
      }

      final List<Map<String, dynamic>> jsonList = rules
          .map((r) => _ruleToJson(r))
          .toList();
      final jsonString = const JsonEncoder.withIndent('  ').convert(jsonList);

      final files = ExportFileService();
      final file = await files.writeString(
        'rules_export_${DateTime.now().millisecondsSinceEpoch}.json',
        jsonString,
      );
      await files.shareAndDelete(
        file,
        text: ref.read(appLocalizationsProvider).rulesShareText,
      );
    } catch (e) {
      Logger.error('Error exporting rules', e);
      rethrow;
    }
  }

  /// Lets the user pick a JSON file and imports it ([importRulesFromJson]).
  Future<RuleImportResult> importRules() async {
    try {
      final result = await ExternalUiGuard.run(
        () => FilePicker.pickFile(
          type: FileType.custom,
          allowedExtensions: ['json'],
        ),
      );
      if (result == null) {
        return const RuleImportResult(imported: 0, droppedActions: 0);
      }
      return await importRulesFromJson(await result.readAsText());
    } catch (e) {
      Logger.error('Error importing rules', e);
      rethrow;
    }
  }

  /// Imports the rules of [jsonString] (an export of [exportRules]): a rule
  /// with a known id is updated, others are created. Invalid entries are
  /// skipped; actions with unknown targets are dropped.
  Future<RuleImportResult> importRulesFromJson(String jsonString) async {
    final List<dynamic> jsonList = jsonDecode(jsonString);
    var imported = 0;
    var dropped = 0;
    final repository = ref.read(ruleRepositoryProvider);
    for (final item in jsonList) {
      try {
        final parsed = _ruleFromJson(item);
        final rule = await _withKnownReferences(parsed);
        dropped += parsed.actions.length - rule.actions.length;
        final existing = await repository.getRule(rule.id);
        if (existing != null) {
          await repository.updateRule(rule);
        } else {
          await repository.createRule(rule);
        }
        imported++;
      } catch (e) {
        Logger.warning('Skipping invalid rule during import: $e');
      }
    }
    return RuleImportResult(imported: imported, droppedActions: dropped);
  }

  /// [rule] without actions whose category, payee or account does not
  /// exist here; a rule left without actions is deactivated (like
  /// `replaceRuleActionReferences` does when an entity is deleted).
  Future<Rule> _withKnownReferences(Rule rule) async {
    final actions = <RuleAction>[
      for (final action in rule.actions)
        if (await _targetExists(action)) action,
    ];
    if (actions.length == rule.actions.length) {
      return rule;
    }
    return rule.copyWith(
      actions: actions,
      isActive: actions.isEmpty ? false : rule.isActive,
    );
  }

  Future<bool> _targetExists(RuleAction action) async {
    switch (action.type) {
      case RuleActionType.setCategory:
        return await ref
                .read(categoryRepositoryProvider)
                .getCategoryById(action.value) !=
            null;
      case RuleActionType.setPayee:
        return await ref
                .read(payeeRepositoryProvider)
                .getPayeeById(action.value) !=
            null;
      case RuleActionType.setAccount:
        return await ref
                .read(accountRepositoryProvider)
                .getAccountById(action.value) !=
            null;
      case RuleActionType.setMemo:
      case RuleActionType.markCleared:
      case RuleActionType.markApproved:
        return true;
    }
  }

  Map<String, dynamic> _ruleToJson(Rule rule) {
    return {
      'id': rule.id,
      'name': rule.name,
      'description': rule.description,
      'priority': rule.priority,
      'isActive': rule.isActive,
      'matchLogic': rule.matchLogic.name,
      'conditions': rule.conditions.map((c) => c.toJson()).toList(),
      'actions': rule.actions.map((a) => a.toJson()).toList(),
    };
  }

  Rule _ruleFromJson(Map<String, dynamic> json) {
    return Rule(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      priority: json['priority'] as int,
      isActive: json['isActive'] as bool,
      matchLogic: RuleMatchLogic.values.firstWhere(
        (e) => e.name == json['matchLogic'],
      ),
      conditions: (json['conditions'] as List)
          .map((e) => RuleCondition.fromJson(e))
          .toList(),
      actions: (json['actions'] as List)
          .map((e) => RuleAction.fromJson(e))
          .toList(),
    );
  }
}

final ruleImportExportServiceProvider = Provider(
  (ref) => RuleImportExportService(ref),
);
