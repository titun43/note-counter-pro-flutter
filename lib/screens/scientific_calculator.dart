import 'dart:math';
import 'package:flutter/material.dart';
import '../utils/constants.dart';

class ScientificCalculator extends StatefulWidget {
  const ScientificCalculator({super.key});

  @override
  State<ScientificCalculator> createState() => _ScientificCalculatorState();
}

class _ScientificCalculatorState extends State<ScientificCalculator> {
  String _display = '0';
  String _expression = '';
  bool _isDegree = true;

  void _onButton(String value) {
    setState(() {
      if (value == 'AC') {
        _display = '0';
        _expression = '';
      } else if (value == '⌫') {
        if (_expression.isNotEmpty) {
          _expression = _expression.substring(0, _expression.length - 1);
          _display = _expression.isEmpty ? '0' : _expression;
        }
      } else if (value == '=') {
        _evaluate();
      } else if (value == 'deg/rad') {
        _isDegree = !_isDegree;
      } else if (value == 'π') {
        _expression += '3.141592653589793';
        _display = _expression;
      } else if (value == 'e') {
        _expression += '2.718281828459045';
        _display = _expression;
      } else if (['sin','cos','tan','asin','acos','atan','log','ln','√','exp'].contains(value)) {
        final fn = value == '√' ? 'sqrt' : value;
        _expression += '$fn(';
        _display = _expression;
      } else {
        _expression += value;
        _display = _expression;
      }
    });
  }

  void _evaluate() {
    if (_expression.isEmpty) return;
    try {
      String expr = _expression
          .replaceAll('×', '*')
          .replaceAll('÷', '/')
          .replaceAll('−', '-');

      // Auto-close unclosed parentheses
      int open = 0;
      for (int i = 0; i < expr.length; i++) {
        if (expr[i] == '(') open++;
        if (expr[i] == ')') open--;
      }
      while (open > 0) { expr += ')'; open--; }

      // Resolve step by step — innermost to outermost
      // Repeat until no more changes (safety: 200 iterations)
      for (int iter = 0; iter < 200; iter++) {
        // Try to find innermost function call: fn(content_without_parens)
        final fnMatch = RegExp(r'(asin|acos|atan|sin|cos|tan|sqrt|exp|log|ln)\(([^()]+)\)').firstMatch(expr);
        if (fnMatch != null) {
          final fn = fnMatch.group(1)!;
          final argStr = fnMatch.group(2)!;
          final arg = _safeEval(argStr);
          final result = _applyFunction(fn, arg);
          expr = expr.substring(0, fnMatch.start) + _safeNum(result) + expr.substring(fnMatch.end);
          continue;
        }

        // Try to find innermost parentheses: (content_without_parens)
        final parenMatch = RegExp(r'\(([^()]+)\)').firstMatch(expr);
        if (parenMatch != null) {
          final inner = parenMatch.group(1)!;
          final val = _safeEval(inner);
          expr = expr.substring(0, parenMatch.start) + _safeNum(val) + expr.substring(parenMatch.end);
          continue;
        }

        // No more parens or functions — handle power
        final powIdx = expr.indexOf('^');
        if (powIdx != -1) {
          expr = _handlePower(expr, powIdx);
          continue;
        }

        // Nothing left to resolve — final evaluation
        break;
      }

      final result = _safeEval(expr);
      if (result.isNaN || result.isInfinite) {
        _display = 'Error';
        _expression = '';
      } else {
        _display = _fmt(result);
        _expression = _display;
      }
    } catch (e) {
      _display = 'Error';
      _expression = '';
    }
  }

  double _applyFunction(String fn, double arg) {
    try {
      switch (fn) {
        case 'sin': return sin(_isDegree ? arg * pi / 180 : arg);
        case 'cos': return cos(_isDegree ? arg * pi / 180 : arg);
        case 'tan': return tan(_isDegree ? arg * pi / 180 : arg);
        case 'asin': return _isDegree ? asin(arg) * 180 / pi : asin(arg);
        case 'acos': return _isDegree ? acos(arg) * 180 / pi : acos(arg);
        case 'atan': return _isDegree ? atan(arg) * 180 / pi : atan(arg);
        case 'log': return log(arg) / 2.302585092994046;
        case 'ln': return log(arg);
        case 'sqrt': return sqrt(arg);
        case 'exp': return exp(arg);
        default: return 0;
      }
    } catch (_) {
      return double.nan;
    }
  }

  /// Convert double to safe string (no scientific notation, no infinity)
  String _safeNum(double v) {
    if (v.isNaN || v.isInfinite) return '0';
    // Avoid scientific notation by using fixed point
    if (v == v.truncateToDouble() && v.abs() < 1e15) {
      return v.toStringAsFixed(0);
    }
    return v.toString();
  }

  /// Handle one ^ operation at given index
  String _handlePower(String expr, int idx) {
    // Find left operand
    int leftEnd = idx;
    int leftStart = leftEnd - 1;
    // Handle negative numbers
    if (leftStart >= 0 && expr[leftStart] == '-') leftStart--;
    while (leftStart >= 0 && expr[leftStart].contains(RegExp(r'[0-9.]'))) {
      leftStart--;
    }
    leftStart++;
    // Find right operand
    int rightStart = idx + 1;
    int rightEnd = rightStart;
    if (rightEnd < expr.length && expr[rightEnd] == '-') rightEnd++;
    while (rightEnd < expr.length && expr[rightEnd].contains(RegExp(r'[0-9.]'))) {
      rightEnd++;
    }
    if (leftStart >= leftEnd || rightStart >= rightEnd) return expr;
    final left = double.tryParse(expr.substring(leftStart, leftEnd)) ?? 0;
    final right = double.tryParse(expr.substring(rightStart, rightEnd)) ?? 0;
    final result = pow(left, right).toDouble();
    return expr.substring(0, leftStart) + _safeNum(result) + expr.substring(rightEnd);
  }

  /// Safe simple expression evaluator — no functions, no parens, no ^.
  /// Handles +, -, *, / with proper precedence.
  /// CRASH-SAFE: returns 0 on any error.
  double _safeEval(String expr) {
    try {
      expr = expr.trim();
      if (expr.isEmpty) return 0;

      // Simple approach: split by + and - (lowest precedence)
      // Then evaluate each part for * and /

      // First, handle * and / within each + - segment
      // Tokenize into numbers and operators
      final tokens = <dynamic>[];
      int i = 0;
      while (i < expr.length) {
        final c = expr[i];
        if (c == ' ') { i++; continue; }
        if ('+-*/'.contains(c)) {
          // Check for negative number
          if (c == '-' && (tokens.isEmpty || tokens.last is String)) {
            // Parse negative number
            String num = '-';
            i++;
            while (i < expr.length && expr[i].contains(RegExp(r'[0-9.]'))) {
              num += expr[i]; i++;
            }
            final v = double.tryParse(num);
            if (v != null) tokens.add(v);
          } else {
            tokens.add(c);
            i++;
          }
        } else {
          String num = '';
          while (i < expr.length && expr[i].contains(RegExp(r'[0-9.]'))) {
            num += expr[i]; i++;
          }
          final v = double.tryParse(num);
          if (v != null) tokens.add(v);
        }
      }

      if (tokens.isEmpty) return 0;
      if (tokens.length == 1 && tokens[0] is double) return tokens[0];

      // First pass: handle * and /
      final pass1 = <dynamic>[];
      for (int j = 0; j < tokens.length; j++) {
        if (tokens[j] is String && (tokens[j] == '*' || tokens[j] == '/')) {
          if (pass1.isEmpty) continue;
          final left = pass1.removeLast() as double;
          if (j + 1 >= tokens.length || tokens[j + 1] is! double) continue;
          final right = tokens[j + 1] as double;
          double r;
          if (tokens[j] == '*') r = left * right;
          else r = right == 0 ? double.nan : left / right;
          pass1.add(r);
          j++; // skip right operand
        } else if (tokens[j] is double) {
          pass1.add(tokens[j]);
        } else if (tokens[j] is String && (tokens[j] == '+' || tokens[j] == '-')) {
          pass1.add(tokens[j]);
        }
      }

      // Second pass: handle + and -
      if (pass1.isEmpty) return 0;
      double result = pass1[0] is double ? pass1[0] as double : 0;
      for (int j = 1; j < pass1.length; j += 2) {
        if (j + 1 >= pass1.length) break;
        if (pass1[j] is! String) continue;
        final op = pass1[j] as String;
        final right = pass1[j + 1] as double;
        if (op == '+') result += right;
        if (op == '-') result -= right;
      }
      return result;
    } catch (_) {
      return 0;
    }
  }

  String _fmt(double v) {
    if (v.isNaN || v.isInfinite) return 'Error';
    if (v == v.truncateToDouble() && v.abs() < 1e15) return v.toStringAsFixed(0);
    String s = v.toStringAsFixed(6);
    s = s.replaceAll(RegExp(r'0+$'), '');
    s = s.replaceAll(RegExp(r'\.$'), '');
    return s;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF5F5F5);

    final rows = [
      ['sin', 'cos', 'tan', 'π'],
      ['log', 'ln', '√', 'e'],
      ['(', ')', '^', 'deg/rad'],
      ['AC', '⌫', '÷', '×'],
      ['7', '8', '9', '-'],
      ['4', '5', '6', '+'],
      ['1', '2', '3', '='],
      ['0', '.', '00', ''],
    ];

    return Container(
      color: bgColor,
      child: Column(
        children: [
          // Display
          Expanded(
            flex: 2,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              alignment: Alignment.bottomRight,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (_expression.isNotEmpty && _expression != _display)
                    Text(_expression,
                        style: TextStyle(fontSize: 13,
                            color: isDark ? Colors.grey[400] : Colors.grey[500]),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(_display,
                        style: TextStyle(fontSize: 38, fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black)),
                  ),
                  const SizedBox(height: 4),
                  Text(_isDegree ? 'DEG' : 'RAD',
                      style: TextStyle(fontSize: 10, color: Colors.grey[400])),
                ],
              ),
            ),
          ),
          // Round buttons
          Expanded(
            flex: 6,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: rows.map((row) => Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: row.map((label) {
                    if (label.isEmpty) return const SizedBox(width: 60, height: 60);
                    return _btn(label, isDark);
                  }).toList(),
                )).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _btn(String label, bool isDark) {
    final isOp = ['÷','×','-','+'].contains(label);
    final isEq = label == '=';
    final isFn = ['AC','⌫'].contains(label);
    final isSci = ['sin','cos','tan','log','ln','√','π','e','^','deg/rad','(',')'].contains(label);

    Color bg, fg;
    if (isEq) { bg = const Color(0xFFFF9500); fg = Colors.white; }
    else if (isOp) { bg = isDark ? const Color(0xFF3A3A3A) : const Color(0xFFE0E0E0); fg = const Color(0xFFFF9500); }
    else if (isFn) { bg = isDark ? const Color(0xFF3A3A3A) : const Color(0xFFD1D1D1); fg = isDark ? Colors.white : Colors.black87; }
    else if (isSci) { bg = isDark ? const Color(0xFF1E3A5F) : const Color(0xFFE3F2FD); fg = const Color(0xFF1976D2); }
    else { bg = isDark ? const Color(0xFF2C2C2C) : Colors.white; fg = isDark ? Colors.white : Colors.black87; }

    return Container(
      width: 60,
      height: 60,
      margin: const EdgeInsets.all(3),
      child: ElevatedButton(
        onPressed: () => _onButton(label),
        style: ElevatedButton.styleFrom(
          shape: const CircleBorder(),
          padding: EdgeInsets.zero,
          backgroundColor: bg,
          foregroundColor: fg,
          elevation: 1,
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(label, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
        ),
      ),
    );
  }
}
