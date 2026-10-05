// PDF generation service for invoices
import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';

class PdfService {
  // Generate invoice PDF
  static Future<File> generateInvoicePdf({
    required String shopName,
    required String shopAddress,
    required String shopPhone,
    required String shopGstin,
    required String invoiceNumber,
    required DateTime invoiceDate,
    String? customerName,
    String? customerPhone,
    String? customerAddress,
    required List<InvoiceItem> items,
    required double subtotal,
    required double taxAmount,
    required double total,
    required String paymentMode,
    required String paymentStatus,
  }) async {
    final pdf = pw.Document();

    // Load font for better rendering
    final font = await PdfGoogleFonts.notoSansRegular();
    final fontBold = await PdfGoogleFonts.notoSansBold();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              _buildHeader(shopName, shopAddress, shopPhone, shopGstin, font, fontBold),
              pw.SizedBox(height: 20),
              pw.Divider(),
              pw.SizedBox(height: 10),

              // Invoice details
              _buildInvoiceDetails(
                invoiceNumber,
                invoiceDate,
                customerName,
                customerPhone,
                customerAddress,
                font,
                fontBold,
              ),
              pw.SizedBox(height: 20),

              // Items table
              _buildItemsTable(items, font, fontBold),
              pw.SizedBox(height: 20),

              // Totals
              _buildTotals(subtotal, taxAmount, total, font, fontBold),
              pw.SizedBox(height: 20),

              // Payment info
              _buildPaymentInfo(paymentMode, paymentStatus, font, fontBold),
              pw.Spacer(),

              // Footer
              _buildFooter(font),
            ],
          );
        },
      ),
    );

    // Save to file
    final output = await getTemporaryDirectory();
    final file = File('${output.path}/invoice_$invoiceNumber.pdf');
    await file.writeAsBytes(await pdf.save());

    return file;
  }

  static pw.Widget _buildHeader(
    String shopName,
    String shopAddress,
    String shopPhone,
    String shopGstin,
    pw.Font font,
    pw.Font fontBold,
  ) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              shopName,
              style: pw.TextStyle(
                font: fontBold,
                fontSize: 24,
                color: PdfColors.blue800,
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Text(shopAddress, style: pw.TextStyle(font: font, fontSize: 10)),
            pw.Text('Phone: $shopPhone', style: pw.TextStyle(font: font, fontSize: 10)),
            if (shopGstin.isNotEmpty)
              pw.Text('GSTIN: $shopGstin', style: pw.TextStyle(font: font, fontSize: 10)),
          ],
        ),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Text(
              'TAX INVOICE',
              style: pw.TextStyle(
                font: fontBold,
                fontSize: 18,
                color: PdfColors.blue800,
              ),
            ),
          ],
        ),
      ],
    );
  }

  static pw.Widget _buildInvoiceDetails(
    String invoiceNumber,
    DateTime invoiceDate,
    String? customerName,
    String? customerPhone,
    String? customerAddress,
    pw.Font font,
    pw.Font fontBold,
  ) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Customer details
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('Bill To:', style: pw.TextStyle(font: fontBold, fontSize: 12)),
            pw.SizedBox(height: 4),
            if (customerName != null)
              pw.Text(customerName, style: pw.TextStyle(font: font, fontSize: 10)),
            if (customerPhone != null)
              pw.Text(customerPhone, style: pw.TextStyle(font: font, fontSize: 10)),
            if (customerAddress != null)
              pw.Text(customerAddress, style: pw.TextStyle(font: font, fontSize: 10)),
            if (customerName == null) pw.Text('Walk-in Customer', style: pw.TextStyle(font: font, fontSize: 10)),
          ],
        ),

        // Invoice details
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Text('Invoice #: $invoiceNumber', style: pw.TextStyle(font: fontBold, fontSize: 10)),
            pw.SizedBox(height: 4),
            pw.Text(
              'Date: ${DateFormat('dd MMM yyyy').format(invoiceDate)}',
              style: pw.TextStyle(font: font, fontSize: 10),
            ),
            pw.Text(
              'Time: ${DateFormat('hh:mm a').format(invoiceDate)}',
              style: pw.TextStyle(font: font, fontSize: 10),
            ),
          ],
        ),
      ],
    );
  }

  static pw.Widget _buildItemsTable(
    List<InvoiceItem> items,
    pw.Font font,
    pw.Font fontBold,
  ) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey400),
      children: [
        // Header
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey200),
          children: [
            _buildTableCell('#', fontBold, isHeader: true),
            _buildTableCell('Item', fontBold, isHeader: true),
            _buildTableCell('Qty', fontBold, isHeader: true),
            _buildTableCell('Price', fontBold, isHeader: true),
            _buildTableCell('GST%', fontBold, isHeader: true),
            _buildTableCell('Amount', fontBold, isHeader: true),
          ],
        ),

        // Items
        ...items.asMap().entries.map((entry) {
          final index = entry.key + 1;
          final item = entry.value;
          return pw.TableRow(
            children: [
              _buildTableCell(index.toString(), font),
              _buildTableCell(item.name, font),
              _buildTableCell(item.quantity.toString(), font),
              _buildTableCell('₹${item.price.toStringAsFixed(2)}', font),
              _buildTableCell('${item.gstRate}%', font),
              _buildTableCell('₹${item.total.toStringAsFixed(2)}', font),
            ],
          );
        }).toList(),
      ],
    );
  }

  static pw.Widget _buildTableCell(String text, pw.Font font, {bool isHeader = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          font: font,
          fontSize: isHeader ? 11 : 10,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }

  static pw.Widget _buildTotals(
    double subtotal,
    double taxAmount,
    double total,
    pw.Font font,
    pw.Font fontBold,
  ) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.end,
      children: [
        pw.Container(
          width: 250,
          child: pw.Column(
            children: [
              _buildTotalRow('Subtotal:', subtotal, font),
              pw.SizedBox(height: 4),
              _buildTotalRow('Tax (GST):', taxAmount, font),
              pw.SizedBox(height: 4),
              pw.Divider(),
              pw.SizedBox(height: 4),
              _buildTotalRow('Grand Total:', total, fontBold, isGrandTotal: true),
            ],
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildTotalRow(String label, double amount, pw.Font font, {bool isGrandTotal = false}) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(
            font: font,
            fontSize: isGrandTotal ? 14 : 11,
            fontWeight: isGrandTotal ? pw.FontWeight.bold : pw.FontWeight.normal,
          ),
        ),
        pw.Text(
          '₹${amount.toStringAsFixed(2)}',
          style: pw.TextStyle(
            font: font,
            fontSize: isGrandTotal ? 14 : 11,
            fontWeight: isGrandTotal ? pw.FontWeight.bold : pw.FontWeight.normal,
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildPaymentInfo(
    String paymentMode,
    String paymentStatus,
    pw.Font font,
    pw.Font fontBold,
  ) {
    final statusColor = paymentStatus == 'paid'
        ? PdfColors.green
        : paymentStatus == 'pending'
            ? PdfColors.red
            : PdfColors.orange;

    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'Payment Mode: ${paymentMode.toUpperCase()}',
            style: pw.TextStyle(font: font, fontSize: 10),
          ),
          pw.Text(
            'Status: ${paymentStatus.toUpperCase()}',
            style: pw.TextStyle(
              font: fontBold,
              fontSize: 10,
              color: statusColor,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildFooter(pw.Font font) {
    return pw.Column(
      children: [
        pw.Divider(),
        pw.SizedBox(height: 10),
        pw.Text(
          'Thank you for your business!',
          style: pw.TextStyle(font: font, fontSize: 12, fontStyle: pw.FontStyle.italic),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          'Powered by ShopOS',
          style: pw.TextStyle(font: font, fontSize: 8, color: PdfColors.grey600),
        ),
      ],
    );
  }

  // Print PDF
  static Future<void> printPdf(File pdfFile) async {
    final bytes = await pdfFile.readAsBytes();
    await Printing.layoutPdf(onLayout: (_) => bytes);
  }

  // Share PDF
  static Future<void> sharePdf(File pdfFile) async {
    await Printing.sharePdf(
      bytes: await pdfFile.readAsBytes(),
      filename: pdfFile.path.split('/').last,
    );
  }
}

// Invoice item model for PDF
class InvoiceItem {
  final String name;
  final int quantity;
  final double price;
  final double gstRate;
  final double total;

  InvoiceItem({
    required this.name,
    required this.quantity,
    required this.price,
    required this.gstRate,
    required this.total,
  });
}
