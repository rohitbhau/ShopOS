import 'package:flutter/material.dart';

class FieldSchema {
  const FieldSchema({
    required this.name,
    required this.type,
    this.label = '',
    this.required = false,
    this.readonly = false,
    this.unique = false,
    this.defaultValue,
    this.pattern,
    this.min,
    this.max,
    this.options,
    this.target,
    this.config = const {},
  });
  final String name;
  final String type;
  final String label;
  final bool required;
  final bool readonly;
  final bool unique;
  final dynamic defaultValue;
  final String? pattern;
  final num? min;
  final num? max;
  final List<String>? options;
  final String? target;
  final Map<String, dynamic> config;

  String get title => label.isEmpty ? name : label;

  FieldSchema copyWith({bool? readonly, Map<String, dynamic>? config}) =>
      FieldSchema(
        name: name,
        type: type,
        label: label,
        required: required,
        readonly: readonly ?? this.readonly,
        unique: unique,
        defaultValue: defaultValue,
        pattern: pattern,
        min: min,
        max: max,
        options: options,
        target: target,
        config: config ?? this.config,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'type': type,
        'label': label,
        'required': required,
        'readonly': readonly,
        'unique': unique,
        if (defaultValue != null) 'default': defaultValue,
        if (pattern != null) 'pattern': pattern,
        if (min != null) 'min': min,
        if (max != null) 'max': max,
        if (options != null) 'options': options,
        if (target != null) 'target': target,
        if (config.isNotEmpty) 'config': config,
      };

  factory FieldSchema.fromJson(Map<String, dynamic> json) => FieldSchema(
        name: json['name'] as String,
        type: json['type'] as String,
        label: json['label'] as String? ?? '',
        required: json['required'] as bool? ?? false,
        readonly: json['readonly'] as bool? ?? false,
        unique: json['unique'] as bool? ?? false,
        defaultValue: json['default'],
        pattern: (json['pattern'] ?? json['regex']) as String?,
        min: json['min'] as num?,
        max: json['max'] as num?,
        options:
            (json['options'] as List?)?.map((item) => item.toString()).toList(),
        target: json['target'] as String?,
        config: {
          if (json['expression'] != null) 'expression': json['expression'],
          if (json['formula'] != null) 'expression': json['formula'],
          ...Map<String, dynamic>.from(json['config'] as Map? ?? const {}),
        },
      );
}

typedef FieldWidgetBuilder = Widget Function(BuildContext context,
    FieldSchema schema, dynamic value, ValueChanged<dynamic> onChanged);
typedef FieldValidator = String? Function(FieldSchema schema, dynamic value);
typedef FieldSerializer = dynamic Function(FieldSchema schema, dynamic value);

class FieldType {
  const FieldType(
      {required this.key,
      required this.label,
      required this.icon,
      required this.widgetBuilder,
      required this.validator,
      required this.serializer});
  final String key;
  final String label;
  final IconData icon;
  final FieldWidgetBuilder widgetBuilder;
  final FieldValidator validator;
  final FieldSerializer serializer;
}

class FieldRegistry {
  FieldRegistry._();
  static final FieldRegistry _instance = FieldRegistry._();
  factory FieldRegistry() => _instance;
  final Map<String, FieldType> _types = {};
  void register(FieldType type) => _types[type.key] = type;
  FieldType? getType(String key) => _types[key];
  bool hasType(String key) => _types.containsKey(key);
  List<FieldType> getAllTypes() => _types.values.toList(growable: false);
  Widget buildWidget(BuildContext context, FieldSchema schema, dynamic value,
      ValueChanged<dynamic> onChanged) {
    final type = getType(schema.type);
    return type == null
        ? Text('Unsupported field: ${schema.type}')
        : type.widgetBuilder(context, schema, value, onChanged);
  }

  String? validate(FieldSchema schema, dynamic value) =>
      getType(schema.type)?.validator(schema, value) ??
      (hasType(schema.type) ? null : 'Unsupported field: ${schema.type}');
  dynamic serialize(FieldSchema schema, dynamic value) {
    final type = getType(schema.type);
    return type == null ? value : type.serializer(schema, value);
  }
}

class CommonValidators {
  static String? required(FieldSchema schema, dynamic value) {
    if (!schema.required) return null;
    if (value == null ||
        (value is String && value.trim().isEmpty) ||
        (value is Iterable && value.isEmpty) ||
        (value is Map && value.isEmpty)) {
      return '${schema.title} is required';
    }
    return null;
  }

  static String? numeric(FieldSchema schema, dynamic value) {
    final requiredError = required(schema, value);
    if (requiredError != null || value == null || value == '')
      return requiredError;
    final number = value is num ? value : num.tryParse(value.toString());
    if (number == null || !number.isFinite)
      return '${schema.title} must be a finite number';
    if (schema.min != null && number < schema.min!)
      return '${schema.title} must be at least ${schema.min}';
    if (schema.max != null && number > schema.max!)
      return '${schema.title} must be at most ${schema.max}';
    if (schema.config['integerOnly'] == true &&
        number != number.truncateToDouble()) {
      return '${schema.title} must be a whole number';
    }
    if (schema.config['positiveOnly'] == true && number < 0) {
      return '${schema.title} must be positive';
    }
    final multiple = schema.config['multipleOf'];
    if (multiple is num &&
        multiple > 0 &&
        (number / multiple - (number / multiple).round()).abs() > 0.00000001) {
      return '${schema.title} must be a multiple of $multiple';
    }
    final decimals = schema.config['decimalPlaces'];
    if (decimals is int &&
        decimals >= 0 &&
        decimals <= 12 &&
        (number - num.parse(number.toStringAsFixed(decimals))).abs() >
            0.0000000001) {
      return '${schema.title} allows at most $decimals decimal places';
    }
    return null;
  }

  static String? min(FieldSchema schema, dynamic value) {
    if (schema.min != null && value is num && value < schema.min!) {
      return '${schema.label} must be at least ${schema.min}';
    }
    return null;
  }

  static String? max(FieldSchema schema, dynamic value) {
    if (schema.max != null && value is num && value > schema.max!) {
      return '${schema.label} must be at most ${schema.max}';
    }
    return null;
  }

  static String? pattern(FieldSchema schema, dynamic value) {
    if (schema.pattern == null || value == null || value == '') return null;
    try {
      if (!RegExp(schema.pattern!).hasMatch(value.toString())) {
        return '${schema.title} format is invalid';
      }
    } on FormatException {
      return '${schema.title} has an invalid validation pattern';
    }
    return null;
  }

  static String? text(FieldSchema schema, dynamic value) {
    final requiredError = required(schema, value);
    if (requiredError != null || value == null || value == '')
      return requiredError;
    final minLength = schema.config['minLength'] ?? schema.min;
    final maxLength = schema.config['maxLength'] ?? schema.max;
    if (minLength is num && value.toString().length < minLength) {
      return '${schema.title} must have at least $minLength characters';
    }
    if (maxLength is num && value.toString().length > maxLength) {
      return '${schema.title} must have at most $maxLength characters';
    }
    return pattern(schema, value);
  }
}
