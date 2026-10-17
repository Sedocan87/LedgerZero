import 'package:ledger_zero/l10n/app_localizations.dart';

/// Names of the default category groups and categories seeded into a new
/// database, in the app language. The seeded rows keep ids derived from the
/// English names (decision D7); only the display name is localised.
String Function(String englishName) defaultCategoryNames(
  AppLocalizations l10n,
) =>
    (englishName) => switch (englishName) {
      'Immediate Obligations' => l10n.seedGroupImmediate,
      'Rent/Mortgage' => l10n.seedCatRent,
      'Electric' => l10n.seedCatElectric,
      'Water' => l10n.seedCatWater,
      'Internet' => l10n.seedCatInternet,
      'Groceries' => l10n.seedCatGroceries,
      'Transportation' => l10n.seedCatTransportation,
      'True Expenses' => l10n.seedGroupTrueExpenses,
      'Medical' => l10n.seedCatMedical,
      'Auto Maintenance' => l10n.seedCatAutoMaintenance,
      'Home Maintenance' => l10n.seedCatHomeMaintenance,
      "Renter's/Home Insurance" => l10n.seedCatInsurance,
      'Software Subscriptions' => l10n.seedCatSubscriptions,
      'Debt Payments' => l10n.seedGroupDebt,
      'Student Loan' => l10n.seedCatStudentLoan,
      'Car Payment' => l10n.seedCatCarPayment,
      'Credit Card' => l10n.seedCatCreditCard,
      'Quality of Life' => l10n.seedGroupQualityOfLife,
      'Vacation' => l10n.seedCatVacation,
      'Fitness' => l10n.seedCatFitness,
      'Education' => l10n.seedCatEducation,
      'Dining Out' => l10n.seedCatDiningOut,
      'Entertainment' => l10n.seedCatEntertainment,
      'Just for Fun' => l10n.seedGroupFun,
      'Gaming' => l10n.seedCatGaming,
      'Music' => l10n.seedCatMusic,
      'Fun Money' => l10n.seedCatFunMoney,
      'Savings & Investments' => l10n.seedGroupSavings,
      'Cash Reserve' => l10n.seedCatCashReserve,
      'Stocks & ETFs' => l10n.seedCatStocks,
      'Crypto' => l10n.seedCatCrypto,
      'Bonds' => l10n.seedCatBonds,
      'Retirement' => l10n.seedCatRetirement,
      _ => englishName,
    };
