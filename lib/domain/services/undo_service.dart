import 'dart:async';
import 'package:ledger_zero/core/utils/logger.dart';

abstract class ReversibleAction {
  Future<void> undo();
  Future<void> redo();
}

class UndoService {
  final List<ReversibleAction> _undoStack = [];
  final List<ReversibleAction> _redoStack = [];

  bool get canUndo => _undoStack.isNotEmpty;
  bool get canRedo => _redoStack.isNotEmpty;

  void addAction(ReversibleAction action) {
    _undoStack.add(action);
    _redoStack.clear();
    Logger.debug('Action added to Undo Stack. Undo size: ${_undoStack.length}');
  }

  Future<void> undo() async {
    if (!canUndo) {
      return;
    }
    final action = _undoStack.removeLast();
    try {
      await action.undo();
      _redoStack.add(action);
      Logger.info('Undid action.');
    } catch (e, s) {
      Logger.error('Undo failed', e, s);
      // Ideally we might want to reload state or handle error
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
      _undoStack.add(action);
      Logger.info('Redid action.');
    } catch (e, s) {
      Logger.error('Redo failed', e, s);
      rethrow;
    }
  }

  void clear() {
    _undoStack.clear();
    _redoStack.clear();
  }
}
