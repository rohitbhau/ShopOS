import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../domain/shop_models.dart';

enum InvoicePaper { a4, roll58, roll80 }

class InvoicePdfService {
  String buildUpiUri({
    required String payeeVpa,
    required String payeeName,
    required double amount,
    required String reference,
  }) {
    final query = <String, String>{
      'pa': payeeVpa,
      'pn': payeeName,
      'am': amount.toStringAsFixed(2),
      'cu': 'INR',
      'tn': reference,
    };
    return 'upi://pay?${query.entries.map((entry) => '${Uri.encodeComponent(entry.key)}=${Uri.encodeComponent(entry.value)}').join('&')}';
  }

  Future<Uint8List> generate({
    required String shopName,
    required Invoice invoice,
    String? address,
    String? gstin,
    String? payeeVpa,
    InvoicePaper paper = InvoicePaper.a4,
  }) async {
    final document = pw.Document();
    final pageFormat = switch (paper) {
      InvoicePaper.a4 => PdfPageFormat.a4,
      InvoicePaper.roll58 => PdfPageFormat(
          58 * PdfPageFormat.mm, 297 * PdfPageFormat.mm,
          marginAll: 4 * PdfPageFormat.mm),
      InvoicePaper.roll80 => PdfPageFormat(
          80 * PdfPageFormat.mm, 297 * PdfPageFormat.mm,
          marginAll: 5 * PdfPageFormat.mm),
    };
    final upiUri = payeeVpa == null
        ? null
        : buildUpiUri(
            payeeVpa: payeeVpa,
            payeeName: shopName,
            amount: invoice.total,
            reference: invoice.number,
          );

    document.addPage(
      pw.MultiPage(
        pageFormat: pageFormat,
        build: (context) => [
          pw.Center(
              child: pw.Text(shopName,
                  style: pw.TextStyle(
                      fontSize: 20, fontWeight: pw.FontWeight.bold))),
          if (address != null) pw.Center(child: pw.Text(address)),
          if (gstin != null) pw.Center(child: pw.Text('GSTIN: $gstin')),
          pw.SizedBox(height: 14),
          pw.Text('Invoice ${invoice.number}'),
          pw.Text(
              'Date: ${invoice.createdAt.toLocal().toIso8601String().substring(0, 10)}'),
          pw.SizedBox(height: 10),
          pw.TableHelper.fromTextArray(
            headers: const ['Item', 'Qty', 'Rate', 'Total'],
            data: invoice.lines
                .map((line) => [
                      line.product.name,
                      '${line.quantity}',
                      line.product.price.toStringAsFixed(2),
                      line.total.toStringAsFixed(2),
                    ])
                .toList(),
          ),
          pw.Divider(),
          pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Text('Total: Rs ${invoice.total.toStringAsFixed(2)}',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
          pw.SizedBox(height: 12),
          if (upiUri != null) ...[
            pw.Center(
                child: pw.BarcodeWidget(
                    barcode: pw.Barcode.qrCode(),
                    data: upiUri,
                    width: 110,
                    height: 110)),
            pw.Center(child: pw.Text('Scan to pay by UPI')),
          ],
          pw.SizedBox(height: 14),
          pw.Center(child: pw.Text('Thank you, visit again')),
        ],
      ),
    );
    return document.save();
  }
}
