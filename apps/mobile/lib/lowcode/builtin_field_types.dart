import 'dart:convert';

import 'package:flutter/material.dart';

import 'field_registry.dart';
import 'field_types/attachment_field.dart';
import 'field_types/code_field.dart';
import 'field_types/signature_field.dart';

void registerBuiltinFieldTypes() {
  final registry = FieldRegistry();
  final types = [
    _textType('text'),
    _textType('textarea'),
    _numberType('number'),
    _numberType('decimal'),
    _selectType('select', multiple: false),
    _selectType('multiselect', multiple: true),
    _booleanType(),
    _dateType('date', withTime: false),
    _dateType('datetime', withTime: true),
    _relationType(),
    _jsonType(),
    _computedType(),
    createAttachmentFieldType('file'),
    createAttachmentFieldType('image'),
    createCodeFieldType('barcode'),
    createCodeFieldType('qr'),
    createSignatureFieldType(),
  ];
  for (final type in types) {
    // Extensions registered by the app keep precedence.
    if (!registry.hasType(type.key)) registry.register(type);
  }
}

InputDecoration fieldDecoration(FieldSchema schema) => InputDecoration(
      border: const OutlineInputBorder(),
      hintText: schema.config['placeholder']?.toString(),
      prefixText: schema.config['prefix']?.toString() ??
          (schema.config['currency'] == true ||
                  schema.config['showCurrency'] == true
              ? '\u20b9 '
              : null),
      suffixText: schema.config['suffix']?.toString(),
    );

FieldType _textType(String type) => FieldType(
      key: type,
      label: type == 'textarea' ? 'Long text' : 'Text',
      icon: Icons.text_fields,
      widgetBuilder: (context, schema, value, onChanged) => TextFormField(
        initialValue: value?.toString(),
        readOnly: schema.readonly,
        maxLines: type == 'textarea' ? 4 : 1,
        keyboardType: switch (schema.config['keyboardType']) {
          'email' => TextInputType.emailAddress,
          'phone' => TextInputType.phone,
          'url' => TextInputType.url,
          _ =>
            type == 'textarea' ? TextInputType.multiline : TextInputType.text,
        },
        decoration: fieldDecoration(schema),
        onChanged: schema.readonly ? null : onChanged,
      ),
      validator: CommonValidators.text,
      serializer: (_, value) => value?.toString(),
    );

FieldType _numberType(String type) => FieldType(
      key: type,
      label: type == 'decimal' ? 'Decimal' : 'Number',
      icon: Icons.numbers,
      widgetBuilder: (context, schema, value, onChanged) => TextFormField(
        initialValue: value?.toString(), readOnly: schema.readonly,
        keyboardType:
            const TextInputType.numberWithOptions(decimal: true, signed: true),
        decoration: fieldDecoration(schema),
        // Keep invalid input so it can be validated instead of silently becoming null.
        onChanged: schema.readonly
            ? null
            : (input) => onChanged(input.trim().isEmpty ? null : input),
      ),
      validator: CommonValidators.numeric,
      serializer: (_, value) => value == null || value == ''
          ? null
          : value is num
              ? value
              : num.parse(value.toString()),
    );

FieldType _selectType(String type, {required bool multiple}) => FieldType(
      key: type,
      label: multiple ? 'Multiple choices' : 'Choice',
      icon: Icons.arrow_drop_down_circle_outlined,
      widgetBuilder: (context, schema, value, onChanged) {
        final options = (schema.options ?? const <String>[]).toSet().toList();
        if (multiple) {
          final selected = value is Iterable
              ? value.map((item) => item.toString()).toSet()
              : <String>{};
          return Wrap(spacing: 8, runSpacing: 4, children: [
            for (final option in {...options, ...selected})
              FilterChip(
                label: Text(option),
                selected: selected.contains(option),
                onSelected: schema.readonly
                    ? null
                    : (active) {
                        active ? selected.add(option) : selected.remove(option);
                        onChanged(selected.toList());
                      },
              ),
            if (options.isEmpty && selected.isEmpty)
              const Text('No choices configured'),
          ]);
        }
        final selected = value?.toString();
        final allOptions = {
          ...options,
          if (selected != null && selected.isNotEmpty) selected
        };
        return DropdownButtonFormField<String>(
          key: ValueKey('${schema.name}:$selected'),
          initialValue: allOptions.contains(selected) ? selected : null,
          isExpanded: true,
          decoration: fieldDecoration(schema),
          items: allOptions
              .map((option) =>
                  DropdownMenuItem(value: option, child: Text(option)))
              .toList(),
          onChanged: schema.readonly ? null : onChanged,
        );
      },
      validator: (schema, value) {
        final required = CommonValidators.required(schema, value);
        if (required != null || value == null || value == '') return required;
        if (multiple && value is! List) return 'Choose one or more options';
        final selected = multiple ? value as List : [value];
        if (selected
            .any((item) => !(schema.options ?? []).contains(item.toString()))) {
          return 'Choose a valid option for ${schema.title}';
        }
        return null;
      },
      serializer: (_, value) => value,
    );

FieldType _booleanType() => FieldType(
      key: 'bool',
      label: 'Yes / No',
      icon: Icons.toggle_on_outlined,
      widgetBuilder: (_, schema, value, onChanged) => SwitchListTile(
        contentPadding: EdgeInsets.zero,
        value: value == true,
        title: Text((value == true
                    ? schema.config['trueLabel']
                    : schema.config['falseLabel'])
                ?.toString() ??
            (value == true ? 'Yes' : 'No')),
        onChanged: schema.readonly ? null : onChanged,
      ),
      validator: (schema, value) =>
          CommonValidators.required(schema, value) ??
          (value != null && value is! bool
              ? '${schema.title} must be Yes or No'
              : null),
      serializer: (_, value) => value == true,
    );

DateTime? fieldDate(dynamic value) =>
    value is DateTime ? value : DateTime.tryParse(value?.toString() ?? '');

FieldType _dateType(String type, {required bool withTime}) => FieldType(
      key: type,
      label: withTime ? 'Date & time' : 'Date',
      icon: Icons.calendar_today_outlined,
      widgetBuilder: (context, schema, value, onChanged) {
        final selected = fieldDate(value);
        final firstDate = fieldDate(schema.config['minDate']) ?? DateTime(1900);
        final lastDate =
            fieldDate(schema.config['maxDate']) ?? DateTime(2200, 12, 31);
        return Row(children: [
          Expanded(
              child: OutlinedButton.icon(
            icon: const Icon(Icons.calendar_today_outlined),
            label: Text(selected == null
                ? (value == null
                    ? 'Choose ${withTime ? 'date & time' : 'date'}'
                    : value.toString())
                : selected
                    .toLocal()
                    .toString()
                    .substring(0, withTime ? 16 : 10)),
            onPressed: schema.readonly
                ? null
                : () async {
                    if (firstDate.isAfter(lastDate)) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content:
                              Text('The configured date range is invalid')));
                      return;
                    }
                    final proposed = selected ?? DateTime.now();
                    final initial = proposed.isBefore(firstDate)
                        ? firstDate
                        : proposed.isAfter(lastDate)
                            ? lastDate
                            : proposed;
                    final date = await showDatePicker(
                        context: context,
                        initialDate: initial,
                        firstDate: firstDate,
                        lastDate: lastDate);
                    if (date == null || !context.mounted) return;
                    if (!withTime) {
                      onChanged(date);
                      return;
                    }
                    final time = await showTimePicker(
                        context: context,
                        initialTime:
                            TimeOfDay.fromDateTime(selected ?? DateTime.now()));
                    if (time == null || !context.mounted) return;
                    onChanged(DateTime(date.year, date.month, date.day,
                        time.hour, time.minute));
                  },
          )),
          if (!schema.readonly && value != null)
            IconButton(
                tooltip: 'Clear date',
                onPressed: () => onChanged(null),
                icon: const Icon(Icons.clear)),
        ]);
      },
      validator: (schema, value) {
        final required = CommonValidators.required(schema, value);
        if (required != null || value == null || value == '') return required;
        final date = fieldDate(value);
        if (date == null) return '${schema.title} must be a valid date';
        final minimum = fieldDate(schema.config['minDate']);
        final maximum = fieldDate(schema.config['maxDate']);
        if (minimum != null && date.isBefore(minimum))
          return '${schema.title} is before the earliest allowed date';
        if (maximum != null &&
            date.isAfter(withTime
                ? maximum
                : DateTime(
                    maximum.year, maximum.month, maximum.day, 23, 59, 59)))
          return '${schema.title} is after the latest allowed date';
        return null;
      },
      serializer: (_, value) {
        final date = fieldDate(value);
        return date == null
            ? null
            : withTime
                ? date.toIso8601String()
                : '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      },
    );

/// Resolved by the data-owning screen, so the renderer remains tenant-agnostic.
Map<String, String> relationOptions(FieldSchema schema) {
  final configured = schema.config['records'] ??
      schema.config['options'] ??
      schema.options ??
      const [];
  final result = <String, String>{};
  if (configured is Map) {
    for (final entry in configured.entries)
      result[entry.key.toString()] = entry.value.toString();
  } else if (configured is Iterable) {
    for (final option in configured) {
      if (option is Map) {
        final id =
            option[schema.config['valueField'] ?? 'id'] ?? option['value'];
        final label = option[schema.config['labelField'] ?? 'name'] ??
            option['label'] ??
            id;
        if (id != null) result[id.toString()] = label.toString();
      } else {
        result[option.toString()] = option.toString();
      }
    }
  }
  return result;
}

FieldType _relationType() => FieldType(
      key: 'relation',
      label: 'Related record',
      icon: Icons.link,
      widgetBuilder: (context, schema, value, onChanged) {
        final options = relationOptions(schema);
        final selected = value?.toString();
        if (selected != null &&
            selected.isNotEmpty &&
            !options.containsKey(selected)) {
          options[selected] = 'Unavailable record ($selected)';
        }
        return DropdownButtonFormField<String>(
          key: ValueKey('${schema.name}:$selected'),
          initialValue: options.containsKey(selected) ? selected : null,
          isExpanded: true,
          decoration: fieldDecoration(schema).copyWith(
              hintText: options.isEmpty
                  ? 'No ${schema.target ?? 'related'} records yet'
                  : 'Choose a record'),
          items: [
            if (!schema.required)
              const DropdownMenuItem(value: '', child: Text('None')),
            for (final entry in options.entries)
              DropdownMenuItem(
                  value: entry.key,
                  child: Text(entry.value, overflow: TextOverflow.ellipsis)),
          ],
          onChanged: schema.readonly
              ? null
              : (value) => onChanged(value == '' ? null : value),
        );
      },
      validator: CommonValidators.required,
      serializer: (_, value) => value == '' ? null : value?.toString(),
    );

FieldType _jsonType() => FieldType(
      key: 'json',
      label: 'Structured data',
      icon: Icons.data_object,
      widgetBuilder: (context, schema, value, onChanged) => TextFormField(
        initialValue: value is String
            ? value
            : value == null
                ? ''
                : const JsonEncoder.withIndent('  ').convert(value),
        readOnly: schema.readonly,
        maxLines: 5,
        decoration: fieldDecoration(schema),
        onChanged: schema.readonly ? null : onChanged,
      ),
      validator: (schema, value) {
        final required = CommonValidators.required(schema, value);
        if (required != null || value == null || value == '') return required;
        try {
          final decoded = value is String ? jsonDecode(value) : value;
          if (decoded is! Map && decoded is! List)
            return '${schema.title} must be a JSON object or list';
          jsonEncode(decoded);
          return null;
        } on Object {
          return '${schema.title} must contain valid JSON';
        }
      },
      serializer: (_, value) => value == null || value == ''
          ? null
          : value is String
              ? jsonDecode(value)
              : value,
    );

FieldType _computedType() => FieldType(
      key: 'computed',
      label: 'Calculated value',
      icon: Icons.calculate_outlined,
      widgetBuilder: (_, schema, value, __) => InputDecorator(
          decoration: fieldDecoration(schema),
          child: SelectableText(value?.toString() ?? '—')),
      validator: CommonValidators.required,
      serializer: (_, value) => value,
    );
