import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/pdf_invoice_service.dart';

/// Provider für PDF Invoice Service
final pdfInvoiceServiceProvider = Provider<PdfInvoiceService>((ref) {
  return PdfInvoiceService();
});
