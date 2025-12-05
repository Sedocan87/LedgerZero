import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledger_zero/domain/entities/rule.dart';
import 'package:ledger_zero/domain/entities/rules/rule_action.dart';
import 'package:ledger_zero/domain/entities/rules/rule_condition.dart';
import 'package:ledger_zero/presentation/providers/repository_providers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:ledger_zero/core/utils/logger.dart';

class RuleImportExportService {
  final Ref ref;

  RuleImportExportService(this.ref);

  Future<void> exportRules() async {
    try {
      final rules = await ref.read(ruleRepositoryProvider).getRules();
      if (rules.isEmpty) {
        throw Exception('No rules to export');
      }

      final List<Map<String, dynamic>> jsonList = rules.map((r) => _ruleToJson(r)).toList();
      final jsonString = const JsonEncoder.withIndent('  ').convert(jsonList);

      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/rules_export_${DateTime.now().millisecondsSinceEpoch}.json');
      await file.writeAsString(jsonString);

      await Share.shareXFiles([XFile(file.path)], text: 'LedgerZero Rules Export');
    } catch (e) {
      Logger.error('Error exporting rules', e);
      rethrow;
    }
  }

  Future<int> importRules() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        final jsonString = await file.readAsString();
        final List<dynamic> jsonList = jsonDecode(jsonString);

        int importedCount = 0;
        final repository = ref.read(ruleRepositoryProvider);

        for (final item in jsonList) {
          try {
            final rule = _ruleFromJson(item);
            // check if rule with same ID exists
            final existing = await repository.getRule(rule.id);
            if (existing != null) {
                await repository.updateRule(rule);
            } else {
                await repository.createRule(rule);
            }
            importedCount++;
          } catch (e) {
            Logger.warning('Skipping invalid rule during import: $e');
          }
        }
        return importedCount;
      }
      return 0;
    } catch (e) {
      Logger.error('Error importing rules', e);
      rethrow;
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
      matchLogic: RuleMatchLogic.values.firstWhere((e) => e.name == json['matchLogic']),
      conditions: (json['conditions'] as List).map((e) => RuleCondition.fromJson(e)).toList(),
      actions: (json['actions'] as List).map((e) => RuleAction.fromJson(e)).toList(),
    );
  }
}

final ruleImportExportServiceProvider = Provider((ref) => RuleImportExportService(ref));
