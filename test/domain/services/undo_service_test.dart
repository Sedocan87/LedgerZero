import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/domain/services/undo_service.dart';

class _Action implements ReversibleAction {
  _Action(this.name, this.log, {this.failUndo = false, this.failRedo = false});

  final String name;
  final List<String> log;
  bool failUndo;
  bool failRedo;

  @override
  Future<void> undo() async {
    if (failUndo) {
      throw StateError('undo $name failed');
    }
    log.add('undo $name');
  }

  @override
  Future<void> redo() async {
    if (failRedo) {
      throw StateError('redo $name failed');
    }
    log.add('redo $name');
  }
}

void main() {
  late List<String> log;
  late UndoService undo;

  setUp(() {
    log = [];
    undo = UndoService(maxStackSize: 3);
  });

  test('stack is capped; the oldest actions drop off', () async {
    for (var i = 0; i < 5; i++) {
      undo.addAction(_Action('a$i', log));
    }
    expect(undo.undoCount, 3);
    while (undo.canUndo) {
      await undo.undo();
    }
    expect(log, ['undo a4', 'undo a3', 'undo a2']);
  });

  test('a failed undo puts the action back', () async {
    final action = _Action('a', log, failUndo: true);
    undo.addAction(action);
    await expectLater(undo.undo(), throwsStateError);
    expect(undo.canUndo, isTrue);
    expect(undo.canRedo, isFalse);

    action.failUndo = false;
    await undo.undo();
    expect(log, ['undo a']);
    expect(undo.canRedo, isTrue);
  });

  test('a failed redo puts the action back', () async {
    final action = _Action('a', log, failRedo: true);
    undo.addAction(action);
    await undo.undo();
    await expectLater(undo.redo(), throwsStateError);
    expect(undo.canRedo, isTrue);
    action.failRedo = false;
    await undo.redo();
    expect(log, ['undo a', 'redo a']);
    expect(undo.canUndo, isTrue);
  });

  test('undo(action) undoes exactly that action', () async {
    final first = _Action('first', log);
    final second = _Action('second', log);
    undo.addAction(first);
    undo.addAction(second);
    await undo.undo(first);
    expect(log, ['undo first']);
    expect(undo.undoCount, 1);
    // Undoing an action that is no longer on the stack does nothing.
    await undo.undo(first);
    expect(log, ['undo first']);
  });
}
