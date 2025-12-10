import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:ledger_zero/core/errors/exceptions.dart';

class NetworkErrorHandler {
  static Future<void> checkConnectivity() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult.contains(ConnectivityResult.none)) {
      throw const SyncException('No internet connection', retryable: true);
    }
  }

  static SyncException handle(dynamic error) {
    if (error is SyncException) {
      return error;
    }

    // Handle specific exceptions if needed (e.g., from Dio or HTTP)
    // For now, wrap generic errors
    return SyncException(error.toString(), retryable: true);
  }
}
