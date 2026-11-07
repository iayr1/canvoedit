/// Snapshot-based undo stack. Editors serialise their project to a JSON string
/// after each completed edit and restore it on undo or redo.
class History {
  History(String initial, {this.limit = 60}) : _stack = [initial];

  final int limit;
  final List<String> _stack;
  int _index = 0;

  bool get canUndo => _index > 0;
  bool get canRedo => _index < _stack.length - 1;

  void push(String snapshot) {
    if (_stack[_index] == snapshot) return;
    _stack.removeRange(_index + 1, _stack.length);
    _stack.add(snapshot);
    if (_stack.length > limit) _stack.removeAt(0);
    _index = _stack.length - 1;
  }

  String? undo() => canUndo ? _stack[--_index] : null;
  String? redo() => canRedo ? _stack[++_index] : null;
}
