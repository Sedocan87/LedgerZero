import 'package:flutter/material.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/widgets/help/help_topics.dart';

/// The user guide: every [GuideChapter], numbered. Help sheets open it at
/// [initialChapter].
class UserGuideScreen extends StatefulWidget {
  const UserGuideScreen({super.key, this.initialChapter});

  final GuideChapter? initialChapter;

  @override
  State<UserGuideScreen> createState() => _UserGuideScreenState();
}

class _UserGuideScreenState extends State<UserGuideScreen> {
  final _keys = {for (final c in GuideChapter.values) c: GlobalKey()};

  @override
  void initState() {
    super.initState();
    final chapter = widget.initialChapter;
    if (chapter != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final target = _keys[chapter]!.currentContext;
        if (target != null && target.mounted) {
          Scrollable.ensureVisible(target);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.userGuide)),
      // Not lazy: a chapter must be laid out to scroll to it.
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (i, chapter) in GuideChapter.values.indexed)
              UserGuideSection(
                key: _keys[chapter],
                title: '${i + 1}. ${chapter.title(l10n)}',
                content: chapter.body(l10n),
              ),
          ],
        ),
      ),
    );
  }
}

class UserGuideSection extends StatelessWidget {
  final String title;
  final String content;

  const UserGuideSection({
    super.key,
    required this.title,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.5),
          ),
        ],
      ),
    );
  }
}
