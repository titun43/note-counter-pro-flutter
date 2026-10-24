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

  String get _currencySymbol =>
      AppConstants.getCurrencySymbol(widget.currencyCode);

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

  void _onButtonPressed(String value) {
    setState(() {
      if (value == 'C') {
        _display = '0';
        _expression = '';
      } else if (value == '=') {
        try {
          final result = _evaluate(_expression);
          _history.insert(0, '$_expression = ${_formatResult(result)}');
          if (_history.length > 20) _history.removeLast();
          _display = _formatResult(result);
          _expression = _display;
        } catch (e) {
          _display = 'Error';
          _expression = '';
        }
      } else if (value == '⌫') {
        if (_expression.isNotEmpty) {
          _expression = _expression.substring(0, _expression.length - 1);
          _display = _expression.isEmpty ? '0' : _expression;
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
        if (end == -1) throw Exception('Missing )');
        final subResult = eval(e.substring(start + 1, end));
        e = e.substring(0, start) + subResult.toString() + e.substring(end + 1);
      }
      final addSub = RegExp(r'([+-])');
      final parts = e.split(addSub);
      if (parts.length > 1) {
        double result = double.tryParse(parts[0]) ?? 0;
        for (int i = 1; i < parts.length; i += 2) {
          final op = parts[i];
          final val = double.tryParse(parts[i + 1]) ?? 0;
          if (op == '+') result += val;
          if (op == '-') result -= val;
        }
        return result;
      }
      final mulDiv = RegExp(r'([*/])');
      final mdParts = e.split(mulDiv);
      if (mdParts.length > 1) {
        double result = double.tryParse(mdParts[0]) ?? 0;
        for (int i = 1; i < mdParts.length; i += 2) {
          final op = mdParts[i];
          final val = double.tryParse(mdParts[i + 1]) ?? 0;
          if (op == '*') result *= val;
          if (op == '/') result /= val;
        }
        return result;
      }
      return double.tryParse(e) ?? 0;
    }
    return eval(expr);
  }

  String _formatResult(double val) {
    if (val == val.truncateToDouble()) {
      return val.toStringAsFixed(0);
    }
    return val.toStringAsFixed(2);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final buttons = [
      ['C', '⌫', '÷', '×'],
      ['7', '8', '9', '-'],
      ['4', '5', '6', '+'],
      ['1', '2', '3', '='],
      ['0', '.', '00', ''],
    ];

    return Column(
      children: [
        // Top bar: history toggle
        if (_history.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            child: Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => setState(() => _showHistory = !_showHistory),
                icon: Icon(
                  _showHistory ? Icons.expand_less : Icons.expand_more,
                  size: 18,
                ),
                label: Text(
                  _showHistory ? 'Hide History' : 'Show History (${_history.length})',
                  style: const TextStyle(fontSize: 12),
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                  minimumSize: const Size(0, 28),
                ),
              ),
            ),
          ),
        // History list
        if (_showHistory && _history.isNotEmpty)
          Container(
            height: 80,
            margin: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[850] : Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: _history.length,
              itemBuilder: (ctx, i) => Text(
                _history[i],
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ),
        // Display area
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
                  Text(
                    _expression,
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.grey[400] : Colors.grey[500],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    _display,
                    style: TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        // Buttons
        Expanded(
          flex: 5,
          child: Column(
            children: buttons.map((row) {
              return Expanded(
                child: Row(
                  children: row.map((label) {
                    if (label.isEmpty) return const Expanded(child: SizedBox());
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(2),
                        child: ElevatedButton(
                          onPressed: () => _onButtonPressed(label),
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
                            child: Text(
                              label,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
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

  Color? _getButtonColor(String btn, bool isDark) {
    if ('+-×÷'.contains(btn)) return AppColors.primary;
    if (btn == '=') return AppColors.success;
    if (btn == 'C' || btn == '⌫') return AppColors.danger;
    return isDark ? Colors.grey[850] : Colors.grey[100];
  }

  Color _getButtonTextColor(String btn, bool isDark) {
    if ('+-×÷=C⌫'.contains(btn)) return Colors.white;
    return isDark ? Colors.white : Colors.black87;
  }
}
