import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledger_zero/presentation/providers/database_provider.dart';
import 'package:ledger_zero/presentation/providers/sync_providers.dart';
import 'package:ledger_zero/data/database/database.dart';
import 'package:intl/intl.dart';

final syncLogListProvider = FutureProvider<List<SyncLogData>>((ref) async {
  final dao = ref.watch(syncLogDaoProvider);
  return dao.getLogs();
});

class SyncDebugScreen extends ConsumerWidget {
  const SyncDebugScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sync Debug & Conflicts'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(syncLogListProvider);
            },
          ),
        ],
      ),
      body: Consumer(
        builder: (context, ref, child) {
          final asyncLogs = ref.watch(syncLogListProvider);
          return asyncLogs.when(
            data: (logs) {
              if (logs.isEmpty) {
                return const Center(child: Text('No sync logs'));
              }
              return ListView.builder(
                itemCount: logs.length,
                itemBuilder: (context, index) {
                  final log = logs[index];
                  final isConflict = log.action?.contains('IGNORED') == true;
                  final dateStr = log.appliedAt != null
                      ? DateFormat('yyyy-MM-dd HH:mm:ss')
                          .format(log.appliedAt!)
                      : 'Unknown';

                  return ListTile(
                    leading: Icon(
                      isConflict ? Icons.warning : Icons.check_circle,
                      color: isConflict ? Colors.orange : Colors.green,
                    ),
                    title: Text('${log.targetTableName} - ${log.action}'),
                    subtitle: Text(dateStr),
                    trailing: Text(log.deltaFilename ?? 'Local'),
                    onTap: () {
                      showDialog(
                          context: context,
                          builder: (c) => AlertDialog(
                                title: const Text('Log Details'),
                                content: SingleChildScrollView(
                                  child: Text(
                                      'ID: ${log.id}\nRecord: ${log.recordId}\nDevice: ${log.deviceUuid}'),
                                ),
                                actions: [
                                  TextButton(
                                      onPressed: () => Navigator.pop(c),
                                      child: const Text('OK'))
                                ],
                              ));
                    },
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, stack) => Center(child: Text('Error: $err')),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.health_and_safety),
        onPressed: () async {
          final engine = ref.read(syncEngineProvider);
          final health = await engine.checkHealth();
          if (context.mounted) {
            await showDialog(
              context: context,
              builder: (c) => AlertDialog(
                title: const Text('Health Check'),
                content: Text(health.toString()),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(c),
                      child: const Text('OK'))
                ],
              ),
            );
          }
        },
      ),
    );
  }
}
