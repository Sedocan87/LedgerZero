import 'package:mockito/annotations.dart';
import 'package:ledger_zero/domain/services/budgeting_service.dart';
import 'package:ledger_zero/services/notifications/notification_service.dart';

@GenerateMocks([
  BudgetingService,
  NotificationService,
])
void main() {}
