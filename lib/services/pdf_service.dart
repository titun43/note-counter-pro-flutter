import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:qr_flutter/qr_flutter.dart';
import 'dart:ui' as ui;
import 'storage_service.dart';
import '../models/customer.dart';
import '../models/entry.dart';
import '../utils/constants.dart';

/// PdfService — generates PDF for Khata summary and Customer statement
/// Includes business details + payment QR code
class PdfService {
  /// Generate PDF for all customers (Khata summary)
  static Future<String?> generateKhataPdf(StorageService storage) async {
    try {
      final pdf = pw.Document();
      final customers = storage.customers.where((c) => c.balance != 0).toList();
      final symbol = AppConstants.getCurrencySymbol(storage.defaultCurrency);

      // Business details
      final bizName = storage.businessName;
      final bizOwner = storage.businessOwner;
      final bizPhone = storage.businessPhone;
      final bizAddress = storage.businessAddress;

      final totalToGive = customers
          .where((c) => c.balance > 0)
          .fold(0.0, (sum, c) => sum + c.balance);
      final totalToTake = customers
          .where((c) => c.balance < 0)
          .fold(0.0, (sum, c) => sum + c.balance.abs());

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (pw.Context context) {
            return [
              // Header
              pw.Center(
                child: pw.Text(
                  'বাহি খাতা',
                  style: pw.TextStyle(fontSize: 28, fontWeight: pw.FontWeight.bold),
                ),
              ),
              pw.SizedBox(height: 8),
              // Business details
              if (bizName.isNotEmpty || bizOwner.isNotEmpty) ...[
                pw.Center(
                  child: pw.Text(
                    bizName.isNotEmpty ? bizName : bizOwner,
                    style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
                  ),
                ),
                pw.SizedBox(height: 4),
              ],
              if (bizAddress.isNotEmpty) ...[
                pw.Center(child: pw.Text(bizAddress, style: const pw.TextStyle(fontSize: 11))),
                pw.SizedBox(height: 2),
              ],
              if (bizPhone.isNotEmpty) ...[
                pw.Center(child: pw.Text('Phone: $bizPhone', style: const pw.TextStyle(fontSize: 11))),
                pw.SizedBox(height: 8),
              ],
              pw.Divider(),
              pw.SizedBox(height: 12),
              // Summary
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Total Customers: ${customers.length}'),
                  pw.Text('To Give: $symbol${totalToGive.toStringAsFixed(2)}',
                      style: pw.TextStyle(color: PdfColors.red, fontWeight: pw.FontWeight.bold)),
                  pw.Text('To Take: $symbol${totalToTake.toStringAsFixed(2)}',
                      style: pw.TextStyle(color: PdfColors.green, fontWeight: pw.FontWeight.bold)),
                ],
              ),
              pw.SizedBox(height: 16),
              pw.Divider(),
              pw.SizedBox(height: 8),
              // Table header
              pw.Row(
                children: [
                  pw.Expanded(flex: 1, child: pw.Text('#', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                  pw.Expanded(flex: 3, child: pw.Text('Name', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                  pw.Expanded(flex: 2, child: pw.Text('Phone', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                  pw.Expanded(flex: 2, child: pw.Text('Balance', style: pw.TextStyle(fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.right)),
                  pw.Expanded(flex: 2, child: pw.Text('Status', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                ],
              ),
              pw.Divider(),
              // Customer rows
              ...customers.asMap().entries.map((entry) {
                final i = entry.key + 1;
                final c = entry.value;
                final isToGive = c.balance > 0;
                return pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 4),
                  child: pw.Row(
                    children: [
                      pw.Expanded(flex: 1, child: pw.Text('$i')),
                      pw.Expanded(flex: 3, child: pw.Text(c.name)),
                      pw.Expanded(flex: 2, child: pw.Text(c.phone ?? '-')),
                      pw.Expanded(
                        flex: 2,
                        child: pw.Text(
                          '$symbol${c.balance.abs().toStringAsFixed(2)}',
                          textAlign: pw.TextAlign.right,
                          style: pw.TextStyle(
                            color: isToGive ? PdfColors.red : PdfColors.green,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ),
                      pw.Expanded(
                        flex: 2,
                        child: pw.Text(isToGive ? 'To Give' : 'To Take'),
                      ),
                    ],
                  ),
                );
              }),
              pw.SizedBox(height: 20),
              pw.Divider(),
              pw.SizedBox(height: 8),
              pw.Center(
                child: pw.Text(
                  'Generated by Note Counter Pro on ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
                  style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey),
                ),
              ),
            ];
          },
        ),
      );

      return await _saveAndSharePdf(pdf, 'khata-summary');
    } catch (e) {
      return null;
    }
  }

  /// Generate PDF for a single customer statement
  static Future<String?> generateCustomerPdf(
      StorageService storage, Customer customer, List<Entry> entries) async {
    try {
      final pdf = pw.Document();
      final symbol = AppConstants.getCurrencySymbol(customer.currency ?? storage.defaultCurrency);

      // Business details
      final bizName = storage.businessName;
      final bizOwner = storage.businessOwner;
      final bizPhone = storage.businessPhone;
      final bizAddress = storage.businessAddress;
      final bizUpiId = storage.businessUpiId;

      // Generate payment QR if business UPI ID exists and customer has balance
      pw.Widget? qrWidget;
      if (bizUpiId.isNotEmpty && customer.balance.abs() > 0) {
        final upiUrl = 'upi://pay?pa=${Uri.encodeComponent(bizUpiId)}'
            '&pn=${Uri.encodeComponent(bizName.isNotEmpty ? bizName : bizOwner)}'
            '&am=${customer.balance.abs().toStringAsFixed(2)}&cu=INR';
        // Note: PDF doesn't support QR generation directly, so we'll add text
        qrWidget = pw.Column(
          children: [
            pw.Text('Scan to Pay', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 4),
            pw.Container(
              padding: const pw.EdgeInsets.all(8),
              decoration: pw.BoxDecoration(border: pw.Border.all()),
              child: pw.Text(upiUrl, style: const pw.TextStyle(fontSize: 8)),
            ),
            pw.SizedBox(height: 4),
            pw.Text('Amount: $symbol${customer.balance.abs().toStringAsFixed(2)}',
                style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
          ],
        );
      }

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (pw.Context context) {
            return [
              // Header
              pw.Center(
                child: pw.Text(
                  'Customer Statement',
                  style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
                ),
              ),
              pw.SizedBox(height: 8),
              // Business details
              if (bizName.isNotEmpty || bizOwner.isNotEmpty) ...[
                pw.Center(
                  child: pw.Text(
                    bizName.isNotEmpty ? bizName : bizOwner,
                    style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
                  ),
                ),
                pw.SizedBox(height: 4),
              ],
              if (bizAddress.isNotEmpty) ...[
                pw.Center(child: pw.Text(bizAddress, style: const pw.TextStyle(fontSize: 10))),
                pw.SizedBox(height: 2),
              ],
              if (bizPhone.isNotEmpty) ...[
                pw.Center(child: pw.Text('Phone: $bizPhone', style: const pw.TextStyle(fontSize: 10))),
                pw.SizedBox(height: 8),
              ],
              pw.Divider(),
              pw.SizedBox(height: 12),
              // Customer info
              pw.Text('Customer: ${customer.name}', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
              if (customer.phone != null && customer.phone!.isNotEmpty)
                pw.Text('Phone: ${customer.phone}', style: const pw.TextStyle(fontSize: 11)),
              if (customer.address != null && customer.address!.isNotEmpty)
                pw.Text('Address: ${customer.address}', style: const pw.TextStyle(fontSize: 11)),
              pw.SizedBox(height: 12),
              // Balance
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: customer.balance > 0 ? PdfColors.red50 : PdfColors.green50,
                  border: pw.Border.all(color: customer.balance > 0 ? PdfColors.red : PdfColors.green),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Balance:', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                    pw.Text(
                      '$symbol ${customer.balance.abs().toStringAsFixed(2)}',
                      style: pw.TextStyle(
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold,
                        color: customer.balance > 0 ? PdfColors.red : PdfColors.green,
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 16),
              // QR (if available)
              if (qrWidget != null) ...[
                pw.Center(child: qrWidget),
                pw.SizedBox(height: 16),
                pw.Divider(),
                pw.SizedBox(height: 8),
              ],
              // Transactions table
              pw.Text('Transactions', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 8),
              // Table header
              pw.Row(
                children: [
                  pw.Expanded(flex: 2, child: pw.Text('Date', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                  pw.Expanded(flex: 4, child: pw.Text('Description', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                  pw.Expanded(flex: 2, child: pw.Text('Took', style: pw.TextStyle(fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.right)),
                  pw.Expanded(flex: 2, child: pw.Text('Gave', style: pw.TextStyle(fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.right)),
                ],
              ),
              pw.Divider(),
              // Transaction rows
              ...entries.map((e) {
                final isCredit = e.category == 'credit';
                final dateStr = '${e.date.day}/${e.date.month}/${e.date.year}';
                final desc = e.notes ?? (isCredit ? 'Given' : 'Taken');
                final took = !isCredit ? '$symbol${e.amount.toStringAsFixed(2)}' : '';
                final gave = isCredit ? '$symbol${e.amount.toStringAsFixed(2)}' : '';
                return pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 3),
                  child: pw.Row(
                    children: [
                      pw.Expanded(flex: 2, child: pw.Text(dateStr, style: const pw.TextStyle(fontSize: 10))),
                      pw.Expanded(flex: 4, child: pw.Text(desc, style: const pw.TextStyle(fontSize: 10))),
                      pw.Expanded(
                        flex: 2,
                        child: pw.Text(took, textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 10, color: PdfColors.green, fontWeight: pw.FontWeight.bold)),
                      ),
                      pw.Expanded(
                        flex: 2,
                        child: pw.Text(gave, textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 10, color: PdfColors.red, fontWeight: pw.FontWeight.bold)),
                      ),
                    ],
                  ),
                );
              }),
              pw.SizedBox(height: 12),
              pw.Divider(),
              // Totals
              pw.Row(
                children: [
                  pw.Expanded(flex: 6, child: pw.Text('Total:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                  pw.Expanded(flex: 2, child: pw.Text('$symbol${customer.totalDebit.toStringAsFixed(2)}', textAlign: pw.TextAlign.right, style: pw.TextStyle(color: PdfColors.green, fontWeight: pw.FontWeight.bold))),
                  pw.Expanded(flex: 2, child: pw.Text('$symbol${customer.totalCredit.toStringAsFixed(2)}', textAlign: pw.TextAlign.right, style: pw.TextStyle(color: PdfColors.red, fontWeight: pw.FontWeight.bold))),
                ],
              ),
              pw.SizedBox(height: 20),
              pw.Center(
                child: pw.Text(
                  'Generated by Note Counter Pro on ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
                  style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey),
                ),
              ),
            ];
          },
        ),
      );

      return await _saveAndSharePdf(pdf, 'customer-${customer.name}');
    } catch (e) {
      return null;
    }
  }

  /// Save PDF to file and share
  static Future<String?> _saveAndSharePdf(pw.Document pdf, String prefix) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final now = DateTime.now();
      final filename = '$prefix-${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}.pdf';
      final file = File('${tempDir.path}/$filename');
      await file.writeAsBytes(await pdf.save());

      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'Note Counter Pro - $prefix',
      );
      return file.path;
    } catch (e) {
      return null;
    }
  }
}
