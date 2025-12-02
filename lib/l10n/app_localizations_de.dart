// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get budget => 'Budget';

  @override
  String get home => 'Startseite';

  @override
  String get accounts => 'Konten';

  @override
  String get transactions => 'Transaktionen';

  @override
  String get toBeBudgeted => 'Zu Budgetieren';

  @override
  String get totalIncome => 'Gesamteinkommen';

  @override
  String get totalSpending => 'Gesamtausgaben';

  @override
  String get recentTransactions => 'Letzte Transaktionen';

  @override
  String get noRecentTransactions => 'Keine letzten Transaktionen';

  @override
  String get addTransaction => 'Transaktion hinzufügen';

  @override
  String get editTransaction => 'Transaktion bearbeiten';

  @override
  String get welcomeToLedgerZero => 'Willkommen bei LedgerZero';

  @override
  String get createFirstAccountMessage => 'Erstellen Sie Ihr erstes Konto.';

  @override
  String get createAccount => 'Konto erstellen';

  @override
  String get accountDetails => 'Kontodetails';

  @override
  String get loading => 'Laden...';

  @override
  String get error => 'Fehler';

  @override
  String get accountNotFound => 'Konto nicht gefunden';

  @override
  String get noTransactions => 'Keine Transaktionen';

  @override
  String get unknownPayee => 'Unbekannt';

  @override
  String get balanceTrend => 'Saldo-Trend';

  @override
  String get noTransactionsTrend => 'Kein Trend';

  @override
  String get deleteAccount => 'Konto löschen';

  @override
  String get closeAccount => 'Konto schließen';

  @override
  String get reopenAccount => 'Konto öffnen';

  @override
  String get reconcileAccount => 'Abgleichen';

  @override
  String get exportToCsv => 'Export CSV';

  @override
  String get deleteAccountConfirmation => 'Sind Sie sicher?';

  @override
  String get cancel => 'Abbrechen';

  @override
  String get delete => 'Löschen';

  @override
  String exportedTo(String path) {
    return 'Exportiert nach $path';
  }

  @override
  String currentBalance(double balance) {
    final intl.NumberFormat balanceNumberFormat = intl.NumberFormat.currency(
      locale: localeName,
    );
    final String balanceString = balanceNumberFormat.format(balance);

    return 'Saldo: $balanceString';
  }

  @override
  String get enterActualBalance => 'Saldo eingeben';

  @override
  String get discrepancyFound => 'Abweichung';

  @override
  String discrepancyMessage(String diff) {
    return 'Differenz von $diff. Anpassen?';
  }

  @override
  String get yes => 'Ja';

  @override
  String get no => 'Nein';

  @override
  String get reconcile => 'Abgleichen';

  @override
  String get accountReconciled => 'Abgeglichen!';

  @override
  String get adjustmentCreated => 'Anpassung erstellt.';

  @override
  String get amount => 'Betrag';

  @override
  String get inflow => 'Einnahme';

  @override
  String get outflow => 'Ausgabe';

  @override
  String get payee => 'Empfänger';

  @override
  String get category => 'Kategorie';

  @override
  String get account => 'Konto';

  @override
  String get memo => 'Memo';

  @override
  String get notes => 'Notizen';

  @override
  String get date => 'Datum';

  @override
  String get cleared => 'Gebucht';

  @override
  String get uncleared => 'Offen';

  @override
  String get save => 'Speichern';

  @override
  String get saveAndAddAnother => 'Speichern & Weiter';

  @override
  String get transfer => 'Umbuchung';

  @override
  String get split => 'Split';

  @override
  String get recurring => 'Wiederkehrend';

  @override
  String get invalidAmount => 'Ungültiger Betrag';

  @override
  String get selectAccount => 'Konto wählen';

  @override
  String get transactionSaved => 'Gespeichert';

  @override
  String get toAccount => 'Nach';

  @override
  String get frequency => 'Frequenz';

  @override
  String get daily => 'Täglich';

  @override
  String get weekly => 'Wöchentlich';

  @override
  String get monthly => 'Monatlich';

  @override
  String get yearly => 'Jährlich';

  @override
  String get categories => 'Kategorien';

  @override
  String get addCategory => 'Kategorie hinzufügen';

  @override
  String get manageCategories => 'Verwalten';

  @override
  String get categoryGroup => 'Gruppe';

  @override
  String get editCategory => 'Bearbeiten';

  @override
  String get deleteCategory => 'Löschen';

  @override
  String get categoryName => 'Name';

  @override
  String get createCategory => 'Erstellen';

  @override
  String get editCategoryGroup => 'Gruppe bearbeiten';

  @override
  String get deleteCategoryGroup => 'Gruppe löschen';

  @override
  String get newCategoryGroup => 'Neue Gruppe';

  @override
  String get addCategoryGroup => 'Gruppe hinzufügen';

  @override
  String get groupName => 'Gruppenname';

  @override
  String get hideCategory => 'Verstecken';

  @override
  String get showCategory => 'Anzeigen';

  @override
  String get hidden => 'Versteckt';

  @override
  String get reorderGroups => 'Gruppen sortieren';

  @override
  String get reorderCategories => 'Kategorien sortieren';

  @override
  String get color => 'Farbe';

  @override
  String get icon => 'Icon';

  @override
  String categoryHasTransactions(int count) {
    return 'Hat $count Transaktionen. Verschieben?';
  }

  @override
  String get merge => 'Zusammenführen';

  @override
  String get reassign => 'Neu zuweisen';

  @override
  String get search => 'Suche';

  @override
  String get export => 'Exportieren';

  @override
  String get import => 'Importieren';

  @override
  String get budgeted => 'Budgetiert';

  @override
  String get activity => 'Aktivität';

  @override
  String get available => 'Verfügbar';
}
