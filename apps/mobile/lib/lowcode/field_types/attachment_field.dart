import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../field_registry.dart';

FieldType createAttachmentFieldType(String type) => FieldType(
      key: type,
      label: type == 'image' ? 'Image' : 'File',
      icon: type == 'image' ? Icons.image_outlined : Icons.attach_file,
      widgetBuilder: (_, schema, value, onChanged) =>
          _AttachmentField(schema: schema, value: value, onChanged: onChanged),
      validator: (schema, value) {
        final required = CommonValidators.required(schema, value);
        if (required != null || value == null || value == '') return required;
        if (value is String && Uri.tryParse(value)?.scheme == 'https')
          return null;
        if (value is! Map ||
            value['data'] is! String ||
            value['name'] is! String) {
          return 'Choose a valid ${schema.type}';
        }
        try {
          final bytes = base64Decode(value['data'] as String);
          if (bytes.isEmpty) return 'The selected file is empty';
          final limit =
              schema.config['maxSizeBytes'] as num? ?? 5 * 1024 * 1024;
          if (bytes.length > limit) return 'This file exceeds the allowed size';
        } on FormatException {
          return 'The selected file could not be read';
        }
        return null;
      },
      serializer: (_, value) => value,
    );

class _AttachmentField extends StatefulWidget {
  const _AttachmentField(
      {required this.schema, this.value, required this.onChanged});
  final FieldSchema schema;
  final dynamic value;
  final ValueChanged<dynamic> onChanged;

  @override
  State<_AttachmentField> createState() => _AttachmentFieldState();
}

class _AttachmentFieldState extends State<_AttachmentField> {
  bool _busy = false;
  String? _error;

  Future<void> _pick({bool camera = false}) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      Uint8List? bytes;
      String? name;
      String? mime;
      if (widget.schema.type == 'image') {
        final file = await ImagePicker().pickImage(
          source: camera ? ImageSource.camera : ImageSource.gallery,
          maxWidth: 1600,
          maxHeight: 1600,
          imageQuality: 85,
        );
        if (file != null) {
          bytes = await file.readAsBytes();
          name = file.name;
          mime = file.mimeType;
        }
      } else {
        final extensions = (widget.schema.config['extensions'] as List?)
            ?.map((item) => item.toString())
            .toList();
        final picked = await FilePicker.platform.pickFiles(
          allowMultiple: false,
          withData: true,
          type: extensions == null || extensions.isEmpty
              ? FileType.any
              : FileType.custom,
          allowedExtensions:
              extensions == null || extensions.isEmpty ? null : extensions,
        );
        if (picked != null && picked.files.isNotEmpty) {
          bytes = picked.files.first.bytes;
          name = picked.files.first.name;
          if (bytes == null)
            throw const FormatException('The selected file could not be read');
        }
      }
      if (!mounted || bytes == null || name == null) return;
      final limit =
          widget.schema.config['maxSizeBytes'] as num? ?? 5 * 1024 * 1024;
      if (bytes.isEmpty)
        throw const FormatException('The selected file is empty');
      if (bytes.length > limit)
        throw FormatException(
            'Choose a file smaller than ${(limit / 1024 / 1024).toStringAsFixed(1)} MB');
      widget.onChanged({
        'name': name,
        'mimeType': mime ?? _mimeType(name),
        'size': bytes.length,
        'data': base64Encode(bytes),
      });
    } on Object catch (error) {
      if (mounted)
        setState(() => _error = error is FormatException
            ? error.message
            : 'Could not open the picker. Check file or camera access and try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _download() async {
    try {
      final value = widget.value;
      if (value is Map && value['data'] is String) {
        await FilePicker.platform.saveFile(
          dialogTitle: 'Save attachment',
          fileName: value['name']?.toString() ?? 'attachment',
          bytes: base64Decode(value['data'] as String),
        );
      } else if (value is String && Uri.tryParse(value)?.scheme == 'https') {
        if (!await launchUrl(Uri.parse(value),
            mode: LaunchMode.externalApplication)) {
          throw const FormatException('The file could not be opened');
        }
      }
    } on Object {
      if (mounted)
        setState(
            () => _error = 'The file could not be saved. Please try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isImage = widget.schema.type == 'image';
    final value = widget.value;
    Uint8List? preview;
    if (isImage && value is Map && value['data'] is String) {
      try {
        preview = base64Decode(value['data'] as String);
      } on FormatException {/* Validation reports invalid data. */}
    }
    final name = value is Map ? value['name']?.toString() : value?.toString();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (preview != null)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Image.memory(preview,
              height: 140,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) =>
                  const Text('Image preview unavailable')),
        )
      else if (isImage &&
          value is String &&
          Uri.tryParse(value)?.scheme == 'https')
        Image.network(value,
            height: 140,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) =>
                const Text('Image preview unavailable offline')),
      if (name != null && name.isNotEmpty)
        Text(name, maxLines: 2, overflow: TextOverflow.ellipsis),
      if (widget.schema.readonly && name == null) const Text('No attachment'),
      Wrap(spacing: 8, runSpacing: 8, children: [
        if (!widget.schema.readonly)
          OutlinedButton.icon(
            onPressed: _busy ? null : _pick,
            icon: Icon(
                isImage ? Icons.photo_library_outlined : Icons.attach_file),
            label: Text(
                _busy ? 'Opening…' : 'Choose ${isImage ? 'image' : 'file'}'),
          ),
        if (isImage && !widget.schema.readonly)
          IconButton(
            tooltip: 'Take photo',
            onPressed: _busy ? null : () => _pick(camera: true),
            icon: const Icon(Icons.camera_alt_outlined),
          ),
        if (name != null)
          IconButton(
              tooltip: 'Save attachment',
              onPressed: _download,
              icon: const Icon(Icons.download_outlined)),
        if (value != null && !widget.schema.readonly)
          IconButton(
            tooltip: 'Remove attachment',
            onPressed: _busy ? null : () => widget.onChanged(null),
            icon: const Icon(Icons.clear),
          ),
      ]),
      if (_error != null)
        Text(_error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error)),
    ]);
  }
}

String _mimeType(String name) => switch (name.split('.').last.toLowerCase()) {
      'png' => 'image/png',
      'jpg' || 'jpeg' => 'image/jpeg',
      'webp' => 'image/webp',
      'gif' => 'image/gif',
      'pdf' => 'application/pdf',
      'txt' => 'text/plain',
      'csv' => 'text/csv',
      'json' => 'application/json',
      _ => 'application/octet-stream',
    };
