import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import 'builtin_field_types.dart';
import 'computed_fields.dart';
import 'field_registry.dart';

enum FormLayout { singleColumn, twoColumn, grid }

/// Renders a tenant-owned schema without knowing its entity or repository.
class DynamicForm extends StatefulWidget {
  const DynamicForm({
    super.key,
    required this.entityId,
    required this.fields,
    this.initialData,
    required this.onSubmit,
    this.onCancel,
    this.submitButtonText,
    this.readonly = false,
    this.layout = FormLayout.twoColumn,
  });

  final String entityId;
  final List<FieldSchema> fields;
  final Map<String, dynamic>? initialData;
  final FutureOr<void> Function(Map<String, dynamic>) onSubmit;
  final VoidCallback? onCancel;
  final String? submitButtonText;
  final bool readonly;
  final FormLayout layout;

  @override
  State<DynamicForm> createState() => _DynamicFormState();
}

class _DynamicFormState extends State<DynamicForm> {
  final _registry = FieldRegistry();
  late Map<String, dynamic> _data;
  final _errors = <String, String?>{};
  final _computedErrors = <String, String>{};
  bool _saving = false;
  String? _submitError;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    registerBuiltinFieldTypes();
    _initialize();
  }

  @override
  void didUpdateWidget(covariant DynamicForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.entityId != widget.entityId) {
      _generation++;
      _initialize();
    }
  }

  void _initialize() {
    _data = Map<String, dynamic>.from(widget.initialData ?? const {});
    _errors.clear();
    _submitError = null;
    for (final field in widget.fields) {
      if (_data.containsKey(field.name)) continue;
      dynamic value = field.defaultValue;
      if (value == 'now' && field.type == 'datetime' ||
          value == 'today' && field.type == 'date') {
        value = DateTime.now();
      } else if (value is Map || value is List) {
        value = jsonDecode(jsonEncode(value));
      }
      _data[field.name] = value ??
          switch (field.type) {
            'bool' => false,
            'multiselect' => <String>[],
            _ => null,
          };
    }
    _compute();
  }

  bool _isComputed(FieldSchema field) =>
      field.type == 'computed' || field.config['expression'] != null;

  void _compute() {
    _computedErrors.clear();
    final computed = {
      for (final field in widget.fields.where(_isComputed)) field.name: field
    };
    final visited = <String>{};
    final active = <String>{};
    void calculate(String name) {
      if (visited.contains(name)) return;
      if (!active.add(name))
        throw FormatException('Circular calculation involving $name');
      final field = computed[name]!;
      final expression = field.config['expression']?.toString() ?? '';
      try {
        for (final dependency in ComputedFields.dependencies(expression)) {
          if (computed.containsKey(dependency)) calculate(dependency);
          if (_computedErrors.containsKey(dependency))
            throw FormatException('Fix the calculation for $dependency');
        }
        _data[name] = ComputedFields.evaluate(expression, _data);
      } on FormatException catch (error) {
        _data[name] = null;
        _computedErrors[name] = error.message;
      } finally {
        active.remove(name);
        visited.add(name);
      }
    }

    for (final name in computed.keys) calculate(name);
  }

  void _changed(FieldSchema field, dynamic value) {
    if (_saving || widget.readonly || field.readonly || _isComputed(field))
      return;
    setState(() {
      _data[field.name] = value;
      _errors.remove(field.name);
      _submitError = null;
      _compute();
    });
  }

  String? _customError(FieldSchema field) {
    final rules = field.config['rules'] ?? field.config['customRules'];
    if (rules is! List) return null;
    for (final rule in rules) {
      if (rule is! Map || rule['expression'] is! String)
        return '${field.title} has an invalid validation rule';
      try {
        if (ComputedFields.evaluate(rule['expression'] as String,
                {..._data, 'value': _data[field.name]}) !=
            true) {
          return rule['message']?.toString() ??
              '${field.title} does not satisfy its validation rule';
        }
      } on FormatException {
        return '${field.title} has an invalid validation rule';
      }
    }
    return null;
  }

  Future<void> _submit() async {
    if (_saving || widget.readonly) return;
    FocusScope.of(context).unfocus();
    _compute();
    final errors = <String, String?>{..._computedErrors};
    for (final field in widget.fields) {
      if (_computedErrors.containsKey(field.name)) continue;
      final error =
          _registry.validate(field, _data[field.name]) ?? _customError(field);
      if (error != null) errors[field.name] = error;
    }
    setState(() {
      _errors
        ..clear()
        ..addAll(errors);
      _submitError = null;
    });
    if (errors.isNotEmpty) {
      setState(() =>
          _submitError = 'Please fix the highlighted fields before saving.');
      return;
    }
    setState(() => _saving = true);
    try {
      // Preserve fields unknown to the current schema/client during edits.
      final serialized = Map<String, dynamic>.from(_data);
      for (final field in widget.fields) {
        serialized[field.name] = _registry.serialize(field, _data[field.name]);
      }
      await widget.onSubmit(serialized);
    } on Object catch (error) {
      if (mounted)
        setState(() => _submitError =
            'Could not save: ${error.toString().replaceFirst(RegExp(r'^(Exception|StateError|Bad state): '), '')}');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) =>
      LayoutBuilder(builder: (context, constraints) {
        final available = constraints.maxWidth - 32;
        final columns =
            widget.layout == FormLayout.singleColumn || available < 640
                ? 1
                : widget.layout == FormLayout.grid
                    ? (available / 320).floor().clamp(2, 4)
                    : 2;
        final width = (available - (columns - 1) * 16) / columns;
        return Form(
            child: ListView(padding: const EdgeInsets.all(16), children: [
          Wrap(spacing: 16, runSpacing: 16, children: [
            for (final field in widget.fields)
              if (field.config['hidden'] != true)
                SizedBox(
                  key: ValueKey('$_generation:${field.name}'),
                  width: field.config['fullWidth'] == true ? available : width,
                  child: _buildField(field),
                ),
          ]),
          const SizedBox(height: 24),
          if (_submitError != null)
            Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  _submitError!,
                  key: const ValueKey('form-submit-error'),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                )),
          if (!widget.readonly)
            Row(children: [
              if (widget.onCancel != null) ...[
                Expanded(
                    child: OutlinedButton(
                        onPressed: _saving ? null : widget.onCancel,
                        child: const Text('Cancel'))),
                const SizedBox(width: 16),
              ],
              Expanded(
                  child: ElevatedButton(
                onPressed: _saving ? null : _submit,
                child: _saving
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(widget.submitButtonText ?? 'Save'),
              )),
            ]),
        ]));
      });

  Widget _buildField(FieldSchema field) {
    final readonly =
        widget.readonly || field.readonly || _saving || _isComputed(field);
    final error = _computedErrors[field.name] ?? _errors[field.name];
    final effective = field.copyWith(readonly: readonly);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text.rich(TextSpan(
            text: field.title,
            style: const TextStyle(fontWeight: FontWeight.w500),
            children: [
              if (field.required)
                TextSpan(
                    text: ' *',
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error))
            ],
          ))),
      if (_isComputed(field))
        InputDecorator(
            decoration: const InputDecoration(border: OutlineInputBorder()),
            child: SelectableText(_data[field.name]?.toString() ?? '—'))
      else
        _registry.buildWidget(context, effective, _data[field.name],
            (value) => _changed(field, value)),
      if (error != null)
        Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(error,
                style: TextStyle(
                    color: Theme.of(context).colorScheme.error, fontSize: 12))),
      if (field.config['helpText'] != null)
        Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(field.config['helpText'].toString(),
                style: Theme.of(context).textTheme.bodySmall)),
    ]);
  }
}

class DynamicFormBuilder {
  static Widget build({
    required BuildContext context,
    required String entityId,
    required List<FieldSchema> fields,
    Map<String, dynamic>? initialData,
    required FutureOr<void> Function(Map<String, dynamic>) onSubmit,
    VoidCallback? onCancel,
    String? submitButtonText,
    bool readonly = false,
    FormLayout layout = FormLayout.twoColumn,
  }) =>
      DynamicForm(
        entityId: entityId,
        fields: fields,
        initialData: initialData,
        onSubmit: onSubmit,
        onCancel: onCancel,
        submitButtonText: submitButtonText,
        readonly: readonly,
        layout: layout,
      );
}
