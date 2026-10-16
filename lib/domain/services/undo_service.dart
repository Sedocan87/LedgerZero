import 'dart:async';
import 'package:ledger_zero/core/utils/logger.dart';

abstract class ReversibleAction {
  Future<void> undo();
  Future<void> redo();
}

/// Undo/redo stacks of [ReversibleAction]s.
///
/// * Both stacks are capped at [maxStackSize]; the oldest actions drop off.
/// * When undoing or redoing fails, the action is put back on the stack it
///   came from (nothing is lost) and the error is rethrown.
class UndoService {
  UndoService({this.maxStackSize = 50});

  /// Maximum number of actions kept on each stack.
  final int maxStackSize;

  final List<ReversibleAction> _undoStack = [];
  final List<ReversibleAction> _redoStack = [];

  bool get canUndo => _undoStack.isNotEmpty;
  bool get canRedo => _redoStack.isNotEmpty;

  /// Number of actions that can be undone.
  int get undoCount => _undoStack.length;

  void addAction(ReversibleAction action) {
    _push(_undoStack, action);
    _redoStack.clear();
    Logger.debug('Action added to Undo Stack. Undo size: ${_undoStack.length}');
  }

  void _push(List<ReversibleAction> stack, ReversibleAction action) {
    stack.add(action);
    while (stack.length > maxStackSize) {
      stack.removeAt(0);
    }
  }

  /// Undoes the latest action, or [action] if given (a snackbar's "Undo"
  /// passes the action it announced, so a later action is never undone by
  /// mistake). Does nothing if [action] is no longer on the stack.
  Future<void> undo([ReversibleAction? action]) async {
    if (!canUndo) {
      return;
    }
    final target = action ?? _undoStack.last;
    final index = _undoStack.lastIndexOf(target);
    if (index < 0) {
      return;
    }
    _undoStack.removeAt(index);
    try {
      await target.undo();
      _push(_redoStack, target);
      Logger.info('Undid action.');
    } catch (e, s) {
      Logger.error('Undo failed', e, s);
      _undoStack.insert(index.clamp(0, _undoStack.length), target);
      rethrow;
    }
  }

  Future<void> redo() async {
    if (!canRedo) {
      return;
    }
    final action = _redoStack.removeLast();
    try {
      await action.redo();
      _push(_undoStack, action);
      Logger.info('Redid action.');
    } catch (e, s) {
      Logger.error('Redo failed', e, s);
      _redoStack.add(action);
      rethrow;
    }
  }

  void clear() {
    _undoStack.clear();
    _redoStack.clear();
  }
}
