// =============================================================================
// Note Counter Pro - Bluetooth Receipt Printer Service
// =============================================================================
// Premium feature: Print receipt to ESC/POS Bluetooth thermal printers
// (common 58mm and 80mm Bluetooth printers used in Indian shops).
//
// Flow:
//   1. discoverPrinters() — scan for nearby Bluetooth printers
//   2. connect() — connect to a printer by IP/host (for network) or
//                  by MAC address (for Bluetooth)
//   3. printReceipt() — print a cash-in/cash-out receipt
//   4. disconnect() — close connection
// =============================================================================

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:esc_pos_printer_plus/esc_pos_printer_plus.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import '../models/entry.dart';
import '../models/bill.dart';
import '../utils/constants.dart';
import 'storage_service.dart';

class PrinterService {
  PrinterService._();
  static final PrinterService _instance = PrinterService._();
  factory PrinterService() => _instance;

  NetworkPrinter? _printer;
  bool _isConnected = false;
  String? _lastConnectedHost;
  int _lastConnectedPort = 9100;

  bool get isConnected => _isConnected;
  String? get lastConnectedHost => _lastConnectedHost;
  int get lastConnectedPort => _lastConnectedPort;

  /// Connect to a network printer (most common ESC/POS printers support
  /// TCP/IP on port 9100).
  /// NOTE: Receipt Printer is FREE for all users (not premium-gated).
  Future<bool> connect({
    required String host,
    int port = 9100,
  }) async {

    try {
      final profile = await CapabilityProfile.load();
      _printer = NetworkPrinter(PaperSize.mm80, profile);
      final result = await _printer!.connect(host, port: port);

      if (result == PosPrintResult.success) {
        _isConnected = true;
        _lastConnectedHost = host;
        _lastConnectedPort = port;
        debugPrint('PrinterService: connected to $host:$port');
        return true;
      } else {
        debugPrint('PrinterService: connect failed: ${result.msg}');
        _isConnected = false;
        return false;
      }
    } catch (e) {
      debugPrint('PrinterService: connect error: $e');
      _isConnected = false;
      return false;
    }
  }

  /// Disconnect from printer
  Future<void> disconnect() async {
    try {
      _printer?.disconnect();
      _isConnected = false;
    } catch (e) { debugPrint('PrinterService failed: $e'); }
  }

  /// Print a cash-in/cash-out receipt
  /// NOTE: Receipt Printer is FREE for all users (not premium-gated).
  Future<bool> printReceipt({
    required Entry entry,
    required StorageService storage,
    String? customerName,
  }) async {
    if (!_isConnected || _printer == null) {
      debugPrint('PrinterService: not connected');
      return false;
    }

    try {
      final p = _printer!;
      final business = storage.businessName.isNotEmpty
          ? storage.businessName
          : 'Note Counter Pro';
      final symbol = AppConstants.getCurrencySymbol(storage.defaultCurrency);
      final date = DateTime.now();
      final dateStr =
          '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';

      // Header
      p.text(business,
          styles: const PosStyles(
            align: PosAlign.center,
            bold: true,
            height: PosTextSize.size2,
            width: PosTextSize.size2,
          ));
      if (storage.businessPhone.isNotEmpty) {
        p.text('Ph: ${storage.businessPhone}',
            styles: const PosStyles(align: PosAlign.center));
      }
      if (storage.businessAddress.isNotEmpty) {
        p.text(storage.businessAddress,
            styles: const PosStyles(align: PosAlign.center));
        p.feed(1);
      }

      p.text('RECEIPT',
          styles: const PosStyles(
            align: PosAlign.center,
            bold: true,
          ));
      p.feed(1);

      // Transaction details
      p.text('Date: $dateStr');
      p.text('Type: ${entry.type == 'cash_in' ? 'CASH IN' : 'CASH OUT'}');
      if (customerName != null && customerName.isNotEmpty) {
        p.text('Customer: $customerName');
      }
      p.feed(1);

      // Denominations breakdown
      if (entry.denominationCounts != null &&
          entry.denominationCounts!.isNotEmpty) {
        p.text('Denominations:',
            styles: const PosStyles(bold: true, underline: true));
        for (final entry in entry.denominationCounts!.entries) {
          final value = int.tryParse(entry.key) ?? 0;
          final count = entry.value;
          final subtotal = value * count;
          p.text(
              '$symbol$value x $count = $symbol${subtotal.toStringAsFixed(0)}');
        }
        p.feed(1);
      }

      // Total
      p.text('TOTAL: $symbol${entry.amount.toStringAsFixed(2)}',
          styles: const PosStyles(
            bold: true,
            height: PosTextSize.size2,
            width: PosTextSize.size2,
          ));
      p.feed(1);

      // Notes
      if (entry.notes != null && entry.notes!.isNotEmpty) {
        p.text('Notes: ${entry.notes}');
        p.feed(1);
      }

      // Footer
      p.feed(1);
      p.text('Thank You!',
          styles: const PosStyles(
            align: PosAlign.center,
            bold: true,
          ));
      p.text('Powered by Note Counter Pro',
          styles: const PosStyles(align: PosAlign.center));
      p.feed(2);
      p.cut();

      debugPrint('PrinterService: receipt printed');
      return true;
    } catch (e) {
      debugPrint('PrinterService: print failed: $e');
      return false;
    }
  }

  /// Print a bill/invoice receipt (#44).
  /// Prints the full bill: header, customer, items, totals, payment
  /// status, and footer. Works with 58mm and 80mm thermal printers.
  Future<bool> printBill({
    required Bill bill,
    required StorageService storage,
  }) async {
    if (!_isConnected || _printer == null) {
      debugPrint('PrinterService: not connected');
      return false;
    }

    try {
      final p = _printer!;
      final business = storage.businessName.isNotEmpty
          ? storage.businessName
          : 'Note Counter Pro';
      final symbol = AppConstants.getCurrencySymbol(bill.currency);
      final dateStr =
          '${bill.date.day}/${bill.date.month}/${bill.date.year}';

      // Header
      p.text(business,
          styles: const PosStyles(
            align: PosAlign.center,
            bold: true,
            height: PosTextSize.size2,
            width: PosTextSize.size2,
          ));
      if (storage.businessPhone.isNotEmpty) {
        p.text('Ph: ${storage.businessPhone}',
            styles: const PosStyles(align: PosAlign.center));
      }
      if (storage.businessAddress.isNotEmpty) {
        p.text(storage.businessAddress,
            styles: const PosStyles(align: PosAlign.center));
        p.feed(1);
      }

      p.text('INVOICE',
          styles: const PosStyles(
            align: PosAlign.center,
            bold: true,
          ));
      p.feed(1);

      // Bill details
      p.text('Bill: ${bill.billNumber}');
      p.text('Date: $dateStr');
      if (bill.customerName != null && bill.customerName!.isNotEmpty) {
        p.text('Customer: ${bill.customerName}');
      }
      if (bill.customerPhone != null && bill.customerPhone!.isNotEmpty) {
        p.text('Phone: ${bill.customerPhone}');
      }
      p.feed(1);

      // Items
      p.text('Items:',
          styles: const PosStyles(bold: true, underline: true));
      for (final item in bill.items) {
        p.text(
            '${item.name} x${item.quantity} = $symbol${item.total.toStringAsFixed(2)}');
      }
      p.feed(1);

      // Totals
      p.text('Subtotal: $symbol${bill.subtotal.toStringAsFixed(2)}');
      if (bill.totalGst > 0) {
        p.text('GST: $symbol${bill.totalGst.toStringAsFixed(2)}');
      }
      if (bill.discountPercent > 0) {
        p.text(
            'Discount (${bill.discountPercent.toStringAsFixed(0)}%): -$symbol${bill.discountAmount.toStringAsFixed(2)}');
      }
      p.text('TOTAL: $symbol${bill.total.toStringAsFixed(2)}',
          styles: const PosStyles(
            bold: true,
            height: PosTextSize.size2,
            width: PosTextSize.size2,
          ));

      // Payment status
      p.feed(1);
      if (bill.paidAmount > 0) {
        p.text('Paid: $symbol${bill.paidAmount.toStringAsFixed(2)}');
        if (bill.remainingAmount > 0) {
          p.text(
              'Balance Due: $symbol${bill.remainingAmount.toStringAsFixed(2)}',
              styles: const PosStyles(bold: true));
        } else {
          p.text('FULLY PAID',
              styles: const PosStyles(bold: true, align: PosAlign.center));
        }
      } else {
        p.text('UNPAID', styles: const PosStyles(bold: true, align: PosAlign.center));
      }

      // Notes
      if (bill.notes != null && bill.notes!.isNotEmpty) {
        p.feed(1);
        p.text('Notes: ${bill.notes}');
      }

      // Footer
      p.feed(1);
      p.text('Thank You!',
          styles: const PosStyles(
            align: PosAlign.center,
            bold: true,
          ));
      p.text('Powered by Note Counter Pro',
          styles: const PosStyles(align: PosAlign.center));
      p.feed(2);
      p.cut();

      debugPrint('PrinterService: bill printed');
      return true;
    } catch (e) {
      debugPrint('PrinterService: printBill failed: $e');
      return false;
    }
  }

  /// Print a barcode label for a product (#41).
  /// Prints the product name, price, and barcode (as text — most thermal
  /// printers don't support barcode rendering via ESC/POS text mode, so
  /// we print the barcode number as large text for manual entry or
  /// external scanning).
  Future<bool> printBarcodeLabel({
    required String productName,
    required double price,
    required String? barcode,
    required String currencySymbol,
  }) async {
    if (!_isConnected || _printer == null) {
      debugPrint('PrinterService: not connected');
      return false;
    }

    try {
      final p = _printer!;

      // Product name
      p.text(productName,
          styles: const PosStyles(
            align: PosAlign.center,
            bold: true,
            height: PosTextSize.size2,
            width: PosTextSize.size2,
          ));

      // Price
      p.text('$currencySymbol${price.toStringAsFixed(2)}',
          styles: const PosStyles(
            align: PosAlign.center,
            bold: true,
            height: PosTextSize.size2,
            width: PosTextSize.size2,
          ));

      // Barcode
      if (barcode != null && barcode.isNotEmpty) {
        p.feed(1);
        p.text('Barcode: $barcode',
            styles: const PosStyles(align: PosAlign.center));
      }

      p.feed(2);
      p.cut();

      debugPrint('PrinterService: barcode label printed');
      return true;
    } catch (e) {
      debugPrint('PrinterService: printBarcodeLabel failed: $e');
      return false;
    }
  }
}
