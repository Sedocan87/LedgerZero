import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:ledger_zero/core/utils/log_level.dart';
import 'package:ledger_zero/data/models/log_entry.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:synchronized/synchronized.dart';

class LocalErrorReportingService {
  static final LocalErrorReportingService _instance = LocalErrorReportingService._internal();

  factory LocalErrorReportingService() {
    return _instance;
  }

  LocalErrorReportingService._internal();

  static const String _logDirName = 'logs';
  static const String _logFileNamePrefix = 'app_log_';
  static const String _logFileExtension = '.jsonl';
  static const int _maxLogFiles = 5;
  static const int _maxFileSize = 1024 * 1024; // 1MB

  Directory? _documentsDirectory;
  final Lock _lock = Lock();

  @visibleForTesting
  void resetForTesting() {
    _documentsDirectory = null;
  }

  Future<Directory> get _directory async {
    if (_documentsDirectory != null) return _documentsDirectory!;
    final appDocDir = await getApplicationDocumentsDirectory();
    _documentsDirectory = Directory(path.join(appDocDir.path, _logDirName));
    return _documentsDirectory!;
  }

  Future<void> log(LogEntry entry) async {
    await _lock.synchronized(() async {
      try {
        final directory = await _directory;
        if (!await directory.exists()) {
          await directory.create(recursive: true);
        }

        final file = await _getCurrentLogFile(directory);

        final jsonLine = jsonEncode(entry.toJson());
        await file.writeAsString('$jsonLine\n', mode: FileMode.append);

        // Clean up old files
        await _pruneOldLogs(directory);
      } catch (e) {
        if (kDebugMode) {
          print('Failed to write log: $e');
        }
      }
    });
  }

  Future<List<LogEntry>> getLogs() async {
    return await _lock.synchronized(() async {
      List<LogEntry> logs = [];
      try {
        final directory = await _directory;
        if (!await directory.exists()) return [];

        final files = await _getLogFiles(directory);

        for (var file in files) {
          final lines = await file.readAsLines();
          for (var line in lines) {
            if (line.isNotEmpty) {
              try {
                logs.add(LogEntry.fromJson(jsonDecode(line)));
              } catch (_) {
                // Ignore malformed lines
              }
            }
          }
        }
      } catch (e) {
        if (kDebugMode) {
          print('Failed to read logs: $e');
        }
      }

      logs.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return logs;
    });
  }

  Future<File> _getCurrentLogFile(Directory directory) async {
    final files = await _getLogFiles(directory);

    if (files.isEmpty) {
      return _createNewLogFile(directory);
    }

    final lastFile = files.last;
    if (await lastFile.length() >= _maxFileSize) {
      return _createNewLogFile(directory);
    }

    return lastFile;
  }

  File _createNewLogFile(Directory directory) {
    // Generate unique filename even if called multiple times in same ms
    // We can loop until we find a free name, or use high res timer, or just random/UUID suffix.
    // Given the lock, we can ensure uniqueness by checking existence.
    // But since we sort by name, we want it to be chronological.
    // Let's use timestamp + counter if needed.
    // Or just sleep 1ms? No.
    // Let's just append a random suffix to be safe, but sorting relies on timestamp.

    var timestamp = DateTime.now().millisecondsSinceEpoch;
    var file = File(path.join(directory.path, '${_logFileNamePrefix}${timestamp}$_logFileExtension'));

    while (file.existsSync()) {
      timestamp++;
      file = File(path.join(directory.path, '${_logFileNamePrefix}${timestamp}$_logFileExtension'));
    }
    return file;
  }

  Future<List<File>> _getLogFiles(Directory directory) async {
    try {
      if (!await directory.exists()) return [];

      final entities = await directory.list().toList();
      final files = entities.whereType<File>().where((file) {
        final name = path.basename(file.path);
        return name.startsWith(_logFileNamePrefix) && name.endsWith(_logFileExtension);
      }).toList();

      files.sort((a, b) => path.basename(a.path).compareTo(path.basename(b.path)));
      return files;
    } catch (e) {
      return [];
    }
  }

  Future<void> _pruneOldLogs(Directory directory) async {
     final files = await _getLogFiles(directory);
     if (files.length > _maxLogFiles) {
       final filesToDelete = files.sublist(0, files.length - _maxLogFiles);
       for (var file in filesToDelete) {
         try {
           await file.delete();
         } catch (_) {}
       }
     }
  }
}
