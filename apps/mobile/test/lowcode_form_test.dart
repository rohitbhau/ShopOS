import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shopos/lowcode/builtin_field_types.dart';
import 'package:shopos/lowcode/field_registry.dart';
import 'package:shopos/lowcode/form_renderer.dart';

void main() {
  setUp(registerBuiltinFieldTypes);

  Future<void> form(WidgetTester tester, List<FieldSchema> fields, {
    Map<String, dynamic>? data,
    FutureOr<void> Function(Map<String, dynamic>)? onSubmit,
    bool readonly = false,
    FormLayout layout = FormLayout.singleColumn,
  }) => tester.pumpWidget(MaterialApp(home: Scaffold(body: DynamicForm(
    entityId: 'test', fields: fields, initialData: data,
    onSubmit: onSubmit ?? (_) {}, readonly: readonly, layout: layout,
  ))));

  final values = <String, dynamic>{
    'text': 'Rice', 'textarea': 'A long description', 'number': 12,
    'decimal': 12.5, 'date': '2026-09-29', 'datetime': '2026-09-29T09:30:00.000',
    'bool': true, 'select': 'Retail', 'multiselect': ['Retail'],
    'file': {'name': 'note.txt', 'mimeType': 'text/plain', 'size': 1, 'data': 'YQ=='},
    'image': {'name': 'pixel.png', 'mimeType': 'image/png', 'size': 68, 'data': 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+j5N8AAAAASUVORK5CYII='},
    'relation': 'c1', 'barcode': '8901234567890', 'qr': 'shopos:invoice-1',
    'signature': {'format': 'strokes', 'width': 1, 'height': 1, 'strokes': [[{'x': 0.1, 'y': 0.2}, {'x': 0.6, 'y': 0.7}]]},
    'json': {'amount': 10}, 'computed': 6,
  };

  for (final entry in values.entries) {
    testWidgets('${entry.key} field renders and serializes', (tester) async {
      Map<String, dynamic>? saved;
      final field = FieldSchema(name: 'value', type: entry.key, label: 'Field', required: true,
        options: const ['Retail', 'Wholesale'],
        config: {
          if (entry.key == 'relation') 'records': [{'id': 'c1', 'name': 'Customer one'}],
          if (entry.key == 'computed') 'expression': '2 * 3',
        },
      );
      await form(tester, [field], data: {'value': entry.value}, onSubmit: (value) => saved = value);
      expect(find.textContaining('Unsupported field'), findsNothing);
      await tester.tap(find.text('Save'));
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(saved?['value'], entry.value);
    });
  }

  testWidgets('invalid numeric input is rejected instead of being cleared', (tester) async {
    var saved = false;
    await form(tester, [const FieldSchema(name: 'price', type: 'decimal', label: 'Price')], onSubmit: (_) => saved = true);
    await tester.enterText(find.byType(TextFormField), '-');
    await tester.tap(find.text('Save'));
    await tester.pump();
    expect(find.text('Price must be a finite number'), findsOneWidget);
    expect(saved, false);
    await tester.enterText(find.byType(TextFormField), '12.5');
    await tester.tap(find.text('Save'));
    await tester.pump();
    expect(saved, true);
  });

  testWidgets('defaults, unknown keys, computed dependencies and validation survive edits', (tester) async {
    Map<String, dynamic>? saved;
    await form(tester, const [
      FieldSchema(name: 'total', type: 'computed', config: {'expression': 'subtotal + 5'}),
      FieldSchema(name: 'subtotal', type: 'computed', config: {'expression': 'price * qty'}),
      FieldSchema(name: 'price', type: 'decimal', defaultValue: 10),
      FieldSchema(name: 'qty', type: 'number', defaultValue: 2, config: {'rules': [{'expression': 'value > 0', 'message': 'Enter a positive quantity'}]}),
    ], data: {'legacy': {'retained': true}}, onSubmit: (value) => saved = value);
    expect(find.text('25'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).last, '3');
    await tester.tap(find.text('Save'));
    await tester.pump();
    expect(saved?['total'], 35);
    expect(saved?['subtotal'], 30);
    expect(saved?['qty'], 3);
    expect(saved?['legacy'], {'retained': true});
    await tester.enterText(find.byType(TextFormField).last, '0');
    await tester.tap(find.text('Save'));
    await tester.pump();
    expect(find.text('Enter a positive quantity'), findsOneWidget);
  });

  testWidgets('saving awaits completion, prevents duplicate submits and displays errors', (tester) async {
    var calls = 0;
    final completer = Completer<void>();
    await form(tester, const [FieldSchema(name: 'name', type: 'text')], onSubmit: (_) { calls++; return completer.future; });
    await tester.enterText(find.byType(TextFormField), 'Original');
    await tester.tap(find.text('Save'));
    await tester.pump();
    expect(tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed, isNull);
    expect(calls, 1);
    completer.completeError(StateError('Storage unavailable'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Storage unavailable'), findsOneWidget);
    expect(find.text('Original'), findsOneWidget);
    expect(tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed, isNotNull);
  });

  testWidgets('readonly empty fields cannot be edited or submitted', (tester) async {
    await form(tester, const [FieldSchema(name: 'name', type: 'text'), FieldSchema(name: 'active', type: 'bool')], readonly: true);
    expect(tester.widget<TextFormField>(find.byType(TextFormField)).readOnly, true);
    expect(tester.widget<SwitchListTile>(find.byType(SwitchListTile)).onChanged, isNull);
    expect(find.text('Save'), findsNothing);
  });

  testWidgets('tablet layout uses two columns and narrow layout stacks fields', (tester) async {
    tester.view.physicalSize = const Size(1000, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await form(tester, const [FieldSchema(name: 'first', type: 'text'), FieldSchema(name: 'second', type: 'text')], layout: FormLayout.twoColumn);
    var fields = find.byType(TextFormField);
    expect(tester.getTopLeft(fields.first).dy, tester.getTopLeft(fields.last).dy);
    expect(tester.getTopLeft(fields.last).dx, greaterThan(tester.getTopLeft(fields.first).dx));
    tester.view.physicalSize = const Size(400, 800);
    await tester.pump();
    fields = find.byType(TextFormField);
    expect(tester.getTopLeft(fields.last).dy, greaterThan(tester.getTopLeft(fields.first).dy));
  });

  testWidgets('signature can be drawn, saved and cleared', (tester) async {
    Map<String, dynamic>? saved;
    await form(tester, const [FieldSchema(name: 'sign', type: 'signature')], onSubmit: (value) => saved = value);
    await tester.drag(find.byKey(const ValueKey('signature-pad-sign')), const Offset(70, 20));
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pump();
    expect(saved?['sign']['strokes'], isNotEmpty);
    await tester.tap(find.text('Clear signature'));
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pump();
    expect(saved?['sign'], isNull);
  });

  testWidgets('file picker retains bytes for offline saves and supports removal', (tester) async {
    final original = FilePicker.platform;
    FilePicker.platform = _FilePicker();
    addTearDown(() => FilePicker.platform = original);
    Map<String, dynamic>? saved;
    await form(tester, const [FieldSchema(name: 'file', type: 'file')], onSubmit: (value) => saved = value);
    await tester.tap(find.text('Choose file'));
    await tester.pumpAndSettle();
    expect(find.text('sample.txt'), findsOneWidget);
    await tester.tap(find.text('Save'));
    await tester.pump();
    expect(utf8.decode(base64Decode(saved?['file']['data'] as String)), 'offline');
    await tester.tap(find.byTooltip('Remove attachment'));
    await tester.pump();
    expect(find.text('sample.txt'), findsNothing);
  });

  testWidgets('cyclic computed fields block saving with a visible error', (tester) async {
    var saved = false;
    await form(tester, const [
      FieldSchema(name: 'a', type: 'computed', config: {'expression': 'b + 1'}),
      FieldSchema(name: 'b', type: 'computed', config: {'expression': 'a + 1'}),
    ], onSubmit: (_) => saved = true);
    expect(find.textContaining('Circular calculation'), findsOneWidget);
    await tester.tap(find.text('Save'));
    await tester.pump();
    expect(saved, false);
  });

  test('validation handles bounds, regex configuration, precision and JSON', () {
    final registry = FieldRegistry();
    const price = FieldSchema(name: 'price', type: 'decimal', min: 0, max: 100, config: {'decimalPlaces': 2});
    for (final value in [-1, 101, 'NaN', 'Infinity', 'abc', 1.234]) expect(registry.validate(price, value), isNotNull);
    expect(registry.validate(price, '12.50'), isNull);
    expect(registry.validate(const FieldSchema(name: 'text', type: 'text', pattern: '['), 'a'), contains('invalid validation pattern'));
    expect(registry.validate(const FieldSchema(name: 'data', type: 'json'), '{broken}'), isNotNull);
    expect(registry.validate(const FieldSchema(name: 'data', type: 'json'), '{"ok":true}'), isNull);
    expect(registry.serialize(const FieldSchema(name: 'data', type: 'json'), '{"ok":true}'), {'ok': true});
    expect(registry.validate(const FieldSchema(name: 'date', type: 'date'), 'not a date'), isNotNull);
    final schema = FieldSchema.fromJson({'name': 'total', 'type': 'computed', 'expression': 'price * qty'});
    expect(FieldSchema.fromJson(schema.toJson()).config['expression'], 'price * qty');
  });
}

class _FilePicker extends FilePicker {
  @override
  Future<FilePickerResult?> pickFiles({
    String? dialogTitle, String? initialDirectory,
    FileType type = FileType.any, List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading, bool allowCompression = true,
    int compressionQuality = 30, bool allowMultiple = false, bool withData = false,
    bool withReadStream = false, bool lockParentWindow = false,
    bool readSequential = false,
  }) async => FilePickerResult([PlatformFile(name: 'sample.txt', size: 7, bytes: Uint8List.fromList(utf8.encode('offline')))]);
}
