import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/providers/theme_provider.dart';
import 'package:ledger_zero/presentation/widgets/tutorial/tutorial_data.dart';

/// Dims the screen, highlights the current step's target and shows the
/// step's card. The card fades in and cross-fades between steps unless
/// animations are disabled (Reduced Motion setting or platform setting).
class TutorialOverlay extends ConsumerStatefulWidget {
  final List<TutorialStep> steps;
  final VoidCallback onComplete;
  final VoidCallback? onSkip;

  const TutorialOverlay({
    super.key,
    required this.steps,
    required this.onComplete,
    this.onSkip,
  });

  /// Duration of the card's fade.
  static const fadeDuration = Duration(milliseconds: 250);

  @override
  ConsumerState<TutorialOverlay> createState() => _TutorialOverlayState();
}

class _TutorialOverlayState extends ConsumerState<TutorialOverlay> {
  int _currentStepIndex = 0;

  @override
  Widget build(BuildContext context) {
    if (widget.steps.isEmpty) {
      return const SizedBox.shrink();
    }
    final animate = animationsEnabled(context, ref);

    final step = widget.steps[_currentStepIndex];
    final targetContext = step.targetKey?.currentContext;

    // If target context is not found (e.g. scrolled out of view or not built),
    // we default to center or handle gracefully.
    // For simplicity, if target is missing, we show centered.

    Rect? targetRect;
    if (targetContext != null) {
      final renderObject = targetContext.findRenderObject();
      if (renderObject is RenderBox) {
        final offset = renderObject.localToGlobal(Offset.zero);
        final size = renderObject.size;
        targetRect = Rect.fromLTWH(
          offset.dx,
          offset.dy,
          size.width,
          size.height,
        );
      }
    }

    // A modal layer: screen readers stay inside the tutorial card.
    return BlockSemantics(
      child: Semantics(
        scopesRoute: true,
        namesRoute: true,
        explicitChildNodes: true,
        label: step.title,
        child: Stack(
          children: [
            // Background with hole punch
            Positioned.fill(
              child: CustomPaint(painter: _HolePainter(targetRect: targetRect)),
            ),

            // Tooltip/Card
            if (targetRect != null)
              _buildPositionedCard(context, step, targetRect, animate)
            else
              Center(child: _animatedCard(context, step, animate)),
          ],
        ),
      ),
    );
  }

  /// The step's card, faded in on first show and between steps when
  /// [animate] is true; shown directly otherwise.
  Widget _animatedCard(BuildContext context, TutorialStep step, bool animate) {
    final card = KeyedSubtree(
      key: ValueKey<int>(_currentStepIndex),
      child: _buildCard(context, step),
    );
    if (!animate) {
      return card;
    }
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: TutorialOverlay.fadeDuration,
      builder: (context, opacity, child) =>
          Opacity(opacity: opacity, child: child),
      child: AnimatedSwitcher(
        duration: TutorialOverlay.fadeDuration,
        child: card,
      ),
    );
  }

  Widget _buildPositionedCard(
    BuildContext context,
    TutorialStep step,
    Rect targetRect,
    bool animate,
  ) {
    // Determine best position
    // Simple logic: if target is in top half, show below. Else above.
    final screenSize = MediaQuery.of(context).size;

    double? top;
    double? bottom;
    double? left;
    double? right;

    final isTopHalf = targetRect.center.dy < screenSize.height / 2;

    if (isTopHalf) {
      top = targetRect.bottom + 16;
      left = 16;
      right = 16;
    } else {
      bottom = screenSize.height - targetRect.top + 16;
      left = 16;
      right = 16;
    }

    return Positioned(
      top: top,
      bottom: bottom,
      left: left,
      right: right,
      child: _animatedCard(context, step, animate),
    );
  }

  Widget _buildCard(BuildContext context, TutorialStep step) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return Material(
      color: Colors.transparent,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 24),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              header: true,
              child: Text(
                step.title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(step.description, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 16),
            // Wraps on narrow phones with long (German) button labels.
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: Wrap(
                alignment: WrapAlignment.end,
                spacing: 8,
                children: [
                  if (widget.onSkip != null)
                    TextButton(
                      onPressed: widget.onSkip,
                      child: Text(l10n.skip),
                    ),
                  FilledButton(
                    onPressed: _nextStep,
                    child: Text(
                      _currentStepIndex < widget.steps.length - 1
                          ? l10n.tutorialNext
                          : l10n.tutorialFinish,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _nextStep() {
    if (_currentStepIndex < widget.steps.length - 1) {
      setState(() {
        _currentStepIndex++;
      });
    } else {
      widget.onComplete();
    }
  }
}

class _HolePainter extends CustomPainter {
  final Rect? targetRect;

  _HolePainter({required this.targetRect});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black.withValues(alpha: 0.7);

    final path = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));

    final holePath = Path();
    if (targetRect != null) {
      holePath.addRRect(
        RRect.fromRectAndRadius(
          targetRect!.inflate(4), // Add padding
          const Radius.circular(8),
        ),
      );
    }

    final finalPath = Path.combine(PathOperation.difference, path, holePath);

    // We actually need to clear the hole area because we already have a ModalBarrier behind?
    // Wait, the ModalBarrier is already there. If I draw another layer with a hole, I need to make sure the ModalBarrier doesn't cover the hole if I want it interactive.
    // Actually, usually tutorial overlays *block* interaction with the target unless specified.
    // For this simple implementation, we just want to highlight it visually.
    // The ModalBarrier in the stack is behind this CustomPaint? No, the ModalBarrier is first child.

    // Let's refine:
    // Remove the ModalBarrier from the Stack children list above, and use this CustomPainter to draw the dimmed background with a hole.
    canvas.drawPath(finalPath, paint);
  }

  @override
  bool shouldRepaint(covariant _HolePainter oldDelegate) {
    return oldDelegate.targetRect != targetRect;
  }
}
