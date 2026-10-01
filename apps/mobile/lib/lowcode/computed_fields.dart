import 'dart:math' as math;

/// Small expression language: only data lookups, operators and these functions.
/// Expressions never invoke Dart, JavaScript, reflection, or object methods.
class ComputedFields {
  static dynamic evaluate(String expression, Map<String, dynamic> data) {
    final value = _Parser(expression).parse()(data);
    if (value is num && !value.isFinite) {
      throw const FormatException('The result is not a finite number');
    }
    return value;
  }

  static Set<String> dependencies(String expression) {
    final parser = _Parser(expression);
    parser.parse();
    return parser.dependencies;
  }
}

typedef _Node = dynamic Function(Map<String, dynamic> data);

class _Token {
  const _Token(this.kind, this.text, [this.value]);
  final String kind;
  final String text;
  final dynamic value;
}

class _Parser {
  _Parser(String expression) : tokens = _tokenize(expression);

  final List<_Token> tokens;
  final dependencies = <String>{};
  int index = 0;
  int depth = 0;
  _Token get current => tokens[index];

  _Node parse() {
    final result = _expression();
    if (current.kind != 'end') {
      throw FormatException('Unexpected token: ${current.text}');
    }
    return result;
  }

  bool _take(String text) {
    if (current.text != text || current.kind == 'end') return false;
    index++;
    return true;
  }

  void _expect(String text) {
    if (!_take(text)) throw FormatException('Expected "$text"');
  }

  static const _precedence = {
    '||': 1,
    '&&': 2,
    '==': 3,
    '!=': 3,
    '<': 4,
    '<=': 4,
    '>': 4,
    '>=': 4,
    '+': 5,
    '-': 5,
    '*': 6,
    '/': 6,
    '%': 6,
  };

  _Node _expression([int minimum = 0]) {
    if (++depth > 64)
      throw const FormatException('Expression is too deeply nested');
    var left = _primary();
    while (true) {
      final precedence = _precedence[current.text];
      if (precedence == null || precedence < minimum) break;
      final operator = current.text;
      index++;
      final right = _expression(precedence + 1);
      final prior = left;
      left = (data) {
        final a = prior(data);
        if (operator == '&&') return _truth(a) && _truth(right(data));
        if (operator == '||') return _truth(a) || _truth(right(data));
        return _binary(operator, a, right(data));
      };
    }
    depth--;
    return left;
  }

  _Node _primary() {
    if (current.kind == 'literal') {
      final value = current.value;
      index++;
      return (_) => value;
    }
    if (_take('!')) {
      final value = _expression(7);
      return (data) => !_truth(value(data));
    }
    if (_take('-')) {
      final value = _expression(7);
      return (data) => -_number(value(data));
    }
    if (_take('+')) {
      final value = _expression(7);
      return (data) => _number(value(data));
    }
    if (_take('(')) {
      final value = _expression();
      _expect(')');
      return value;
    }
    if (current.kind != 'identifier') {
      throw FormatException('Expected a value, got "${current.text}"');
    }
    final identifier = current.text;
    index++;
    if (_take('(')) {
      const functions = {
        'if',
        'coalesce',
        'sum',
        'count',
        'avg',
        'min',
        'max',
        'round',
        'abs',
        'concat',
        'lower',
        'upper',
        'trim',
        'length',
        'contains',
      };
      if (!functions.contains(identifier)) {
        throw FormatException('Function "$identifier" is not allowed');
      }
      final arguments = <_Node>[];
      if (!_take(')')) {
        do {
          arguments.add(_expression());
        } while (_take(','));
        _expect(')');
      }
      if (identifier == 'if') {
        if (arguments.length != 3)
          throw const FormatException('if requires 3 arguments');
        return (data) => arguments[_truth(arguments[0](data)) ? 1 : 2](data);
      }
      if (identifier == 'coalesce') {
        return (data) {
          for (final argument in arguments) {
            final value = argument(data);
            if (value != null) return value;
          }
          return null;
        };
      }
      return (data) =>
          _function(identifier, arguments.map((arg) => arg(data)).toList());
    }
    dependencies.add(identifier.split('.').first);
    return (data) {
      final path = identifier.split('.');
      if (!data.containsKey(path.first)) {
        throw FormatException('Unknown field "${path.first}"');
      }
      return _lookup(data, path);
    };
  }
}

dynamic _lookup(dynamic value, List<String> path) {
  if (path.isEmpty || value == null) return value;
  if (value is Iterable)
    return value.map((item) => _lookup(item, path)).toList();
  if (value is Map) return _lookup(value[path.first], path.sublist(1));
  throw FormatException('Cannot read "${path.first}" from this value');
}

bool _truth(dynamic value) =>
    value != null && value != false && value != 0 && value != '';

num _number(dynamic value) {
  final parsed = value is num ? value : num.tryParse(value?.toString() ?? '');
  if (parsed == null || !parsed.isFinite)
    throw const FormatException('Expected a finite number');
  return parsed;
}

dynamic _binary(String operator, dynamic a, dynamic b) {
  switch (operator) {
    case '==':
      return a == b;
    case '!=':
      return a != b;
    case '+':
      return _number(a) + _number(b);
    case '-':
      return _number(a) - _number(b);
    case '*':
      return _number(a) * _number(b);
    case '/':
      if (_number(b) == 0) throw const FormatException('Cannot divide by zero');
      return _number(a) / _number(b);
    case '%':
      if (_number(b) == 0) throw const FormatException('Cannot divide by zero');
      return _number(a) % _number(b);
    default:
      final comparison = a is String && b is String
          ? a.compareTo(b)
          : _number(a).compareTo(_number(b));
      switch (operator) {
        case '<':
          return comparison < 0;
        case '<=':
          return comparison <= 0;
        case '>':
          return comparison > 0;
        case '>=':
          return comparison >= 0;
      }
      throw FormatException('Unknown operator "$operator"');
  }
}

dynamic _function(String name, List<dynamic> args) {
  void arity(int minimum, [int? maximum]) {
    if (args.length < minimum || args.length > (maximum ?? minimum)) {
      throw FormatException('$name has the wrong number of arguments');
    }
  }

  List<num> numbers() {
    final values = args.length == 1 && args.first is Iterable
        ? args.first as Iterable
        : args;
    return values.map(_number).toList();
  }

  switch (name) {
    case 'sum':
      return numbers().fold<num>(0, (a, b) => a + b);
    case 'avg':
      final values = numbers();
      return values.isEmpty
          ? 0
          : values.reduce((a, b) => a + b) / values.length;
    case 'min':
    case 'max':
      final values = numbers();
      if (values.isEmpty)
        throw FormatException('$name needs at least one value');
      return values.reduce(name == 'min' ? math.min : math.max);
    case 'count':
    case 'length':
      arity(1);
      final value = args.first;
      if (value == null) return 0;
      if (value is Iterable) return value.length;
      if (value is Map) return value.length;
      if (value is String) return value.length;
      throw FormatException('$name requires a list, string or object');
    case 'abs':
      arity(1);
      return _number(args.first).abs();
    case 'round':
      arity(1, 2);
      final places = args.length == 2 ? _number(args[1]).toInt() : 0;
      if (places < 0 || places > 12)
        throw const FormatException('round precision must be between 0 and 12');
      return num.parse(_number(args.first).toStringAsFixed(places));
    case 'concat':
      return args.map((arg) => arg?.toString() ?? '').join();
    case 'lower':
      arity(1);
      return args.first?.toString().toLowerCase() ?? '';
    case 'upper':
      arity(1);
      return args.first?.toString().toUpperCase() ?? '';
    case 'trim':
      arity(1);
      return args.first?.toString().trim() ?? '';
    case 'contains':
      arity(2);
      final value = args.first;
      return value is Iterable
          ? value.contains(args[1])
          : (value?.toString() ?? '').contains(args[1].toString());
  }
  throw FormatException('Function "$name" is not allowed');
}

List<_Token> _tokenize(String source) {
  if (source.length > 4096)
    throw const FormatException('Expression is too long');
  final tokens = <_Token>[];
  final number = RegExp(r'^(?:\d+(?:\.\d*)?|\.\d+)(?:[eE][+-]?\d+)?');
  final identifier =
      RegExp(r'^[a-zA-Z_][a-zA-Z_0-9]*(?:\.[a-zA-Z_][a-zA-Z_0-9]*)*');
  var index = 0;
  while (index < source.length) {
    if (tokens.length >= 1024)
      throw const FormatException('Expression has too many tokens');
    final character = source[index];
    if (character.trim().isEmpty) {
      index++;
      continue;
    }
    if (character == "'" || character == '"') {
      final quote = character;
      final value = StringBuffer();
      index++;
      var closed = false;
      while (index < source.length) {
        final part = source[index++];
        if (part == quote) {
          closed = true;
          break;
        }
        if (part == r'\') {
          if (index == source.length) break;
          final escaped = source[index++];
          value.write(
              const {'n': '\n', 'r': '\r', 't': '\t'}[escaped] ?? escaped);
        } else {
          value.write(part);
        }
      }
      if (!closed) throw const FormatException('Unclosed string');
      tokens.add(_Token('literal', '', value.toString()));
      continue;
    }
    final remaining = source.substring(index);
    final numeric = number.firstMatch(remaining);
    if (numeric != null) {
      final text = numeric.group(0)!;
      tokens.add(_Token('literal', text, num.parse(text)));
      index += text.length;
      continue;
    }
    final named = identifier.firstMatch(remaining);
    if (named != null) {
      final text = named.group(0)!;
      if (text == 'true' || text == 'false' || text == 'null') {
        tokens.add(
            _Token('literal', text, text == 'null' ? null : text == 'true'));
      } else {
        tokens.add(_Token('identifier', text));
      }
      index += text.length;
      continue;
    }
    final pair =
        index + 1 < source.length ? source.substring(index, index + 2) : '';
    if (const ['==', '!=', '<=', '>=', '&&', '||'].contains(pair)) {
      tokens.add(_Token('operator', pair));
      index += 2;
    } else if ('+-*/%<>!(),'.contains(character)) {
      tokens.add(_Token('operator', character));
      index++;
    } else {
      throw FormatException('Unsupported character "$character"');
    }
  }
  tokens.add(const _Token('end', ''));
  return tokens;
}
