class BankImportPreset {
  final String name;
  final Map<String, String> columnMapping;
  final String dateFormat;
  final bool outflowIsNegative;

  const BankImportPreset({
    required this.name,
    required this.columnMapping,
    required this.dateFormat,
    required this.outflowIsNegative,
  });
}

class BankImportPresets {
  static const List<BankImportPreset> presets = [
    BankImportPreset(
      name: 'Chase Bank',
      columnMapping: {
        'Date': 'Posting Date',
        'Amount': 'Amount',
        'Payee': 'Description',
        'Memo': 'Type', // Sometimes useful
      },
      dateFormat: 'MM/dd/yyyy',
      outflowIsNegative: true,
    ),
    BankImportPreset(
      name: 'Bank of America',
      columnMapping: {
        'Date': 'Date',
        'Amount': 'Amount',
        'Payee': 'Description',
      },
      dateFormat: 'MM/dd/yyyy',
      outflowIsNegative: true,
    ),
    BankImportPreset(
      name: 'Wells Fargo',
      columnMapping: {
        'Date': 'Date',
        'Amount': 'Amount',
        'Payee': 'Description', // Actually 5th column usually
      },
      dateFormat: 'MM/dd/yyyy',
      outflowIsNegative: true,
    ),
    BankImportPreset(
      name: 'Citibank',
      columnMapping: {
        'Date': 'Date',
        'Amount':
            'Debit', // Or Credit, requires careful handling or custom logic
        'Payee': 'Description',
      },
      dateFormat: 'MM/dd/yyyy',
      outflowIsNegative: false, // Often split into Debit/Credit columns
    ),
  ];
}
