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
    try {
      String expr = _expression.replaceAll('×', '*').replaceAll('÷', '/');
      double result = _evalExpr(expr);
      _display = result.isNaN || result.isInfinite ? 'Error' : _fmt(result);
      _expression = _display;
    } catch (_) {
      _display = 'Error';
    }
  }

  double _evalExpr(String s) {
    s = s.replaceAll(' ', '');
    if (s.isEmpty) return 0;
    return _parse(s, 0).$1;
  }

  (double, int) _parse(String s, int pos) {
    double v;
    (v, pos) = _term(s, pos);
    while (pos < s.length && (s[pos] == '+' || s[pos] == '-')) {
      final op = s[pos++];
      double r;
      (r, pos) = _term(s, pos);
      v = op == '+' ? v + r : v - r;
    }
    return (v, pos);
  }

  (double, int) _term(String s, int pos) {
    double v;
    (v, pos) = _factor(s, pos);
    while (pos < s.length && (s[pos] == '*' || s[pos] == '/')) {
      final op = s[pos++];
      double r;
      (r, pos) = _factor(s, pos);
      v = op == '*' ? v * r : v / r;
    }
    return (v, pos);
  }

  (double, int) _factor(String s, int pos) {
    if (pos >= s.length) return (0, pos);
    // Check for function names
    for (final fn in ['asin','acos','atan','sin','cos','tan','sqrt','exp','log','ln']) {
      if (pos + fn.length <= s.length && s.substring(pos, pos + fn.length) == fn) {
        pos += fn.length;
        if (pos < s.length && s[pos] == '(') pos++;
        double arg;
        (arg, pos) = _parse(s, pos);
        if (pos < s.length && s[pos] == ')') pos++;
        double r;
        switch (fn) {
          case 'sin': r = sin(_isDegree ? arg * pi / 180 : arg); break;
          case 'cos': r = cos(_isDegree ? arg * pi / 180 : arg); break;
          case 'tan': r = tan(_isDegree ? arg * pi / 180 : arg); break;
          case 'asin': r = _isDegree ? asin(arg) * 180 / pi : asin(arg); break;
          case 'acos': r = _isDegree ? acos(arg) * 180 / pi : acos(arg); break;
          case 'atan': r = _isDegree ? atan(arg) * 180 / pi : atan(arg); break;
          case 'log': r = log(arg) / 2.302585; break;
          case 'ln': r = log(arg); break;
          case 'sqrt': r = sqrt(arg); break;
          case 'exp': r = exp(arg); break;
          default: r = 0;
        }
        // Power after function
        if (pos < s.length && s[pos] == '^') {
          pos++;
          double e;
          (e, pos) = _factor(s, pos);
          r = pow(r, e).toDouble();
        }
        return (r, pos);
      }
    }
    // Parentheses
    if (s[pos] == '(') {
      pos++;
      double v;
      (v, pos) = _parse(s, pos);
      if (pos < s.length && s[pos] == ')') pos++;
      return (v, pos);
    }
    // Number
    double v;
    (v, pos) = _num(s, pos);
    if (pos < s.length && s[pos] == '^') {
      pos++;
      double e;
      (e, pos) = _factor(s, pos);
      return (pow(v, e).toDouble(), pos);
    }
    return (v, pos);
  }

  (double, int) _num(String s, int pos) {
    String n = '';
    while (pos < s.length && _isDigitOrDot(s[pos])) {
      n += s[pos++];
    }
    return (double.tryParse(n) ?? 0, pos);
  }

  bool _isDigitOrDot(String c) =>
      c.codeUnitAt(0) >= 48 && c.codeUnitAt(0) <= 57 || c == '.';

  String _fmt(double v) {
    if (v == v.truncateToDouble()) return v.toStringAsFixed(0);
    return v.toStringAsFixed(6).replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF5F5F5);

    final rows = [
      ['sin', 'cos', 'tan', 'π'],
      ['log', 'ln', '√', 'e'],
      ['AC', '%', '⌫', '÷'],
      ['7', '8', '9', '×'],
      ['4', '5', '6', '-'],
      ['1', '2', '3', '+'],
      ['0', '.', '^', '='],
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
                  children: row.map((label) => _btn(label, isDark)).toList(),
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
    final isFn = ['AC','%','⌫'].contains(label);
    final isSci = ['sin','cos','tan','log','ln','√','π','e','^'].contains(label);

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
          elevation: 0,
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(label, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
        ),
      ),
    );
  }
}
