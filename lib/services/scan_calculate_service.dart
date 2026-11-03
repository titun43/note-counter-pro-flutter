// =============================================================================
// Note Counter Pro — Scan & Calculate Service
// =============================================================================
//
// OCR-based number extraction + column detection + sum calculation.
//
// Flow:
//   1. User captures/picks an image of a handwritten page (optionally crops it)
//   2. google_mlkit_text_recognition extracts text + bounding boxes
//   3. We extract all numeric tokens from each LINE (Bengali + English + Hindi)
//   4. We group numbers by X position into "columns"
//   5. Within each column, we sort by Y to get row order
//   6. Each column sum is computed, then all column sums are added
//      to produce the grand total.
//
// Output: ScanResult with columns, rows, per-column sums, and grand total.
// =============================================================================

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

  // Use the DEFAULT script (no script parameter) so ML Kit uses its
  // general Latin model that handles handwritten English digits well.
  // For Bengali digits, we normalize manually after OCR.
  final _recognizer = TextRecognizer();

  // ----------------------------------------------------------------- public

  /// Run OCR on the image at [imagePath] and return a structured result
  /// with columns detected by X-position grouping.
  Future<ScanResult> processImage(String imagePath) async {
    try {
      debugPrint('ScanCalculate: starting OCR on $imagePath');
      final inputImage = InputImage.fromFilePath(imagePath);
      final recognizedText = await _recognizer.processImage(inputImage);
      debugPrint('ScanCalculate: OCR done. blocks=${recognizedText.blocks.length}, '
          'text length=${recognizedText.text.length}');

      // Step 1: extract all numbers (with positions) from each LINE.
      // We use line-level (not element-level) parsing because in handwritten
      // text, multiple numbers often appear on one line and ML Kit merges
      // them into a single element. Parsing the full line text with a regex
      // captures every number reliably.
      final numbers = <DetectedNumber>[];
      for (final block in recognizedText.blocks) {
        for (final line in block.lines) {
          final lineNumbers = _extractNumbersFromLine(line);
          numbers.addAll(lineNumbers);
        }
      }
      debugPrint('ScanCalculate: extracted ${numbers.length} numbers');

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
      debugPrint('ScanCalculate: detected ${columns.length} columns');

      // Step 3: compute grand total (sum of column sums).
      final grandTotal = columns.fold(0.0, (a, c) => a + c.sum);
      debugPrint('ScanCalculate: grand total = $grandTotal');

      return ScanResult(
        columns: columns,
        totalNumbers: numbers.length,
        grandTotal: grandTotal,
      );
    } catch (e, st) {
      debugPrint('ScanCalculateService.processImage failed: $e\n$st');
      return ScanResult(
        columns: [],
        totalNumbers: 0,
        grandTotal: 0,
        errorMessage: 'Scan failed: $e',
      );
    }
  }

  // ----------------------------------------------------- number extraction

  /// Extract all numbers from a single recognized LINE.
  /// Returns one DetectedNumber per numeric token found, with position
  /// approximated from the line's bounding box and the token's relative
  /// position within the line text.
  List<DetectedNumber> _extractNumbersFromLine(TextLine line) {
    final results = <DetectedNumber>[];
    final rawText = line.text;
    if (rawText.isEmpty) return results;

    // Normalize digits (Bengali + Hindi → English) BEFORE regex.
    final normalized = _normalizeDigits(rawText);

    // Regex: match numbers with optional thousands separators and decimals.
    // We capture:
    //   - integer: 123
    //   - decimal: 123.45 or 123,45 (European)
    //   - with commas: 1,234
    final numberRegex = RegExp(r'\d{1,3}(?:,\d{3})*(?:\.\d+)?|\d+(?:\.\d+)?');

    // Pre-decompose the line into "text elements" by splitting on whitespace
    // so we can attempt to align each detected number back to an element's
    // bounding box. If alignment fails, we fall back to distributing numbers
    // evenly across the line's bounding box width.
    final lineBox = line.boundingBox;
    final lineLeft = lineBox.left;
    final lineTop = lineBox.top;
    final lineWidth = lineBox.width;
    final lineCenterY = lineBox.center.dy;

    // Try to map each regex match to an element by comparing normalized text.
    final elements = line.elements;
    final elementMatches = <int, int>{}; // regexMatchIndex → elementIndex

    final allMatches = numberRegex.allMatches(normalized).toList();
    if (allMatches.isEmpty) return results;

    // Build a parallel list of normalized element texts for matching.
    final normElements = elements
        .map((e) => _normalizeDigits(e.text).replaceAll(RegExp(r'[^\d.,]'), ''))
        .toList();

    for (var mi = 0; mi < allMatches.length; mi++) {
      final match = allMatches[mi];
      final matchText = match.group(0)!;
      // Try to find an element whose normalized text contains this number.
      int? bestElementIdx;
      for (var ei = 0; ei < normElements.length; ei++) {
        if (normElements[ei] == matchText ||
            normElements[ei].endsWith(matchText) ||
            normElements[ei].startsWith(matchText)) {
          bestElementIdx = ei;
          break;
        }
      }
      elementMatches[mi] = bestElementIdx ?? -1;
    }

    // Now build DetectedNumber for each match.
    for (var mi = 0; mi < allMatches.length; mi++) {
      final match = allMatches[mi];
      final raw = match.group(0)!;
      final value = _parseNumberString(raw);
      if (value == null) continue;

      double x;
      if (elementMatches[mi] != null && elementMatches[mi]! >= 0) {
        // Use the element's bounding box center.
        final el = elements[elementMatches[mi]!];
        x = el.boundingBox.center.dx;
      } else {
        // Fallback: distribute across line width proportional to match start.
        final charStart = match.start;
        final charEnd = match.end;
        final lineLen = normalized.length;
        final ratioStart = lineLen == 0 ? 0.0 : charStart / lineLen;
        final ratioEnd = lineLen == 0 ? 1.0 : charEnd / lineLen;
        final ratioMid = (ratioStart + ratioEnd) / 2;
        x = lineLeft + lineWidth * ratioMid;
      }

      results.add(DetectedNumber(value: value, x: x, y: lineCenterY));
    }
    return results;
  }

  /// Parse a normalized number string (English digits, optional comma
  /// thousands separator, optional decimal point) into a double.
  double? _parseNumberString(String s) {
    // Remove thousands separators (commas between digits).
    final cleaned = s.replaceAll(RegExp(r'(?<=\d),(?=\d)'), '');
    return double.tryParse(cleaned);
  }

  /// Convert Bengali (০-৯) and Hindi (०-९) digits to English (0-9).
  /// Also normalize Bengali decimal separator (।) to English dot.
  String _normalizeDigits(String text) {
    const bengali = ['০', '১', '২', '৩', '৪', '৫', '৬', '৭', '৮', '৯'];
    const hindi = ['०', '१', '२', '३', '४', '५', '६', '७', '८', '९'];
    var result = text;
    for (var i = 0; i < 10; i++) {
      result = result.replaceAll(bengali[i], i.toString());
      result = result.replaceAll(hindi[i], i.toString());
    }
    // Bengali decimal separator (দাঁড়ি) → English dot
    result = result.replaceAll('।', '.');
    return result;
  }

  // ----------------------------------------------------- column detection

  /// Group numbers into columns by X position.
  /// Numbers with similar X (within tolerance) are in the same column.
  /// Returns columns sorted left-to-right, each column's numbers sorted
  /// top-to-bottom by Y.
  List<ScanColumn> _groupIntoColumns(List<DetectedNumber> numbers) {
    if (numbers.isEmpty) return [];

    // Sort by X to make grouping easier.
    final sortedByX = List<DetectedNumber>.from(numbers)
      ..sort((a, b) => a.x.compareTo(b.x));

    // Adaptive tolerance: 40% of the median X gap, clamped to [40, 80]px.
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
