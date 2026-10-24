import 'package:flutter/material.dart';
import '../utils/constants.dart';

class StandardCalculator extends StatefulWidget {
  final double? initialValue;
  final String currencyCode;

  const StandardCalculator({
    super.key,
    this.initialValue,
    this.currencyCode = 'INR',
  });

  @override
  State<StandardCalculator> createState() => _StandardCalculatorState();
}

class _StandardCalculatorState extends State<StandardCalculator> {
  String _display = '0';
  String _expression = '';
  final List<String> _history = [];

  @override
  void initState() {
    super.initState();
    if (widget.initialValue != null && widget.initialValue! > 0) {
      final value = widget.initialValue!.toStringAsFixed(2);
      if (value.endsWith('.00')) {
        _display = value.substring(0, value.length - 3);
      } else {
        _display = value;
      }
      _expression = _display;
    }
  }

  void _onButton(String value) {
    setState(() {
      if (value == 'AC') {
        _display = '0';
        _expression = '';
      } else if (value == '=') {
        if (_expression.isEmpty) return;
        try {
          final result = _eval(_expression);
          final formatted = _fmt(result);
          _history.insert(0, '$_expression = $formatted');
          if (_history.length > 20) _history.removeLast();
          _display = formatted;
          _expression = formatted;
        } catch (_) {
          _display = 'Error';
          _expression = '';
        }
      } else if (value == '⌫') {
        if (_expression.isNotEmpty) {
          _expression = _expression.substring(0, _expression.length - 1);
          _display = _expression.isEmpty ? '0' : _expression;
        }
      } else if (value == '%') {
        if (_expression.isNotEmpty) {
          try {
            final val = _eval(_expression);
            final pct = val / 100;
            _expression = _fmt(pct);
            _display = _fmt(pct);
          } catch (_) {}
        }
      } else {
        // Prevent double operators
        if ('+-×÷'.contains(value) && _expression.isNotEmpty) {
          final last = _expression[_expression.length - 1];
          if ('+-×÷'.contains(last)) {
            _expression = _expression.substring(0, _expression.length - 1) + value;
            _display = _expression;
            return;
          }
        }
        _expression += value;
        _display = _expression;
      }
    });
  }

  /// Robust expression evaluator — tokenizes then parses.
  double _eval(String expr) {
    // Replace display symbols
    expr = expr.replaceAll('×', '*').replaceAll('÷', '/').replaceAll('−', '-');
    expr = expr.trim();
    if (expr.isEmpty) return 0;

    // Tokenize: numbers and operators
    final tokens = <String>[];
    int i = 0;
    while (i < expr.length) {
      final c = expr[i];
      if (c == ' ') { i++; continue; }
      if ('+-*/'.contains(c)) {
        // Handle negative numbers at start or after operator
        if (c == '-' && (tokens.isEmpty || '+-*/('.contains(tokens.last))) {
          // This is a negative sign, not subtraction
          String num = '-';
          i++;
          while (i < expr.length && (expr[i].contains(RegExp(r'[0-9.]')))) {
            num += expr[i];
            i++;
          }
          tokens.add(num);
        } else {
          tokens.add(c);
          i++;
        }
      } else if (c == '(' || c == ')') {
        tokens.add(c);
        i++;
      } else {
        // Number
        String num = '';
        while (i < expr.length && expr[i].contains(RegExp(r'[0-9.]'))) {
          num += expr[i];
          i++;
        }
        if (num.isNotEmpty) tokens.add(num);
      }
    }

    if (tokens.isEmpty) return 0;

    // Shunting yard: convert to RPN then evaluate
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
      } else if (token == '(') {
        ops.add(token);
      } else if (token == ')') {
        while (ops.isNotEmpty && ops.last != '(') {
          output.add(ops.removeLast());
        }
        if (ops.isNotEmpty) ops.removeLast(); // remove (
      } else {
        // operator
        while (ops.isNotEmpty && ops.last != '(' && prec(ops.last) >= prec(token)) {
          output.add(ops.removeLast());
        }
        ops.add(token);
      }
    }
    while (ops.isNotEmpty) {
      output.add(ops.removeLast());
    }

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
    if (v.isNaN || v.isInfinite) return 'Error';
    if (v == v.truncateToDouble()) return v.toStringAsFixed(0);
    // Limit to 8 decimal places, trim trailing zeros
    String s = v.toStringAsFixed(8);
    s = s.replaceAll(RegExp(r'0+$'), '');
    s = s.replaceAll(RegExp(r'\.$'), '');
    return s;
  }

  void _showHistory() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(Icons.history, size: 20),
                    const SizedBox(width: 8),
                    const Text('History',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const Spacer(),
                    if (_history.isNotEmpty)
                      TextButton(
                        onPressed: () => setState(() {
                          _history.clear();
                          Navigator.pop(ctx);
                        }),
                        child: const Text('Clear', style: TextStyle(fontSize: 13)),
                      ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // History list
              if (_history.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Text('No history yet',
                      style: TextStyle(color: Colors.grey)),
                )
              else
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.4,
                  ),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _history.length,
                    itemBuilder: (ctx, i) => ListTile(
                      title: Text(
                        _history[i],
                        style: TextStyle(
                          fontSize: 14,
                          fontFamily: 'monospace',
                          color: isDark ? Colors.grey[300] : Colors.grey[700],
                        ),
                      ),
                      onTap: () {
                        // Tap to reuse result
                        final parts = _history[i].split(' = ');
                        if (parts.length == 2) {
                          setState(() {
                            _display = parts[1];
                            _expression = parts[1];
                          });
                        }
                        Navigator.pop(ctx);
                      },
                    ),
                  ),
                ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF5F5F5);

    return Container(
      color: bgColor,
      child: Column(
        children: [
          // Top bar with history (⋮) button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            child: Row(
              children: [
                if (_history.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF9500).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${_history.length}',
                      style: const TextStyle(fontSize: 10, color: Color(0xFFFF9500), fontWeight: FontWeight.bold),
                    ),
                  ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.more_vert, size: 22),
                  onPressed: _showHistory,
                  tooltip: 'History',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                ),
              ],
            ),
          ),
          // Display
          Expanded(
            flex: 3,
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
                        style: TextStyle(fontSize: 14,
                            color: isDark ? Colors.grey[400] : Colors.grey[500]),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(_display,
                        style: TextStyle(fontSize: 48, fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black)),
                  ),
                ],
              ),
            ),
          ),
          // Round buttons — bigger (72px)
          Expanded(
            flex: 5,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _row(['AC', '%', '⌫', '÷'], isDark),
                  _row(['7', '8', '9', '×'], isDark),
                  _row(['4', '5', '6', '-'], isDark),
                  _row(['1', '2', '3', '+'], isDark),
                  _row(['0', '00', '.', '='], isDark),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(List<String> labels, bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: labels.map((label) => _roundButton(label, isDark)).toList(),
    );
  }

  Widget _roundButton(String label, bool isDark) {
    final isOperator = ['÷', '×', '-', '+'].contains(label);
    final isEquals = label == '=';
    final isFunction = ['AC', '%', '⌫'].contains(label);

    Color bg;
    Color fg;
    if (isEquals) {
      bg = const Color(0xFFFF9500);
      fg = Colors.white;
    } else if (isOperator) {
      bg = isDark ? const Color(0xFF3A3A3A) : const Color(0xFFE0E0E0);
      fg = const Color(0xFFFF9500);
    } else if (isFunction) {
      bg = isDark ? const Color(0xFF3A3A3A) : const Color(0xFFD1D1D1);
      fg = isDark ? Colors.white : Colors.black87;
    } else {
      bg = isDark ? const Color(0xFF2C2C2C) : Colors.white;
      fg = isDark ? Colors.white : Colors.black87;
    }

    // Bigger buttons: 72px
    return Container(
      width: 72,
      height: 72,
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
          child: Text(label,
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w500)),
        ),
      ),
    );
  }
}
