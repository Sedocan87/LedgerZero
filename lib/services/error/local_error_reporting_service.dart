import 'dart:developer' as developer;
import 'dart:convert';
import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:ledger_zero/core/utils/log_level.dart';
import 'package:ledger_zero/core/utils/stack_trace_formatter.dart';
import 'package:ledger_zero/services/error/log_scrubber.dart';
import 'package:ledger_zero/data/models/log_entry.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:synchronized/synchronized.dart';

/// Writes diagnostic logs and crash reports to the app's cache directory
/// (not included in device backups on iOS or Android, and never uploaded).
///
/// Crash reports are opt-in ([crashReportsEnabled], off by default) and all
/// message text is scrubbed with [LogScrubber] before it is written.
/// SharedPreferences key of the crash-report opt-in (default off).
const String kCrashReportsEnabledKey = 'privacy_crash_reports_enabled';

class LocalErrorReportingService {
  /// Set from the user's privacy setting at start-up and when it changes.
  static bool crashReportsEnabled = false;

  static final LocalErrorReportingService _instance =
      LocalErrorReportingService._internal();

  factory LocalErrorReportingService() {
    return _instance;
  }

  LocalErrorReportingService._internal();

  static const String _logDirName = 'logs';
  static const String _crashDirName = 'crashes';
  static const String _logFileNamePrefix = 'app_log_';
  static const String _logFileExtension = '.jsonl';
  static const String _errorStatsKey = 'error_stats';
  static const int _maxLogFiles = 5;
  static const int _maxFileSize = 1024 * 1024; // 1MB

  Directory? _documentsDirectory;
  final Lock _lock = Lock();

  @visibleForTesting
  void resetForTesting() {
    _documentsDirectory = null;
  }

  Future<Directory> get _directory async {
    if (_documentsDirectory != null) {
      return _documentsDirectory!;
    }
    final cacheDir = await getApplicationCacheDirectory();
    _documentsDirectory = Directory(path.join(cacheDir.path, _logDirName));
    return _documentsDirectory!;
  }

  Future<void> log(LogEntry entry) =>
      _lock.synchronized(() => _writeLog(entry));

  /// Writes [entry]; the caller holds [_lock] (it is not reentrant).
  Future<void> _writeLog(LogEntry entry) async {
    try {
      final directory = await _directory;
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }

      final file = await _getCurrentLogFile(directory);

      final jsonLine = jsonEncode(
        LogEntry(
          timestamp: entry.timestamp,
          level: entry.level,
          message: LogScrubber.scrub(entry.message),
          error: entry.error == null ? null : LogScrubber.scrub(entry.error),
          stackTrace: entry.stackTrace,
        ).toJson(),
      );
      await file.writeAsString('$jsonLine\n', mode: FileMode.append);

      if (entry.level == LogLevel.error) {
        await _incrementErrorCount(LogScrubber.scrub(entry.message));
      }

      // Clean up old files
      await _pruneOldLogs(directory);
    } catch (e) {
      if (kDebugMode) {
        developer.log('Failed to write log', name: 'Logs', error: e);
      }
    }
  }

  Future<void> generateCrashReport(
    Object error,
    StackTrace? stack, {
    String? userComments,
  }) async {
    if (!crashReportsEnabled) {
      return;
    }
    await _lock.synchronized(() async {
      try {
        final directory = await _directory;
        final crashDir = Directory(path.join(directory.path, _crashDirName));
        if (!await crashDir.exists()) {
          await crashDir.create(recursive: true);
        }

        final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
        final file = File(
          path.join(crashDir.path, 'crash_report_$timestamp.txt'),
        );

        final buffer = StringBuffer();
        buffer.writeln('CRASH REPORT');
        buffer.writeln('============');
        buffer.writeln('Time: ${DateTime.now().toUtc().toIso8601String()}');

        // App Info
        try {
          final packageInfo = await PackageInfo.fromPlatform();
          buffer.writeln('App Name: ${packageInfo.appName}');
          buffer.writeln('Version: ${packageInfo.version}');
          buffer.writeln('Build Number: ${packageInfo.buildNumber}');
        } catch (_) {
          buffer.writeln('App Info: Unavailable');
        }

        // Device Info
        buffer.writeln('Device Info:');
        try {
          final deviceInfo = DeviceInfoPlugin();
          if (Platform.isAndroid) {
            final androidInfo = await deviceInfo.androidInfo;
            buffer.writeln('  Model: ${androidInfo.model}');
            buffer.writeln('  Brand: ${androidInfo.brand}');
            buffer.writeln('  SDK: ${androidInfo.version.sdkInt}');
          } else if (Platform.isIOS) {
            final iosInfo = await deviceInfo.iosInfo;
            // Not the device name: it usually contains the owner's name.
            buffer.writeln('  Model: ${iosInfo.model}');
            buffer.writeln('  System Name: ${iosInfo.systemName}');
            buffer.writeln('  System Version: ${iosInfo.systemVersion}');
          } else if (Platform.isLinux) {
            final linuxInfo = await deviceInfo.linuxInfo;
            buffer.writeln('  Distribution: ${linuxInfo.id}');
            buffer.writeln('  Version: ${linuxInfo.version}');
          } else if (Platform.isMacOS) {
            final macOsInfo = await deviceInfo.macOsInfo;
            buffer.writeln('  Model: ${macOsInfo.model}');
            buffer.writeln('  OS Release: ${macOsInfo.osRelease}');
          } else if (Platform.isWindows) {
            final windowsInfo = await deviceInfo.windowsInfo;
            buffer.writeln('  Build: ${windowsInfo.buildNumber}');
          }
        } catch (_) {
          buffer.writeln('  Unavailable');
        }

        if (userComments != null && userComments.isNotEmpty) {
          buffer.writeln('\nUser Comments:');
          buffer.writeln(LogScrubber.scrub(userComments));
        }

        buffer.writeln('\nError:');
        buffer.writeln(LogScrubber.scrub(error.toString()));

        if (stack != null) {
          buffer.writeln('\nStack Trace:');
          buffer.writeln(StackTraceFormatter.format(stack));
        }

        await file.writeAsString(buffer.toString());

        // Also log to standard log (we already hold the lock).
        await _writeLog(
          LogEntry(
            timestamp: DateTime.now(),
            level: LogLevel.error,
            message: 'Crash report generated',
            error: error.runtimeType.toString(),
          ),
        );

        await _incrementErrorCount('Crash');
      } catch (e) {
        if (kDebugMode) {
          developer.log(
            'Failed to generate crash report',
            name: 'Logs',
            error: e,
          );
        }
      }
    });
  }

  Future<void> _incrementErrorCount(String errorType) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final statsString = prefs.getString(_errorStatsKey) ?? '{}';
      final stats = Map<String, int>.from(jsonDecode(statsString));

      // Simplify error type to avoid explosion of keys (optional, but good practice)
      // For now, let's just use the first 50 chars of the error or a generic category if possible.
      // But for analytics, maybe we just want "Crash", "Database", "Sync".
      // Let's rely on the caller or just distinct keys.
      // For this task, keeping it simple.
      final key = errorType.length > 50
          ? errorType.substring(0, 50)
          : errorType;

      stats[key] = (stats[key] ?? 0) + 1;
      await prefs.setString(_errorStatsKey, jsonEncode(stats));
    } catch (_) {}
  }

  Future<Map<String, int>> getErrorStats() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final statsString = prefs.getString(_errorStatsKey) ?? '{}';
      return Map<String, int>.from(jsonDecode(statsString));
    } catch (_) {
      return {};
    }
  }

  /// The text a "Share diagnostic log" action shares: saved crash reports
  /// and recent log entries, already scrubbed when written. Empty when
  /// nothing is stored.
  Future<String> buildDiagnosticReport({int maxLogEntries = 200}) async {
    final buffer = StringBuffer();
    final directory = await _directory;
    final crashDir = Directory(path.join(directory.path, _crashDirName));
    if (await crashDir.exists()) {
      final reports =
          (await crashDir.list().toList()).whereType<File>().toList()
            ..sort((a, b) => a.path.compareTo(b.path));
      for (final report in reports) {
        buffer.writeln(await report.readAsString());
        buffer.writeln('---');
      }
    }
    final logs = await getLogs();
    for (final log in logs.take(maxLogEntries)) {
      buffer.writeln(
        '[${log.timestamp.toUtc().toIso8601String()}] '
        '${log.level.name.toUpperCase()}: ${LogScrubber.scrub(log.message)}',
      );
      if (log.error != null) {
        buffer.writeln('  ${LogScrubber.scrub(log.error)}');
      }
    }
    return buffer.toString().trim();
  }

  /// Deletes all logs, crash reports and error counters.
  Future<void> deleteAll() async {
    await _lock.synchronized(() async {
      final directory = await _directory;
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(_errorStatsKey);
      } catch (_) {}
    });
  }

  Future<List<LogEntry>> getLogs() async {
    return await _lock.synchronized(() async {
      final List<LogEntry> logs = [];
      try {
        final directory = await _directory;
        if (!await directory.exists()) {
          return [];
        }

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
          developer.log('Failed to read logs', name: 'Logs', error: e);
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
    var timestamp = DateTime.now().millisecondsSinceEpoch;
    var file = File(
      path.join(
        directory.path,
        '$_logFileNamePrefix$timestamp$_logFileExtension',
      ),
    );

    while (file.existsSync()) {
      timestamp++;
      file = File(
        path.join(
          directory.path,
          '$_logFileNamePrefix$timestamp$_logFileExtension',
        ),
      );
    }
    return file;
  }

  Future<List<File>> _getLogFiles(Directory directory) async {
    try {
      if (!await directory.exists()) {
        return [];
      }

      final entities = await directory.list().toList();
      final files = entities.whereType<File>().where((file) {
        final name = path.basename(file.path);
        return name.startsWith(_logFileNamePrefix) &&
            name.endsWith(_logFileExtension);
      }).toList();

      files.sort(
        (a, b) => path.basename(a.path).compareTo(path.basename(b.path)),
      );
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
