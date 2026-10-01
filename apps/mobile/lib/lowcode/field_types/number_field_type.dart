import '../builtin_field_types.dart';
import '../field_registry.dart';

/// Compatibility factories use the same validated implementation as the form.
FieldType createNumberFieldType() {
  registerBuiltinFieldTypes();
  return FieldRegistry().getType('number')!;
}

FieldType createDecimalFieldType() {
  registerBuiltinFieldTypes();
  return FieldRegistry().getType('decimal')!;
}
