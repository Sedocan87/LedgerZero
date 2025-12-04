import 'package:mockito/annotations.dart';
import 'package:ledger_zero/domain/services/budgeting_service.dart';
import 'package:ledger_zero/services/notifications/notification_service.dart';
import 'package:ledger_zero/services/sync/delta_generation_service.dart';
import 'package:ledger_zero/services/sync/google_auth_service.dart';
import 'package:ledger_zero/services/sync/google_drive_sync.dart';
import 'package:ledger_zero/services/sync/icloud_drive_service.dart';
import 'package:ledger_zero/services/sync/local_delta_queue.dart';
import 'package:shared_preferences/shared_preferences.dart';

@GenerateMocks([
  BudgetingService,
  NotificationService,
  GoogleAuthService,
  GoogleDriveService,
  ICloudDriveService,
  DeltaGenerationService,
  LocalDeltaQueue,
  SharedPreferences,
])
void main() {}
