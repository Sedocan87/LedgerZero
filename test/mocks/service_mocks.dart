// Shared service mocks (see repository_mocks.dart for when to use them).
import 'package:mockito/annotations.dart';
import 'package:ledger_zero/domain/services/budgeting_service.dart';
import 'package:ledger_zero/services/sync/google_auth_service.dart';

@GenerateNiceMocks([
  MockSpec<BudgetingService>(),
  MockSpec<GoogleAuthService>(),
])
void main() {}
