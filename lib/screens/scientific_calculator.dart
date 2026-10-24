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
      while (open > 0) {
        expr += ')';
        open--;
      }

      // Step 1: Resolve all function calls (innermost first)
      // Pattern: functionName(content) where content has no parentheses
      final funcPattern = RegExp(r'(asin|acos|atan|sin|cos|tan|sqrt|exp|log|ln)\(([^()]+)\)');
      bool changed = true;
      int safety = 100; // prevent infinite loop
      while (changed && safety > 0) {
        changed = false;
        safety--;
        final match = funcPattern.firstMatch(expr);
        if (match != null) {
          final fn = match.group(1)!;
          final argStr = match.group(2)!;
          final arg = _evalSimple(argStr);
          double result;
          switch (fn) {
            case 'sin': result = sin(_isDegree ? arg * pi / 180 : arg); break;
            case 'cos': result = cos(_isDegree ? arg * pi / 180 : arg); break;
            case 'tan': result = tan(_isDegree ? arg * pi / 180 : arg); break;
            case 'asin': result = _isDegree ? asin(arg) * 180 / pi : asin(arg); break;
            case 'acos': result = _isDegree ? acos(arg) * 180 / pi : acos(arg); break;
            case 'atan': result = _isDegree ? atan(arg) * 180 / pi : atan(arg); break;
            case 'log': result = log(arg) / 2.302585092994046; break;
            case 'ln': result = log(arg); break;
            case 'sqrt': result = sqrt(arg); break;
            case 'exp': result = exp(arg); break;
            default: result = 0;
          }
          expr = expr.substring(0, match.start) + result.toString() + expr.substring(match.end);
          changed = true;
        }
      }

      // Step 2: Resolve remaining parentheses (no functions inside)
      while (expr.contains('(')) {
        final start = expr.lastIndexOf('(');
        final end = expr.indexOf(')', start);
        if (end == -1) break;
        final subExpr = expr.substring(start + 1, end);
        final subResult = _evalSimple(subExpr);
        expr = expr.substring(0, start) + subResult.toString() + expr.substring(end + 1);
      }

      // Step 3: Handle power (^) — right to left
      while (expr.contains('^')) {
        final idx = expr.lastIndexOf('^');
        // Find left operand (number before ^)
        int leftEnd = idx;
        int leftStart = leftEnd - 1;
        while (leftStart >= 0 && (expr[leftStart].contains(RegExp(r'[0-9.]')) ||
               (expr[leftStart] == '-' && leftStart == 0))) {
          leftStart--;
        }
        leftStart++;
        // Find right operand (number after ^)
        int rightStart = idx + 1;
        int rightEnd = rightStart;
        if (rightEnd < expr.length && expr[rightEnd] == '-') rightEnd++;
        while (rightEnd < expr.length && expr[rightEnd].contains(RegExp(r'[0-9.]'))) {
          rightEnd++;
        }
        if (leftStart >= leftEnd || rightStart >= rightEnd) break;
        final left = double.parse(expr.substring(leftStart, leftEnd));
        final right = double.parse(expr.substring(rightStart, rightEnd));
        final result = pow(left, right).toDouble();
        expr = expr.substring(0, leftStart) + result.toString() + expr.substring(rightEnd);
      }

      // Step 4: Final evaluation with Shunting Yard
      final result = _evalSimple(expr);
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

  /// Evaluate simple expression (no functions, no parentheses, no ^)
  double _evalSimple(String expr) {
    expr = expr.trim();
    if (expr.isEmpty) return 0;

    // Tokenize
    final tokens = <String>[];
    int i = 0;
    while (i < expr.length) {
      final c = expr[i];
      if (c == ' ') { i++; continue; }
      if ('+-*/'.contains(c)) {
        // Check if this minus is a negative sign
        if (c == '-' && (tokens.isEmpty || '+-*/'.contains(tokens.last))) {
          String num = '-';
          i++;
          while (i < expr.length && expr[i].contains(RegExp(r'[0-9.]'))) {
            num += expr[i]; i++;
          }
          if (num.length > 1) tokens.add(num);
        } else {
          tokens.add(c);
          i++;
        }
      } else {
        String num = '';
        while (i < expr.length && expr[i].contains(RegExp(r'[0-9.]'))) {
          num += expr[i]; i++;
        }
        if (num.isNotEmpty) tokens.add(num);
      }
    }

    if (tokens.isEmpty) return 0;

    // Shunting Yard
    final output = <String>[];
    final ops = <String>[];
    int prec(String op) {
      if (op == '+' || op == '-') return 1;
      if (op == '*' || op == '/') return 2;
      return 0;
    }

    for (final token in tokens) {
      if (double.tryParse(token) != null) {
        output.add(token);
      } else {
        while (ops.isNotEmpty && prec(ops.last) >= prec(token)) {
          output.add(ops.removeLast());
        }
        ops.add(token);
      }
    }
    while (ops.isNotEmpty) output.add(ops.removeLast());

    // Evaluate RPN
    final stack = <double>[];
    for (final token in output) {
      if (double.tryParse(token) != null) {
        stack.add(double.parse(token));
      } else {
        if (stack.length < 2) throw Exception('Invalid');
        final b = stack.removeLast();
        final a = stack.removeLast();
        switch (token) {
          case '+': stack.add(a + b); break;
          case '-': stack.add(a - b); break;
          case '*': stack.add(a * b); break;
          case '/': stack.add(a / b); break;
        }
      }
    }
    return stack.isEmpty ? 0 : stack.last;
  }

  String _fmt(double v) {
    if (v == v.truncateToDouble()) return v.toStringAsFixed(0);
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
