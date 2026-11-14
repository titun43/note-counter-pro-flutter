// =============================================================================
// Note Counter Pro - Group Split PDF Service
// =============================================================================
// Generates a settlement PDF for a GroupExpenseGroup and returns the file
// path. The caller (GroupDetailScreen) then shares it via share_plus.
//
// PDF-safe currency: the default PDF font (Helvetica) has no ₹ glyph, so the
// INR symbol is rendered as "Rs." and other symbols as their ISO code. This
// matches the convention used by the existing PdfService for Khata/customer
// statements.
// =============================================================================

import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/group_expense.dart';
import '../utils/app_localizations.dart';

class GroupSplitPdfService {
  /// PDF-safe currency label for a currency symbol.
  static String _pdfSymbol(String sym) {
    switch (sym) {
      case '₹':
        return 'Rs.';
      case '\$':
        return '\$';
      case '€':
        return 'EUR';
      case '£':
        return 'GBP';
      case '৳':
        return 'Tk.';
      case 'রू':
        return 'Rs.';
      default:
        return sym;
    }
  }

  static String _fmt(double v) =>
      v == v.roundToDouble() ? v.round().toString() : v.toStringAsFixed(2);

  /// Generate the settlement PDF and return the file. Never returns null —
  /// throws on failure so the caller can surface a snackbar.
  Future<File> generate(
    GroupExpenseGroup group,
    List<GroupSettlement> settlements,
    AppLocalizations loc,
  ) async {
    final sym = _pdfSymbol(group.currencySymbol);
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        header: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: pw.BoxDecoration(
                color: PdfColor.fromHex('0A0A1A'),
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Note Counter Pro',
                      style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('D4AF37'))),
                  pw.SizedBox(height: 2),
                  pw.Text(loc.t('settlementSummary'),
                      style: pw.TextStyle(fontSize: 12, color: PdfColors.grey400)),
                ],
              ),
            ),
            pw.SizedBox(height: 12),
            pw.Text(group.name,
                style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('1A1A2E'))),
            pw.SizedBox(height: 2),
            pw.Text(_formatDateHeader(group.updatedAt),
                style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
            pw.Divider(),
          ],
        ),
        build: (ctx) => [
          // === Summary row ===
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: PdfColor.fromHex('FFF8E1'),
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
              children: [
                _summaryCell(loc.t('totalExpense'), '$sym${_fmt(group.totalExpenses)}'),
                _summaryCell(loc.t('members'), '${group.members.length}'),
                _summaryCell(loc.t('perPerson'), '$sym${_fmt(group.perPersonShare)}'),
              ],
            ),
          ),
          pw.SizedBox(height: 20),

          // === Expenses table ===
          pw.Text(loc.t('totalExpense').toUpperCase(),
              style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('D4AF37'))),
          pw.SizedBox(height: 6),
          _expensesTable(group, loc, sym),
          pw.SizedBox(height: 20),

          // === Settlement ===
          pw.Text(loc.t('settlement').toUpperCase(),
              style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('D4AF37'))),
          pw.SizedBox(height: 6),
          if (settlements.isEmpty)
            pw.Text(loc.t('noSettlementNeeded'), style: const pw.TextStyle(color: PdfColors.grey600))
          else
            _settlementTable(settlements, sym, loc),

          pw.SizedBox(height: 24),
          pw.Center(
            child: pw.Text(loc.t('calculatedBy'),
                style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey)),
          ),
        ],
      ),
    );

    final tempDir = await getTemporaryDirectory();
    final now = DateTime.now();
    final filename = 'settlement-${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}.pdf';
    final file = File('${tempDir.path}/$filename');
    await file.writeAsBytes(await pdf.save());
    return file;
  }

  pw.Widget _summaryCell(String label, String value) {
    return pw.Expanded(
      child: pw.Column(
        children: [
          pw.Text(value, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('FBBF24'))),
          pw.SizedBox(height: 2),
          pw.Text(label, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
        ],
      ),
    );
  }

  pw.Widget _expensesTable(GroupExpenseGroup g, AppLocalizations loc, String sym) {
    if (g.expenses.isEmpty) {
      return pw.Text(loc.t('noExpenses'), style: const pw.TextStyle(color: PdfColors.grey600));
    }
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
      columnWidths: const {
        0: pw.FlexColumnWidth(3),
        1: pw.FlexColumnWidth(2),
        2: pw.FlexColumnWidth(2),
        3: pw.FixedColumnWidth(70),
      },
      children: [
        pw.TableRow(
          decoration: pw.BoxDecoration(color: PdfColor.fromHex('1A1A2E')),
          children: [
            _cellHeader(loc.t('whoPaid')),
            _cellHeader(loc.t('categoryLabel')),
            _cellHeader(loc.t('descriptionLabel')),
            _cellHeader(loc.t('amountLabel'), right: true),
          ],
        ),
        ...g.expenses.map((e) => pw.TableRow(
              children: [
                _cell(e.paidBy),
                _cell(loc.t('groupCategory_${e.category}')),
                _cell(e.description.isEmpty ? '—' : e.description),
                _cell('$sym${_fmt(e.amount)}', right: true, bold: true),
              ],
            )),
      ],
    );
  }

  pw.Widget _settlementTable(List<GroupSettlement> settlements, String sym, AppLocalizations loc) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
      columnWidths: const {
        0: pw.FlexColumnWidth(3),
        1: pw.FixedColumnWidth(20),
        2: pw.FlexColumnWidth(3),
        3: pw.FixedColumnWidth(70),
      },
      children: [
        pw.TableRow(
          decoration: pw.BoxDecoration(color: PdfColor.fromHex('1A1A2E')),
          children: [
            _cellHeader('From'),
            _cellHeader(''),
            _cellHeader('To'),
            _cellHeader(loc.t('amountLabel'), right: true),
          ],
        ),
        ...settlements.map((s) => pw.TableRow(
              children: [
                _cell(s.from),
                _cell('→', center: true),
                _cell(s.to),
                _cell('$sym${_fmt(s.amount)}', right: true, bold: true),
              ],
            )),
      ],
    );
  }

  pw.Widget _cellHeader(String text, {bool right = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: pw.Text(text,
          style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('D4AF37')),
          textAlign: right ? pw.TextAlign.right : pw.TextAlign.left),
    );
  }

  pw.Widget _cell(String text, {bool right = false, bool center = false, bool bold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      child: pw.Text(text,
          style: pw.TextStyle(fontSize: 10, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal),
          textAlign: center ? pw.TextAlign.center : (right ? pw.TextAlign.right : pw.TextAlign.left)),
    );
  }

  String _formatDateHeader(DateTime d) {
    const months = ['January','February','March','April','May','June',
      'July','August','September','October','November','December'];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }
}
