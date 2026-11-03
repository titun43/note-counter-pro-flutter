// =============================================================================
// Note Counter Pro — Scan & Calculate Service
// =============================================================================
//
// OCR-based number extraction + column detection + sum calculation.
//
// Flow:
//   1. User captures/picks an image of a handwritten page
//   2. google_mlkit_text_recognition extracts text + bounding boxes
//   3. We extract all numeric tokens (Bengali + English + decimals)
//   4. We group numbers by X position into "columns"
//   5. Within each column, we sort by Y to get row order
//   6. Each column sum is computed, then all column sums are added
//      to produce the grand total.
//
// Output: ScanResult with columns, rows, per-column sums, and grand total.
// =============================================================================

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// A single detected number with its position on the page.
class DetectedNumber {
  final double value;
  final double x; // center X
  final double y; // center Y

  DetectedNumber({required this.value, required this.x, required this.y});
}

/// A column of numbers (grouped by similar X position).
class ScanColumn {
  final int index;
  final List<DetectedNumber> numbers; // sorted by Y (top to bottom)

  ScanColumn({required this.index, required this.numbers});

  double get sum => numbers.fold(0.0, (a, n) => a + n.value);
}

/// Final scan result.
class ScanResult {
  final List<ScanColumn> columns;
  final int totalNumbers;
  final double grandTotal;
  final String? errorMessage;

  ScanResult({
    required this.columns,
    required this.totalNumbers,
    required this.grandTotal,
    this.errorMessage,
  });

  /// Per-column sums.
  List<double> get columnSums => columns.map((c) => c.sum).toList();

  /// Number of rows (max column length).
  int get rowCount =>
      columns.isEmpty ? 0 : columns.map((c) => c.numbers.length).reduce((a, b) => a > b ? a : b);
}

class ScanCalculateService {
  static final ScanCalculateService _instance = ScanCalculateService._();
  factory ScanCalculateService() => _instance;
  ScanCalculateService._();

  final _recognizer = TextRecognizer(
    script: TextRecognitionScript.latin,
  );

  // ----------------------------------------------------------------- public

  /// Run OCR on the image at [imagePath] and return a structured result
  /// with columns detected by X-position grouping.
  Future<ScanResult> processImage(String imagePath) async {
    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final recognizedText = await _recognizer.processImage(inputImage);

      // Step 1: extract all numbers (with positions) from text blocks.
      final numbers = <DetectedNumber>[];
      for (final block in recognizedText.blocks) {
        for (final line in block.lines) {
          for (final element in line.elements) {
            final parsed = _tryParseNumber(element.text);
            if (parsed != null) {
              final b = element.boundingBox;
              numbers.add(DetectedNumber(
                value: parsed,
                x: b.center.dx,
                y: b.center.dy,
              ));
            }
          }
        }
      }

      if (numbers.isEmpty) {
        return ScanResult(
          columns: [],
          totalNumbers: 0,
          grandTotal: 0,
          errorMessage: 'No numbers found in the image.',
        );
      }

      // Step 2: group numbers into columns by X position.
      final columns = _groupIntoColumns(numbers);

      // Step 3: compute grand total (sum of column sums).
      final grandTotal = columns.fold(0.0, (a, c) => a + c.sum);

      return ScanResult(
        columns: columns,
        totalNumbers: numbers.length,
        grandTotal: grandTotal,
      );
    } catch (e) {
      debugPrint('ScanCalculateService.processImage failed: $e');
      return ScanResult(
        columns: [],
        totalNumbers: 0,
        grandTotal: 0,
        errorMessage: 'Scan failed: $e',
      );
    }
  }

  // ----------------------------------------------------- number extraction

  /// Try to parse [text] as a number.
  /// Supports:
  ///   - English digits: 123, 45.6
  ///   - Bengali digits: ১২৩, ৪৫.৬
  ///   - Hindi digits: १२३
  ///   - Thousands separators: 1,234 → 1234
  /// Returns null if not a number.
  double? _tryParseNumber(String text) {
    if (text.isEmpty) return null;

    // Normalize: convert Bengali/Hindi digits → English
    String normalized = _normalizeDigits(text);

    // Remove thousands separators (commas between digits)
    normalized = normalized.replaceAll(RegExp(r'(?<=\d),(?=\d)'), '');

    // Match a valid number: optional decimal
    final match = RegExp(r'^\d+\.?\d*$').firstMatch(normalized);
    if (match == null) return null;

    final value = double.tryParse(normalized);
    return value;
  }

  /// Convert Bengali (০-৯) and Hindi (०-९) digits to English (0-9).
  String _normalizeDigits(String text) {
    const bengali = ['০', '১', '২', '৩', '৪', '৫', '৬', '৭', '৮', '৯'];
    const hindi = ['०', '१', '२', '३', '४', '५', '६', '७', '८', '९'];
    var result = text;
    for (var i = 0; i < 10; i++) {
      result = result.replaceAll(bengali[i], i.toString());
      result = result.replaceAll(hindi[i], i.toString());
    }
    // Also normalize Bengali decimal separator if used
    result = result.replaceAll('।', '.');
    return result;
  }

  // ----------------------------------------------------- column detection

  /// Group numbers into columns by X position.
  /// Numbers with similar X (within [tolerance] px) are in the same column.
  /// Returns columns sorted left-to-right, each column's numbers sorted
  /// top-to-bottom by Y.
  List<ScanColumn> _groupIntoColumns(List<DetectedNumber> numbers) {
    if (numbers.isEmpty) return [];

    // Sort by X to make grouping easier.
    final sortedByX = List<DetectedNumber>.from(numbers)
      ..sort((a, b) => a.x.compareTo(b.x));

    // Adaptive tolerance: 12% of the median X gap, clamped to a min of 40px.
    // This handles both tight and wide column layouts.
    final tolerance = _computeXTolerance(sortedByX);

    final List<List<DetectedNumber>> groups = [];
    List<DetectedNumber> currentGroup = [sortedByX.first];

    for (var i = 1; i < sortedByX.length; i++) {
      final n = sortedByX[i];
      final groupX = currentGroup.first.x;
      if ((n.x - groupX).abs() <= tolerance) {
        currentGroup.add(n);
      } else {
        groups.add(currentGroup);
        currentGroup = [n];
      }
    }
    groups.add(currentGroup);

    // Build columns, sort each by Y (top to bottom).
    final columns = <ScanColumn>[];
    for (var i = 0; i < groups.length; i++) {
      final groupNumbers = List<DetectedNumber>.from(groups[i])
        ..sort((a, b) => a.y.compareTo(b.y));
      columns.add(ScanColumn(index: i, numbers: groupNumbers));
    }
    return columns;
  }

  /// Compute an adaptive X tolerance for grouping numbers into columns.
  /// Returns a value between 40 and 80 pixels.
  double _computeXTolerance(List<DetectedNumber> sortedByX) {
    if (sortedByX.length < 2) return 50;

    // Find the largest gap between consecutive X values — that's likely
    // the inter-column gap. Tolerance = half of that gap, clamped.
    final gaps = <double>[];
    for (var i = 1; i < sortedByX.length; i++) {
      gaps.add(sortedByX[i].x - sortedByX[i - 1].x);
    }
    gaps.sort();
    final medianGap = gaps[gaps.length ~/ 2];
    return (medianGap * 0.4).clamp(40.0, 80.0);
  }

  /// Release resources (call on app teardown).
  Future<void> dispose() async {
    try {
      await _recognizer.close();
    } catch (_) {}
  }
}
