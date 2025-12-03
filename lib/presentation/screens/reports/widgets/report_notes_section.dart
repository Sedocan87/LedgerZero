import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:ledger_zero/domain/entities/report_note.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/providers/repository_providers.dart';
import 'package:ledger_zero/presentation/screens/reports/providers/report_providers.dart';
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
          error: (e, st) => Text('${l10n.error}: $e'),
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
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(note.date), // Should format this nicely
        subtitle: Text(note.note),
        trailing: IconButton(
          icon: const Icon(Icons.edit),
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
  late DateTime _selectedDate;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _noteController = TextEditingController(text: widget.note?.note ?? '');
    if (widget.note != null) {
      try {
        final parts = widget.note!.date.split('-');
        _selectedDate = DateTime(int.parse(parts[0]), int.parse(parts[1]));
      } catch (_) {
        _selectedDate = DateTime.now();
      }
    } else {
      // Default to start of current report range if available, else now
      final range = ref.read(reportDateRangeProvider);
      _selectedDate = range.start;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
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
                if (picked != null) {
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
                child: Text(DateFormat('yyyy-MM').format(_selectedDate)),
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
              validator: (value) => value == null || value.isEmpty ? l10n.enterNote : null,
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
                    TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l10n.cancel)),
                    TextButton(onPressed: () => Navigator.pop(context, true), child: Text(l10n.delete)),
                  ],
                ),
              );

              if (confirm == true && context.mounted) {
                 await ref.read(reportNoteRepositoryProvider).deleteNote(widget.note!.id);
                 if (context.mounted) {
                    ref.invalidate(reportNotesListProvider);
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(l10n.noteDeleted)),
                    );
                 }
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
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
              final dateStr = DateFormat('yyyy-MM').format(_selectedDate);

              final note = ReportNote(
                id: widget.note?.id ?? const Uuid().v4(),
                date: dateStr,
                note: _noteController.text,
              );

              await repo.saveNote(note);
              if (context.mounted) {
                ref.invalidate(reportNotesListProvider);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(l10n.noteSaved)),
                );
              }
            }
          },
          child: Text(l10n.save),
        ),
      ],
    );
  }
}
