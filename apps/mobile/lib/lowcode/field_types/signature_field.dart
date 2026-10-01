import 'package:flutter/material.dart';

import '../field_registry.dart';

FieldType createSignatureFieldType() => FieldType(
      key: 'signature',
      label: 'Signature',
      icon: Icons.draw_outlined,
      widgetBuilder: (_, schema, value, onChanged) =>
          SignatureField(schema: schema, value: value, onChanged: onChanged),
      validator: (schema, value) {
        final required = CommonValidators.required(schema, value);
        if (required != null || value == null) return required;
        if (value is! Map ||
            value['format'] != 'strokes' ||
            value['strokes'] is! List ||
            (value['strokes'] as List).isEmpty ||
            (value['strokes'] as List)
                .every((stroke) => stroke is! List || stroke.isEmpty)) {
          return 'Draw a signature for ${schema.title}';
        }
        return null;
      },
      serializer: (_, value) => value,
    );

class SignatureField extends StatefulWidget {
  const SignatureField(
      {super.key, required this.schema, this.value, required this.onChanged});
  final FieldSchema schema;
  final dynamic value;
  final ValueChanged<dynamic> onChanged;

  @override
  State<SignatureField> createState() => _SignatureFieldState();
}

class _SignatureFieldState extends State<SignatureField> {
  List<List<Offset>> _strokes = [];

  @override
  void initState() {
    super.initState();
    _read();
  }

  @override
  void didUpdateWidget(covariant SignatureField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) _read();
  }

  void _read() {
    final value = widget.value;
    _strokes = [];
    if (value is! Map || value['strokes'] is! List) return;
    for (final stroke in value['strokes'] as List) {
      if (stroke is! List) continue;
      final points = <Offset>[];
      for (final point in stroke) {
        if (point is Map && point['x'] is num && point['y'] is num) {
          points.add(Offset(
              (point['x'] as num).toDouble(), (point['y'] as num).toDouble()));
        }
      }
      if (points.isNotEmpty) _strokes.add(points);
    }
  }

  Offset _point(Offset local, double width) =>
      Offset((local.dx / width).clamp(0, 1), (local.dy / 160).clamp(0, 1));

  void _save() => widget.onChanged(_strokes.isEmpty
      ? null
      : {
          'format': 'strokes',
          'width': 1,
          'height': 1,
          'strokes': _strokes
              .map((stroke) => stroke
                  .map((point) => {'x': point.dx, 'y': point.dy})
                  .toList())
              .toList(),
        });

  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Semantics(
            label:
                widget.schema.readonly ? 'Saved signature' : 'Draw signature',
            child: LayoutBuilder(
                builder: (context, constraints) => Container(
                      height: 160,
                      width: double.infinity,
                      decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(8)),
                      child: GestureDetector(
                        key: ValueKey('signature-pad-${widget.schema.name}'),
                        behavior: HitTestBehavior.opaque,
                        onPanStart: widget.schema.readonly
                            ? null
                            : (details) => setState(() => _strokes.add([
                                  _point(details.localPosition,
                                      constraints.maxWidth)
                                ])),
                        onPanUpdate: widget.schema.readonly
                            ? null
                            : (details) => setState(() {
                                  if (_strokes.isNotEmpty)
                                    _strokes.last.add(_point(
                                        details.localPosition,
                                        constraints.maxWidth));
                                }),
                        onPanEnd:
                            widget.schema.readonly ? null : (_) => _save(),
                        onPanCancel: widget.schema.readonly ? null : _save,
                        child: CustomPaint(
                            painter: _SignaturePainter(_strokes),
                            child: _strokes.isEmpty
                                ? const Center(
                                    child: Text('Sign here',
                                        style: TextStyle(color: Colors.grey)))
                                : null),
                      ),
                    ))),
        if (!widget.schema.readonly)
          TextButton.icon(
            onPressed: _strokes.isEmpty
                ? null
                : () {
                    setState(() => _strokes = []);
                    _save();
                  },
            icon: const Icon(Icons.clear),
            label: const Text('Clear signature'),
          ),
      ]);
}

class _SignaturePainter extends CustomPainter {
  const _SignaturePainter(this.strokes);
  final List<List<Offset>> strokes;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black87
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    for (final stroke in strokes) {
      if (stroke.isEmpty) continue;
      final first = stroke.first;
      if (stroke.length == 1) {
        canvas.drawCircle(
            Offset(first.dx * size.width, first.dy * size.height), 1.2, paint);
        continue;
      }
      final path = Path()
        ..moveTo(first.dx * size.width, first.dy * size.height);
      for (final point in stroke.skip(1))
        path.lineTo(point.dx * size.width, point.dy * size.height);
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SignaturePainter oldDelegate) => true;
}
