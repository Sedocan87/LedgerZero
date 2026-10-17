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
  String get toBeBudgeted => 'Zu budgetieren';

  @override
  String get totalIncome => 'Einnahmen gesamt';

  @override
  String get totalSpending => 'Gesamtausgaben';

  @override
  String get recentTransactions => 'Letzte Transaktionen';

  @override
  String get noRecentTransactions => 'Noch keine Transaktionen';

  @override
  String get addTransaction => 'Transaktion hinzufügen';

  @override
  String get editTransaction => 'Transaktion bearbeiten';

  @override
  String get welcomeToLedgerZero => 'Willkommen bei LedgerZero';

  @override
  String get createFirstAccountMessage =>
      'Legen Sie Ihr erstes Konto an, um mit dem Budgetieren zu beginnen.';

  @override
  String get createAccount => 'Konto erstellen';

  @override
  String get accountDetails => 'Kontodetails';

  @override
  String get loading => 'Wird geladen …';

  @override
  String get error => 'Fehler';

  @override
  String get warning => 'Warnung';

  @override
  String get accountNotFound => 'Konto nicht gefunden';

  @override
  String get noTransactions => 'Keine Transaktionen';

  @override
  String get unknownPayee => 'Unbekannter Empfänger';

  @override
  String get balanceTrend => 'Saldoverlauf';

  @override
  String get noTransactionsTrend =>
      'Noch keine Transaktionen für einen Verlauf';

  @override
  String get deleteAccount => 'Konto löschen';

  @override
  String get closeAccount => 'Konto schließen';

  @override
  String get reopenAccount => 'Konto wieder öffnen';

  @override
  String get reconcileAccount => 'Konto abgleichen';

  @override
  String get exportToCsv => 'Als CSV exportieren';

  @override
  String get cancel => 'Abbrechen';

  @override
  String get delete => 'Löschen';

  @override
  String get enterActualBalance => 'Tatsächlichen Saldo eingeben';

  @override
  String get discrepancyFound => 'Abweichung gefunden';

  @override
  String discrepancyMessage(String diff) {
    return 'Es gibt eine Differenz von $diff. Ausgleichsbuchung erstellen?';
  }

  @override
  String get yes => 'Ja';

  @override
  String get no => 'Nein';

  @override
  String get reconcile => 'Abgleichen';

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
  String get memo => 'Notiz';

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
  String get split => 'Aufteilen';

  @override
  String get recurring => 'Wiederkehrend';

  @override
  String get invalidAmount => 'Bitte geben Sie einen gültigen Betrag ein';

  @override
  String get selectAccount => 'Bitte wählen Sie ein Konto';

  @override
  String get transactionSaved => 'Transaktion gespeichert';

  @override
  String get toAccount => 'Auf Konto';

  @override
  String get frequency => 'Häufigkeit';

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
  String get manageCategories => 'Kategorien verwalten';

  @override
  String get categoryGroup => 'Kategoriegruppe';

  @override
  String get editCategory => 'Kategorie bearbeiten';

  @override
  String get deleteCategory => 'Kategorie löschen';

  @override
  String get categoryName => 'Kategoriename';

  @override
  String get createCategory => 'Kategorie erstellen';

  @override
  String get editCategoryGroup => 'Gruppe bearbeiten';

  @override
  String get deleteCategoryGroup => 'Gruppe löschen';

  @override
  String get addCategoryGroup => 'Gruppe hinzufügen';

  @override
  String get groupName => 'Gruppenname';

  @override
  String get hideCategory => 'Kategorie ausblenden';

  @override
  String get hidden => 'Ausgeblendet';

  @override
  String get reorderGroups => 'Gruppen sortieren';

  @override
  String get reorderCategories => 'Kategorien sortieren';

  @override
  String get color => 'Farbe';

  @override
  String get icon => 'Symbol';

  @override
  String get merge => 'Zusammenführen';

  @override
  String get search => 'Suchen';

  @override
  String get export => 'Exportieren';

  @override
  String get import => 'Importieren';

  @override
  String get importCsv => 'CSV importieren';

  @override
  String get selectFileToImport => 'Wählen Sie eine CSV-Datei für den Import';

  @override
  String get changeFile => 'Andere Datei';

  @override
  String get selectFile => 'Datei auswählen';

  @override
  String get dateFormat => 'Datumsformat';

  @override
  String get decimalSeparator => 'Dezimaltrennzeichen';

  @override
  String get dot => 'Punkt (.)';

  @override
  String get comma => 'Komma (,)';

  @override
  String get previousMonth => 'Vorheriger Monat';

  @override
  String get nextMonth => 'Nächster Monat';

  @override
  String get numberFormatSystem => 'Wie Sprache';

  @override
  String get negativeValuesAreOutflows => 'Negative Werte sind Ausgaben';

  @override
  String get columnMapping => 'Spaltenzuordnung';

  @override
  String get selectColumn => 'Spalte wählen';

  @override
  String get ignore => 'Ignorieren';

  @override
  String get continueToReview => 'Weiter zur Prüfung';

  @override
  String get budgeted => 'Budgetiert';

  @override
  String get activity => 'Aktivität';

  @override
  String get available => 'Verfügbar';

  @override
  String get budgetPreviousMonth => 'Wie im Vormonat budgetieren';

  @override
  String get budgetAverageSpent => 'Durchschnittsausgaben budgetieren';

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
  String get noCategoriesTitle => 'Noch keine Kategorien';

  @override
  String get noCategoriesDescription =>
      'Legen Sie Kategorien an, um Ihr Geld zu budgetieren.';

  @override
  String get setupBudget => 'Budget einrichten';

  @override
  String get budgetTutorialTitle => 'Willkommen beim Budgetieren';

  @override
  String get budgetTutorialDescription =>
      'Tippen Sie auf einen Betrag, um zu budgetieren. Mit den Schnellaktionen weisen Sie Geld automatisch zu.';

  @override
  String get gotIt => 'Verstanden';

  @override
  String get total => 'Gesamt';

  @override
  String get tbbTooltip =>
      'Geld, das Sie noch keiner Kategorie zugewiesen haben. Budgetieren Sie, bis hier null steht.';

  @override
  String get budgetedTooltip =>
      'Der Betrag, den Sie dieser Kategorie in diesem Monat zugewiesen haben.';

  @override
  String get activityTooltip =>
      'Die Summe der Transaktionen dieses Monats in dieser Kategorie.';

  @override
  String get availableTooltip =>
      'Was Sie noch ausgeben können: Budgetiert plus Aktivität plus Übertrag aus dem Vormonat.';

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
  String get incomeVsExpense => 'Einnahmen vs. Ausgaben';

  @override
  String get netWorth => 'Nettovermögen';

  @override
  String get spendingTrends => 'Ausgabentrends';

  @override
  String get topPayees => 'Top-Empfänger';

  @override
  String get categoryBreakdown => 'Aufschlüsselung nach Kategorie';

  @override
  String get dateRange => 'Zeitraum';

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
  String get allTime => 'Gesamter Zeitraum';

  @override
  String get custom => 'Benutzerdefiniert';

  @override
  String get series => 'Datenreihe';

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
  String get exporting => 'Wird exportiert …';

  @override
  String get budgetVsActual => 'Budget vs. Ist';

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
  String get payeeName => 'Name des Empfängers';

  @override
  String get mergePayee => 'Empfänger zusammenführen';

  @override
  String mergePayeeInto(String name) {
    return 'Zusammenführen mit $name';
  }

  @override
  String get deletePayeeConfirmation => 'Empfänger löschen?';

  @override
  String deletePayeeWarning(String name) {
    return 'Möchten Sie $name wirklich löschen? Die Transaktionen bleiben erhalten, aber ohne Empfänger.';
  }

  @override
  String mergeWarning(String target) {
    return 'Alle Transaktionen dieses Empfängers werden zu $target verschoben. Dies kann nicht rückgängig gemacht werden.';
  }

  @override
  String get noPayees => 'Keine Empfänger';

  @override
  String get searchPayees => 'Empfänger suchen';

  @override
  String get rename => 'Umbenennen';

  @override
  String get defaultAccount => 'Standardkonto';

  @override
  String get usageStats => 'Nutzungsstatistik';

  @override
  String get timesUsed => 'Anzahl Verwendungen';

  @override
  String get totalSpent => 'Ausgaben gesamt';

  @override
  String get lastUsed => 'Zuletzt verwendet';

  @override
  String get autoCategory => 'Automatische Kategorie';

  @override
  String get configuration => 'Einstellungen';

  @override
  String get addToFavorites => 'Zu Favoriten hinzufügen';

  @override
  String get removeFromFavorites => 'Aus Favoriten entfernen';

  @override
  String get none => 'Keine';

  @override
  String get defaultLabel => 'Standard';

  @override
  String get scheduledTransactions => 'Geplante Transaktionen';

  @override
  String get nextDate => 'Nächstes Datum';

  @override
  String get endDate => 'Enddatum';

  @override
  String get autoApprove => 'Automatisch bestätigen';

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
  String get upcoming => 'Anstehend';

  @override
  String get repeatEvery => 'Wiederholen alle';

  @override
  String unitDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Tage',
      one: 'Tag',
    );
    return '$_temp0';
  }

  @override
  String unitWeeks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Wochen',
      one: 'Woche',
    );
    return '$_temp0';
  }

  @override
  String unitMonths(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Monate',
      one: 'Monat',
    );
    return '$_temp0';
  }

  @override
  String unitYears(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Jahre',
      one: 'Jahr',
    );
    return '$_temp0';
  }

  @override
  String get end => 'Ende';

  @override
  String get never => 'Nie';

  @override
  String get onDate => 'An einem Datum';

  @override
  String get afterOccurrences => 'Nach';

  @override
  String get occurrences => 'Wiederholungen';

  @override
  String get recoveryKey => 'Wiederherstellungsschlüssel';

  @override
  String get revealRecoveryKey => 'Wiederherstellungsschlüssel anzeigen';

  @override
  String get autoLock => 'Automatische Sperre';

  @override
  String get autoLockImmediate => 'Sofort';

  @override
  String autoLockMinutes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Minuten',
      one: '1 Minute',
    );
    return '$_temp0';
  }

  @override
  String get autoLockNever => 'Nie';

  @override
  String get incorrectPassword => 'Falsches Passwort';

  @override
  String get passwordsDoNotMatch => 'Die Passwörter stimmen nicht überein';

  @override
  String get biometrics => 'Biometrische Entsperrung';

  @override
  String get encryptionStatus => 'Verschlüsselungsstatus';

  @override
  String get encrypted => 'Verschlüsselt';

  @override
  String get secure => 'Sicher';

  @override
  String get securitySettings => 'Sicherheit';

  @override
  String get securityAndData => 'Sicherheit & Daten';

  @override
  String get syncSettings => 'Synchronisierung';

  @override
  String get connectToGoogleDrive => 'Mit Google Drive verbinden';

  @override
  String get syncNow => 'Jetzt synchronisieren';

  @override
  String get googleDriveSync => 'Google-Drive-Synchronisierung';

  @override
  String lastSynced(String time) {
    return 'Zuletzt synchronisiert: $time';
  }

  @override
  String get syncProvider => 'Speicherdienst';

  @override
  String get providerNone => 'Keiner';

  @override
  String get providerGoogleDrive => 'Google Drive';

  @override
  String get disconnect => 'Trennen';

  @override
  String get offlineMode => 'Offline-Modus';

  @override
  String get syncOnlyOnWifi => 'Nur über WLAN synchronisieren';

  @override
  String get syncFrequency => 'Sync-Intervall';

  @override
  String get frequencyManual => 'Manuell';

  @override
  String get frequencyRealtime => 'Sofort';

  @override
  String get frequency15Min => 'Alle 15 Minuten';

  @override
  String get frequency1Hour => 'Stündlich';

  @override
  String get frequency4Hours => 'Alle 4 Stunden';

  @override
  String get quickAdd => 'Schnelleingabe';

  @override
  String get preview => 'Vorschau';

  @override
  String get confidence => 'Treffsicherheit';

  @override
  String get noAmount => 'Kein Betrag';

  @override
  String get payeeNotFound => 'Empfänger nicht gefunden';

  @override
  String get uncategorized => 'Nicht kategorisiert';

  @override
  String get editDetails => 'Details bearbeiten';

  @override
  String get create => 'Erstellen';

  @override
  String get parsingTips => 'Eingabetipps';

  @override
  String get parsingTipsDescription =>
      'Schreiben Sie einfach, was Sie ausgegeben haben, und die App erstellt daraus eine Transaktion.';

  @override
  String get saveImportProfile => 'Importprofil speichern';

  @override
  String get profileName => 'Profilname';

  @override
  String get profileSaved => 'Importprofil gespeichert';

  @override
  String get loadImportProfile => 'Profil laden';

  @override
  String get deleteProfileConfirmation =>
      'Möchten Sie dieses Profil wirklich löschen?';

  @override
  String get confirmImport => 'Import bestätigen';

  @override
  String get confirmImportDescription =>
      'Prüfen und bestätigen Sie die zu importierenden Transaktionen.';

  @override
  String importedTransactions(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Transaktionen importiert',
      one: '1 Transaktion importiert',
    );
    return '$_temp0';
  }

  @override
  String get importSuccess => 'Import erfolgreich';

  @override
  String get duplicateWarning =>
      'Achtung: Diese Transaktion ist möglicherweise ein Duplikat.';

  @override
  String deduplicationComplete(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Duplikatprüfung abgeschlossen. $count Duplikate gefunden.',
      one: 'Duplikatprüfung abgeschlossen. 1 Duplikat gefunden.',
      zero: 'Duplikatprüfung abgeschlossen. Keine Duplikate gefunden.',
    );
    return '$_temp0';
  }

  @override
  String get generalSettings => 'Allgemeine Einstellungen';

  @override
  String get currency => 'Währung';

  @override
  String get firstDayOfWeek => 'Erster Wochentag';

  @override
  String get theme => 'Design';

  @override
  String get language => 'Sprache';

  @override
  String get defaultCategory => 'Standardkategorie';

  @override
  String get systemTheme => 'System';

  @override
  String get lightTheme => 'Hell';

  @override
  String get darkTheme => 'Dunkel';

  @override
  String get monday => 'Montag';

  @override
  String get saturday => 'Samstag';

  @override
  String get sunday => 'Sonntag';

  @override
  String get numberFormat => 'Zahlenformat';

  @override
  String get loadingAccounts => 'Konten werden geladen …';

  @override
  String get notificationSettings => 'Benachrichtigungen';

  @override
  String get scheduledTransactionNotifications => 'Geplante Transaktionen';

  @override
  String get budgetAlertNotifications => 'Budgetwarnungen';

  @override
  String get syncStatusNotifications => 'Synchronisierungsstatus';

  @override
  String get advancedSettings => 'Erweitert';

  @override
  String get clearCache => 'Cache leeren';

  @override
  String get cacheCleared => 'Cache geleert';

  @override
  String get factoryReset => 'Auf Werkseinstellungen zurücksetzen';

  @override
  String get factoryResetConfirmation =>
      'Möchten Sie die App wirklich auf Werkseinstellungen zurücksetzen? Dabei werden ALLE Daten gelöscht, auch Transaktionen, Budgets und Einstellungen. Dies kann nicht rückgängig gemacht werden.';

  @override
  String get factoryResetTitle => 'Auf Werkseinstellungen zurücksetzen?';

  @override
  String get factoryResetSuccess =>
      'Die App wurde zurückgesetzt. Bitte starten Sie sie neu.';

  @override
  String get helpAndSupport => 'Hilfe & Support';

  @override
  String get faq => 'FAQ';

  @override
  String get faqSubtitle => 'Häufig gestellte Fragen';

  @override
  String get userGuide => 'Benutzerhandbuch';

  @override
  String get userGuideSubtitle => 'So funktioniert LedgerZero';

  @override
  String get contactSupport => 'Support kontaktieren';

  @override
  String get contactSupportSubtitle => 'support@ledgerzero.app';

  @override
  String get errorOccurred => 'Ein Fehler ist aufgetreten';

  @override
  String get serverError => 'Die Verbindung zum Server ist fehlgeschlagen';

  @override
  String get cacheError =>
      'Zwischengespeicherte Daten konnten nicht geladen werden';

  @override
  String get databaseError => 'Der Datenbankzugriff ist fehlgeschlagen';

  @override
  String get syncError => 'Die Synchronisierung ist fehlgeschlagen';

  @override
  String get retry => 'Erneut versuchen';

  @override
  String get ok => 'OK';

  @override
  String get dismiss => 'Schließen';

  @override
  String get incomeAndSalaries => 'Einkommen & Gehälter';

  @override
  String get accessibility => 'Barrierefreiheit';

  @override
  String get reducedMotion => 'Bewegung reduzieren';

  @override
  String get exportCsv => 'CSV exportieren';

  @override
  String get addSplit => 'Aufteilung hinzufügen';

  @override
  String get scheduledTransactionDefaultMemo => 'Geplante Transaktion';

  @override
  String deleteNamedTitle(String name) {
    return '„$name“ löschen?';
  }

  @override
  String deleteCategoryTransactionCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Diese Kategorie hat $count Transaktionen.',
      one: 'Diese Kategorie hat 1 Transaktion.',
      zero: 'Diese Kategorie hat keine Transaktionen.',
    );
    return '$_temp0';
  }

  @override
  String get deleteCategoryMoveOption =>
      'Alles in eine andere Kategorie verschieben';

  @override
  String get deleteCategoryMoveExplanation =>
      'Transaktionen, budgetierte Beträge, Regeln, geplante Transaktionen und Empfänger-Vorgaben werden in die gewählte Kategorie verschoben. „Zu budgetieren“ ändert sich nicht.';

  @override
  String get deleteCategoryNoTargetOption => 'Ohne Ersatz löschen';

  @override
  String get deleteCategoryNoTargetExplanation =>
      'Das in dieser Kategorie budgetierte Geld geht zurück an „Zu budgetieren“. Ihre Transaktionen verlieren die Kategorie und zählen ebenfalls zu „Zu budgetieren“. Regeln, geplante Transaktionen und Empfänger-Vorgaben, die sie verwenden, werden zurückgesetzt.';

  @override
  String get deleteCategoryTargetLabel => 'Zielkategorie';

  @override
  String get deleteCategoryNoOtherCategories =>
      'Es gibt keine andere Kategorie als Ziel.';

  @override
  String get deleteCategoryFailed =>
      'Die Kategorie konnte nicht gelöscht werden. Bitte versuchen Sie es erneut.';

  @override
  String get categoryDeletedMessage => 'Kategorie gelöscht';

  @override
  String get deleteGroupEmptyConfirmation =>
      'Diese Gruppe enthält keine Kategorien. Möchten Sie sie löschen?';

  @override
  String deleteGroupMoveExplanation(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Diese Gruppe enthält $count Kategorien.',
      one: 'Diese Gruppe enthält 1 Kategorie.',
    );
    return '$_temp0 Wählen Sie eine Gruppe, in die sie verschoben werden. Budgets und Transaktionen bleiben dabei erhalten.';
  }

  @override
  String get deleteGroupTargetLabel => 'Kategorien verschieben nach';

  @override
  String get deleteGroupNoOtherGroup =>
      'Diese Gruppe enthält Kategorien und es gibt keine andere Gruppe, in die sie verschoben werden können. Legen Sie zuerst eine weitere Gruppe an oder löschen Sie ihre Kategorien.';

  @override
  String get deleteGroupFailed =>
      'Die Gruppe konnte nicht gelöscht werden. Bitte versuchen Sie es erneut.';

  @override
  String get deleteAccountCloseRecommendation =>
      'Empfohlen: Schließen Sie das Konto stattdessen. Ein geschlossenes Konto wird ausgeblendet, behält aber alle Transaktionen und den Verlauf.';

  @override
  String get deleteAccountPermanentWarning =>
      'Beim Löschen werden alle Transaktionen und geplanten Transaktionen dieses Kontos endgültig entfernt. Dies kann nicht rückgängig gemacht werden.';

  @override
  String get deleteAccountTransfersWarning =>
      'Umbuchungen von oder zu anderen Konten bleiben dort als normale, nicht kategorisierte Transaktionen erhalten. Dadurch ändert sich „Zu budgetieren“.';

  @override
  String get closeAccountInstead => 'Stattdessen schließen';

  @override
  String get deletePermanently => 'Endgültig löschen';

  @override
  String get accountClosedMessage => 'Konto geschlossen';

  @override
  String accountDeletedMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Konto gelöscht. $count Umbuchungen in anderen Konten sind jetzt normale Transaktionen.',
      one:
          'Konto gelöscht. 1 Umbuchung in einem anderen Konto ist jetzt eine normale Transaktion.',
      zero: 'Konto gelöscht.',
    );
    return '$_temp0';
  }

  @override
  String get deleteAccountFailed =>
      'Das Konto konnte nicht gelöscht werden. Bitte versuchen Sie es erneut.';

  @override
  String get accountUpdateFailed =>
      'Das Konto konnte nicht aktualisiert werden. Bitte versuchen Sie es erneut.';

  @override
  String transferToAccount(String account) {
    return 'Umbuchung auf $account';
  }

  @override
  String transferFromAccount(String account) {
    return 'Umbuchung von $account';
  }

  @override
  String get deletePayeeFailed =>
      'Der Empfänger konnte nicht gelöscht werden. Bitte versuchen Sie es erneut.';

  @override
  String get mergePayeeFailed =>
      'Die Empfänger konnten nicht zusammengeführt werden. Bitte versuchen Sie es erneut.';

  @override
  String get reconcileAdjustmentMemo => 'Ausgleichsbuchung (Abgleich)';

  @override
  String get reconcileWorkingBalance => 'Aktueller Saldo';

  @override
  String get reconcileClearedBalance => 'Gebuchter Saldo';

  @override
  String get reconcileClearedUpToDate => 'Gebuchter Saldo bis zum Auszugsdatum';

  @override
  String get reconcileStatementDate => 'Auszugsdatum';

  @override
  String get reconcileStatementBalance => 'Saldo laut Kontoauszug';

  @override
  String get reconcileDifference => 'Differenz';

  @override
  String get reconcileExplanation =>
      'Alle gebuchten Transaktionen bis zum Auszugsdatum werden als abgeglichen markiert. Weicht der gebuchte Saldo vom Kontoauszug ab, wird eine nicht kategorisierte Ausgleichsbuchung erstellt; sie zählt zu „Zu budgetieren“.';

  @override
  String reconcileResultMatched(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count Transaktionen abgeglichen. Der Saldo stimmt mit dem Kontoauszug überein.',
      one:
          '1 Transaktion abgeglichen. Der Saldo stimmt mit dem Kontoauszug überein.',
      zero:
          'Keine Transaktionen abzugleichen. Der Saldo stimmt mit dem Kontoauszug überein.',
    );
    return '$_temp0';
  }

  @override
  String reconcileResultAdjusted(int count, String amount) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Transaktionen abgeglichen.',
      one: '1 Transaktion abgeglichen.',
      zero: 'Keine Transaktionen abgeglichen.',
    );
    return '$_temp0 Eine Ausgleichsbuchung über $amount wurde erstellt.';
  }

  @override
  String get reconcileFailed =>
      'Das Konto konnte nicht abgeglichen werden. Bitte versuchen Sie es erneut.';

  @override
  String get fromAccount => 'Von Konto';

  @override
  String get txSplitSumMismatch =>
      'Die Teilbeträge müssen zusammen den Gesamtbetrag ergeben.';

  @override
  String get txSplitLineZero => 'Jede Teilbuchung braucht einen Betrag.';

  @override
  String get txTransferSameAccount =>
      'Quell- und Zielkonto müssen verschieden sein.';

  @override
  String get txTransferNoSplit =>
      'Eine Umbuchung kann nicht aufgeteilt werden.';

  @override
  String get txRecurringSplitUnsupported =>
      'Wiederkehrende aufgeteilte Transaktionen werden noch nicht unterstützt.';

  @override
  String get txRecurringTransferUnsupported =>
      'Wiederkehrende Umbuchungen werden noch nicht unterstützt.';

  @override
  String get txScheduledCreated => 'Geplante Transaktion erstellt';

  @override
  String get txSaveFailed => 'Die Transaktion konnte nicht gespeichert werden.';

  @override
  String get txReconciledChangeTitle => 'Abgeglichene Transaktion ändern?';

  @override
  String get txReconciledChangeMessage =>
      'Diese Transaktion wurde bereits mit einem Kontoauszug abgeglichen. Wenn Sie sie ändern, stimmt der abgeglichene Saldo nicht mehr mit dem Auszug überein.';

  @override
  String get txReconciledDeleteMessage =>
      'Darunter sind Transaktionen, die bereits mit einem Kontoauszug abgeglichen wurden. Wenn Sie sie löschen, stimmt der abgeglichene Saldo nicht mehr mit dem Auszug überein.';

  @override
  String get txChangeAnyway => 'Trotzdem ändern';

  @override
  String get txDeleteTitle => 'Transaktion löschen?';

  @override
  String txDeleteManyTitle(int count) {
    return '$count Transaktionen löschen?';
  }

  @override
  String get txDeleteMessage =>
      'Sie können das direkt nach dem Löschen rückgängig machen.';

  @override
  String get txDeleteTransferNote =>
      'Die Gegenbuchung der Umbuchung wird ebenfalls gelöscht.';

  @override
  String get txDeleteSplitNote =>
      'Die gesamte aufgeteilte Transaktion mit allen Teilbuchungen wird gelöscht.';

  @override
  String txDeletedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Transaktionen gelöscht',
      one: 'Transaktion gelöscht',
    );
    return '$_temp0';
  }

  @override
  String get txActionFailed =>
      'Das hat nicht geklappt. Bitte versuchen Sie es erneut.';

  @override
  String get txSearchHint => 'Empfänger, Kategorie, Notiz oder Betrag suchen';

  @override
  String get txFilterPayees => 'Empfänger';

  @override
  String get txFilterAmountFrom => 'Betrag von';

  @override
  String get txFilterAmountTo => 'Betrag bis';

  @override
  String txCategoryActivityTitle(String category, String month) {
    return '$category: $month';
  }

  @override
  String get continueAction => 'Weiter';

  @override
  String get confirmAction => 'Bestätigen';

  @override
  String get masterPasswordLabel => 'Master-Passwort';

  @override
  String get confirmPasswordLabel => 'Passwort bestätigen';

  @override
  String get showPassword => 'Passwort anzeigen';

  @override
  String get hidePassword => 'Passwort verbergen';

  @override
  String passwordMinLength(int count) {
    return 'Verwenden Sie mindestens $count Zeichen';
  }

  @override
  String get passwordTooCommon =>
      'Dieses Passwort ist zu verbreitet. Bitte wählen Sie ein anderes.';

  @override
  String get passwordHint =>
      'Eine lange Passphrase aus mehreren Wörtern ist am leichtesten zu merken.';

  @override
  String passwordStrengthTitle(String label) {
    return 'Passwortstärke: $label';
  }

  @override
  String get passwordStrengthTooShort => 'zu kurz';

  @override
  String get passwordStrengthCommon => 'zu verbreitet';

  @override
  String get passwordStrengthWeak => 'schwach';

  @override
  String get passwordStrengthFair => 'mittel';

  @override
  String get passwordStrengthGood => 'gut';

  @override
  String get passwordStrengthStrong => 'stark';

  @override
  String get setupProtectTitle => 'Schützen Sie Ihre Daten';

  @override
  String get setupFailed =>
      'Die Einrichtung der Sicherheit ist fehlgeschlagen. Bitte versuchen Sie es erneut.';

  @override
  String get biometricPromptTitle => 'LedgerZero entsperren';

  @override
  String get biometricPromptSubtitle =>
      'Bestätigen Sie Ihre Identität, um Ihre Daten zu entsperren';

  @override
  String get loginUnlock => 'Entsperren';

  @override
  String get loginUseBiometrics => 'Biometrie verwenden';

  @override
  String get loginUseRecoveryKey => 'Wiederherstellungsschlüssel verwenden';

  @override
  String get loginVaultMissing =>
      'Die Schlüsseldaten dieser App fehlen, daher können Ihre Daten nicht entsperrt werden. Sie können die App zurücksetzen und eine Sicherung wiederherstellen.';

  @override
  String get loginDatabaseKeyMismatch =>
      'Ihr Schlüssel ist korrekt, aber die Datenbankdatei konnte damit nicht geöffnet werden.';

  @override
  String get loginFailed =>
      'Das Entsperren ist fehlgeschlagen. Bitte versuchen Sie es erneut.';

  @override
  String get biometricsInvalidated =>
      'Die biometrische Entsperrung wurde deaktiviert, da sich die biometrischen Daten auf diesem Gerät geändert haben. Entsperren Sie mit Ihrem Passwort und aktivieren Sie sie in den Einstellungen erneut.';

  @override
  String get biometricsUnlockFailed =>
      'Die biometrische Entsperrung ist fehlgeschlagen. Bitte verwenden Sie Ihr Passwort.';

  @override
  String get recoveryKeyEnterTitle => 'Wiederherstellungsschlüssel eingeben';

  @override
  String get recoveryKeyEnterHint =>
      '32 Zeichen; Leerzeichen und Bindestriche sind optional';

  @override
  String get recoveryKeyInvalid =>
      'Dieser Wiederherstellungsschlüssel ist nicht korrekt.';

  @override
  String get recoveryKeyNeedsPassword =>
      'Ein Update wird noch abgeschlossen. Bitte entsperren Sie einmal mit Ihrem Passwort.';

  @override
  String get encryptionStatusEncrypted =>
      'Verschlüsselt mit SQLCipher (AES-256)';

  @override
  String get encryptionStatusPlaintext =>
      'Die Datenbankdatei ist NICHT verschlüsselt';

  @override
  String get encryptionStatusUnknown => 'Noch nicht geprüft';

  @override
  String get lockNow => 'Jetzt sperren';

  @override
  String get privacySection => 'Datenschutz';

  @override
  String get crashReportsTitle => 'Absturzberichte speichern';

  @override
  String get crashReportsSubtitle =>
      'Standardmäßig aus. Wenn aktiviert, werden Fehler nur auf diesem Gerät protokolliert, ohne Beträge, E-Mail-Adressen und Datenbankwerte. Es wird nichts gesendet, außer Sie teilen das Protokoll selbst.';

  @override
  String get notificationAmountsTitle =>
      'Beträge in Benachrichtigungen anzeigen';

  @override
  String get notificationAmountsSubtitle =>
      'Wenn deaktiviert, sagen Erinnerungen nur, dass eine Transaktion fällig ist. So erscheinen keine Finanzdaten auf dem Sperrbildschirm.';

  @override
  String get diagnosticsTitle => 'Diagnoseprotokoll';

  @override
  String get diagnosticsSubtitle =>
      'Gespeicherte Absturzberichte ansehen und teilen';

  @override
  String get diagnosticsEmpty => 'Keine Diagnosedaten gespeichert.';

  @override
  String get diagnosticsShareExplanation =>
      'Genau dieser Inhalt wird geteilt. Bitte prüfen Sie ihn, bevor Sie ihn an jemanden senden.';

  @override
  String get diagnosticsShare => 'Diagnoseprotokoll teilen';

  @override
  String get diagnosticsDelete => 'Diagnosedaten löschen';

  @override
  String get diagnosticsDeleted => 'Diagnosedaten gelöscht';

  @override
  String get notificationScheduledTitle => 'Anstehende Transaktion';

  @override
  String get notificationScheduledBodyGeneric =>
      'Morgen ist eine geplante Transaktion fällig.';

  @override
  String notificationScheduledBodyAmount(String amount) {
    return 'Morgen ist eine geplante Transaktion über $amount fällig.';
  }

  @override
  String get backupCreateTitle => 'Sicherung erstellen';

  @override
  String get backupCreateExplanation =>
      'Eine vollständige Kopie Ihrer Daten, immer verschlüsselt mit einem Sicherungspasswort Ihrer Wahl. Bewahren Sie dieses Passwort auf: Ohne es lässt sich die Sicherung nicht öffnen. Für eine lesbare Kopie verwenden Sie stattdessen den JSON- oder CSV-Export.';

  @override
  String get backupPasswordLabel => 'Sicherungspasswort';

  @override
  String get backupUploadToCloud =>
      'Zusätzlich in Ihren Sync-Speicher hochladen';

  @override
  String get backupUploadNotConfigured =>
      'Richten Sie zuerst die Synchronisierung mit Google Drive ein';

  @override
  String get backupExport => 'Sicherung exportieren';

  @override
  String get backupCreating => 'Sicherung wird erstellt …';

  @override
  String get backupUploaded => 'Sicherung hochgeladen';

  @override
  String get backupUploadFailed =>
      'Das Hochladen ist fehlgeschlagen. Die Sicherung wurde trotzdem erstellt und kann geteilt werden.';

  @override
  String get backupFailed =>
      'Die Sicherung ist fehlgeschlagen. Bitte versuchen Sie es erneut.';

  @override
  String get backupShareSubject => 'LedgerZero-Sicherung';

  @override
  String get restoreTitle => 'Sicherung wiederherstellen';

  @override
  String get restoreExplanation =>
      'Alle Daten auf diesem Gerät durch eine Sicherungsdatei (.lzbk) ersetzen.';

  @override
  String get restoreFromFile => 'Aus Datei wiederherstellen';

  @override
  String get restoreSelective =>
      'Transaktionen aus einer Sicherung übernehmen (Zeitraum)';

  @override
  String get restorePasswordTitle => 'Sicherungspasswort eingeben';

  @override
  String get restoreConfirmTitle => 'Alle Daten ersetzen?';

  @override
  String get restoreConfirmMessage =>
      'Alles auf diesem Gerät wird durch die Sicherung ersetzt. Wenn Sie die Synchronisierung nutzen, werden Änderungen, die nach dem Erstellen dieser Sicherung auf Ihren anderen Geräten gemacht wurden, wieder übernommen.';

  @override
  String get restoreAction => 'Wiederherstellen';

  @override
  String get restoreSuccessTitle => 'Wiederherstellung abgeschlossen';

  @override
  String get restoreSuccessMessage =>
      'Ihre Daten wurden wiederhergestellt. Wenn Sie die Synchronisierung nutzen, wird dieses Gerät neu synchronisiert und neuere Änderungen von Ihren anderen Geräten werden wieder übernommen.';

  @override
  String get restoreWrongPassword =>
      'Falsches Sicherungspasswort oder die Datei ist beschädigt.';

  @override
  String get restoreInvalidFile =>
      'Diese Datei ist keine wiederherstellbare LedgerZero-Sicherung.';

  @override
  String get restoreNewerVersion =>
      'Diese Sicherung wurde mit einer neueren Version von LedgerZero erstellt. Bitte aktualisieren Sie zuerst die App.';

  @override
  String get restoreFailed =>
      'Die Wiederherstellung ist fehlgeschlagen. Ihre Daten wurden nicht verändert.';

  @override
  String get selectiveRestoreSuccess => 'Transaktionen übernommen.';

  @override
  String get syncPassphraseSetTitle => 'Sync-Passphrase festlegen';

  @override
  String get syncPassphraseSetExplanation =>
      'Ihre Daten werden verschlüsselt, bevor sie dieses Gerät verlassen. Wählen Sie eine Sync-Passphrase: Sie müssen sie auf jedem Gerät eingeben, das synchronisiert werden soll. Sie kann nicht wiederhergestellt werden, auch nicht vom Entwickler. Bewahren Sie sie daher sicher auf.';

  @override
  String get syncPassphraseEnterTitle => 'Sync-Passphrase eingeben';

  @override
  String get syncPassphraseEnterExplanation =>
      'Dieser Sync-Ordner wird bereits von einem anderen Gerät verwendet. Geben Sie die dort festgelegte Sync-Passphrase ein.';

  @override
  String get syncPassphraseLabel => 'Sync-Passphrase';

  @override
  String get syncPassphraseConfirmLabel => 'Sync-Passphrase bestätigen';

  @override
  String get syncPassphraseSetButton => 'Passphrase festlegen';

  @override
  String get syncPassphraseEnterButton => 'Passphrase eingeben';

  @override
  String get syncPassphraseWrong => 'Falsche Sync-Passphrase.';

  @override
  String get syncPassphraseFolderExists =>
      'Ein anderes Gerät hat die Synchronisierung gerade eingerichtet. Geben Sie die dort festgelegte Passphrase ein.';

  @override
  String get syncPassphraseFailed =>
      'Die Sync-Passphrase konnte nicht gespeichert werden. Bitte versuchen Sie es erneut.';

  @override
  String syncPendingChanges(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Änderungen warten auf das Hochladen',
      one: '1 Änderung wartet auf das Hochladen',
      zero: 'Alle Änderungen hochgeladen',
    );
    return '$_temp0';
  }

  @override
  String get syncUpdateAppRequired =>
      'Ein anderes Gerät verwendet eine neuere Version von LedgerZero. Aktualisieren Sie die App, um dessen Änderungen zu synchronisieren.';

  @override
  String get syncLegacyFolderFound =>
      'Der Sync-Ordner enthält noch Dateien einer älteren LedgerZero-Version (Endung .json.gz). Sie werden nicht mehr verwendet und können gelöscht werden.';

  @override
  String syncQuarantineTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Änderungsdateien konnten nicht übernommen werden',
      one: '1 Änderungsdatei konnte nicht übernommen werden',
    );
    return '$_temp0';
  }

  @override
  String get syncQuarantineExplanation =>
      'Änderungen des betroffenen Geräts warten, bis die Datei übernommen werden kann. Andere Geräte synchronisieren weiter.';

  @override
  String get syncQuarantineRetry => 'Erneut versuchen';

  @override
  String get syncQuarantineShare => 'Diagnose teilen';

  @override
  String get syncQuarantineSkip => 'Datei überspringen';

  @override
  String get syncQuarantineSkipConfirm =>
      'Die Änderungen in dieser Datei werden auf diesem Gerät nicht übernommen. Möchten Sie die Datei überspringen?';

  @override
  String get syncConflictsTitle => 'Sync-Konflikte';

  @override
  String syncConflictsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Änderungen wurden durch neuere ersetzt',
      one: '1 Änderung wurde durch eine neuere ersetzt',
      zero: 'Keine Konflikte',
    );
    return '$_temp0';
  }

  @override
  String get syncConflictsExplanation =>
      'Diese Änderungen auf diesem Gerät wurden durch neuere Änderungen auf einem anderen Gerät ersetzt. Behalten Sie Ihre Version, um sie auf allen Geräten erneut anzuwenden.';

  @override
  String get syncConflictsEmpty => 'Keine Sync-Konflikte.';

  @override
  String get syncConflictKeepMine => 'Meine behalten';

  @override
  String get syncConflictDismiss => 'Verwerfen';

  @override
  String get syncConflictKeepFailed =>
      'Ihre Version konnte nicht wiederhergestellt werden, weil sie auf gelöschte Daten verweist.';

  @override
  String get syncConflictMine => 'Dieses Gerät';

  @override
  String get syncConflictTheirs => 'Anderes Gerät';

  @override
  String get syncConflictDeleted => 'Gelöscht';

  @override
  String syncConflictResolvedAt(String time) {
    return 'Ersetzt am $time';
  }

  @override
  String get syncTableAccounts => 'Konto';

  @override
  String get syncTableCategories => 'Kategorie';

  @override
  String get syncTableCategoryGroups => 'Kategoriegruppe';

  @override
  String get syncTableTransactions => 'Transaktion';

  @override
  String get syncTablePayees => 'Empfänger';

  @override
  String get syncTableBudgets => 'Budget';

  @override
  String get syncTableScheduledTransactions => 'Geplante Transaktion';

  @override
  String get syncTableBudgetTemplates => 'Budgetvorlage';

  @override
  String get syncTableReportNotes => 'Berichtsnotiz';

  @override
  String get syncTableImportProfiles => 'Importprofil';

  @override
  String get syncTableRules => 'Regel';

  @override
  String syncStatusConnectedAs(String email) {
    return 'Verbunden als $email';
  }

  @override
  String get syncStatusConnected => 'Verbunden';

  @override
  String get syncStatusDisconnected => 'Nicht verbunden';

  @override
  String get syncStatusSyncing => 'Wird synchronisiert …';

  @override
  String get syncStatusPaused => 'Pausiert, solange die App gesperrt ist';

  @override
  String get pickerNoMatches => 'Keine Treffer';

  @override
  String get scheduledDeleteConfirmation =>
      'Diese geplante Transaktion löschen? Bereits erstellte Transaktionen bleiben erhalten.';

  @override
  String get scheduledSaveFailed =>
      'Die geplante Transaktion konnte nicht gespeichert werden. Bitte versuchen Sie es erneut.';

  @override
  String get scheduledLoadFailed =>
      'Die geplante Transaktion konnte nicht geladen werden.';

  @override
  String get scheduledActionFailed =>
      'Die geplante Transaktion konnte nicht aktualisiert werden. Bitte versuchen Sie es erneut.';

  @override
  String get incomeEmpty => 'Kein wiederkehrendes Einkommen eingerichtet';

  @override
  String get incomeAddTitle => 'Gehalt / Einkommen hinzufügen';

  @override
  String get incomeAddButton => 'Einkommen hinzufügen';

  @override
  String get incomeEditTitle => 'Einkommen bearbeiten';

  @override
  String get incomeUnknownSource => 'Unbekannte Quelle';

  @override
  String get incomeSourceName => 'Name der Quelle (z. B. Mein Gehalt)';

  @override
  String get incomeNameRequired => 'Bitte geben Sie einen Namen ein';

  @override
  String get incomeDepositAccount => 'Einzahlungskonto';

  @override
  String get incomeSaveButton => 'Einkommen speichern';

  @override
  String get incomeSaveFailed =>
      'Das Einkommen konnte nicht gespeichert werden. Bitte versuchen Sie es erneut.';

  @override
  String recurrenceEvery(int count, String unit) {
    return 'Alle $count $unit';
  }

  @override
  String get ynabImportTitle => 'YNAB-Migration';

  @override
  String get ynabImportSelectVersion => 'Wählen Sie Ihre YNAB-Version';

  @override
  String get ynabImportMethodCsv => 'nYNAB (CSV-Export)';

  @override
  String get ynabImportMethodYnab4 => 'YNAB 4 (Classic)';

  @override
  String get ynabImportMethodHint =>
      'Für nYNAB: Exportieren Sie Ihr Budget in der Web-App als CSV.\nFür YNAB 4: Wählen Sie Ihren Budget-Ordner (Endung .ynab4).';

  @override
  String get ynabImportUploadCsvTitle => 'CSV-Dateien auswählen';

  @override
  String get ynabImportNotSelected => 'Nicht ausgewählt';

  @override
  String get ynabImportNextPreview => 'Weiter: Vorschau';

  @override
  String get ynabImportSelectFolderTitle => 'YNAB4-Ordner auswählen';

  @override
  String get ynabImportBudgetFolder => 'Budget-Ordner';

  @override
  String get ynabImportPreviewTitle => 'Importvorschau';

  @override
  String get ynabImportPreviewSubtitle =>
      'Prüfen Sie die in Ihren Importdateien gefundenen Daten.';

  @override
  String get ynabImportAccountClosed => 'Geschlossen';

  @override
  String get ynabImportAccountActive => 'Aktiv';

  @override
  String get ynabImportAccountTypeChecking => 'Girokonto';

  @override
  String get ynabImportAccountTypeSavings => 'Sparkonto';

  @override
  String get ynabImportAccountTypeCredit => 'Kreditkarte';

  @override
  String get ynabImportAccountTypeCash => 'Bargeld';

  @override
  String ynabImportAccountSubtitle(String type, String status) {
    return '$type • $status';
  }

  @override
  String ynabImportCategoryCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Kategorien',
      one: '1 Kategorie',
    );
    return '$_temp0';
  }

  @override
  String get ynabImportTotalTransactions => 'Transaktionen gesamt';

  @override
  String get ynabImportBudgetEntries => 'Budgeteinträge';

  @override
  String get ynabImportScheduledTransactions => 'Geplante Transaktionen';

  @override
  String get ynabImportConfirm => 'Bestätigen und importieren';

  @override
  String get ynabImportInProgressTitle => 'Ihr Budget wird übernommen …';

  @override
  String get ynabImportInProgressBody =>
      'Dies kann je nach Umfang Ihres Verlaufs einen Moment dauern.';

  @override
  String get ynabImportDoNotClose =>
      'Bitte schließen Sie die App nicht und wechseln Sie nicht den Bildschirm.';

  @override
  String get ynabImportSuccessTitle => 'Willkommen bei LedgerZero!';

  @override
  String get ynabImportSuccessBody =>
      'Ihre YNAB-Daten wurden erfolgreich übernommen.';

  @override
  String get ynabImportStartBudgeting => 'Mit dem Budgetieren beginnen';

  @override
  String get ynabImportErrorFilePick =>
      'Die Datei konnte nicht geöffnet werden. Bitte versuchen Sie es erneut.';

  @override
  String get ynabImportErrorFolderPick =>
      'Der Ordner konnte nicht geöffnet werden. Bitte versuchen Sie es erneut.';

  @override
  String get ynabImportErrorFilesMissing =>
      'Bitte wählen Sie sowohl Register.csv als auch Budget.csv aus.';

  @override
  String get ynabImportErrorFolderMissing =>
      'Bitte wählen Sie den YNAB-4-Budget-Ordner aus.';

  @override
  String ynabImportErrorMissingColumns(String columns) {
    return 'In Register.csv fehlen erforderliche Spalten: $columns. Bitte exportieren Sie das Register erneut aus YNAB.';
  }

  @override
  String get ynabImportErrorInvalidYnab4 =>
      'Dieser Ordner ist kein gültiges YNAB-4-Budget. Bitte wählen Sie den Ordner mit der Endung .ynab4.';

  @override
  String get ynabImportErrorUnreadable =>
      'Die ausgewählten Dateien konnten nicht gelesen werden. Bitte prüfen Sie, ob es sich um unveränderte YNAB-Exporte handelt.';

  @override
  String get ynabImportErrorImportFailed =>
      'Der Import ist fehlgeschlagen. Es wurden keine Daten geändert; bitte versuchen Sie es erneut.';

  @override
  String get exportFailedGeneric =>
      'Der Export ist fehlgeschlagen. Bitte versuchen Sie es erneut.';

  @override
  String get emptyAccountTransactionsMessage =>
      'Transaktionen, die Sie diesem Konto hinzufügen, erscheinen hier.';

  @override
  String get noMatchingTransactions => 'Keine passenden Transaktionen';

  @override
  String get noMatchingTransactionsMessage =>
      'Versuchen Sie eine andere Suche oder setzen Sie die Filter zurück.';

  @override
  String get emptyTransactionsMessage =>
      'Erfassen Sie Ihre erste Transaktion, um sie hier zu sehen.';

  @override
  String get clearFilters => 'Filter zurücksetzen';

  @override
  String get rules => 'Regeln';

  @override
  String get rulesSettingsSubtitle =>
      'Neue und importierte Transaktionen automatisch kategorisieren';

  @override
  String get settingsManageSection => 'Daten verwalten';

  @override
  String get importFailedGeneric =>
      'Der Import ist fehlgeschlagen. Bitte prüfen Sie die Datei und versuchen Sie es erneut.';

  @override
  String get clearCacheFailed => 'Der Cache konnte nicht geleert werden.';

  @override
  String get backupAndExport => 'Sicherung & Export';

  @override
  String get exportPlaintextWarning =>
      'Exporte sind nicht verschlüsselt: Jeder, der die Datei erhält, kann sie lesen.';

  @override
  String get exportAllCsv => 'Alle Transaktionen (CSV)';

  @override
  String get exportAllCsvSubtitle => 'Eine Tabelle mit allen Transaktionen';

  @override
  String get exportFilteredCsv => 'Gefilterte Transaktionen (CSV)';

  @override
  String get exportFilteredCsvSubtitle =>
      'Zeitraum, Konten und Kategorien auswählen';

  @override
  String get exportAllJson => 'Alle Daten (JSON)';

  @override
  String get exportAllJsonSubtitle =>
      'Alle Daten in einem Format, das andere Apps lesen können';

  @override
  String get backupReminderFrequency => 'Sicherungserinnerung';

  @override
  String get startDate => 'Startdatum';

  @override
  String get exportFilterAll => 'Noch keine vorhanden';

  @override
  String get exportFilterHint =>
      'Ist nichts ausgewählt, wird alles exportiert.';

  @override
  String importSelectedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Transaktionen',
      one: '1 Transaktion',
    );
    return '$_temp0';
  }

  @override
  String categoriesImported(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count neue Kategorien importiert',
      one: '1 neue Kategorie importiert',
      zero: 'Keine neuen Kategorien',
    );
    return '$_temp0';
  }

  @override
  String get categoryImportInvalidFile =>
      'Diese Datei ist keine Kategorienliste. Erwartet werden die Spalten Group, Category (und optional Hidden).';

  @override
  String get help => 'Hilfe';

  @override
  String get noMatchingCategories => 'Keine passenden Kategorien';

  @override
  String get noCategoriesYet =>
      'Noch keine Kategorien. Legen Sie zuerst eine Kategoriegruppe an.';

  @override
  String get notificationChannelScheduledName => 'Geplante Transaktionen';

  @override
  String get notificationChannelScheduledDescription =>
      'Erinnerungen an anstehende geplante Transaktionen';

  @override
  String get notificationChannelBackupName => 'Sicherungserinnerungen';

  @override
  String get notificationChannelBackupDescription =>
      'Erinnerungen, Ihre Daten zu sichern';

  @override
  String get notificationChannelSyncName => 'Synchronisierungsstatus';

  @override
  String get notificationChannelSyncDescription =>
      'Benachrichtigungen, wenn eine Synchronisierung fehlschlägt';

  @override
  String get notificationChannelBudgetName => 'Budgetwarnungen';

  @override
  String get notificationChannelBudgetDescription =>
      'Warnungen, wenn eine Kategorie überzogen ist';

  @override
  String get notificationOpenAction => 'Öffnen';

  @override
  String get notificationBackupTitle => 'Sicherungserinnerung';

  @override
  String get notificationBackupBody =>
      'Ihre letzte Sicherung liegt schon eine Weile zurück. Tippen Sie hier, um Ihre Daten zu sichern.';

  @override
  String get notificationSyncFailedTitle => 'Synchronisierung fehlgeschlagen';

  @override
  String get notificationSyncFailedBody =>
      'Ihre Daten konnten nicht synchronisiert werden. Tippen Sie hier, um die Synchronisierungseinstellungen zu öffnen.';

  @override
  String get notificationBudgetAlertTitle => 'Kategorie überzogen';

  @override
  String get notificationBudgetAlertBodyGeneric =>
      'Eine Budgetkategorie ist in diesem Monat überzogen. Tippen Sie hier, um Ihr Budget zu prüfen.';

  @override
  String notificationBudgetAlertBodyAmount(String category, String amount) {
    return '$category ist in diesem Monat um $amount überzogen.';
  }

  @override
  String get onboardingCompleteTitle => 'Alles bereit!';

  @override
  String get onboardingCompleteMessage =>
      'Fügen Sie als Nächstes das Konto hinzu, von dem Sie bezahlen, zum Beispiel Ihr Girokonto. Sein Kontostand ist das Geld, das Sie budgetieren können.';

  @override
  String get onboardingCreateFirstAccount => 'Erstes Konto anlegen';

  @override
  String get onboardingSkipForNow => 'Später';

  @override
  String get firstAccountTitle => 'Beginnen Sie mit einem Konto';

  @override
  String get firstAccountExplanation =>
      'Geben Sie den aktuellen Kontostand eines Kontos ein, das Sie täglich nutzen. Dieser Betrag wird zu „Zu budgetieren“ und kann Ihren Kategorien zugewiesen werden. Weitere Konten können Sie später hinzufügen.';

  @override
  String get budgetNoAccountsMessage =>
      'Legen Sie zuerst ein Konto an: Sein Kontostand ist das Geld, das Sie Ihren Kategorien zuweisen.';

  @override
  String get noAccountsYet => 'Noch keine Konten';

  @override
  String get noMatchingAccounts => 'Keine passenden Konten';

  @override
  String get csvParseFailedGeneric =>
      'Diese Datei konnte nicht als CSV gelesen werden. Bitte prüfen Sie das Format.';

  @override
  String get filePickFailedGeneric => 'Die Datei konnte nicht geöffnet werden.';

  @override
  String get reportNoDataToExport =>
      'Für diesen Bericht gibt es keine Daten zum Exportieren.';

  @override
  String amountSemanticsAvailable(String amount) {
    return '$amount verfügbar';
  }

  @override
  String amountSemanticsOverspent(String amount) {
    return '$amount überzogen';
  }

  @override
  String amountSemanticsBudgeted(String amount) {
    return '$amount budgetiert';
  }

  @override
  String amountSemanticsActivity(String amount) {
    return 'Aktivität $amount';
  }

  @override
  String amountSemanticsBalance(String amount) {
    return 'Saldo $amount';
  }

  @override
  String amountSemanticsToBeBudgeted(String amount) {
    return '$amount zu budgetieren';
  }

  @override
  String amountSemanticsOverbudgeted(String amount) {
    return '$amount zu viel budgetiert';
  }

  @override
  String amountSemanticsInflow(String amount) {
    return 'Einnahme $amount';
  }

  @override
  String amountSemanticsOutflow(String amount) {
    return 'Ausgabe $amount';
  }

  @override
  String amountSemanticsSpentOfBudgeted(String spent, String budgeted) {
    return '$spent von $budgeted ausgegeben';
  }

  @override
  String chartBarSemantics(String items) {
    return 'Balkendiagramm: $items';
  }

  @override
  String chartPieSemantics(String items) {
    return 'Kreisdiagramm: $items';
  }

  @override
  String chartLineSemantics(String series) {
    return 'Liniendiagramm. $series';
  }

  @override
  String chartLineSeriesSemantics(
    String series,
    String start,
    String end,
    String min,
    String max,
    String latest,
  ) {
    return '$series vom $start bis $end: niedrigster Wert $min, höchster Wert $max, zuletzt $latest';
  }

  @override
  String chartBudgetVsActualSemantics(String items) {
    return 'Budget vs. Ist: $items';
  }

  @override
  String chartBudgetVsActualItemSemantics(
    String category,
    String budgeted,
    String actual,
  ) {
    return '$category: $budgeted budgetiert, $actual ausgegeben';
  }

  @override
  String get chartOthers => 'Sonstige';

  @override
  String get chartTotalZero => 'Die Gesamtausgaben betragen null';

  @override
  String get tutorialNext => 'Weiter';

  @override
  String get tutorialFinish => 'Fertig';

  @override
  String get transactionNoPayee => 'Kein Empfänger';

  @override
  String get transactionNotApproved => 'Noch nicht bestätigt';

  @override
  String get transactionStatusReconciled => 'Abgeglichen';

  @override
  String transactionClearStatusTooltip(String status) {
    return '$status. Zum Ändern tippen';
  }

  @override
  String get accountTypeChecking => 'Girokonto';

  @override
  String get accountTypeSavings => 'Sparkonto';

  @override
  String get accountTypeCredit => 'Kreditkarte';

  @override
  String get accountTypeCash => 'Bargeld';

  @override
  String get budgetGoalUnderfunded => 'Unter dem Zielbetrag';

  @override
  String get close => 'Schließen';

  @override
  String get add => 'Hinzufügen';

  @override
  String get unknown => 'Unbekannt';

  @override
  String get fieldRequired => 'Pflichtfeld';

  @override
  String get tapToSelect => 'Zum Auswählen tippen';

  @override
  String get pickerSelectCategory => 'Kategorie wählen';

  @override
  String get pickerSelectPayee => 'Empfänger wählen';

  @override
  String get pickerSelectAccount => 'Konto wählen';

  @override
  String get ruleChooseTemplate => 'Vorlage wählen';

  @override
  String get ruleNeedsCondition => 'Fügen Sie mindestens eine Bedingung hinzu.';

  @override
  String get ruleNeedsAction => 'Fügen Sie mindestens eine Aktion hinzu.';

  @override
  String get ruleDeleteTitle => 'Regel löschen?';

  @override
  String get ruleDeleteMessage => 'Möchten Sie diese Regel wirklich löschen?';

  @override
  String get ruleEditTitle => 'Regel bearbeiten';

  @override
  String get ruleNewTitle => 'Neue Regel';

  @override
  String get ruleUseTemplate => 'Vorlage verwenden';

  @override
  String get ruleNameLabel => 'Name der Regel';

  @override
  String get ruleActive => 'Aktiv';

  @override
  String get ruleConditionsHeading => 'Bedingungen';

  @override
  String get ruleActionsHeading => 'Aktionen';

  @override
  String get ruleMatchLabel => 'Gilt, wenn';

  @override
  String get ruleMatchAll => 'alle Bedingungen zutreffen';

  @override
  String get ruleMatchAny => 'mindestens eine Bedingung zutrifft';

  @override
  String get ruleAddCondition => 'Bedingung hinzufügen';

  @override
  String get ruleAddAction => 'Aktion hinzufügen';

  @override
  String get ruleSave => 'Regel speichern';

  @override
  String get ruleFieldLabel => 'Feld';

  @override
  String get ruleOperatorLabel => 'Vergleich';

  @override
  String get ruleValueLabel => 'Wert';

  @override
  String get ruleActionLabel => 'Aktion';

  @override
  String get ruleFieldPayee => 'Empfänger';

  @override
  String get ruleFieldAmount => 'Betrag';

  @override
  String get ruleFieldDescription => 'Notiz / Verwendungszweck';

  @override
  String get ruleOperatorEquals => 'ist gleich';

  @override
  String get ruleOperatorContains => 'enthält';

  @override
  String get ruleOperatorStartsWith => 'beginnt mit';

  @override
  String get ruleOperatorEndsWith => 'endet mit';

  @override
  String get ruleOperatorGreaterThan => 'ist größer als';

  @override
  String get ruleOperatorLessThan => 'ist kleiner als';

  @override
  String get ruleOperatorRegex => 'entspricht Muster (Regex)';

  @override
  String get ruleActionSetCategory => 'Kategorie setzen';

  @override
  String get ruleActionSetPayee => 'Empfänger setzen';

  @override
  String get ruleActionSetAccount => 'Konto setzen';

  @override
  String get ruleActionSetMemo => 'Notiz setzen';

  @override
  String get ruleActionMarkCleared => 'Als gebucht markieren';

  @override
  String get ruleActionMarkApproved => 'Als bestätigt markieren';

  @override
  String ruleActionSummarySetCategory(String name) {
    return 'Kategorie auf „$name“ setzen';
  }

  @override
  String ruleActionSummarySetPayee(String name) {
    return 'Empfänger auf „$name“ setzen';
  }

  @override
  String ruleActionSummarySetAccount(String name) {
    return 'Konto auf „$name“ setzen';
  }

  @override
  String ruleActionSummarySetMemo(String memo) {
    return 'Notiz auf „$memo“ setzen';
  }

  @override
  String ruleActionSummaryFlag(String action, String value) {
    return '$action: $value';
  }

  @override
  String get ruleTemplatePayeeTitle => 'Nach Empfängername kategorisieren';

  @override
  String get ruleTemplatePayeeDescription =>
      'Setzt eine Kategorie, wenn der Empfängername ein Stichwort enthält.';

  @override
  String get ruleTemplateAutoClearTitle => 'Kleinbeträge als gebucht markieren';

  @override
  String get ruleTemplateAutoClearDescription =>
      'Markiert Transaktionen unter einem bestimmten Betrag als gebucht.';

  @override
  String get ruleTemplateAutoApproveTitle =>
      'Wiederkehrende Rechnung bestätigen';

  @override
  String get ruleTemplateAutoApproveDescription =>
      'Bestätigt Transaktionen eines Empfängers automatisch (z. B. Netflix).';

  @override
  String get ruleTemplateKeywordTitle => 'Nach Stichwort kategorisieren';

  @override
  String get ruleTemplateKeywordDescription =>
      'Setzt eine Kategorie anhand eines Stichworts in Notiz oder Verwendungszweck.';

  @override
  String get ruleTemplateKeywordExample => 'Kaffee';

  @override
  String rulesImported(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Regeln importiert',
      one: '1 Regel importiert',
      zero: 'Keine Regeln importiert',
    );
    return '$_temp0';
  }

  @override
  String get rulesNoneToApply => 'Es gibt keine Regeln zum Anwenden.';

  @override
  String get rulesApplyTitle => 'Regeln anwenden?';

  @override
  String get rulesApplyMessage =>
      'Alle vorhandenen Transaktionen werden geprüft und die aktiven Regeln angewendet. Dies lässt sich nicht automatisch rückgängig machen.';

  @override
  String rulesApplied(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Transaktionen aktualisiert',
      one: '1 Transaktion aktualisiert',
      zero: 'Keine Transaktionen geändert',
    );
    return '$_temp0';
  }

  @override
  String get rulesMenuImport => 'Regeln importieren';

  @override
  String get rulesMenuExport => 'Regeln exportieren';

  @override
  String get rulesMenuApplyAll => 'Auf alle Transaktionen anwenden';

  @override
  String get rulesMenuSuggest => 'Regeln aus dem Verlauf vorschlagen';

  @override
  String rulesConflictsFound(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Regelkonflikte gefunden',
      one: '1 Regelkonflikt gefunden',
    );
    return '$_temp0';
  }

  @override
  String get rulesConflictsTitle => 'Regelkonflikte';

  @override
  String rulesConflictPair(String first, String second) {
    return '$first vs. $second';
  }

  @override
  String get rulesConflictExplanation =>
      'Gleiche Bedingungen, aber widersprüchliche Aktionen.';

  @override
  String get view => 'Anzeigen';

  @override
  String get rulesEmpty => 'Noch keine Regeln';

  @override
  String get rulesCreate => 'Regel erstellen';

  @override
  String get rulesReorderFailed =>
      'Die neue Reihenfolge konnte nicht gespeichert werden.';

  @override
  String ruleConditionCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Bedingungen',
      one: '1 Bedingung',
    );
    return '$_temp0';
  }

  @override
  String ruleActionCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Aktionen',
      one: '1 Aktion',
    );
    return '$_temp0';
  }

  @override
  String ruleSummary(String conditions, String actions) {
    return '$conditions, $actions';
  }

  @override
  String get rulesNoSuggestions =>
      'In Ihrem Verlauf wurden keine Vorschläge gefunden.';

  @override
  String get rulesSuggestedTitle => 'Vorgeschlagene Regeln';

  @override
  String get ruleAdded => 'Regel hinzugefügt';

  @override
  String ruleSuggestionName(String payee) {
    return '$payee automatisch kategorisieren';
  }

  @override
  String ruleSuggestionDescription(String payee) {
    return 'Transaktionen von $payee haben fast immer dieselbe Kategorie.';
  }

  @override
  String get accountSearchHint => 'Konten durchsuchen';

  @override
  String get clearSearch => 'Suche löschen';

  @override
  String get filter => 'Filtern';

  @override
  String get sort => 'Sortieren';

  @override
  String get accountShowClosed => 'Geschlossene Konten anzeigen';

  @override
  String get accountSortNameAsc => 'Name (A–Z)';

  @override
  String get accountSortNameDesc => 'Name (Z–A)';

  @override
  String get accountSortBalanceAsc => 'Saldo (niedrigster zuerst)';

  @override
  String get accountSortBalanceDesc => 'Saldo (höchster zuerst)';

  @override
  String get accountSortType => 'Kontotyp';

  @override
  String get draftRestored => 'Entwurf wiederhergestellt';

  @override
  String get accountUpdated => 'Konto aktualisiert';

  @override
  String get accountCreated => 'Konto angelegt';

  @override
  String get unsavedChangesTitle => 'Änderungen verwerfen?';

  @override
  String get unsavedChangesMessage =>
      'Sie haben ungespeicherte Änderungen. Möchten Sie sie verwerfen?';

  @override
  String get discard => 'Verwerfen';

  @override
  String get editAccount => 'Konto bearbeiten';

  @override
  String get addAccount => 'Konto hinzufügen';

  @override
  String get accountNameLabel => 'Kontoname';

  @override
  String get accountNameHint => 'z. B. Girokonto Sparkasse';

  @override
  String get accountNameHelper => 'Ein Name, an dem Sie das Konto erkennen';

  @override
  String get accountNameRequired => 'Bitte geben Sie einen Kontonamen ein';

  @override
  String get accountTypeLabel => 'Kontotyp';

  @override
  String get accountTypeHelper => 'Wählen Sie die Art des Kontos';

  @override
  String get startingBalanceLabel => 'Anfangssaldo';

  @override
  String get startingBalanceHelper => 'Der aktuelle Kontostand';

  @override
  String get invalidNumber => 'Ungültige Zahl';

  @override
  String colorOption(int index) {
    return 'Farbe $index';
  }

  @override
  String get saveChanges => 'Änderungen speichern';

  @override
  String get accountIconWallet => 'Geldbörse';

  @override
  String get accountIconBank => 'Bank';

  @override
  String get accountIconCard => 'Karte';

  @override
  String get accountIconCash => 'Bargeld';

  @override
  String get accountIconSavings => 'Sparschwein';

  @override
  String get accountIconInvestment => 'Geldanlage';

  @override
  String selectedCount(int count) {
    return '$count ausgewählt';
  }

  @override
  String get closeSelection => 'Auswahl beenden';

  @override
  String get back => 'Zurück';

  @override
  String get deleteSelected => 'Auswahl löschen';

  @override
  String get approveSelected => 'Auswahl bestätigen';

  @override
  String get categorizeSelected => 'Auswahl kategorisieren';

  @override
  String get selectAll => 'Alle auswählen';

  @override
  String get filters => 'Filter';

  @override
  String get status => 'Status';

  @override
  String get noAccountsFound => 'Keine Konten gefunden';

  @override
  String get noCategoriesFound => 'Keine Kategorien gefunden';

  @override
  String get selectDateRange => 'Zeitraum wählen';

  @override
  String dateRangeValue(String start, String end) {
    return '$start – $end';
  }

  @override
  String get quickAddHint => 'z. B. „Pizza bei Mario 15 €“';

  @override
  String quickAddConfidence(int percent) {
    return '$percent % Treffer';
  }

  @override
  String get quickAddExamplesHeading => 'Beispiele:';

  @override
  String get quickAddDetectsHeading => 'Die App erkennt:';

  @override
  String get quickAddExample1 => '„Mittagessen 15“';

  @override
  String get quickAddExample2 => '„Kaffee 3,50 € bei Starbucks“';

  @override
  String get quickAddExample3 => '„Tanken 60 gestern“';

  @override
  String get quickAddExample4 => '„Gehalt 3000“ (Einnahme)';

  @override
  String bulletItem(String text) {
    return '• $text';
  }

  @override
  String get quickAddTipsTooltip => 'Tipps';

  @override
  String get tutTxAmountTitle => 'Betrag eingeben';

  @override
  String get tutTxAmountBody => 'Geben Sie zuerst den Betrag ein.';

  @override
  String get tutTxPayeeTitle => 'Empfänger wählen';

  @override
  String get tutTxPayeeBody =>
      'Wählen Sie, an wen Sie gezahlt haben oder wer Sie bezahlt hat. Neue Empfänger werden automatisch gespeichert.';

  @override
  String get tutTxCategoryTitle => 'Kategorie zuweisen';

  @override
  String get tutTxCategoryBody =>
      'Mit der Kategorie wird Ihr Budget aktualisiert.';

  @override
  String get tutTxSaveTitle => 'Speichern';

  @override
  String get tutTxSaveBody =>
      'Tippen Sie hier zum Speichern. Mit „Speichern & Weiter“ bleibt das Formular für die nächste Transaktion offen.';

  @override
  String get tutBudgetWelcomeTitle => 'Willkommen in Ihrem Budget';

  @override
  String get tutBudgetWelcomeBody => 'Hier planen Sie Ihre Ausgaben.';

  @override
  String get tutBudgetMonthTitle => 'Monat wählen';

  @override
  String get tutBudgetMonthBody =>
      'Wechseln Sie den Monat, um vorauszuplanen oder frühere Budgets anzusehen.';

  @override
  String get tutBudgetTbbTitle => 'Zu budgetieren';

  @override
  String get tutBudgetTbbBody =>
      'Geld, das Sie noch nicht zugewiesen haben. Verteilen Sie es auf Kategorien, bis hier null steht.';

  @override
  String get tutBudgetCategoriesTitle => 'Kategorien';

  @override
  String get tutBudgetCategoriesBody =>
      'Tippen Sie auf eine Kategorie, um Geld zuzuweisen. Sie können Geld auch zwischen Kategorien verschieben.';

  @override
  String get tutSyncProviderTitle => 'Speicherdienst wählen';

  @override
  String get tutSyncProviderBody =>
      'Synchronisieren Sie über Ihr eigenes Google Drive. Ihre Daten werden verschlüsselt, bevor sie dieses Gerät verlassen.';

  @override
  String get tutSyncConnectTitle => 'Verbinden';

  @override
  String get tutSyncConnectBody =>
      'Melden Sie sich an und legen Sie eine Sync-Passphrase fest. Dieselbe Passphrase geben Sie auf jedem Ihrer Geräte ein.';

  @override
  String get accessibilityVisualSection => 'Darstellung';

  @override
  String get highContrastTitle => 'Hoher Kontrast';

  @override
  String get highContrastSubtitle => 'Stärkerer Kontrast für Farben und Rahmen';

  @override
  String get faqBudgetingQ => 'Wie funktioniert das Umschlagprinzip?';

  @override
  String get faqBudgetingA =>
      'Sie geben jedem Euro eine Aufgabe: Verteilen Sie Ihr Geld auf Kategorien, bis „Zu budgetieren“ bei null steht. Ausgegeben wird, was in einer Kategorie verfügbar ist. Wenn Sie zu viel ausgeben, gleichen Sie das mit Geld aus einer anderen Kategorie aus.';

  @override
  String get faqSafeQ => 'Sind meine Daten sicher?';

  @override
  String get faqSafeA =>
      'Ihre Daten liegen nur auf Ihrem Gerät, in einer mit AES-256 verschlüsselten Datenbank, die Ihr Master-Passwort entsperrt. Wenn Sie die Synchronisierung nutzen, werden die Daten mit Ihrer Sync-Passphrase verschlüsselt, bevor sie das Gerät verlassen. Es gibt keine LedgerZero-Server, kein Tracking und keine Analyse.';

  @override
  String get faqSyncQ => 'Wie synchronisiere ich mehrere Geräte?';

  @override
  String get faqSyncA =>
      'Öffnen Sie Einstellungen > Synchronisierung, wählen Sie Google Drive und melden Sie sich an. Auf dem ersten Gerät legen Sie eine Sync-Passphrase fest, auf allen weiteren Geräten geben Sie dieselbe ein. Bewahren Sie sie gut auf: Sie lässt sich nicht wiederherstellen.';

  @override
  String get faqOfflineQ => 'Funktioniert die App offline?';

  @override
  String get faqOfflineA =>
      'Ja. Alles funktioniert offline. Die Synchronisierung holt Änderungen automatisch nach, sobald Sie wieder online sind.';

  @override
  String get faqPasswordQ => 'Was, wenn ich mein Master-Passwort vergesse?';

  @override
  String get faqPasswordA =>
      'Entsperren Sie mit dem Wiederherstellungsschlüssel, den Sie bei der Einrichtung notiert haben, und wählen Sie ein neues Passwort. Ohne Passwort und Wiederherstellungsschlüssel kann niemand Ihre Daten entsperren, auch nicht der Entwickler.';

  @override
  String get faqBackupQ => 'Wie funktionieren Sicherungen?';

  @override
  String get faqBackupA =>
      'Unter Einstellungen > Sicherung & Export erstellen Sie eine Sicherungsdatei, die immer mit einem Sicherungspasswort Ihrer Wahl verschlüsselt ist. Ohne dieses Passwort lässt sich die Sicherung nicht wiederherstellen. CSV- und JSON-Exporte sind lesbare Kopien und nicht verschlüsselt.';

  @override
  String get faqImportQ =>
      'Kann ich Daten aus YNAB oder von meiner Bank übernehmen?';

  @override
  String get faqImportA =>
      'Ja. Einstellungen > YNAB-Migration übernimmt CSV-Exporte aus nYNAB und Budgets aus YNAB 4. Einstellungen > CSV importieren liest den CSV-Export Ihrer Bank.';

  @override
  String get guideStartTitle => '1. Erste Schritte';

  @override
  String get guideStartBody =>
      'LedgerZero arbeitet nach dem Nullsummen-Umschlagprinzip: Bevor Sie Geld ausgeben, geben Sie ihm eine Aufgabe, indem Sie es einer Kategorie zuweisen.';

  @override
  String get guideAccountsTitle => '2. Konten';

  @override
  String get guideAccountsBody =>
      'Legen Sie die Konten an, von denen Sie bezahlen (Girokonto, Sparkonto, Kreditkarte, Bargeld), jeweils mit dem aktuellen Kontostand. Dieses Geld können Sie budgetieren: Es erscheint unter „Zu budgetieren“.';

  @override
  String get guideBudgetTitle => '3. Budgetieren';

  @override
  String get guideBudgetBody =>
      'Tippen Sie im Budget auf den budgetierten Betrag einer Kategorie, um Geld zuzuweisen, bis „Zu budgetieren“ bei null steht. Einnahmen ohne Kategorie erhöhen „Zu budgetieren“.';

  @override
  String get guideTransactionsTitle => '4. Transaktionen';

  @override
  String get guideTransactionsBody =>
      'Erfassen Sie jede Ausgabe mit Empfänger und Kategorie; sie verringert den verfügbaren Betrag der Kategorie. Mit der Schnelleingabe tippen Sie eine Transaktion in einer Zeile ein, und Regeln kategorisieren importierte Transaktionen automatisch.';

  @override
  String get guideOverspendingTitle => '5. Überzogene Kategorien';

  @override
  String get guideOverspendingBody =>
      'Wird der verfügbare Betrag einer Kategorie rot, haben Sie mehr ausgegeben als budgetiert. Verschieben Sie Geld aus einer anderen Kategorie, um das auszugleichen.';

  @override
  String get guideReconcileTitle => '6. Abgleichen';

  @override
  String get guideReconcileBody =>
      'Gleichen Sie ein Konto ab und zu mit Ihrem Kontoauszug ab: über „Konto abgleichen“ auf der Kontoseite. Gebuchte Transaktionen werden als abgeglichen markiert, eine Differenz wird als Ausgleichsbuchung erfasst.';

  @override
  String get guideSyncTitle => '7. Synchronisierung und Sicherungen';

  @override
  String get guideSyncBody =>
      'Die Synchronisierung hält Ihre Smartphones und Tablets über Ihr eigenes Google Drive aktuell, Ende-zu-Ende-verschlüsselt mit Ihrer Sync-Passphrase. Erstellen Sie regelmäßig verschlüsselte Sicherungen unter Einstellungen > Sicherung & Export.';

  @override
  String get next => 'Weiter';

  @override
  String get getStarted => 'Los geht\'s';

  @override
  String get onbWelcomeTagline =>
      'Privates Budgetieren, das auf Ihrem Gerät bleibt';

  @override
  String get onbWelcomeBody =>
      'Behalten Sie Ihr Geld mit dem Umschlagprinzip im Griff: ohne Registrierung, ohne Server, ohne Tracking.';

  @override
  String get onbBenefitsTitle => 'Warum LedgerZero?';

  @override
  String get onbBenefitPriceTitle => 'Kein Abo';

  @override
  String get onbBenefitPriceBody => 'Einmal kaufen, keine laufenden Gebühren.';

  @override
  String get onbBenefitDataTitle => 'Ihre Daten bleiben bei Ihnen';

  @override
  String get onbBenefitDataBody => 'Verschlüsselt auf Ihrem Gerät gespeichert.';

  @override
  String get onbBenefitOfflineTitle => 'Funktioniert offline';

  @override
  String get onbBenefitOfflineBody =>
      'Alles funktioniert ohne Internetverbindung. Kein Server nötig.';

  @override
  String get onbPrivacyTitle => 'Ihre Daten, Ihr Gerät';

  @override
  String get onbPrivacyIntro => 'Datenschutz ab Werk. Das heißt:';

  @override
  String get onbPrivacyNoTracking =>
      'Kein Tracking, keine Analyse, keine Telemetrie.';

  @override
  String get onbPrivacyEncrypted =>
      'Alle Daten werden auf Ihrem Gerät mit AES-256 verschlüsselt.';

  @override
  String get onbPrivacyOwnCloud =>
      'Wir sehen Ihre Finanzdaten nie. Die Synchronisierung läuft Ende-zu-Ende-verschlüsselt über Ihr eigenes Google Drive.';

  @override
  String get budgetBasicsTitle => 'Budget-Grundlagen';

  @override
  String get budgetBasicsHeadline => 'Geben Sie jedem Euro eine Aufgabe';

  @override
  String get budgetBasicsBody1 =>
      'LedgerZero arbeitet nach dem Umschlagprinzip. Stellen Sie sich Umschläge für Miete, Lebensmittel und Freizeit vor: Wenn Ihr Gehalt kommt, verteilen Sie das Geld auf diese Umschläge.';

  @override
  String get budgetBasicsBody2 =>
      'Ist ein Umschlag leer, geben Sie in dieser Kategorie nichts mehr aus oder holen Geld aus einem anderen Umschlag.';

  @override
  String get budgetBasicsTipZeroTitle => 'Alles verplant';

  @override
  String get budgetBasicsTipZeroBody =>
      'Verteilen Sie Geld, bis „Zu budgetieren“ bei null steht.';

  @override
  String get budgetBasicsTipFlexTitle => 'Flexibel bleiben';

  @override
  String get budgetBasicsTipFlexBody =>
      'Zu viel ausgegeben? Kein Problem: Verschieben Sie Geld aus einer anderen Kategorie.';

  @override
  String get budgetBasicsReady => 'Los geht\'s!';

  @override
  String get categoryGroupRequired => 'Bitte wählen Sie eine Kategoriegruppe';

  @override
  String categoryUsage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'In $count Transaktionen verwendet',
      one: 'In 1 Transaktion verwendet',
      zero: 'In keiner Transaktion verwendet',
    );
    return '$_temp0';
  }

  @override
  String get nameRequired => 'Bitte geben Sie einen Namen ein';

  @override
  String get categoryTipsTitle => 'Tipps für Kategorien';

  @override
  String get categoryTipsBody =>
      '• Fassen Sie ähnliche Ausgaben zusammen (z. B. Wohnen, Lebensmittel).\n• Blenden Sie eine Kategorie aus, statt sie zu löschen, damit ihr Verlauf erhalten bleibt.\n• Symbole oder Emojis helfen, Kategorien schnell zu erkennen.\n• Einfach anfangen: Beginnen Sie mit groben Kategorien und teilen Sie sie bei Bedarf später auf.';

  @override
  String get moveMoneySameCategory =>
      'Quell- und Zielkategorie müssen verschieden sein';

  @override
  String get selectCategoryRequired => 'Bitte wählen Sie eine Kategorie';

  @override
  String get calculatorBackspace => 'Letzte Ziffer löschen';

  @override
  String get skipToContent => 'Zum Inhalt springen';

  @override
  String get payeeMatchesSection => 'Treffer';

  @override
  String get payeeSimilarSection => 'Ähnlich';

  @override
  String payeeSimilarity(int percent) {
    return '$percent % Übereinstimmung';
  }

  @override
  String payeeNoResults(String query) {
    return 'Keine Empfänger für „$query“ gefunden';
  }

  @override
  String get reportPdfDataColumn => 'Daten';

  @override
  String reportPdfCreatedOn(String date) {
    return 'Erstellt am $date';
  }

  @override
  String get reportPdfFooter => 'Erstellt mit LedgerZero';

  @override
  String reportPdfPageOf(int page, int pages) {
    return 'Seite $page von $pages';
  }

  @override
  String reportShareText(String title) {
    return 'LedgerZero-Bericht: $title';
  }

  @override
  String get reportIncomeSeries => 'Einnahmen';

  @override
  String get reportExpenseSeries => 'Ausgaben';

  @override
  String get csvFileEmpty => 'Die CSV-Datei enthält keine Daten.';

  @override
  String fileSizeKb(double size) {
    final intl.NumberFormat sizeNumberFormat =
        intl.NumberFormat.decimalPatternDigits(
          locale: localeName,
          decimalDigits: 1,
        );
    final String sizeString = sizeNumberFormat.format(size);

    return '$sizeString KB';
  }

  @override
  String get csvIssueDateNotMapped => 'Wählen Sie die Spalte mit dem Datum.';

  @override
  String get csvIssueAmountNotMapped => 'Wählen Sie die Spalte mit dem Betrag.';

  @override
  String get csvIssueColumnsMissing =>
      'Die gewählten Spalten gibt es in dieser Datei nicht.';

  @override
  String csvIssueInvalidDates(int count, String format) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count Zeilen haben ein Datum, das nicht zum Format $format passt.',
      one: '1 Zeile hat ein Datum, das nicht zum Format $format passt.',
    );
    return '$_temp0';
  }

  @override
  String csvIssueInvalidAmounts(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Zeilen haben unlesbare Beträge und werden übersprungen.',
      one: '1 Zeile hat einen unlesbaren Betrag und wird übersprungen.',
    );
    return '$_temp0';
  }

  @override
  String csvIssueDateOutliers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count Daten weichen stark von den anderen ab. Bitte prüfen Sie sie in der Übersicht.',
      one:
          '1 Datum weicht stark von den anderen ab. Bitte prüfen Sie es in der Übersicht.',
    );
    return '$_temp0';
  }

  @override
  String labelValue(String label, String value) {
    return '$label: $value';
  }

  @override
  String integerValue(int value) {
    final intl.NumberFormat valueNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String valueString = valueNumberFormat.format(value);

    return '$valueString';
  }

  @override
  String get syncErrorNetwork =>
      'Keine Verbindung zum Cloud-Speicher. Die Synchronisierung wird erneut versucht, sobald Sie online sind.';

  @override
  String get syncErrorNotSignedIn =>
      'Sie sind nicht angemeldet. Bitte verbinden Sie sich erneut.';

  @override
  String get syncErrorAuthFailed =>
      'Die Anmeldung ist abgelaufen. Bitte trennen Sie die Verbindung und verbinden Sie sich erneut.';

  @override
  String get syncErrorStorageFull =>
      'Ihr Cloud-Speicher ist voll. Geben Sie Speicherplatz frei, um weiter zu synchronisieren.';

  @override
  String get transactionsShareText => 'LedgerZero-Transaktionen (CSV)';

  @override
  String get payeesShareText => 'LedgerZero-Empfänger (CSV)';

  @override
  String get dataExportShareText => 'LedgerZero-Datenexport (JSON)';

  @override
  String get rulesShareText => 'LedgerZero-Regeln';

  @override
  String get seedGroupImmediate => 'Laufende Fixkosten';

  @override
  String get seedCatRent => 'Miete/Kredit';

  @override
  String get seedCatElectric => 'Strom';

  @override
  String get seedCatWater => 'Wasser';

  @override
  String get seedCatInternet => 'Internet & Telefon';

  @override
  String get seedCatGroceries => 'Lebensmittel';

  @override
  String get seedCatTransportation => 'Mobilität';

  @override
  String get seedGroupTrueExpenses => 'Unregelmäßige Ausgaben';

  @override
  String get seedCatMedical => 'Gesundheit';

  @override
  String get seedCatAutoMaintenance => 'Auto-Werkstatt';

  @override
  String get seedCatHomeMaintenance => 'Reparaturen Wohnung';

  @override
  String get seedCatInsurance => 'Versicherungen';

  @override
  String get seedCatSubscriptions => 'Abos & Software';

  @override
  String get seedGroupDebt => 'Kredite & Schulden';

  @override
  String get seedCatStudentLoan => 'Studienkredit';

  @override
  String get seedCatCarPayment => 'Autokredit';

  @override
  String get seedCatCreditCard => 'Kreditkarte';

  @override
  String get seedGroupQualityOfLife => 'Lebensqualität';

  @override
  String get seedCatVacation => 'Urlaub';

  @override
  String get seedCatFitness => 'Sport & Fitness';

  @override
  String get seedCatEducation => 'Bildung';

  @override
  String get seedCatDiningOut => 'Essen gehen';

  @override
  String get seedCatEntertainment => 'Freizeit';

  @override
  String get seedGroupFun => 'Vergnügen';

  @override
  String get seedCatGaming => 'Spiele';

  @override
  String get seedCatMusic => 'Musik';

  @override
  String get seedCatFunMoney => 'Taschengeld';

  @override
  String get syncFieldName => 'Name';

  @override
  String importUnmatchedCategories(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count Zeilen nennen eine Kategorie, die es nicht gibt. Sie werden ohne Kategorie importiert, sofern keine Regel und keine Standardkategorie des Empfängers eine zuweist.',
      one:
          '1 Zeile nennt eine Kategorie, die es nicht gibt. Sie wird ohne Kategorie importiert, sofern keine Regel und keine Standardkategorie des Empfängers eine zuweist.',
    );
    return '$_temp0';
  }

  @override
  String importCategoryNotFound(String name) {
    return 'Kategorie „$name“ nicht gefunden – ohne Kategorie';
  }

  @override
  String ynabImportErrorInvalidDates(String value) {
    return 'Die Datumsangaben in Register.csv passen zu keinem einheitlichen Datumsformat (MM/dd/yyyy, dd/MM/yyyy, yyyy-MM-dd oder dd.MM.yyyy). Erstes unlesbares Datum: „$value“. Exportieren Sie das Budget erneut aus YNAB oder korrigieren Sie die Datumsspalte.';
  }

  @override
  String get ynabImportCurrency => 'Währung der importierten Konten';

  @override
  String get ynabImportTrackingAccount =>
      'Tracking-Konto – wird nicht importiert';

  @override
  String ynabImportTrackingSkipped(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count Tracking-Konten wurden nicht importiert. Überweisungen zwischen diesen Konten und Ihren Budgetkonten wurden als Ausgänge und Eingänge der Budgetkonten importiert.',
      one:
          '1 Tracking-Konto wurde nicht importiert. Überweisungen zwischen diesem Konto und Ihren Budgetkonten wurden als Ausgänge und Eingänge der Budgetkonten importiert.',
    );
    return '$_temp0';
  }

  @override
  String get loginResetApp => 'App zurücksetzen';

  @override
  String get loginResetAppTitle => 'LedgerZero zurücksetzen?';

  @override
  String loginResetAppBody(String word) {
    return 'Ohne den Schlüsseltresor lassen sich Ihre Daten nicht entsperren. Das Zurücksetzen löscht die verschlüsselte Datenbank, alle Schlüssel, Einstellungen und exportierten Dateien auf diesem Gerät und startet die Einrichtung neu; anschließend können Sie eine Sicherung wiederherstellen. Dies kann nicht rückgängig gemacht werden. Geben Sie zur Bestätigung $word ein.';
  }

  @override
  String get loginResetConfirmWord => 'ZURÜCKSETZEN';

  @override
  String get loginResetConfirmLabel => 'Bestätigungswort';

  @override
  String get amountMustNotBeZero => 'Der Betrag darf nicht null sein.';

  @override
  String get budgetLastMonthSpent => 'Ausgaben des Vormonats budgetieren';

  @override
  String get moveMoneyDone => 'Betrag verschoben';

  @override
  String get accountOnBudgetLabel => 'Im Budget berücksichtigen';

  @override
  String get accountOnBudgetHelper =>
      'Für Ersparnisse oder Geldanlagen ausschalten, die Sie nicht budgetieren möchten. Sie zählen weiterhin zu Ihrem Nettovermögen.';

  @override
  String get accountOnBudgetChangeTitle => 'Budget ändern?';

  @override
  String get accountOnBudgetChangeOff =>
      'Saldo und Buchungen dieses Kontos zählen in keinem Monat mehr zu „Zu budgetieren“. Überweisungen zwischen diesem Konto und Ihren Budgetkonten bringen Geld aus dem Budget heraus oder hinein.';

  @override
  String get accountOnBudgetChangeOn =>
      'Saldo und Buchungen dieses Kontos zählen in jedem Monat wieder zu „Zu budgetieren“.';

  @override
  String get accountOffBudgetBadge => 'Außerhalb des Budgets';

  @override
  String get offBudgetTransactionHint =>
      'Dieses Konto ist außerhalb des Budgets: Seine Buchungen ändern weder Kategorien noch „Zu budgetieren“.';

  @override
  String get homeBalanceInBudget => 'Auf Budgetkonten';

  @override
  String homeBalancePage(int page, int pages) {
    return '$page von $pages';
  }

  @override
  String get homeBalanceNext => 'Nächste Summe anzeigen';

  @override
  String get transferCategoryHint =>
      'Optional. Ohne Kategorie wird der Betrag „Zu budgetieren“ entnommen bzw. gutgeschrieben.';

  @override
  String get seedGroupSavings => 'Sparen & Geldanlage';

  @override
  String get seedCatStocks => 'Aktien & ETFs';

  @override
  String get seedCatCrypto => 'Krypto';

  @override
  String get seedCatBonds => 'Anleihen';

  @override
  String get seedCatRetirement => 'Altersvorsorge';

  @override
  String get savingsOfferTitle => 'Geld zurücklegen?';

  @override
  String get savingsOfferBody =>
      'Fügen Sie eine Gruppe „Sparen & Geldanlage“ hinzu: Liquiditätsreserve, Aktien & ETFs, Krypto, Anleihen und Altersvorsorge. Geld, das Sie dort zuweisen, zählt nicht mehr zu „Zu budgetieren“ und wird jeden Monat übertragen, z. B. eine Reserve, die Sie immer behalten. Zum Investieren überweisen Sie es mit dieser Kategorie auf Ihr Depot außerhalb des Budgets.';

  @override
  String get savingsOfferAdd => 'Kategorien hinzufügen';

  @override
  String get savingsOfferDismiss => 'Nein, danke';

  @override
  String get savingsOfferAdded =>
      'Kategorien für Sparen & Geldanlage hinzugefügt';

  @override
  String get seedCatCashReserve => 'Liquiditätsreserve';

  @override
  String get cardNotifications => 'Kartenbenachrichtigungen';

  @override
  String get cardNotificationsSubtitle =>
      'Kartenzahlungen aus den Benachrichtigungen Ihrer Bank-App übernehmen';

  @override
  String get cardNotificationsIntro =>
      'LedgerZero kann Zahlungsbenachrichtigungen Ihrer Bank-, Karten- oder Wallet-Apps lesen und jede Zahlung als Transaktion zur Prüfung anlegen. Gelesen werden nur die Apps, die Sie hier auswählen; Benachrichtigungen aller anderen Apps werden ignoriert. Alles bleibt auf diesem Gerät.';

  @override
  String get cardNotificationsAccessTitle => 'Zugriff auf Benachrichtigungen';

  @override
  String get cardNotificationsAccessGranted => 'Erteilt';

  @override
  String get cardNotificationsAccessMissing =>
      'Nicht erteilt: Es wird nichts erfasst';

  @override
  String get cardNotificationsGrantAccess => 'Zugriff erteilen';

  @override
  String get cardNotificationsManageAccess =>
      'In den Systemeinstellungen verwalten';

  @override
  String get cardNotificationsDisclosureTitle =>
      'LedgerZero Benachrichtigungen lesen lassen?';

  @override
  String get cardNotificationsDisclosureBody =>
      'Android fragt Sie gleich, ob LedgerZero auf Benachrichtigungen zugreifen darf. Android erteilt diesen Zugriff für alle Apps, LedgerZero liest aber nur Benachrichtigungen der Bank-, Karten- oder Wallet-Apps, die Sie auswählen, und übernimmt daraus nur Betrag, Händler und Zeitpunkt einer Zahlung. Benachrichtigungen werden nirgendwohin gesendet. Erfasste Zahlungen bleiben verschlüsselt auf diesem Gerät, bis LedgerZero das nächste Mal läuft. Sie können den Zugriff jederzeit in den Systemeinstellungen widerrufen.';

  @override
  String get cardNotificationsContinue => 'Weiter';

  @override
  String get cardNotificationsAppsTitle => 'Apps';

  @override
  String get cardNotificationsNoApps => 'Noch keine Apps ausgewählt.';

  @override
  String get cardNotificationsAddApp => 'App hinzufügen';

  @override
  String get cardNotificationsAccountMissing =>
      'Kein Konto gewählt: Zahlungen warten hier';

  @override
  String cardNotificationsRemoveApp(String app) {
    return '$app nicht mehr beobachten';
  }

  @override
  String get cardNotificationsPickAppTitle => 'App auswählen';

  @override
  String get cardNotificationsPickAppHint =>
      'Apps mit sichtbarer Benachrichtigung, Apps mit kürzlichen Benachrichtigungen und installierte Bank-Apps.';

  @override
  String get cardNotificationsNoCandidates =>
      'Keine Apps gefunden. Lassen Sie eine Benachrichtigung Ihrer Bank-App in der Benachrichtigungsleiste und versuchen Sie es erneut.';

  @override
  String get cardNotificationsOriginActive => 'Benachrichtigung sichtbar';

  @override
  String get cardNotificationsOriginRecent => 'Kürzlich benachrichtigt';

  @override
  String get cardNotificationsOriginKnown => 'Bank- oder Wallet-App';

  @override
  String cardNotificationsPickAccountTitle(String app) {
    return 'Zahlungen aus $app buchen auf';
  }

  @override
  String get cardNotificationsNoAccounts => 'Legen Sie zuerst ein Konto an.';

  @override
  String get cardNotificationsHeldTitle => 'Wartet auf Sie';

  @override
  String get cardNotificationsHeldUnreadable => 'Kein Betrag gefunden';

  @override
  String get cardNotificationsHeldNoAccount =>
      'Kein Konto für diese App gewählt';

  @override
  String get cardNotificationsHeldForeignCurrency =>
      'Andere Währung als das Konto';

  @override
  String get cardNotificationsAddManually => 'Hinzufügen';

  @override
  String get cardNotificationsDismiss => 'Verwerfen';

  @override
  String get cardNotificationsHowItWorksTitle => 'So funktioniert es';

  @override
  String get cardNotificationsHowItWorks =>
      'Erfasste Zahlungen erscheinen unter Transaktionen als nicht genehmigt. Wischen Sie nach links, um eine zu genehmigen, oder tippen Sie darauf, um sie zu korrigieren. Zahlungen, die erfasst werden, während LedgerZero geschlossen ist, werden beim nächsten Start hinzugefügt. Abgelehnte Zahlungen, Codes und Kontostandsmeldungen werden übersprungen.';

  @override
  String cardNotificationsAdded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Kartenzahlungen hinzugefügt',
      one: '1 Kartenzahlung hinzugefügt',
    );
    return '$_temp0';
  }

  @override
  String get appLockTitle => 'App-Sperre';

  @override
  String get appLockSubtitle =>
      'Beim Öffnen von LedgerZero nach Fingerabdruck, Gesicht oder Displaysperre fragen';

  @override
  String get appLockNeedsScreenLock =>
      'Richten Sie in den Android-Einstellungen eine Displaysperre ein, um die App-Sperre zu nutzen.';

  @override
  String get appLockPromptTitle => 'LedgerZero entsperren';

  @override
  String get appLockPromptSubtitle =>
      'Mit Fingerabdruck, Gesicht oder Displaysperre';

  @override
  String get appLockTurnedOffNoScreenLock =>
      'Dieses Telefon hat keine Displaysperre mehr, daher wurde die App-Sperre ausgeschaltet.';

  @override
  String get lockScreenTitle => 'LedgerZero ist gesperrt';

  @override
  String get lockScreenKeyError =>
      'LedgerZero kann Ihre Daten nicht öffnen: Der auf diesem Telefon gespeicherte Schlüssel fehlt oder passt nicht zu den Daten. Setzen Sie die App zurück und stellen Sie dann eine Sicherung wieder her oder synchronisieren Sie erneut von Ihrem anderen Telefon.';

  @override
  String get legacyUnlockTitle => 'Ein letztes Mal entsperren';

  @override
  String get legacyUnlockExplanation =>
      'LedgerZero verwendet kein Master-Passwort mehr. Entsperren Sie ein letztes Mal mit Ihrem Passwort oder Wiederherstellungsschlüssel. Danach bewahrt die App ihren Schlüssel im sicheren Schlüsselspeicher dieses Telefons auf, und die App-Sperre nutzt Fingerabdruck, Gesicht oder Displaysperre.';

  @override
  String get setupDeviceHeading => 'Ihre Daten bleiben auf diesem Telefon';

  @override
  String get setupDeviceExplanation =>
      'Ihr Budget wird nur auf diesem Telefon gespeichert, verschlüsselt mit einem Schlüssel, den Android in seinem sicheren Schlüsselspeicher aufbewahrt. Es gibt kein Konto und kein Passwort, das Sie sich merken müssen. Damit Sie mit dem Telefon nichts verlieren, erstellen Sie Sicherungen oder synchronisieren Sie mit einem zweiten Telefon.';

  @override
  String get lockScreenReadError =>
      'LedgerZero konnte seinen Schlüssel gerade nicht aus dem sicheren Schlüsselspeicher dieses Telefons lesen. Ihre Daten sind nicht betroffen. Versuchen Sie es erneut; wenn es weiterhin fehlschlägt, starten Sie das Telefon neu.';

  @override
  String get providerLocalWifi => 'Heim-WLAN (Telefon zu Telefon)';

  @override
  String get lanSyncTitle => 'WLAN-Synchronisierung';

  @override
  String get lanSetupExplanation =>
      'Teilen Sie ein Budget mit einem zweiten Telefon, zum Beispiel dem Ihres Partners, ganz ohne Cloud. Die Telefone synchronisieren, sobald beide im selben WLAN sind und LedgerZero geöffnet ist.';

  @override
  String get lanStart => 'Auf diesem Telefon starten';

  @override
  String get lanStartHint =>
      'Wählen Sie dies auf dem Telefon, das Ihr Budget bereits hat.';

  @override
  String get lanJoin => 'Dem anderen Telefon beitreten';

  @override
  String get lanJoinHint =>
      'Wählen Sie dies auf dem zweiten Telefon. Seine Daten werden in das gemeinsame Budget übernommen.';

  @override
  String get lanPairPhone => 'Telefon koppeln';

  @override
  String get lanShowCodeInstructions =>
      'Öffnen Sie auf dem anderen Telefon Einstellungen > Synchronisierung, wählen Sie Heim-WLAN, tippen Sie auf „Dem anderen Telefon beitreten“ und scannen Sie diesen Code. Beide Telefone müssen im selben WLAN sein und LedgerZero geöffnet haben.';

  @override
  String get lanShowCodeWarning =>
      'Dieser Code gewährt Zugriff auf Ihr Budget. Zeigen Sie ihn nur Telefonen, denen Sie vertrauen.';

  @override
  String get lanCodeTextLabel =>
      'Scannen klappt nicht? Geben Sie diesen Code auf dem anderen Telefon ein:';

  @override
  String get lanScanTitle => 'Kopplungscode scannen';

  @override
  String get lanEnterCode => 'Stattdessen Code eingeben';

  @override
  String get lanEnterCodeTitle => 'Kopplungscode';

  @override
  String get lanEnterCodeHint => 'Beginnt mit lzpair1:';

  @override
  String get lanCameraUnavailable =>
      'Die Kamera ist nicht verfügbar. Geben Sie stattdessen den Code ein.';

  @override
  String get lanJoining => 'Verbindung zum anderen Telefon wird hergestellt…';

  @override
  String get lanStarted =>
      'Die WLAN-Synchronisierung ist an. Koppeln Sie ein zweites Telefon, um das Budget zu teilen.';

  @override
  String get lanJoined => 'Gekoppelt. Das Budget wird jetzt geteilt.';

  @override
  String get lanInvalidCode => 'Das ist kein LedgerZero-Kopplungscode.';

  @override
  String get lanPhoneNotFound =>
      'Das andere Telefon ist nicht erreichbar. Achten Sie darauf, dass beide Telefone im selben WLAN sind und LedgerZero auf dem anderen Telefon geöffnet ist.';

  @override
  String get lanSetupFailed =>
      'Die WLAN-Synchronisierung konnte nicht eingerichtet werden.';

  @override
  String get lanPeersTitle => 'Gekoppelte Telefone';

  @override
  String get lanNoPeers => 'Noch kein Telefon gekoppelt.';

  @override
  String lanPeerLastSync(String time) {
    return 'Zuletzt synchronisiert $time';
  }

  @override
  String get lanPeerNeverSynced => 'Noch nicht synchronisiert';

  @override
  String get lanTurnOff => 'WLAN-Synchronisierung ausschalten';

  @override
  String get syncErrorPairingMismatch =>
      'Dieses und das andere Telefon wurden mit unterschiedlichen Codes gekoppelt. Schalten Sie die WLAN-Synchronisierung auf diesem Telefon aus und koppeln Sie es erneut.';
}
