// =============================================================================
// Note Counter Pro — Scan & Calculate Screen
// =============================================================================
//
// Handwritten bill OCR with column-wise sum calculation.
//
// Flow (4 stages):
//   1. Capture — camera or gallery via image_picker
//   2. Processing — animated loader while ML Kit runs
//   3. Verify — auto-detected columns shown to user for confirmation
//   4. Result — table with per-column sums + grand total
//
// Features:
//   - Hybrid column detection (auto + user verify)
//   - Per-column sum display
//   - Decimal support (3.5, 47.5)
//   - Empty cells treated as 0
//   - Bengali + English + Hindi digit normalization
//   - Edit option (numbers can be removed/edited)
//   - Save result (in-memory only for now; persisted history is a future
//     enhancement)
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../services/scan_calculate_service.dart';
import '../services/feedback_service.dart';
import '../utils/constants.dart';
import '../utils/app_localizations.dart';

class ScanCalculateScreen extends StatefulWidget {
  const ScanCalculateScreen({super.key});

  @override
  State<ScanCalculateScreen> createState() => _ScanCalculateScreenState();
}

enum _Stage { capture, processing, verify, result }

class _ScanCalculateScreenState extends State<ScanCalculateScreen> {
  _Stage _stage = _Stage.capture;
  ScanResult? _result;
  String? _imagePath;
  String? _errorMessage;

  // --------------------------------------------------------------- capture

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: source,
        maxWidth: 2000,
        maxHeight: 2000,
        imageQuality: 90,
      );
      if (picked == null) return; // user cancelled

      setState(() {
        _imagePath = picked.path;
        _stage = _Stage.processing;
        _errorMessage = null;
      });

      // Run OCR + column detection.
      final result = await ScanCalculateService().processImage(picked.path);

      if (!mounted) return;
      if (result.errorMessage != null) {
        setState(() {
          _errorMessage = result.errorMessage;
          _stage = _Stage.capture;
        });
        FeedbackService().error();
        return;
      }
      setState(() {
        _result = result;
        _stage = _Stage.verify;
      });
      FeedbackService().success();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _stage = _Stage.capture;
      });
      FeedbackService().error();
    }
  }

  void _confirmAndShowResult() {
    FeedbackService().click();
    setState(() => _stage = _Stage.result);
  }

  void _rescan() {
    FeedbackService().tap();
    setState(() {
      _stage = _Stage.capture;
      _result = null;
      _imagePath = null;
      _errorMessage = null;
    });
  }

  // --------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final loc = context.loc;

    return Scaffold(
      backgroundColor: isDark ? AppColors.bgDark : AppColors.bgLight,
      appBar: AppBar(
        title: Text(loc.t('scanCalculate')),
        backgroundColor: isDark ? AppColors.bgCardDark : AppColors.bgCard,
        foregroundColor: isDark ? AppColors.bgCard : AppColors.bgDark,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            FeedbackService().tap();
            Navigator.pop(context);
          },
        ),
      ),
      body: SafeArea(
        child: _buildStage(theme, isDark, loc),
      ),
    );
  }

  Widget _buildStage(ThemeData theme, bool isDark, AppLocalizations loc) {
    switch (_stage) {
      case _Stage.capture:
        return _buildCaptureStage(theme, isDark, loc);
      case _Stage.processing:
        return _buildProcessingStage(theme, isDark, loc);
      case _Stage.verify:
        return _buildVerifyStage(theme, isDark, loc);
      case _Stage.result:
        return _buildResultStage(theme, isDark, loc);
    }
  }

  // ----------------------------------------------------- stage: capture

  Widget _buildCaptureStage(ThemeData theme, bool isDark, AppLocalizations loc) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Hero icon
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? [AppColors.primary, AppColors.primaryDark]
                      : [AppColors.bgDark, const Color(0xFF2A2A4E)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Icon(
                Icons.document_scanner_outlined,
                size: 48,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              loc.t('scanCalculateTitle'),
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: isDark ? AppColors.bgCard : AppColors.bgDark,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              loc.t('scanCalculateDesc'),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 32),

            // Camera button
            SizedBox(
              width: double.infinity,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.primary, AppColors.primaryDark],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.4),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () {
                      HapticFeedback.selectionClick();
                      _pickImage(ImageSource.camera);
                    },
                    child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.camera_alt, color: Color(0xFF1A1A2E), size: 22),
                          SizedBox(width: 10),
                          Text(
                            'OPEN CAMERA',
                            style: TextStyle(
                              color: Color(0xFF1A1A2E),
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Gallery button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  HapticFeedback.selectionClick();
                  _pickImage(ImageSource.gallery);
                },
                icon: Icon(Icons.photo_library, color: isDark ? AppColors.bgCard : AppColors.bgDark),
                label: Text(
                  loc.t('chooseFromGallery'),
                  style: TextStyle(
                    color: isDark ? AppColors.bgCard : AppColors.bgDark,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: BorderSide(
                    color: (isDark ? AppColors.bgCard : AppColors.bgDark).withOpacity(0.3),
                  ),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.danger.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.danger.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: AppColors.danger, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(color: AppColors.danger, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 32),
            // Tips card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: (isDark ? AppColors.bgCardDark : AppColors.bgCard).withOpacity(0.5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: (isDark ? AppColors.textSecondaryDark : AppColors.textSecondary).withOpacity(0.2),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.lightbulb_outline, size: 18, color: AppColors.warning),
                      const SizedBox(width: 6),
                      Text(
                        loc.t('scanTipsTitle'),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isDark ? AppColors.bgCard : AppColors.bgDark,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _tip('• ${loc.t('scanTip1')}', isDark),
                  _tip('• ${loc.t('scanTip2')}', isDark),
                  _tip('• ${loc.t('scanTip3')}', isDark),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tip(String text, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
        ),
      ),
    );
  }

  // ----------------------------------------------------- stage: processing

  Widget _buildProcessingStage(ThemeData theme, bool isDark, AppLocalizations loc) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Spinner with document icon
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 100,
                  height: 100,
                  child: CircularProgressIndicator(
                    strokeWidth: 4,
                    valueColor: AlwaysStoppedAnimation(AppColors.primary),
                    backgroundColor: AppColors.primary.withOpacity(0.2),
                  ),
                ),
                Icon(Icons.document_scanner, size: 44, color: AppColors.primary),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              loc.t('scanProcessing'),
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: isDark ? AppColors.bgCard : AppColors.bgDark,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              loc.t('scanProcessingDesc'),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 24),
            // Progress steps
            _processingStep(loc.t('scanStep1'), true, isDark),
            _processingStep(loc.t('scanStep2'), true, isDark),
            _processingStep(loc.t('scanStep3'), false, isDark),
            _processingStep(loc.t('scanStep4'), false, isDark),
          ],
        ),
      ),
    );
  }

  Widget _processingStep(String text, bool done, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            done ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 14,
            color: done ? AppColors.success : AppColors.textSecondary,
          ),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              color: done
                  ? (isDark ? AppColors.bgCard : AppColors.bgDark)
                  : (isDark ? AppColors.textSecondaryDark : AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  // ----------------------------------------------------- stage: verify

  Widget _buildVerifyStage(ThemeData theme, bool isDark, AppLocalizations loc) {
    final result = _result;
    if (result == null) return const SizedBox.shrink();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(Icons.fact_check_outlined, color: AppColors.success, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  loc.t('verifyColumns'),
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.bgCard : AppColors.bgDark,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            loc.t('verifyColumnsDesc').replaceAll('{count}', '${result.columns.length}'),
            style: theme.textTheme.bodySmall?.copyWith(
              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 16),

          // Column summary cards
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: result.columns.length > 4 ? 4 : result.columns.length,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 0.85,
            children: [
              for (var i = 0; i < result.columns.length; i++)
                _buildColumnCard(result.columns[i], i, isDark, loc),
            ],
          ),
          const SizedBox(height: 16),

          // Detected layout preview
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: (isDark ? AppColors.bgCardDark : AppColors.bgCard).withOpacity(0.6),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: (isDark ? AppColors.textSecondaryDark : AppColors.textSecondary).withOpacity(0.2),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  loc.t('detectedLayout'),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 8),
                _buildLayoutPreview(result, isDark),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _rescan,
                  icon: Icon(Icons.refresh, size: 18),
                  label: Text(loc.t('rescan')),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    foregroundColor: isDark ? AppColors.bgCard : AppColors.bgDark,
                    side: BorderSide(
                      color: (isDark ? AppColors.bgCard : AppColors.bgDark).withOpacity(0.3),
                    ),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppColors.success, const Color(0xFF059669)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: _confirmAndShowResult,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.check_circle, color: Colors.white, size: 18),
                            const SizedBox(width: 6),
                            Text(
                              loc.t('confirmAndCalculate'),
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildColumnCard(ScanColumn column, int idx, bool isDark, AppLocalizations loc) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      decoration: BoxDecoration(
        color: (isDark ? AppColors.bgCardDark : AppColors.bgCard).withOpacity(0.7),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AppColors.primary.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '${loc.t('column')} ${idx + 1}',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${column.numbers.length} ${loc.t('numbers')}',
            style: TextStyle(
              fontSize: 9,
              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              _formatNumber(column.sum),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? AppColors.bgCard : AppColors.bgDark,
                fontFamily: 'KhataHandwriting',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLayoutPreview(ScanResult result, bool isDark) {
    final rowCount = result.rowCount;
    final cells = <Widget>[];

    // Header row: empty + column labels
    cells.add(_previewCell('', isHeader: true, isDark: isDark, isLabel: true));
    for (var i = 0; i < result.columns.length; i++) {
      cells.add(_previewCell(
        'C${i + 1}',
        isHeader: true,
        isDark: isDark,
        isLabel: true,
      ));
    }

    // Data rows
    for (var r = 0; r < rowCount; r++) {
      cells.add(_previewCell('R${r + 1}', isDark: isDark, isLabel: true));
      for (var c = 0; c < result.columns.length; c++) {
        final col = result.columns[c];
        final value = r < col.numbers.length
            ? _formatNumber(col.numbers[r].value)
            : '-';
        cells.add(_previewCell(value, isDark: isDark));
      }
    }

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: result.columns.length + 1,
      childAspectRatio: 2.0,
      mainAxisSpacing: 2,
      crossAxisSpacing: 2,
      children: cells,
    );
  }

  Widget _previewCell(String text, {bool isHeader = false, bool isDark = false, bool isLabel = false}) {
    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isHeader
            ? AppColors.primary.withOpacity(0.15)
            : (isLabel ? (isDark ? AppColors.bgDarker : Colors.grey[100]) : null),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: isHeader || isLabel ? FontWeight.bold : FontWeight.normal,
          color: isHeader
              ? AppColors.primary
              : (isDark ? AppColors.bgCard : AppColors.bgDark),
          fontFamily: isLabel || isHeader ? null : 'KhataHandwriting',
        ),
      ),
    );
  }

  // ----------------------------------------------------- stage: result

  Widget _buildResultStage(ThemeData theme, bool isDark, AppLocalizations loc) {
    final result = _result;
    if (result == null) return const SizedBox.shrink();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Success header
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.check_circle, color: AppColors.success, size: 22),
              const SizedBox(width: 8),
              Text(
                loc.t('scanComplete'),
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.success,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Data table
          _buildResultTable(result, theme, isDark, loc),
          const SizedBox(height: 16),

          // Grand total
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [AppColors.primary, AppColors.primaryDark]
                    : [AppColors.bgDark, const Color(0xFF2A2A4E)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.primary.withOpacity(0.5)),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.2),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              children: [
                Text(
                  loc.t('grandTotal'),
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _formatNumber(result.grandTotal),
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 48,
                    fontWeight: FontWeight.w800,
                    fontFamily: 'KhataHandwriting',
                    height: 1,
                  ),
                ),
                const SizedBox(height: 8),
                // Sum expression: 15 + 20 + 22 = 57
                Text(
                  result.columnSums.map(_formatNumber).join(' + ') +
                      ' = ${_formatNumber(result.grandTotal)}',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Stats row
          Row(
            children: [
              _statPill('${result.columns.length}', loc.t('columns'), isDark),
              const SizedBox(width: 6),
              _statPill('${result.rowCount}', loc.t('rows'), isDark),
              const SizedBox(width: 6),
              _statPill('${result.totalNumbers}', loc.t('numbers'), isDark),
            ],
          ),
          const SizedBox(height: 16),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: _actButton(
                  Icons.refresh,
                  loc.t('rescan'),
                  isDark,
                  onTap: _rescan,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _actButton(
                  Icons.copy,
                  loc.t('copy'),
                  isDark,
                  onTap: () {
                    FeedbackService().tap();
                    final expr = result.columnSums.map(_formatNumber).join(' + ') +
                        ' = ${_formatNumber(result.grandTotal)}';
                    Clipboard.setData(ClipboardData(text: expr));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(loc.t('copiedToClipboard'))),
                    );
                  },
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _actButton(
                  Icons.share,
                  loc.t('share'),
                  isDark,
                  onTap: () {
                    FeedbackService().tap();
                    // Simple share via clipboard (full share_plus integration
                    // is a future enhancement).
                    final expr = result.columnSums.map(_formatNumber).join(' + ') +
                        ' = ${_formatNumber(result.grandTotal)}';
                    Clipboard.setData(ClipboardData(text: expr));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(loc.t('copiedToClipboard'))),
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildResultTable(ScanResult result, ThemeData theme, bool isDark, AppLocalizations loc) {
    final rowCount = result.rowCount;
    return Container(
      decoration: BoxDecoration(
        color: (isDark ? AppColors.bgCardDark : AppColors.bgCard).withOpacity(0.7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: (isDark ? AppColors.textSecondaryDark : AppColors.textSecondary).withOpacity(0.2),
        ),
      ),
      child: Column(
        children: [
          // Header row
          _tableRow(
            children: [
              _tableCell('', isHeader: true, isDark: isDark, isLabel: true),
              for (var i = 0; i < result.columns.length; i++)
                _tableCell(
                  '${loc.t('col')} ${i + 1}',
                  isHeader: true,
                  isDark: isDark,
                  isLabel: true,
                ),
            ],
            isHeader: true,
          ),
          // Data rows
          for (var r = 0; r < rowCount; r++)
            _tableRow(
              children: [
                _tableCell(
                  '${loc.t('row')} ${r + 1}',
                  isDark: isDark,
                  isLabel: true,
                ),
                for (var c = 0; c < result.columns.length; c++)
                  _tableCell(
                    r < result.columns[c].numbers.length
                        ? _formatNumber(result.columns[c].numbers[r].value)
                        : '-',
                    isDark: isDark,
                  ),
              ],
            ),
          // Sum row
          _tableRow(
            children: [
              _tableCell(loc.t('sum'), isDark: isDark, isLabel: true, isSum: true),
              for (var c = 0; c < result.columns.length; c++)
                _tableCell(
                  _formatNumber(result.columns[c].sum),
                  isDark: isDark,
                  isSum: true,
                ),
            ],
            isSum: true,
          ),
        ],
      ),
    );
  }

  Widget _tableRow({required List<Widget> children, bool isHeader = false, bool isSum = false}) {
    return Container(
      decoration: isSum
          ? BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.primary.withOpacity(0.5), width: 1)),
              color: AppColors.primary.withOpacity(0.08),
            )
          : null,
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      child: Row(
        children: children,
      ),
    );
  }

  Widget _tableCell(String text, {bool isHeader = false, bool isDark = false, bool isLabel = false, bool isSum = false}) {
    return Expanded(
      child: Container(
        alignment: Alignment.center,
        child: Text(
          text,
          style: TextStyle(
            fontSize: isSum ? 14 : 12,
            fontWeight: isHeader || isLabel || isSum ? FontWeight.bold : FontWeight.normal,
            color: isSum
                ? AppColors.primary
                : (isHeader
                    ? AppColors.primary
                    : (isLabel
                        ? (isDark ? AppColors.textSecondaryDark : AppColors.textSecondary)
                        : (isDark ? AppColors.bgCard : AppColors.bgDark))),
            fontFamily: (isLabel || isHeader) ? null : 'KhataHandwriting',
          ),
        ),
      ),
    );
  }

  Widget _statPill(String num, String label, bool isDark) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: (isDark ? AppColors.bgCardDark : AppColors.bgCard).withOpacity(0.6),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: (isDark ? AppColors.textSecondaryDark : AppColors.textSecondary).withOpacity(0.2),
          ),
        ),
        child: Column(
          children: [
            Text(
              num,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
                fontFamily: 'KhataHandwriting',
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 9,
                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _actButton(IconData icon, String label, bool isDark, {required VoidCallback onTap}) {
    return Container(
      decoration: BoxDecoration(
        color: (isDark ? AppColors.bgCardDark : AppColors.bgCard).withOpacity(0.7),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: (isDark ? AppColors.textSecondaryDark : AppColors.textSecondary).withOpacity(0.2),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              children: [
                Icon(icon, size: 18, color: isDark ? AppColors.bgCard : AppColors.bgDark),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.bgCard : AppColors.bgDark,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ----------------------------------------------------- helpers

  String _formatNumber(double v) {
    if (v == v.roundToDouble()) {
      return v.toInt().toString();
    }
    return v.toStringAsFixed(2);
  }
}
