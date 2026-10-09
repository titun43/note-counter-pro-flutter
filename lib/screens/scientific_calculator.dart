import 'dart:math';
import 'package:flutter/material.dart';

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
        return; // Don't add = to expression
      } else if (value == 'deg/rad') {
        _isDegree = !_isDegree;
        return;
      } else if (value == 'π') {
        _expression += '3.14159265358979';
        _display = _expression;
      } else if (value == 'e') {
        _expression += '2.71828182845905';
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

    String expr = _expression;
    // Replace display symbols
    expr = expr.replaceAll('×', '*');
    expr = expr.replaceAll('÷', '/');
    expr = expr.replaceAll('−', '-');

    // Auto-close parentheses
    int open = 0;
    for (int i = 0; i < expr.length; i++) {
      if (expr[i] == '(') open++;
      if (expr[i] == ')') open--;
    }
    while (open > 0) { expr += ')'; open--; }

    try {
      final result = _resolve(expr);
      if (result.isNaN || result.isInfinite) {
        setState(() { _display = 'Error'; _expression = ''; });
      } else {
        final formatted = _fmt(result);
        setState(() { _display = formatted; _expression = formatted; });
      }
    } on Error {
      // Catch StackOverflowError etc. (must come BEFORE catch (_), otherwise
      // catch (_) swallows everything and this branch becomes unreachable).
      setState(() { _display = 'Error'; _expression = ''; });
    } catch (e) {
      debugPrint('Scientific calculator eval failed: $e');
      setState(() { _display = 'Error'; _expression = ''; });
    }
  }

  /// Recursively resolve expression: functions, parentheses, power, arithmetic.
  /// NO regex. All manual string parsing. Maximum safety.
  double _resolve(String expr) {
    expr = expr.trim();
    if (expr.isEmpty) return 0;

    // Step 1: Find and resolve function calls (innermost first)
    // Look for pattern: functionName(...) where ... has no nested parens
    for (int iter = 0; iter < 100; iter++) {
      // Find a function name followed by '('
      String? foundFn;
      int fnStart = -1;

      for (final fn in ['asin','acos','atan','sin','cos','tan','sqrt','exp','log','ln']) {
        int idx = expr.indexOf('$fn(');
        if (idx != -1) {
          // Check it's not part of a longer name (e.g. 'sin' in 'asin')
          if (idx > 0 && expr[idx - 1].contains(RegExp(r'[a-z]'))) continue;
          if (foundFn == null || idx < fnStart) {
            foundFn = fn;
            fnStart = idx;
          }
        }
      }

      if (foundFn == null) break;

      // Find the content between ( and matching )
      int parenStart = fnStart + foundFn.length; // position of '('
      int depth = 1;
      int parenEnd = parenStart + 1;
      while (parenEnd < expr.length && depth > 0) {
        if (expr[parenEnd] == '(') depth++;
        if (expr[parenEnd] == ')') depth--;
        if (depth == 0) break;
        parenEnd++;
      }
      if (depth != 0) break; // unbalanced

      // Get content inside parens
      String content = expr.substring(parenStart + 1, parenEnd);

      // Check if content has no nested parens (innermost)
      if (!content.contains('(')) {
        // Evaluate content
        double arg = _resolve(content); // recursive
        // Apply function
        double result = _applyFn(foundFn, arg);
        // Replace in expression
        String resultStr = _numToStr(result);
        expr = expr.substring(0, fnStart) + resultStr + expr.substring(parenEnd + 1);
      } else {
        // Has nested parens — resolve innermost first
        // Find innermost parens
        int innerStart = content.lastIndexOf('(');
        int innerEnd = content.indexOf(')', innerStart);
        if (innerEnd == -1) break;
        String innerContent = content.substring(innerStart + 1, innerEnd);
        double innerVal = _resolve(innerContent);
        String innerResult = _numToStr(innerVal);
        // Rebuild: replace innermost parens in content, then rebuild expr
        String newContent = content.substring(0, innerStart) + innerResult + content.substring(innerEnd + 1);
        expr = expr.substring(0, fnStart + foundFn.length + 1) + newContent + expr.substring(parenEnd);
      }
    }

    // Step 2: Resolve remaining parentheses (no functions)
    for (int iter = 0; iter < 100; iter++) {
      int start = expr.lastIndexOf('(');
      if (start == -1) break;
      int end = expr.indexOf(')', start);
      if (end == -1) break;
      String content = expr.substring(start + 1, end);
      double val = _arithmetic(content);
      String resultStr = _numToStr(val);
      expr = expr.substring(0, start) + resultStr + expr.substring(end + 1);
    }

    // Step 3: Handle power (^)
    while (expr.contains('^')) {
      int idx = expr.lastIndexOf('^');
      // Find left number
      int ls = idx - 1;
      while (ls >= 0 && (expr[ls].contains(RegExp(r'[0-9.]')) ||
             (expr[ls] == '-' && ls == 0))) ls--;
      ls++;
      // Find right number
      int rs = idx + 1;
      int re = rs;
      if (re < expr.length && expr[re] == '-') re++;
      while (re < expr.length && expr[re].contains(RegExp(r'[0-9.]'))) re++;
      if (ls >= idx || rs >= re) break;
      double left = double.tryParse(expr.substring(ls, idx)) ?? 0;
      double right = double.tryParse(expr.substring(rs, re)) ?? 0;
      double result = pow(left, right).toDouble();
      expr = expr.substring(0, ls) + _numToStr(result) + expr.substring(re);
    }

    // Step 4: Final arithmetic
    return _arithmetic(expr);
  }

  double _applyFn(String fn, double arg) {
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

  /// Convert double to safe string — NO scientific notation.
  String _numToStr(double v) {
    if (v.isNaN || v.isInfinite) return '0';
    if (v == v.truncateToDouble() && v.abs() < 1e15) {
      return v.toStringAsFixed(0);
    }
    // Force fixed-point, avoid scientific notation
    String s = v.toStringAsFixed(10);
    // Trim trailing zeros
    s = s.replaceAll(RegExp(r'0+$'), '');
    s = s.replaceAll(RegExp(r'\.$'), '');
    return s;
  }

  /// Simple arithmetic: +, -, *, / — no parens, no functions.
  /// Two-pass approach: * and / first, then + and -.
  double _arithmetic(String expr) {
    expr = expr.trim();
    if (expr.isEmpty) return 0;

    // Parse into tokens (numbers and operators)
    final items = <dynamic>[]; // double or String (operator)
    int i = 0;
    while (i < expr.length) {
      String c = expr[i];
      if (c == ' ') { i++; continue; }
      if ('+-*/'.contains(c)) {
        // Negative number?
        if (c == '-' && (items.isEmpty || (items.last is String))) {
          // Parse negative number
          String num = '-';
          i++;
          while (i < expr.length && expr[i].contains(RegExp(r'[0-9.]'))) {
            num += expr[i]; i++;
          }
          double? v = double.tryParse(num);
          if (v != null) items.add(v);
        } else {
          items.add(c);
          i++;
        }
      } else {
        String num = '';
        while (i < expr.length && expr[i].contains(RegExp(r'[0-9.]'))) {
          num += expr[i]; i++;
        }
        double? v = double.tryParse(num);
        if (v != null) items.add(v);
      }
    }

    if (items.isEmpty) return 0;
    if (items.length == 1 && items[0] is double) return items[0];

    // Pass 1: * and /
    final pass1 = <dynamic>[];
    int j = 0;
    while (j < items.length) {
      if (items[j] is String && (items[j] == '*' || items[j] == '/')) {
        if (pass1.isEmpty || j + 1 >= items.length) { j++; continue; }
        double left = pass1.removeLast() as double;
        double right = items[j + 1] as double;
        double r;
        if (items[j] == '*') r = left * right;
        else r = right == 0 ? double.nan : left / right;
        pass1.add(r);
        j += 2;
      } else {
        pass1.add(items[j]);
        j++;
      }
    }

    // Pass 2: + and -
    if (pass1.isEmpty) return 0;
    double result = pass1[0] is double ? pass1[0] as double : 0.0;
    for (int k = 1; k < pass1.length; k += 2) {
      if (k + 1 >= pass1.length) break;
      if (pass1[k] is! String) continue;
      String op = pass1[k] as String;
      double right = pass1[k + 1] as double;
      if (op == '+') result += right;
      if (op == '-') result -= right;
    }
    return result;
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
