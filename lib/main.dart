import 'package:ledger_zero/app/bootstrap.dart';
import 'package:ledger_zero/core/config/app_config.dart';

/// Default entry point (production configuration).
Future<void> main() => bootstrap(AppEnvironment.production);
