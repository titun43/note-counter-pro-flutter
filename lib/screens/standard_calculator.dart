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
  bool _showHistory = false;

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
        try {
          final result = _evaluate(_expression);
          _history.insert(0, '$_expression = ${_formatResult(result)}');
          if (_history.length > 20) _history.removeLast();
          _display = _formatResult(result);
          _expression = _display;
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
            final val = _evaluate(_expression);
            _expression = (val / 100).toString();
            _display = _formatResult(val / 100);
          } catch (_) {}
        }
      } else {
        _expression += value;
        _display = _expression;
      }
    });
  }

  double _evaluate(String expr) {
    expr = expr.replaceAll('×', '*').replaceAll('÷', '/');
    double eval(String e) {
      e = e.trim();
      if (e.isEmpty) return 0;
      while (e.contains('(')) {
        final start = e.lastIndexOf('(');
        final end = e.indexOf(')', start);
        if (end == -1) throw Exception(')');
        final sub = eval(e.substring(start + 1, end));
        e = e.substring(0, start) + sub.toString() + e.substring(end + 1);
      }
      final parts = e.split(RegExp(r'([+-])'));
      if (parts.length > 1) {
        double r = double.tryParse(parts[0]) ?? 0;
        for (int i = 1; i < parts.length; i += 2) {
          final v = double.tryParse(parts[i + 1]) ?? 0;
          if (parts[i] == '+') r += v;
          if (parts[i] == '-') r -= v;
        }
        return r;
      }
      final md = e.split(RegExp(r'([*/])'));
      if (md.length > 1) {
        double r = double.tryParse(md[0]) ?? 0;
        for (int i = 1; i < md.length; i += 2) {
          final v = double.tryParse(md[i + 1]) ?? 0;
          if (md[i] == '*') r *= v;
          if (md[i] == '/') r /= v;
        }
        return r;
      }
      return double.tryParse(e) ?? 0;
    }
    return eval(expr);
  }

  String _formatResult(double v) {
    if (v == v.truncateToDouble()) return v.toStringAsFixed(0);
    return v.toStringAsFixed(2);
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
          // History toggle
          if (_history.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
              child: Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => setState(() => _showHistory = !_showHistory),
                  icon: Icon(_showHistory ? Icons.expand_less : Icons.expand_more, size: 18),
                  label: Text(
                    _showHistory ? 'Hide History' : 'Show History (${_history.length})',
                    style: const TextStyle(fontSize: 12),
                  ),
                  style: TextButton.styleFrom(minimumSize: const Size(0, 28)),
                ),
              ),
            ),
          if (_showHistory && _history.isNotEmpty)
            Container(
              height: 70,
              margin: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[850] : Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
              ),
              child: ListView.builder(
                padding: const EdgeInsets.all(8),
                itemCount: _history.length,
                itemBuilder: (ctx, i) => Text(
                  _history[i],
                  style: TextStyle(fontSize: 12, fontFamily: 'monospace',
                      color: isDark ? Colors.grey[400] : Colors.grey[600]),
                ),
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
                        style: TextStyle(fontSize: 44, fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black)),
                  ),
                ],
              ),
            ),
          ),
          // Round buttons
          Expanded(
            flex: 5,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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

    return Container(
      width: 64,
      height: 64,
      margin: const EdgeInsets.all(4),
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
          child: Text(label,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w500)),
        ),
      ),
    );
  }
}
