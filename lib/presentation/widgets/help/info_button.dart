import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ledger_zero/core/providers/shared_preferences_provider.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/widgets/help/help_topics.dart';

/// An ⓘ button that explains [topic] in a bottom sheet.
class InfoButton extends StatelessWidget {
  const InfoButton(this.topic, {super.key, this.color});

  final HelpTopic topic;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return IconButton(
      key: Key('info.${topic.name}'),
      icon: const Icon(Icons.info_outline, size: 20),
      color: color ?? Theme.of(context).colorScheme.onSurfaceVariant,
      tooltip: l10n.helpInfoTooltip(topic.title(l10n)),
      onPressed: () => showHelpSheet(context, topic),
    );
  }
}

/// Shows [topic]: its text, its steps, and a link to its guide chapter (when
/// the app's router is there to open it).
Future<void> showHelpSheet(BuildContext context, HelpTopic topic) {
  final router = GoRouter.maybeOf(context);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (context) {
      final l10n = AppLocalizations.of(context)!;
      final theme = Theme.of(context);
      final steps = topic.steps(l10n);
      return ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.85,
        ),
        child: SingleChildScrollView(
          key: Key('help.${topic.name}'),
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                header: true,
                child: Text(
                  topic.title(l10n),
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                topic.body(l10n),
                style: theme.textTheme.bodyLarge?.copyWith(height: 1.45),
              ),
              if (steps.isNotEmpty) ...[
                const SizedBox(height: 20),
                Text(
                  l10n.helpHowTo,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                for (final step in steps)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ExcludeSemantics(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 1),
                            child: Text(
                              '•',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            step,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
              const SizedBox(height: 16),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 8,
                runSpacing: 4,
                children: [
                  if (router != null)
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        router.push(
                          '/settings/help/user-guide'
                          '?chapter=${topic.chapter.name}',
                        );
                      },
                      child: Text(l10n.helpOpenGuide),
                    ),
                  FilledButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(l10n.gotIt),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// A hint shown until the user dismisses it once ([prefsKey] remembers
/// that), with "Show me" opening [topic].
class OneTimeHintCard extends ConsumerStatefulWidget {
  const OneTimeHintCard({
    super.key,
    required this.prefsKey,
    required this.text,
    required this.topic,
    this.margin = EdgeInsets.zero,
  });

  final String prefsKey;
  final String text;
  final HelpTopic topic;
  final EdgeInsetsGeometry margin;

  /// Whether the hint stored under [prefsKey] was dismissed.
  static bool isDismissed(WidgetRef ref, String prefsKey) =>
      ref.read(sharedPreferencesProvider).getBool(prefsKey) ?? false;

  @override
  ConsumerState<OneTimeHintCard> createState() => _OneTimeHintCardState();
}

class _OneTimeHintCardState extends ConsumerState<OneTimeHintCard> {
  late bool _dismissed = OneTimeHintCard.isDismissed(ref, widget.prefsKey);

  Future<void> _dismiss() async {
    setState(() => _dismissed = true);
    await ref.read(sharedPreferencesProvider).setBool(widget.prefsKey, true);
  }

  @override
  Widget build(BuildContext context) {
    if (_dismissed) {
      return const SizedBox.shrink();
    }
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: widget.margin,
      child: Card(
        key: Key('hint.${widget.prefsKey}'),
        margin: EdgeInsets.zero,
        color: scheme.secondaryContainer,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.lightbulb_outline,
                    size: 20,
                    color: scheme.onSecondaryContainer,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.text,
                      style: TextStyle(color: scheme.onSecondaryContainer),
                    ),
                  ),
                ],
              ),
              Wrap(
                alignment: WrapAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => showHelpSheet(context, widget.topic),
                    child: Text(l10n.helpShowMe),
                  ),
                  TextButton(onPressed: _dismiss, child: Text(l10n.gotIt)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
