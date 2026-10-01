String nextInvoiceNumber({required String devicePrefix, required DateTime now, required int sequence}) {
  final date = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
  return '$devicePrefix-$date-${sequence.toString().padLeft(4, '0')}';
}
