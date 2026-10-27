/// Helper utilities for decimal input validation in amount fields.
///
/// The actual filtering is done via FilteringTextInputFormatter.allow
/// (a regex that allows digits and '.'). This file provides a helper
/// that callers can use in their onChanged callbacks to validate that
/// the input is a parseable decimal number (i.e. doesn't have multiple
/// dots like "12.34.56").
///
/// Usage:
///   TextField(
///     keyboardType: TextInputType.number,
///     inputFormatters: const [
///       FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
///     ],
///     onChanged: (v) {
///       if (!DecimalValidator.isValid(v)) return; // reject
///       // ... handle valid input
///     },
///   )
import 'package:flutter/services.dart';

/// Re-export the standard formatter for convenience.
class DecimalInputFormatter {
  /// Returns a TextInputFormatter that allows only digits and at most
  /// one '.'. Use this in inputFormatters.
  ///
  /// Note: FilteringTextInputFormatter.allow can't enforce "at most one
  /// dot" via regex, so callers should also validate in onChanged.
  static List<TextInputFormatter> get formatters =>
      [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))];
}

/// Stateful validator for decimal input strings.
class DecimalValidator {
  /// Returns true if [s] is a valid decimal amount:
  /// - empty string is valid (user is clearing)
  /// - single '.' is valid (user is starting a decimal)
  /// - otherwise must parse as double
  static bool isValid(String s) {
    if (s.isEmpty) return true;
    if (s == '.') return true;
    return double.tryParse(s) != null;
  }

  /// Returns the parsed double value of [s], or 0 if invalid/empty.
  static double parse(String s) {
    return double.tryParse(s) ?? 0;
  }
}
