import 'package:flutter/material.dart';
import 'package:ledger_zero/core/utils/log_level.dart';
import 'package:ledger_zero/data/models/log_entry.dart';
import 'package:ledger_zero/services/error/local_error_reporting_service.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class LogViewerScreen extends StatefulWidget {
  const LogViewerScreen({super.key});

  @override
  State<LogViewerScreen> createState() => _LogViewerScreenState();
}

class _LogViewerScreenState extends State<LogViewerScreen> {
  List<LogEntry>? _logs;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    setState(() => _isLoading = true);
    final logs = await LocalErrorReportingService().getLogs();
    setState(() {
      _logs = logs;
      _isLoading = false;
    });
  }

  Future<void> _exportLogs() async {
    try {
      final logs = await LocalErrorReportingService().getLogs();
      if (logs.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppLocalizations.of(context)!.noLogs)),
          );
        }
        return;
      }

      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/ledger_zero_logs_export.txt');

      final buffer = StringBuffer();
      for (var log in logs) {
        buffer.writeln(
          '[${log.timestamp.toIso8601String()}] ${log.level.name.toUpperCase()}: ${log.message}',
        );
        if (log.error != null) {
          buffer.writeln('Error: ${log.error}');
        }
        if (log.stackTrace != null) {
          buffer.writeln('Stack: ${log.stackTrace}');
        }
        buffer.writeln('---');
      }

      await file.writeAsString(buffer.toString());

      await SharePlus.instance.share(
        ShareParams(text: 'LedgerZero Logs', files: [XFile(file.path)]),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!.logsExportFailed(e.toString()),
            ),
          ),
        );
      }
    }
  }

  Color _getLevelColor(LogLevel level) {
    switch (level) {
      case LogLevel.debug:
        return Colors.grey;
      case LogLevel.info:
        return Colors.blue;
      case LogLevel.warning:
        return Colors.orange;
      case LogLevel.error:
        return Colors.red;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.errorLogs),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadLogs),
          IconButton(icon: const Icon(Icons.share), onPressed: _exportLogs),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _logs == null || _logs!.isEmpty
          ? Center(child: Text(l10n.noLogs))
          : ListView.builder(
              itemCount: _logs!.length,
              itemBuilder: (context, index) {
                final log = _logs![index];
                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  child: ExpansionTile(
                    leading: CircleAvatar(
                      backgroundColor: _getLevelColor(log.level),
                      radius: 10,
                    ),
                    title: Text(
                      log.message,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 14),
                    ),
                    subtitle: Text(
                      DateFormat('yyyy-MM-dd HH:mm:ss').format(log.timestamp),
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    children: [
                      if (log.error != null || log.stackTrace != null)
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (log.error != null) ...[
                                const Text(
                                  'Error:',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                SelectableText(log.error!),
                                const SizedBox(height: 8),
                              ],
                              if (log.stackTrace != null) ...[
                                const Text(
                                  'Stack Trace:',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                SelectableText(log.stackTrace!),
                              ],
                            ],
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
