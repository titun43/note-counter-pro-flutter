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
      if (value == 'C') {
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
      } else if (value == 'sin' || value == 'cos' || value == 'tan' ||
                 value == 'asin' || value == 'acos' || value == 'atan' ||
                 value == 'log' || value == 'ln' || value == 'sqrt' ||
                 value == 'exp') {
        _expression += '$value(';
        _display = _expression;
      } else {
        _expression += value;
        _display = _expression;
      }
    });
  }

  void _evaluate() {
    try {
      String expr = _expression;
      // Replace symbols
      expr = expr.replaceAll('×', '*').replaceAll('÷', '/');

      // Handle functions
      final funcs = ['asin', 'acos', 'atan', 'sin', 'cos', 'tan', 'sqrt', 'exp'];
      for (final f in funcs) {
        expr = expr.replaceAll('$f(', '_$f(');
      }
      expr = expr.replaceAll('log(', '_log(');
      expr = expr.replaceAll('ln(', '_ln(');

      double result = _evalExpression(expr);
      if (result.isNaN || result.isInfinite) {
        _display = 'Error';
      } else {
        _display = _formatResult(result);
        _expression = _display;
      }
    } catch (_) {
      _display = 'Error';
    }
  }

  double _evalExpression(String expr) {
    // Simple recursive descent parser
    expr = expr.replaceAll(' ', '');
    if (expr.isEmpty) return 0;
    int pos = 0;
    return _parseExpr(expr, pos).$1;
  }

  (double, int) _parseExpr(String s, int pos) {
    double val = 0;
    (val, pos) = _parseTerm(s, pos);
    while (pos < s.length && (s[pos] == '+' || s[pos] == '-')) {
      final op = s[pos++];
      double rhs;
      (rhs, pos) = _parseTerm(s, pos);
      val = op == '+' ? val + rhs : val - rhs;
    }
    return (val, pos);
  }

  (double, int) _parseTerm(String s, int pos) {
    double val = 0;
    (val, pos) = _parseFactor(s, pos);
    while (pos < s.length && (s[pos] == '*' || s[pos] == '/')) {
      final op = s[pos++];
      double rhs;
      (rhs, pos) = _parseFactor(s, pos);
      val = op == '*' ? val * rhs : val / rhs;
    }
    return (val, pos);
  }

  (double, int) _parseFactor(String s, int pos) {
    if (pos >= s.length) return (0, pos);

    // Functions
    if (s[pos] == '_') {
      pos++;
      String func = '';
      while (pos < s.length && s[pos] != '(') {
        func += s[pos++];
      }
      pos++; // skip (
      double arg;
      (arg, pos) = _parseExpr(s, pos);
      if (pos < s.length && s[pos] == ')') pos++;

      double result;
      switch (func) {
        case 'sin':
          result = sin(_isDegree ? arg * pi / 180 : arg);
          break;
        case 'cos':
          result = cos(_isDegree ? arg * pi / 180 : arg);
          break;
        case 'tan':
          result = tan(_isDegree ? arg * pi / 180 : arg);
          break;
        case 'asin':
          result = _isDegree ? asin(arg) * 180 / pi : asin(arg);
          break;
        case 'acos':
          result = _isDegree ? acos(arg) * 180 / pi : acos(arg);
          break;
        case 'atan':
          result = _isDegree ? atan(arg) * 180 / pi : atan(arg);
          break;
        case 'log':
          result = log(arg) / ln10;
          break;
        case 'ln':
          result = log(arg);
          break;
        case 'sqrt':
          result = sqrt(arg);
          break;
        case 'exp':
          result = exp(arg);
          break;
        default:
          result = 0;
      }
      return (result, pos);
    }

    // Parentheses
    if (s[pos] == '(') {
      pos++;
      double val;
      (val, pos) = _parseExpr(s, pos);
      if (pos < s.length && s[pos] == ')') pos++;
      return (val, pos);
    }

    // Power
    double val;
    (val, pos) = _parseNumber(s, pos);
    if (pos < s.length && s[pos] == '^') {
      pos++;
      double exp;
      (exp, pos) = _parseFactor(s, pos);
      return (pow(val, exp).toDouble(), pos);
    }

    return (val, pos);
  }

  (double, int) _parseNumber(String s, int pos) {
    String num = '';
    while (pos < s.length && (s[pos].digitOrDot)) {
      num += s[pos++];
    }
    return (double.tryParse(num) ?? 0, pos);
  }

  static const ln10 = 2.302585092994046;

  String _formatResult(double val) {
    if (val == val.truncateToDouble()) {
      return val.toStringAsFixed(0);
    }
    return val.toStringAsFixed(6).replaceAll(RegExp(r'0+$'), '');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final rows = [
      ['sin', 'cos', 'tan', 'π'],
      ['asin', 'acos', 'atan', 'e'],
      ['log', 'ln', '√', '^'],
      ['(', ')', 'n!', 'deg/rad'],
      ['C', '⌫', '÷', '×'],
      ['7', '8', '9', '-'],
      ['4', '5', '6', '+'],
      ['1', '2', '3', '='],
      ['0', '.', '00', ''],
    ];

    return Column(
      children: [
        // Display
        Expanded(
          flex: 2,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            alignment: Alignment.bottomRight,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (_expression.isNotEmpty && _expression != _display)
                  Text(_expression,
                      style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(_display,
                      style: TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black,
                      )),
                ),
                const SizedBox(height: 4),
                Text(_isDegree ? 'DEG' : 'RAD',
                    style: TextStyle(fontSize: 11, color: Colors.grey[400])),
              ],
            ),
          ),
        ),
        // Buttons
        Expanded(
          flex: 5,
          child: Column(
            children: rows.map((row) {
              return Expanded(
                child: Row(
                  children: row.map((label) {
                    if (label.isEmpty) return const Expanded(child: SizedBox());
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(2),
                        child: ElevatedButton(
                          onPressed: () => _onButton(label),
                          style: ElevatedButton.styleFrom(
                            padding: EdgeInsets.zero,
                            backgroundColor: _getButtonColor(label, isDark),
                            foregroundColor: _getButtonTextColor(label, isDark),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(label,
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Color? _getButtonColor(String label, bool isDark) {
    if (label == 'C' || label == '⌫') return Colors.red.withOpacity(0.2);
    if (label == '=') return AppColors.primary;
    if (['÷', '×', '-', '+'].contains(label)) return AppColors.primary.withOpacity(0.15);
    if (['sin','cos','tan','asin','acos','atan','log','ln','√','^','π','e','n!','deg/rad'].contains(label)) {
      return AppColors.info.withOpacity(0.15);
    }
    return isDark ? Colors.grey[850] : Colors.grey[100];
  }

  Color _getButtonTextColor(String label, bool isDark) {
    if (label == '=') return Colors.white;
    if (['÷', '×', '-', '+'].contains(label)) return AppColors.primary;
    if (['sin','cos','tan','asin','acos','atan','log','ln','√','^','π','e','n!','deg/rad'].contains(label)) {
      return AppColors.info;
    }
    if (label == 'C' || label == '⌫') return Colors.red;
    return isDark ? Colors.white : Colors.black87;
  }
}

extension on String {
  bool get digitOrDot {
    final c = codeUnitAt(0);
    return (c >= 48 && c <= 57) || this == '.';
  }
}
