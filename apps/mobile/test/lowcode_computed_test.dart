import 'package:flutter_test/flutter_test.dart';
import 'package:shopos/lowcode/computed_fields.dart';

void main() {
  test('arithmetic precedence, numeric input and nested functions', () {
    expect(ComputedFields.evaluate('price * qty + 10 / 2', {'price': '12.5', 'qty': 4}), 55);
    expect(ComputedFields.evaluate('round((price - 2) * qty, 2)', {'price': 3.567, 'qty': 3}), 4.7);
    expect(ComputedFields.evaluate('-2 + abs(-4) % 3', {}), -1);
  });

  test('aggregate functions traverse lists of records', () {
    final data = {'items': [{'total': 12}, {'total': 8}, {'total': 10}]};
    expect(ComputedFields.evaluate('sum(items.total)', data), 30);
    expect(ComputedFields.evaluate('count(items)', data), 3);
    expect(ComputedFields.evaluate('avg(items.total)', data), 10);
    expect(ComputedFields.evaluate('min(items.total)', data), 8);
    expect(ComputedFields.evaluate('max(items.total)', data), 12);
    expect(ComputedFields.evaluate('sum(items)', {'items': []}), 0);
  });

  test('conditionals are lazy and strings cannot execute code', () {
    expect(ComputedFields.evaluate("if(stock < 5, 'low', 'ok')", {'stock': 2}), 'low');
    expect(ComputedFields.evaluate('if(true, 8, 1 / 0)', {}), 8);
    expect(ComputedFields.evaluate('false && (1 / 0 > 0)', {}), false);
    expect(ComputedFields.evaluate('true || (1 / 0 > 0)', {}), true);
    expect(ComputedFields.evaluate("concat(upper(first), ' ', trim(last))", {'first': 'Rohit', 'last': ' Shah '}), 'ROHIT Shah');
    expect(ComputedFields.evaluate("'fetch(\"secrets\")'", {}), 'fetch("secrets")');
    expect(ComputedFields.evaluate('coalesce(name, \'Guest\')', {'name': null}), 'Guest');
  });

  test('invalid expressions and unapproved functions are rejected', () {
    for (final expression in ['eval(1)', 'process.exit()', 'price.toString()', 'items[0]', '1; 2', '1 / 0', 'sum(1e999)', 'unknown', '1 +', 'round(1, 30)', "'open"]) {
      expect(() => ComputedFields.evaluate(expression, {'price': 1, 'items': []}), throwsFormatException, reason: expression);
    }
    expect(() => ComputedFields.evaluate('(' * 70 + '1' + ')' * 70, {}), throwsFormatException);
    expect(() => ComputedFields.evaluate('1' * 5000, {}), throwsFormatException);
  });

  test('dependencies include root data fields, excluding function and string names', () {
    expect(ComputedFields.dependencies("if(stock < 5, concat(name, ' stock'), sum(items.total))"), {'stock', 'name', 'items'});
  });
}
