import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:qr_flutter/qr_flutter.dart';
import 'storage_service.dart';
import '../models/customer.dart';
import '../models/entry.dart';
import '../utils/constants.dart';

/// PdfService — generates professional PDF for Khata summary and Customer statement
/// Includes business details + actual QR code image
class PdfService {
  /// Generate QR code as image bytes for embedding in PDF
  static Future<Uint8List?> _generateQrImage(String data, {double size = 200}) async {
    try {
      final qrPainter = QrPainter(
        data: data,
        version: QrVersions.auto,
        gapless: true,
        color: const ui.Color(0xFF000000),
        emptyColor: const ui.Color(0xFFFFFFFF),
      );

      final pic = await qrPainter.toImageData(size * 2);
      return pic?.buffer.asUint8List();
    } catch (e) {
      return null;
    }
  }

  /// Generate professional PDF for all customers (Khata summary)
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
      final bizUpiId = storage.businessUpiId;

      final totalToGive = customers
          .where((c) => c.balance > 0)
          .fold(0.0, (sum, c) => sum + c.balance);
      final totalToTake = customers
          .where((c) => c.balance < 0)
          .fold(0.0, (sum, c) => sum + c.balance.abs());
      final netBalance = totalToTake - totalToGive;

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
          header: (pw.Context context) {
            return pw.Column(
              children: [
                // Professional header bar
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: pw.BoxDecoration(
                    color: PdfColor.fromHex('8B0000'),
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            bizName.isNotEmpty ? bizName : (bizOwner.isNotEmpty ? bizOwner : 'My Business'),
                            style: pw.TextStyle(
                              color: PdfColor.fromHex('D4AF37'),
                              fontSize: 18,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                          if (bizOwner.isNotEmpty && bizName.isNotEmpty)
                            pw.Text(
                              'Owner: $bizOwner',
                              style: pw.TextStyle(color: PdfColors.white, fontSize: 9),
                            ),
                        ],
                      ),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.Text(
                            'বাহি খাতা',
                            style: pw.TextStyle(
                              color: PdfColor.fromHex('D4AF37'),
                              fontSize: 16,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                          pw.Text(
                            '${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
                            style: pw.TextStyle(color: PdfColors.white, fontSize: 9),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Business contact info
                pw.Padding(
                  padding: const pw.EdgeInsets.only(top: 6, left: 4, right: 4),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      if (bizPhone.isNotEmpty)
                        pw.Text('📞 $bizPhone', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                      if (bizAddress.isNotEmpty)
                        pw.Text('📍 ${bizAddress.length > 40 ? '${bizAddress.substring(0, 40)}...' : bizAddress}',
                            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                    ],
                  ),
                ),
                pw.SizedBox(height: 10),
              ],
            );
          },
          footer: (pw.Context context) {
            return pw.Column(
              children: [
                pw.Divider(color: PdfColor.fromHex('8B0000')),
                pw.SizedBox(height: 4),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      bizUpiId.isNotEmpty ? 'UPI: $bizUpiId' : 'Note Counter Pro',
                      style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
                    ),
                    pw.Text(
                      'Page ${context.pageNumber} of ${context.pagesCount}',
                      style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
                    ),
                  ],
                ),
              ],
            );
          },
          build: (pw.Context context) {
            return [
              // Summary cards
              pw.Row(
                children: [
                  pw.Expanded(
                    child: pw.Container(
                      padding: const pw.EdgeInsets.all(12),
                      decoration: pw.BoxDecoration(
                        color: PdfColor.fromHex('FFEBEE'),
                        borderRadius: pw.BorderRadius.circular(8),
                        border: pw.Border.all(color: PdfColor.fromHex('EF5350')),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('To Give', style: pw.TextStyle(fontSize: 10, color: PdfColor.fromHex('C62828'))),
                          pw.SizedBox(height: 4),
                          pw.Text(
                            '$symbol${totalToGive.toStringAsFixed(2)}',
                            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('C62828')),
                          ),
                        ],
                      ),
                    ),
                  ),
                  pw.SizedBox(width: 8),
                  pw.Expanded(
                    child: pw.Container(
                      padding: const pw.EdgeInsets.all(12),
                      decoration: pw.BoxDecoration(
                        color: PdfColor.fromHex('E8F5E9'),
                        borderRadius: pw.BorderRadius.circular(8),
                        border: pw.Border.all(color: PdfColor.fromHex('66BB6A')),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('To Take', style: pw.TextStyle(fontSize: 10, color: PdfColor.fromHex('2E7D32'))),
                          pw.SizedBox(height: 4),
                          pw.Text(
                            '$symbol${totalToTake.toStringAsFixed(2)}',
                            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('2E7D32')),
                          ),
                        ],
                      ),
                    ),
                  ),
                  pw.SizedBox(width: 8),
                  pw.Expanded(
                    child: pw.Container(
                      padding: const pw.EdgeInsets.all(12),
                      decoration: pw.BoxDecoration(
                        color: netBalance >= 0 ? PdfColor.fromHex('E8F5E9') : PdfColor.fromHex('FFEBEE'),
                        borderRadius: pw.BorderRadius.circular(8),
                        border: pw.Border.all(color: netBalance >= 0 ? PdfColor.fromHex('66BB6A') : PdfColor.fromHex('EF5350')),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('Net Balance', style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                          pw.SizedBox(height: 4),
                          pw.Text(
                            '$symbol${netBalance.abs().toStringAsFixed(2)}',
                            style: pw.TextStyle(
                              fontSize: 18,
                              fontWeight: pw.FontWeight.bold,
                              color: netBalance >= 0 ? PdfColor.fromHex('2E7D32') : PdfColor.fromHex('C62828'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 16),
              // Table title
              pw.Text('Customer List (${customers.length})', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('8B0000'))),
              pw.SizedBox(height: 8),
              // Table
              pw.TableHelper.fromTextArray(
                border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
                headerDecoration: pw.BoxDecoration(color: PdfColor.fromHex('8B0000')),
                headerStyle: pw.TextStyle(color: PdfColor.fromHex('D4AF37'), fontWeight: pw.FontWeight.bold, fontSize: 10),
                headerAlignment: pw.Alignment.center,
                cellAlignment: pw.Alignment.center,
                cellPadding: const pw.EdgeInsets.all(6),
                headers: ['#', 'Name', 'Phone', 'Balance', 'Status'],
                data: customers.asMap().entries.map((entry) {
                  final i = entry.key + 1;
                  final c = entry.value;
                  final isToGive = c.balance > 0;
                  return [
                    '$i',
                    c.name,
                    c.phone ?? '-',
                    '$symbol${c.balance.abs().toStringAsFixed(2)}',
                    isToGive ? 'To Give' : 'To Take',
                  ];
                }).toList(),
                rowDecoration: pw.BoxDecoration(
                  color: PdfColor.fromHex('F5F5F5'),
                ),
                cellStyle: const pw.TextStyle(fontSize: 10),
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

  /// Generate professional PDF for a single customer statement
  static Future<String?> generateCustomerPdf(
      StorageService storage, Customer customer, List<Entry> entries) async {
    try {
      final pdf = pw.Document();
      final symbol = AppConstants.getCurrencySymbol(storage.defaultCurrency);

      // Business details
      final bizName = storage.businessName;
      final bizOwner = storage.businessOwner;
      final bizPhone = storage.businessPhone;
      final bizAddress = storage.businessAddress;
      final bizUpiId = storage.businessUpiId;

      // Generate QR image if business UPI ID exists and customer has balance
      Uint8List? qrImageBytes;
      if (bizUpiId.isNotEmpty && customer.balance.abs() > 0) {
        final upiUrl = 'upi://pay?pa=${Uri.encodeComponent(bizUpiId)}'
            '&pn=${Uri.encodeComponent(bizName.isNotEmpty ? bizName : bizOwner)}'
            '&am=${customer.balance.abs().toStringAsFixed(2)}&cu=INR';
        qrImageBytes = await _generateQrImage(upiUrl, size: 150);
      }

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
          header: (pw.Context context) {
            return pw.Column(
              children: [
                // Professional header bar
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: pw.BoxDecoration(
                    color: PdfColor.fromHex('8B0000'),
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            bizName.isNotEmpty ? bizName : (bizOwner.isNotEmpty ? bizOwner : 'My Business'),
                            style: pw.TextStyle(
                              color: PdfColor.fromHex('D4AF37'),
                              fontSize: 18,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                          if (bizOwner.isNotEmpty && bizName.isNotEmpty)
                            pw.Text(
                              'Owner: $bizOwner',
                              style: pw.TextStyle(color: PdfColors.white, fontSize: 9),
                            ),
                        ],
                      ),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.Text(
                            'Customer Statement',
                            style: pw.TextStyle(
                              color: PdfColor.fromHex('D4AF37'),
                              fontSize: 14,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                          pw.Text(
                            '${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
                            style: pw.TextStyle(color: PdfColors.white, fontSize: 9),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Business contact info
                pw.Padding(
                  padding: const pw.EdgeInsets.only(top: 6, left: 4, right: 4),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      if (bizPhone.isNotEmpty)
                        pw.Text('Phone: $bizPhone', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                      if (bizAddress.isNotEmpty)
                        pw.Text('Address: ${bizAddress.length > 35 ? '${bizAddress.substring(0, 35)}...' : bizAddress}',
                            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                    ],
                  ),
                ),
                pw.SizedBox(height: 10),
              ],
            );
          },
          footer: (pw.Context context) {
            return pw.Column(
              children: [
                pw.Divider(color: PdfColor.fromHex('8B0000')),
                pw.SizedBox(height: 4),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'Generated by Note Counter Pro',
                      style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
                    ),
                    pw.Text(
                      'Page ${context.pageNumber} of ${context.pagesCount}',
                      style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
                    ),
                  ],
                ),
              ],
            );
          },
          build: (pw.Context context) {
            return [
              // Customer info card
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(16),
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromHex('FFF8E1'),
                  borderRadius: pw.BorderRadius.circular(8),
                  border: pw.Border.all(color: PdfColor.fromHex('D4AF37')),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Customer Details', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('8B0000'))),
                    pw.SizedBox(height: 8),
                    pw.Row(
                      children: [
                        pw.Expanded(
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text('Name: ${customer.name}', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                              if (customer.phone != null && customer.phone!.isNotEmpty)
                                pw.Padding(
                                  padding: const pw.EdgeInsets.only(top: 2),
                                  child: pw.Text('Phone: ${customer.phone}', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                                ),
                              if (customer.address != null && customer.address!.isNotEmpty)
                                pw.Padding(
                                  padding: const pw.EdgeInsets.only(top: 2),
                                  child: pw.Text('Address: ${customer.address}', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                                ),
                            ],
                          ),
                        ),
                        // QR image
                        if (qrImageBytes != null) ...[
                          pw.Column(
                            children: [
                              pw.Text('Scan to Pay', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('8B0000'))),
                              pw.SizedBox(height: 4),
                              pw.Image(pw.MemoryImage(qrImageBytes), width: 100, height: 100),
                              pw.SizedBox(height: 4),
                              pw.Text('$symbol${customer.balance.abs().toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('8B0000'))),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 16),
              // Balance box
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(16),
                decoration: pw.BoxDecoration(
                  color: customer.balance > 0 ? PdfColor.fromHex('FFEBEE') : (customer.balance < 0 ? PdfColor.fromHex('E8F5E9') : PdfColor.fromHex('F5F5F5')),
                  borderRadius: pw.BorderRadius.circular(8),
                  border: pw.Border.all(color: customer.balance > 0 ? PdfColor.fromHex('EF5350') : (customer.balance < 0 ? PdfColor.fromHex('66BB6A') : PdfColors.grey)),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Outstanding Balance', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                    pw.Text(
                      '$symbol ${customer.balance.abs().toStringAsFixed(2)}',
                      style: pw.TextStyle(
                        fontSize: 22,
                        fontWeight: pw.FontWeight.bold,
                        color: customer.balance > 0 ? PdfColor.fromHex('C62828') : (customer.balance < 0 ? PdfColor.fromHex('2E7D32') : PdfColors.black),
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 16),
              // Transactions table
              pw.Text('Transaction History (${entries.length})', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('8B0000'))),
              pw.SizedBox(height: 8),
              pw.TableHelper.fromTextArray(
                border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
                headerDecoration: pw.BoxDecoration(color: PdfColor.fromHex('8B0000')),
                headerStyle: pw.TextStyle(color: PdfColor.fromHex('D4AF37'), fontWeight: pw.FontWeight.bold, fontSize: 10),
                headerAlignment: pw.Alignment.center,
                cellAlignment: pw.Alignment.center,
                cellPadding: const pw.EdgeInsets.all(6),
                headers: ['Date', 'Description', 'Took', 'Gave'],
                data: entries.map((e) {
                  final isCredit = e.category == 'credit';
                  final dateStr = '${e.date.day}/${e.date.month}/${e.date.year}';
                  final desc = e.notes ?? (isCredit ? 'Given' : 'Taken');
                  final took = !isCredit ? '$symbol${e.amount.toStringAsFixed(2)}' : '-';
                  final gave = isCredit ? '$symbol${e.amount.toStringAsFixed(2)}' : '-';
                  return [dateStr, desc, took, gave];
                }).toList(),
                rowDecoration: pw.BoxDecoration(color: PdfColor.fromHex('F5F5F5')),
                cellStyle: const pw.TextStyle(fontSize: 9),
              ),
              pw.SizedBox(height: 12),
              // Totals
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromHex('FFF8E1'),
                  borderRadius: pw.BorderRadius.circular(8),
                  border: pw.Border.all(color: PdfColor.fromHex('D4AF37')),
                ),
                child: pw.Column(
                  children: [
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('Total Took:', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                        pw.Text('$symbol${customer.totalDebit.toStringAsFixed(2)}',
                            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('2E7D32'))),
                      ],
                    ),
                    pw.SizedBox(height: 4),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('Total Gave:', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                        pw.Text('$symbol${customer.totalCredit.toStringAsFixed(2)}',
                            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('C62828'))),
                      ],
                    ),
                    pw.Divider(),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('Balance:', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                        pw.Text('$symbol${customer.balance.abs().toStringAsFixed(2)}',
                            style: pw.TextStyle(
                              fontSize: 16,
                              fontWeight: pw.FontWeight.bold,
                              color: customer.balance > 0 ? PdfColor.fromHex('C62828') : PdfColor.fromHex('2E7D32'),
                            )),
                      ],
                    ),
                  ],
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
