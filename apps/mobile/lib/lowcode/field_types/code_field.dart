import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../field_registry.dart';

FieldType createCodeFieldType(String type) => FieldType(
      key: type,
      label: type == 'qr' ? 'QR code' : 'Barcode',
      icon: type == 'qr' ? Icons.qr_code : Icons.barcode_reader,
      widgetBuilder: (_, schema, value, onChanged) => _CodeField(
          schema: schema, value: value?.toString() ?? '', onChanged: onChanged),
      validator: CommonValidators.text,
      serializer: (_, value) => value?.toString(),
    );

/// Shared scanner for POS, products and schema-based barcode fields.
Future<String?> scanCode(BuildContext context) =>
    Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const CodeScannerScreen()),
    );

class CodeScannerScreen extends StatefulWidget {
  const CodeScannerScreen({super.key});

  @override
  State<CodeScannerScreen> createState() => _CodeScannerScreenState();
}

class _CodeScannerScreenState extends State<CodeScannerScreen> {
  bool _returned = false;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Scan barcode or QR code')),
        body: Stack(children: [
          MobileScanner(
            onDetect: (capture) {
              if (_returned) return;
              for (final barcode in capture.barcodes) {
                final value = barcode.rawValue;
                if (value == null || value.isEmpty) continue;
                _returned = true;
                Navigator.of(context).pop(value);
                return;
              }
            },
            errorBuilder: (_, error, __) => Center(
                child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.no_photography_outlined, size: 48),
                const SizedBox(height: 16),
                const Text(
                    'Camera unavailable. Allow camera access, or go back and enter the code manually.',
                    textAlign: TextAlign.center),
                const SizedBox(height: 16),
                OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Enter manually')),
              ]),
            )),
          ),
          const Positioned(
              left: 16,
              right: 16,
              bottom: 32,
              child: Card(
                  child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('Place the code inside the camera view',
                    textAlign: TextAlign.center),
              ))),
        ]),
      );
}

class _CodeField extends StatefulWidget {
  const _CodeField(
      {required this.schema, required this.value, required this.onChanged});
  final FieldSchema schema;
  final String value;
  final ValueChanged<dynamic> onChanged;

  @override
  State<_CodeField> createState() => _CodeFieldState();
}

class _CodeFieldState extends State<_CodeField> {
  late final TextEditingController _controller;
  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
  }

  @override
  void didUpdateWidget(covariant _CodeField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_controller.text != widget.value) {
      _controller.value = TextEditingValue(
          text: widget.value,
          selection: TextSelection.collapsed(offset: widget.value.length));
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        TextFormField(
          controller: _controller,
          readOnly: widget.schema.readonly,
          decoration: InputDecoration(
              border: const OutlineInputBorder(),
              hintText: 'Scan or enter code',
              suffixIcon: widget.schema.readonly
                  ? null
                  : IconButton(
                      tooltip: 'Scan code',
                      icon: const Icon(Icons.qr_code_scanner),
                      onPressed: () async {
                        final code = await scanCode(context);
                        if (!mounted || code == null) return;
                        _controller.text = code;
                        widget.onChanged(code);
                      },
                    )),
          onChanged: widget.schema.readonly ? null : widget.onChanged,
        ),
        if (widget.schema.type == 'qr' && widget.value.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: QrImageView(
                data: widget.value,
                size: 160,
                backgroundColor: Colors.white,
                errorStateBuilder: (_, __) =>
                    const Text('This value is too long for a QR code')),
          ),
      ]);
}
