import 'package:ledger_zero/app/bootstrap.dart';
import 'package:ledger_zero/core/config/app_config.dart';

/// Release builds (`--flavor production -t lib/main_production.dart`).
Future<void> main() => bootstrap(AppEnvironment.production);
