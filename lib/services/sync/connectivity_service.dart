import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

enum ConnectionStatus { online, offline }

/// Network reachability. Subscribes to the platform only while someone
/// listens to [connectionStatusStream]; [dispose] releases it.
class ConnectivityService {
  final Connectivity _connectivity;
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  late final StreamController<ConnectionStatus> _controller =
      StreamController<ConnectionStatus>.broadcast(
        onListen: _start,
        onCancel: _stop,
      );

  ConnectivityService({Connectivity? connectivity})
    : _connectivity = connectivity ?? Connectivity();

  /// Current status first, then every change.
  Stream<ConnectionStatus> get connectionStatusStream => _controller.stream;

  void _start() {
    _subscription ??= _connectivity.onConnectivityChanged.listen(
      _emit,
      onError: (Object _) {},
    );
    _connectivity.checkConnectivity().then(_emit, onError: (Object _) {});
  }

  void _stop() {
    _subscription?.cancel();
    _subscription = null;
  }

  void _emit(List<ConnectivityResult> results) {
    if (_controller.isClosed) {
      return;
    }
    _controller.add(_statusOf(results));
  }

  static ConnectionStatus _statusOf(List<ConnectivityResult> results) =>
      results.isEmpty || results.every((r) => r == ConnectivityResult.none)
      ? ConnectionStatus.offline
      : ConnectionStatus.online;

  Future<bool> get isConnected async =>
      _statusOf(await _connectivity.checkConnectivity()) ==
      ConnectionStatus.online;

  Future<bool> get isWifi async {
    final result = await _connectivity.checkConnectivity();
    return result.contains(ConnectivityResult.wifi) ||
        result.contains(ConnectivityResult.ethernet);
  }

  Future<void> dispose() async {
    _stop();
    await _controller.close();
  }
}
