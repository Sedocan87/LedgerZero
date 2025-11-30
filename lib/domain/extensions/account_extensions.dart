import 'package:ledger_zero/domain/entities/account.dart';

/// Extension methods for [Account] entity.
extension AccountExtensions on Account {
  /// Returns true if the account is a liability (e.g., credit card).
  bool get isLiability => type == AccountType.credit;

  /// Returns true if the account is an asset (e.g., checking, savings, cash).
  bool get isAsset => !isLiability;
}
