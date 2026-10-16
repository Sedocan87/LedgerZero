import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/providers/backup_providers.dart';
import 'package:ledger_zero/services/error/local_error_reporting_service.dart';

/// Shows exactly the diagnostic text that "Share" sends, so the user can
/// review it first, and lets them delete it.
class DiagnosticsScreen extends ConsumerStatefulWidget {
  const DiagnosticsScreen({super.key});

  @override
  ConsumerState<DiagnosticsScreen> createState() => _DiagnosticsScreenState();
}

class _DiagnosticsScreenState extends ConsumerState<DiagnosticsScreen> {
  String? _report;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final report = await LocalErrorReportingService().buildDiagnosticReport();
    if (mounted) {
      setState(() => _report = report);
    }
  }

  Future<void> _share() async {
    final report = _report;
    if (report == null || report.isEmpty) {
      return;
    }
    final files = ref.read(exportFileServiceProvider);
    final stamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final file = await files.writeString(
      'ledgerzero_diagnostics_$stamp.txt',
      report,
    );
    await files.shareAndDelete(file);
  }

  Future<void> _delete() async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    await LocalErrorReportingService().deleteAll();
    await _load();
    messenger.showSnackBar(SnackBar(content: Text(l10n.diagnosticsDeleted)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final report = _report;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.diagnosticsTitle)),
      body: report == null
          ? const Center(child: CircularProgressIndicator())
          : report.isEmpty
          ? Center(child: Text(l10n.diagnosticsEmpty))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(l10n.diagnosticsShareExplanation),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: SelectableText(
                      report,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _delete,
                          child: Text(l10n.diagnosticsDelete),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _share,
                          child: Text(l10n.diagnosticsShare),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
