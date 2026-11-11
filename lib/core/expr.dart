import 'dart:math' as math;

/// A small evaluator for the subset of FFmpeg's expression language that the
/// app writes. Transition patterns are written once as FFmpeg expressions; the
/// preview evaluates the very same text, so preview and export cannot drift.
class Expr {
  Expr._(this._root);

  factory Expr.parse(String source) {
    final p = _Parser(source);
    final node = p.expression();
    p.expectEnd();
    return Expr._(node);
  }

  final _Node _root;

  double eval(Map<String, double> vars) => _root.eval(vars);
}

abstract class _Node {
  double eval(Map<String, double> v);
}

class _Num extends _Node {
  _Num(this.value);
  final double value;
  @override
  double eval(Map<String, double> v) => value;
}

class _Var extends _Node {
  _Var(this.name);
  final String name;
  @override
  double eval(Map<String, double> v) {
    final x = v[name];
    if (x == null) throw FormatException('Unknown variable $name');
    return x;
  }
}

class _Neg extends _Node {
  _Neg(this.a);
  final _Node a;
  @override
  double eval(Map<String, double> v) => -a.eval(v);
}

class _Bin extends _Node {
  _Bin(this.op, this.a, this.b);
  final String op;
  final _Node a, b;
  @override
  double eval(Map<String, double> v) {
    final x = a.eval(v), y = b.eval(v);
    return switch (op) {
      '+' => x + y,
      '-' => x - y,
      '*' => x * y,
      '/' => x / y,
      '^' => math.pow(x, y).toDouble(),
      _ => throw StateError(op),
    };
  }
}

class _Call extends _Node {
  _Call(this.name, this.args);
  final String name;
  final List<_Node> args;

  static const arity = {
    'if': 3,
    'lt': 2,
    'gt': 2,
    'lte': 2,
    'gte': 2,
    'eq': 2,
    'abs': 1,
    'sin': 1,
    'cos': 1,
    'atan2': 2,
    'hypot': 2,
    'floor': 1,
    'ceil': 1,
    'trunc': 1,
    'mod': 2,
    'min': 2,
    'max': 2,
    'sqrt': 1,
    'clip': 3,
  };

  @override
  double eval(Map<String, double> v) {
    double a(int i) => args[i].eval(v);
    switch (name) {
      case 'if':
        return a(0) != 0 ? a(1) : a(2);
      case 'lt':
        return a(0) < a(1) ? 1 : 0;
      case 'gt':
        return a(0) > a(1) ? 1 : 0;
      case 'lte':
        return a(0) <= a(1) ? 1 : 0;
      case 'gte':
        return a(0) >= a(1) ? 1 : 0;
      case 'eq':
        return a(0) == a(1) ? 1 : 0;
      case 'abs':
        return a(0).abs();
      case 'sin':
        return math.sin(a(0));
      case 'cos':
        return math.cos(a(0));
      case 'atan2':
        return math.atan2(a(0), a(1));
      case 'hypot':
        final x = a(0), y = a(1);
        return math.sqrt(x * x + y * y);
      case 'floor':
        return a(0).floorToDouble();
      case 'ceil':
        return a(0).ceilToDouble();
      case 'trunc':
        return a(0).truncateToDouble();
      case 'mod':
        // FFmpeg's mod follows the sign of the divisor, like floor division.
        final x = a(0), y = a(1);
        return x - y * (x / y).floorToDouble();
      case 'min':
        return math.min(a(0), a(1));
      case 'max':
        return math.max(a(0), a(1));
      case 'sqrt':
        return math.sqrt(a(0));
      case 'clip':
        final x = a(0), lo = a(1), hi = a(2);
        return x < lo ? lo : (x > hi ? hi : x);
    }
    throw StateError(name);
  }
}

class _Parser {
  _Parser(this.s);
  final String s;
  int i = 0;

  void _ws() {
    while (i < s.length && s[i] == ' ') {
      i++;
    }
  }

  bool _eat(String c) {
    _ws();
    if (i < s.length && s[i] == c) {
      i++;
      return true;
    }
    return false;
  }

  void expectEnd() {
    _ws();
    if (i != s.length) throw FormatException('Unexpected "${s.substring(i)}"', s, i);
  }

  _Node expression() {
    var n = _term();
    while (true) {
      if (_eat('+')) {
        n = _Bin('+', n, _term());
      } else if (_eat('-')) {
        n = _Bin('-', n, _term());
      } else {
        return n;
      }
    }
  }

  _Node _term() {
    var n = _power();
    while (true) {
      if (_eat('*')) {
        n = _Bin('*', n, _power());
      } else if (_eat('/')) {
        n = _Bin('/', n, _power());
      } else {
        return n;
      }
    }
  }

  // As in FFmpeg, a sign applies to a whole power chain, and powers group from
  // the left: -2^2 is -4 and 2^3^2 is 64.
  _Node _power() {
    var negative = false;
    if (_eat('-')) {
      negative = true;
    } else {
      _eat('+');
    }
    var n = _primary();
    while (_eat('^')) {
      final exponentNegative = _eat('-');
      if (!exponentNegative) _eat('+');
      final e = _primary();
      n = _Bin('^', n, exponentNegative ? _Neg(e) : e);
    }
    return negative ? _Neg(n) : n;
  }

  _Node _primary() {
    _ws();
    if (_eat('(')) {
      final n = expression();
      if (!_eat(')')) throw FormatException('Expected )', s, i);
      return n;
    }
    final start = i;
    if (i < s.length && RegExp(r'[0-9.]').hasMatch(s[i])) {
      while (i < s.length && RegExp(r'[0-9.eE]').hasMatch(s[i])) {
        i++;
      }
      return _Num(double.parse(s.substring(start, i)));
    }
    while (i < s.length && RegExp(r'[A-Za-z0-9_]').hasMatch(s[i])) {
      i++;
    }
    final name = s.substring(start, i);
    if (name.isEmpty) throw FormatException('Expected a value', s, i);
    if (name == 'PI') return _Num(math.pi);
    if (_eat('(')) {
      final args = <_Node>[expression()];
      while (_eat(',')) {
        args.add(expression());
      }
      if (!_eat(')')) throw FormatException('Expected )', s, i);
      final want = _Call.arity[name];
      if (want == null) throw FormatException('Unknown function $name', s, start);
      if (want != args.length) throw FormatException('$name takes $want arguments', s, start);
      return _Call(name, args);
    }
    return _Var(name);
  }
}
