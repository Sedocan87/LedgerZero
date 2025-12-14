import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

enum ConnectionStatus { online, offline }

class ConnectivityService {
  final Connectivity _connectivity;
  final _connectionStatusController =
      StreamController<ConnectionStatus>.broadcast();

  ConnectivityService({Connectivity? connectivity})
    : _connectivity = connectivity ?? Connectivity() {
    _connectivity.onConnectivityChanged.listen(_updateConnectionStatus);
    _checkInitialStatus();
  }

  Stream<ConnectionStatus> get connectionStatusStream =>
      _connectionStatusController.stream;

  Future<void> _checkInitialStatus() async {
    final result = await _connectivity.checkConnectivity();
    _updateConnectionStatus(result);
  }

  void _updateConnectionStatus(List<ConnectivityResult> results) {
    if (results.contains(ConnectivityResult.none) && results.length == 1) {
      _connectionStatusController.add(ConnectionStatus.offline);
    } else {
      _connectionStatusController.add(ConnectionStatus.online);
    }
  }

  Future<bool> get isConnected async {
    final result = await _connectivity.checkConnectivity();
    return !result.contains(ConnectivityResult.none);
  }

  Future<bool> get isWifi async {
    final result = await _connectivity.checkConnectivity();
    return result.contains(ConnectivityResult.wifi);
  }
}
