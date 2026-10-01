// WhatsApp sharing service
import 'dart:io';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';

class WhatsAppService {
  static Future<bool> shareInvoice({
    required String phoneNumber,
    required String shopName,
    required String invoiceNumber,
    required double total,
    File? pdfFile,
  }) async {
    final phone = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
    final message = 'Invoice from $shopName\nInvoice #: $invoiceNumber\nTotal: ₹${total.toStringAsFixed(2)}\n\nThank you for your business!';

    if (pdfFile != null) {
      await Share.shareXFiles([XFile(pdfFile.path)], text: message);
      return true;
    } else {
      final url = 'https://wa.me/$phone?text=${Uri.encodeComponent(message)}';
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        return await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
      return false;
    }
  }
}
