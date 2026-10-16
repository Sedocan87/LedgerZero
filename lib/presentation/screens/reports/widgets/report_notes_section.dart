import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledger_zero/core/time/calendar_date.dart';
import 'package:ledger_zero/domain/entities/report_note.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/providers/formatter_provider.dart';
import 'package:ledger_zero/presentation/providers/repository_providers.dart';
import 'package:ledger_zero/presentation/screens/reports/providers/report_providers.dart';
import 'package:ledger_zero/presentation/widgets/common/load_error_view.dart';
import 'package:uuid/uuid.dart';

class ReportNotesSection extends ConsumerWidget {
  const ReportNotesSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notesAsync = ref.watch(reportNotesListProvider);
    final l10n = AppLocalizations.of(context)!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(l10n.notes, style: Theme.of(context).textTheme.titleLarge),
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: l10n.addNote,
              onPressed: () => _showAddNoteDialog(context, ref),
            ),
          ],
        ),
        const SizedBox(height: 8),
        notesAsync.when(
          data: (notes) {
            if (notes.isEmpty) {
              return Text(l10n.noNotes);
            }
            return Column(
              children: notes.map((note) => _NoteCard(note: note)).toList(),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, st) =>
              LoadErrorView(error: e, stackTrace: st, compact: true),
        ),
      ],
    );
  }

  void _showAddNoteDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => const _AddEditNoteDialog(),
    );
  }
}

class _NoteCard extends ConsumerWidget {
  final ReportNote note;

  const _NoteCard({required this.note});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fmt = ref.watch(appFormatterProvider);
    String title;
    try {
      title = fmt.formatMonthYear(CalendarDate.parseMonthKey(note.date));
    } catch (_) {
      title = note.date;
    }
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(title),
        subtitle: Text(note.note),
        trailing: IconButton(
          icon: const Icon(Icons.edit),
          tooltip: AppLocalizations.of(context)!.editNote,
          onPressed: () {
            showDialog(
              context: context,
              builder: (context) => _AddEditNoteDialog(note: note),
            );
          },
        ),
      ),
    );
  }
}

class _AddEditNoteDialog extends ConsumerStatefulWidget {
  final ReportNote? note;

  const _AddEditNoteDialog({this.note});

  @override
  ConsumerState<_AddEditNoteDialog> createState() => _AddEditNoteDialogState();
}

class _AddEditNoteDialogState extends ConsumerState<_AddEditNoteDialog> {
  late TextEditingController _noteController;

  /// First day of the selected month (local, for the date picker).
  late DateTime _selectedDate;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _noteController = TextEditingController(text: widget.note?.note ?? '');
    if (widget.note != null) {
      try {
        final month = CalendarDate.parseMonthKey(widget.note!.date);
        _selectedDate = DateTime(month.year, month.month);
      } catch (_) {
        final now = DateTime.now();
        _selectedDate = DateTime(now.year, now.month);
      }
    } else {
      // Default to start of current report range if available, else now
      final range = ref.read(reportDateRangeProvider);
      _selectedDate = DateTime(range.start.year, range.start.month);
    }
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final fmt = ref.watch(appFormatterProvider);
    final isEditing = widget.note != null;

    return AlertDialog(
      title: Text(isEditing ? l10n.editNote : l10n.addNote),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Month Picker (simplified as a button showing date)
            InkWell(
              onTap: () async {
                // Show month picker
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _selectedDate,
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2100),
                  initialDatePickerMode: DatePickerMode.year,
                );
                // Note: Standard DatePicker isn't great for selecting just Month/Year.
                // But it's sufficient if we just ignore the day.
                if (picked != null && mounted) {
                  setState(() {
                    _selectedDate = DateTime(picked.year, picked.month);
                  });
                }
              },
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: l10n.month,
                  border: const OutlineInputBorder(),
                ),
                child: Text(fmt.formatMonthYear(_selectedDate)),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _noteController,
              decoration: InputDecoration(
                labelText: l10n.note,
                border: const OutlineInputBorder(),
              ),
              maxLines: 3,
              validator: (value) =>
                  value == null || value.isEmpty ? l10n.enterNote : null,
            ),
          ],
        ),
      ),
      actions: [
        if (isEditing)
          TextButton(
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text(l10n.deleteNoteConfirmationTitle),
                  content: Text(l10n.deleteNoteConfirmationMessage),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: Text(l10n.cancel),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: Text(l10n.delete),
                    ),
                  ],
                ),
              );

              if (confirm == true && context.mounted) {
                final messenger = ScaffoldMessenger.of(context);
                final navigator = Navigator.of(context);
                await ref
                    .read(reportNoteRepositoryProvider)
                    .deleteNote(widget.note!.id);
                if (mounted) {
                  ref.invalidate(reportNotesListProvider);
                  navigator.pop();
                  messenger.showSnackBar(
                    SnackBar(content: Text(l10n.noteDeleted)),
                  );
                }
              }
            },
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: Text(l10n.delete),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () async {
            if (_formKey.currentState!.validate()) {
              final repo = ref.read(reportNoteRepositoryProvider);
              final dateStr = CalendarDate.monthKey(_selectedDate);

              final note = ReportNote(
                id: widget.note?.id ?? const Uuid().v4(),
                date: dateStr,
                note: _noteController.text,
              );

              final messenger = ScaffoldMessenger.of(context);
              final navigator = Navigator.of(context);
              await repo.saveNote(note);
              if (mounted) {
                ref.invalidate(reportNotesListProvider);
                navigator.pop();
                messenger.showSnackBar(SnackBar(content: Text(l10n.noteSaved)));
              }
            }
          },
          child: Text(l10n.save),
        ),
      ],
    );
  }
}
