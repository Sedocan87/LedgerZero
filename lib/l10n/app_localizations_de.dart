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
  String get reports => 'Berichte';

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

  @override
  String get budgetPreviousMonth => 'Budget Vormonat';

  @override
  String get budgetAverageSpent => 'Durchschnittl. Ausgaben';

  @override
  String get budgetZeroOut => 'Auf Null setzen';

  @override
  String get moveMoney => 'Geld verschieben';

  @override
  String get moveMoneyFrom => 'Verschieben von';

  @override
  String get moveMoneyTo => 'Verschieben nach';

  @override
  String get quickActions => 'Schnellaktionen';

  @override
  String get noCategoriesTitle => 'Keine Kategorien';

  @override
  String get noCategoriesDescription =>
      'Erstellen Sie Kategorien, um zu budgetieren.';

  @override
  String get setupBudget => 'Budget einrichten';

  @override
  String get budgetTutorialTitle => 'Willkommen beim Budgetieren';

  @override
  String get budgetTutorialDescription =>
      'Tippen Sie auf Beträge zum Budgetieren. Nutzen Sie Schnellaktionen.';

  @override
  String get gotIt => 'Verstanden';

  @override
  String get total => 'Gesamt';

  @override
  String get tbbTooltip =>
      'Einkommen abzüglich budgetiertem Betrag. Das ist der verfügbare Rest.';

  @override
  String get budgetedTooltip =>
      'Der Betrag, den Sie diesem Monat dieser Kategorie zugewiesen haben.';

  @override
  String get activityTooltip =>
      'Summe aller Transaktionen (Ausgaben) in dieser Kategorie für diesen Monat.';

  @override
  String get availableTooltip =>
      'Verfügbarer Betrag. Berechnet aus Budgetiert - Aktivität + Übertrag.';

  @override
  String get categoryTooltip => 'Name der Kategorie.';

  @override
  String assignTo(String name) {
    return 'Zuweisen an $name';
  }

  @override
  String get viewMode => 'Ansichtsmodus';

  @override
  String get budgetUpdated => 'Budget aktualisiert';

  @override
  String get undo => 'Rückgängig';

  @override
  String get variance => 'Varianz';

  @override
  String get remaining => 'Verbleibend';

  @override
  String get overspent => 'Überzogen';

  @override
  String get underfunded => 'Unterfinanziert';

  @override
  String get goalTarget => 'Zielbetrag';

  @override
  String get saveAsTemplate => 'Als Vorlage speichern';

  @override
  String get applyTemplate => 'Vorlage anwenden';

  @override
  String get templateName => 'Vorlagenname';

  @override
  String get templateSaved => 'Vorlage gespeichert';

  @override
  String get copyFromPreviousMonth => 'Vom Vormonat kopieren';

  @override
  String get resetBudget => 'Budget zurücksetzen';

  @override
  String resetBudgetConfirmation(String month) {
    return 'Sind Sie sicher, dass Sie das Budget für $month zurücksetzen möchten? Alle budgetierten Beträge werden auf Null gesetzt.';
  }

  @override
  String get reset => 'Zurücksetzen';

  @override
  String get templates => 'Vorlagen';

  @override
  String get noTemplates => 'Keine Vorlagen';

  @override
  String get createTemplateDescription =>
      'Speichern Sie Ihre aktuellen Budgetzuweisungen als wiederverwendbare Vorlage.';

  @override
  String get deleteTemplate => 'Vorlage löschen';

  @override
  String get spendingByCategory => 'Ausgaben nach Kategorie';

  @override
  String get incomeVsExpense => 'Einnahmen vs Ausgaben';

  @override
  String get netWorth => 'Nettovermögen';

  @override
  String get spendingTrends => 'Ausgabentrends';

  @override
  String get topPayees => 'Top Empfänger';

  @override
  String get categoryBreakdown => 'Kategorie-Aufschlüsselung';

  @override
  String get dateRange => 'Datumsbereich';

  @override
  String get thisMonth => 'Dieser Monat';

  @override
  String get lastMonth => 'Letzter Monat';

  @override
  String get last3Months => 'Letzte 3 Monate';

  @override
  String get last6Months => 'Letzte 6 Monate';

  @override
  String get thisYear => 'Dieses Jahr';

  @override
  String get lastYear => 'Letztes Jahr';

  @override
  String get allTime => 'Gesamte Zeit';

  @override
  String get custom => 'Benutzerdefiniert';

  @override
  String get series => 'Serie';

  @override
  String get exportReport => 'Bericht exportieren';

  @override
  String get selectReportToExport => 'Bericht wählen';

  @override
  String get exportFormat => 'Format';

  @override
  String get csv => 'CSV';

  @override
  String get pdf => 'PDF';

  @override
  String get image => 'Bild';

  @override
  String get share => 'Teilen';

  @override
  String get exporting => 'Exportieren...';

  @override
  String get exportSuccess => 'Export erfolgreich';

  @override
  String exportFailed(String error) {
    return 'Export fehlgeschlagen: $error';
  }

  @override
  String get budgetVsActual => 'Budget vs Ist';

  @override
  String get filterCategories => 'Kategorien filtern';

  @override
  String get clear => 'Leeren';

  @override
  String get apply => 'Anwenden';

  @override
  String get noNotes => 'Keine Notizen für diesen Zeitraum.';

  @override
  String get addNote => 'Notiz hinzufügen';

  @override
  String get editNote => 'Notiz bearbeiten';

  @override
  String get month => 'Monat';

  @override
  String get note => 'Notiz';

  @override
  String get enterNote => 'Bitte Notiz eingeben';

  @override
  String get deleteNoteConfirmationTitle => 'Notiz löschen?';

  @override
  String get deleteNoteConfirmationMessage =>
      'Dies kann nicht rückgängig gemacht werden.';

  @override
  String get noteDeleted => 'Notiz gelöscht';

  @override
  String get noteSaved => 'Notiz gespeichert';

  @override
  String get settings => 'Einstellungen';

  @override
  String get payees => 'Empfänger';

  @override
  String get payeeName => 'Name';

  @override
  String get payeeDefaultCategory => 'Standardkategorie';

  @override
  String get editPayee => 'Empfänger bearbeiten';

  @override
  String get mergePayee => 'Zusammenführen';

  @override
  String mergePayeeInto(String name) {
    return 'Zusammenführen mit $name';
  }

  @override
  String get deletePayeeConfirmation => 'Löschen?';

  @override
  String deletePayeeWarning(String name) {
    return '$name löschen? Transaktionen bleiben erhalten, Empfänger wird entfernt.';
  }

  @override
  String mergeWarning(String target) {
    return 'Alle Transaktionen werden zu $target verschoben. Nicht rückgängig machbar.';
  }

  @override
  String get noPayees => 'Keine Empfänger';

  @override
  String get searchPayees => 'Empfänger suchen';

  @override
  String get rename => 'Umbenennen';

  @override
  String get defaultAccount => 'Default Account';

  @override
  String get usageStats => 'Usage Statistics';

  @override
  String get timesUsed => 'Times Used';

  @override
  String get totalSpent => 'Total Spent';

  @override
  String get lastUsed => 'Last Used';

  @override
  String get autoCategory => 'Auto Category';

  @override
  String get configuration => 'Configuration';

  @override
  String get addToFavorites => 'Add to Favorites';

  @override
  String get removeFromFavorites => 'Remove from Favorites';

  @override
  String get none => 'None';

  @override
  String get defaultLabel => 'Default';

  @override
  String get scheduledTransactions => 'Geplante Transaktionen';

  @override
  String get nextDate => 'Nächstes Datum';

  @override
  String get endDate => 'Enddatum';

  @override
  String get autoApprove => 'Automatisch genehmigen';

  @override
  String get createScheduledTransaction => 'Geplante Transaktion erstellen';

  @override
  String get editScheduledTransaction => 'Geplante Transaktion bearbeiten';

  @override
  String get schedule => 'Zeitplan';

  @override
  String get noScheduledTransactions => 'Keine geplanten Transaktionen';

  @override
  String get createScheduledTransactionDescription =>
      'Erstellen Sie geplante Transaktionen für wiederkehrende Rechnungen oder Einnahmen.';

  @override
  String get skip => 'Überspringen';

  @override
  String get repeatEvery => 'Repeat Every';

  @override
  String unitDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Days',
      one: 'Day',
    );
    return '$_temp0';
  }

  @override
  String unitWeeks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Weeks',
      one: 'Week',
    );
    return '$_temp0';
  }

  @override
  String unitMonths(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Months',
      one: 'Month',
    );
    return '$_temp0';
  }

  @override
  String unitYears(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Years',
      one: 'Year',
    );
    return '$_temp0';
  }

  @override
  String get end => 'End';

  @override
  String get never => 'Never';

  @override
  String get onDate => 'On Date';

  @override
  String get afterOccurrences => 'After';

  @override
  String get occurrences => 'Occurrences';
}
