import 'package:flutter/material.dart';
import '../utils/constants.dart';

class ProgrammerCalculator extends StatefulWidget {
  const ProgrammerCalculator({super.key});

  @override
  State<ProgrammerCalculator> createState() => _ProgrammerCalculatorState();
}

class _ProgrammerCalculatorState extends State<ProgrammerCalculator> {
  int _base = 10;
  String _display = '0';
  String _expression = '';

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
      } else if (['AND','OR','XOR','NOT'].contains(value)) {
        _expression += ' $value ';
        _display = _expression;
      } else {
        _expression += value;
        _display = _expression;
      }
    });
  }

  void _evaluate() {
    try {
      String expr = _expression.trim();
      
      // Handle bitwise operations
      if (expr.contains(' AND ')) {
        final p = expr.split(' AND ');
        _display = ((int.parse(p[0], radix: _base)) & (int.parse(p[1], radix: _base))).toRadixString(_base).toUpperCase();
      } else if (expr.contains(' OR ')) {
        final p = expr.split(' OR ');
        _display = ((int.parse(p[0], radix: _base)) | (int.parse(p[1], radix: _base))).toRadixString(_base).toUpperCase();
      } else if (expr.contains(' XOR ')) {
        final p = expr.split(' XOR ');
        _display = ((int.parse(p[0], radix: _base)) ^ (int.parse(p[1], radix: _base))).toRadixString(_base).toUpperCase();
      } else if (expr.contains(' NOT ')) {
        final a = int.parse(expr.replaceAll('NOT ', ''), radix: _base);
        _display = (~a).toRadixString(_base).toUpperCase();
      } else if (expr.contains('+') || expr.contains('-') || expr.contains('*') || expr.contains('/')) {
        // Arithmetic in current base
        // Convert all numbers to decimal, evaluate, convert back
        String decExpr = expr;
        // Find all number tokens and convert from current base to decimal
        final numberRegex = RegExp(r'[0-9A-Fa-f]+');
        decExpr = decExpr.replaceAllMapped(numberRegex, (match) {
          try {
            return int.parse(match.group(0)!, radix: _base).toString();
          } catch (_) {
            return match.group(0)!;
          }
        });
        // Now evaluate as decimal
        final result = _evalDecimal(decExpr);
        _display = result.toRadixString(_base).toUpperCase();
      } else {
        _display = int.parse(expr, radix: _base).toRadixString(_base).toUpperCase();
      }
      _expression = _display;
    } catch (_) {
      _display = 'Error';
    }
  }

  /// Simple decimal evaluator using Shunting Yard
  int _evalDecimal(String expr) {
    expr = expr.replaceAll(' ', '');
    final tokens = <String>[];
    int i = 0;
    while (i < expr.length) {
      final c = expr[i];
      if ('+-*/'.contains(c)) {
        if (c == '-' && (tokens.isEmpty || '+-*/'.contains(tokens.last))) {
          String num = '-';
          i++;
          while (i < expr.length && expr[i].contains(RegExp(r'[0-9]'))) {
            num += expr[i]; i++;
          }
          tokens.add(num);
        } else {
          tokens.add(c);
          i++;
        }
      } else {
        String num = '';
        while (i < expr.length && expr[i].contains(RegExp(r'[0-9]'))) {
          num += expr[i]; i++;
        }
        if (num.isNotEmpty) tokens.add(num);
      }
    }
    // Shunting Yard
    final output = <String>[];
    final ops = <String>[];
    int prec(String op) {
      if (op == '+' || op == '-') return 1;
      if (op == '*' || op == '/') return 2;
      return 0;
    }
    for (final token in tokens) {
      if (int.tryParse(token) != null) {
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
    final stack = <int>[];
    for (final token in output) {
      if (int.tryParse(token) != null) {
        stack.add(int.parse(token));
      } else {
        if (stack.length < 2) throw Exception('Invalid');
        final b = stack.removeLast();
        final a = stack.removeLast();
        switch (token) {
          case '+': stack.add(a + b); break;
          case '-': stack.add(a - b); break;
          case '*': stack.add(a * b); break;
          case '/': stack.add(a ~/ b); break; // integer division
        }
      }
    }
    return stack.isEmpty ? 0 : stack.last;
  }

  void _changeBase(int base) {
    setState(() {
      try {
        final v = _expression.isNotEmpty ? int.parse(_expression, radix: _base) : 0;
        _base = base;
        _display = v.toRadixString(base).toUpperCase();
        _expression = _display;
      } catch (_) {
        _base = base;
        _display = '0';
        _expression = '';
      }
    });
  }

  String _allBases() {
    try {
      final v = int.parse(_expression.isNotEmpty ? _expression : '0', radix: _base);
      return 'DEC:${v}  HEX:${v.toRadixString(16).toUpperCase()}  OCT:${v.toRadixString(8)}  BIN:${v.toRadixString(2)}';
    } catch (_) {
      return '';
    }
  }

  List<String> get _activeDigits {
    if (_base == 16) return ['0','1','2','3','4','5','6','7','8','9','A','B','C','D','E','F'];
    if (_base == 10) return ['0','1','2','3','4','5','6','7','8','9'];
    if (_base == 8) return ['0','1','2','3','4','5','6','7'];
    return ['0','1'];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF5F5F5);

    // Build digit rows (4 per row)
    List<List<String>> digitRows = [];
    List<String> digits = List.from(_activeDigits);
    digitRows.add(['AC', '%', '⌫', '÷']);
    for (int i = 0; i < digits.length; i += 3) {
      final row = <String>[];
      for (int j = i; j < i + 3 && j < digits.length; j++) {
        row.add(digits[j]);
      }
      while (row.length < 3) row.add('');
      if (i == 0) { row.add('×'); }
      else if (i == 3) { row.add('-'); }
      else if (i == 6) { row.add('+'); }
      else if (i == 9) { row.add('='); }
      else { row.add(''); }
      digitRows.add(row);
    }
    // Ensure at least 5 rows
    while (digitRows.length < 5) {
      digitRows.add(['', '', '', '']);
    }

    return Container(
      color: bgColor,
      child: Column(
        children: [
          // Base selector
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _baseBtn('DEC', 10, isDark),
                _baseBtn('HEX', 16, isDark),
                _baseBtn('OCT', 8, isDark),
                _baseBtn('BIN', 2, isDark),
              ],
            ),
          ),
          // Multi-base display
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            margin: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[850] : Colors.grey[200],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(_allBases(),
                style: TextStyle(fontSize: 10, fontFamily: 'monospace',
                    color: isDark ? Colors.grey[400] : Colors.grey[600])),
          ),
          // Main display
          Expanded(
            flex: 2,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              alignment: Alignment.bottomRight,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(_display,
                    style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black,
                        fontFamily: 'monospace')),
              ),
            ),
          ),
          // Bitwise ops row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: ['AND','OR','XOR','NOT'].map((op) => _smallBtn(op, isDark)).toList(),
            ),
          ),
          // Digit buttons (round)
          Expanded(
            flex: 4,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: digitRows.take(5).map((row) => Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: row.map((label) => label.isEmpty
                      ? const SizedBox(width: 64, height: 64)
                      : _btn(label, isDark)).toList(),
                )).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _baseBtn(String label, int base, bool isDark) {
    final active = _base == base;
    return Container(
      height: 36,
      margin: const EdgeInsets.symmetric(horizontal: 2),
      child: ElevatedButton(
        onPressed: () => _changeBase(base),
        style: ElevatedButton.styleFrom(
          backgroundColor: active ? const Color(0xFFFF9500) : (isDark ? Colors.grey[800] : Colors.grey[300]),
          foregroundColor: active ? Colors.white : (isDark ? Colors.white70 : Colors.black54),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          elevation: 0,
        ),
        child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _smallBtn(String label, bool isDark) {
    return Container(
      height: 40,
      margin: const EdgeInsets.all(2),
      child: ElevatedButton(
        onPressed: () => _onButton(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: isDark ? const Color(0xFF1E3A5F) : const Color(0xFFE3F2FD),
          foregroundColor: const Color(0xFF1976D2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          elevation: 0,
        ),
        child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _btn(String label, bool isDark) {
    final isOp = ['÷','×','-','+'].contains(label);
    final isEq = label == '=';
    final isFn = ['AC','%','⌫'].contains(label);

    Color bg, fg;
    if (isEq) { bg = const Color(0xFFFF9500); fg = Colors.white; }
    else if (isOp) { bg = isDark ? const Color(0xFF3A3A3A) : const Color(0xFFE0E0E0); fg = const Color(0xFFFF9500); }
    else if (isFn) { bg = isDark ? const Color(0xFF3A3A3A) : const Color(0xFFD1D1D1); fg = isDark ? Colors.white : Colors.black87; }
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
          child: Text(label, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500,
              fontFamily: isOp || isFn ? null : 'monospace')),
        ),
      ),
    );
  }
}
