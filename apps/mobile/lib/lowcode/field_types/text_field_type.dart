import 'package:flutter/services.dart';

import '../builtin_field_types.dart';
import '../field_registry.dart';

FieldType createTextFieldType() {
  registerBuiltinFieldTypes();
  return FieldRegistry().getType('text')!;
}

class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) =>
      newValue.copyWith(text: newValue.text.toUpperCase());
}
