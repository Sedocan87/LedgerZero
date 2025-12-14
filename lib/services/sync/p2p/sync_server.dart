import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:ledger_zero/core/utils/logger.dart';
import 'package:ledger_zero/services/sync/local_delta_queue.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';

class SyncServer {
  final LocalDeltaQueue _deltaQueue;
  HttpServer? _server;
  int _port = 0;

  int get port => _port;

  SyncServer(this._deltaQueue);

  Future<void> start() async {
    if (_server != null) {
      return;
    }

    final router = Router();

    // GET /deltas - List all available deltas
    router.get('/deltas', (Request request) async {
      try {
        final files = await _deltaQueue.getAllDeltaFiles();
        final filenames = files.map((f) => f.uri.pathSegments.last).toList();
        return Response.ok(
          jsonEncode(filenames),
          headers: {'content-type': 'application/json'},
        );
      } catch (e, stack) {
        Logger.error('SyncServer: Error listing deltas', e, stack);
        return Response.internalServerError(body: 'Error listing deltas');
      }
    });

    // GET /deltas/<filename> - Download a delta
    router.get('/deltas/<filename>', (Request request, String filename) async {
      try {
        final file = await _deltaQueue.getFile(filename);
        if (file == null) {
          return Response.notFound('File not found');
        }
        return Response.ok(
          file.openRead(),
          headers: {
            'content-type': 'application/gzip',
            'content-disposition': 'attachment; filename="$filename"',
          },
        );
      } catch (e, stack) {
        Logger.error('SyncServer: Error serving file $filename', e, stack);
        return Response.internalServerError(body: 'Error serving file');
      }
    });

    // POST /upload - Receive a delta from a peer
    router.post('/upload', (Request request) async {
      try {
        final filename = request.url.queryParameters['filename'];
        if (filename == null) {
          return Response.badRequest(body: 'Missing filename query parameter');
        }

        Logger.info('SyncServer: Receiving upload: $filename');

        // Save to temp file first
        final tempDir = await Directory.systemTemp.createTemp('upload');
        final tempFile = File('${tempDir.path}/$filename');
        final sink = tempFile.openWrite();

        await request.read().pipe(sink);
        // sink is closed by pipe

        // Enqueue incoming
        await _deltaQueue.enqueueIncoming(tempFile, filename);

        // Cleanup
        if (await tempFile.exists()) {
          await tempFile.delete();
        }
        await tempDir.delete();

        return Response.ok('Uploaded');
      } catch (e, stack) {
        Logger.error('SyncServer: Error handling upload', e, stack);
        return Response.internalServerError(body: 'Error processing upload');
      }
    });

    final handler = const Pipeline()
        .addMiddleware(
          logRequests(
            logger: (msg, isError) {
              if (isError) {
                Logger.error('SyncServer: $msg');
              } else {
                Logger.info('SyncServer: $msg');
              }
            },
          ),
        )
        .addHandler(router.call);

    try {
      // Bind to any available port on all interfaces (0.0.0.0)
      _server = await shelf_io.serve(handler, InternetAddress.anyIPv4, 0);
      _port = _server!.port;
      Logger.info('SyncServer listening on port $_port');
    } catch (e, stack) {
      Logger.error('Failed to start SyncServer', e, stack);
      _server = null;
    }
  }

  Future<void> stop() async {
    await _server?.close();
    _server = null;
    Logger.info('SyncServer stopped');
  }
}
