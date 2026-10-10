import 'package:flutter/material.dart';
import '../utils/constants.dart';

class CalculatorScreen extends StatefulWidget {
  final double? initialValue;
  final String currencyCode;
  
  const CalculatorScreen({
    super.key,
    this.initialValue,
    this.currencyCode = 'INR',
  });
  
  @override
  State<CalculatorScreen> createState() => _CalculatorScreenState();
}

class _CalculatorScreenState extends State<CalculatorScreen> {
  String _display = '0';
  String _expression = '';
  final List<String> _history = [];
  bool _showHistory = false;
  
  String get _currencySymbol => AppConstants.getCurrencySymbol(widget.currencyCode);
  
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
  
  String _formatResult(double value) {
    if (value == value.toInt()) {
      return value.toInt().toString();
    }
    return value.toStringAsFixed(2);
  }
  
  double _evaluate(String expr) {
    expr = expr.replaceAll('×', '*').replaceAll('÷', '/');
    final sanitized = expr.replaceAll(RegExp(r'[^0-9+\-*/.]'), '');
    final tokens = _tokenize(sanitized);
    return _parseExpression(tokens);
  }
  
  List<String> _tokenize(String expr) {
    final tokens = <String>[];
    var current = '';
    for (final char in expr.split('')) {
      if ('+-*/'.contains(char)) {
        if (current.isNotEmpty) {
          tokens.add(current);
          current = '';
        }
        tokens.add(char);
      } else {
        current += char;
      }
    }
    if (current.isNotEmpty) tokens.add(current);
    return tokens;
  }
  
  double _parseExpression(List<String> tokens) {
    if (tokens.isEmpty) return 0;
    
    var i = 0;
    while (i < tokens.length) {
      if (tokens[i] == '*' || tokens[i] == '/') {
        final left = double.parse(tokens[i - 1]);
        final right = double.parse(tokens[i + 1]);
        final result = tokens[i] == '*' ? left * right : left / right;
        tokens[i - 1] = result.toString();
        tokens.removeAt(i);
        tokens.removeAt(i);
      } else {
        i++;
      }
    }
    
    var result = double.parse(tokens[0]);
    for (var j = 1; j < tokens.length; j += 2) {
      final op = tokens[j];
      final num = double.parse(tokens[j + 1]);
      if (op == '+') {
        result += num;
      } else if (op == '-') {
        result -= num;
      }
    }
    
    return result;
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
    
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Top bar: initial value + history button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  if (widget.initialValue != null && widget.initialValue! > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.info.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.download, color: AppColors.info, size: 16),
                          const SizedBox(width: 6),
                          Text(
                            '$_currencySymbol${widget.initialValue!.toStringAsFixed(2)}',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: AppColors.info,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(
                      _showHistory ? Icons.history_toggle_off : Icons.history,
                      color: AppColors.info,
                    ),
                    onPressed: () {
                      setState(() {
                        _showHistory = !_showHistory;
                      });
                    },
                    tooltip: 'History',
                  ),
                ],
              ),
            ),
            
            // History panel (collapsible)
            if (_showHistory)
              Container(
                height: 120,
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.bgCardDark : Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.info.withOpacity(0.3)),
                ),
                child: _history.isEmpty
                    ? Center(
                        child: Text(
                          'No history yet',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _history.length,
                        itemBuilder: (context, index) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Text(
                              _history[index],
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: AppColors.textSecondary,
                              ),
                              textAlign: TextAlign.end,
                            ),
                          );
                        },
                      ),
              ),
            
            // Display
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(24),
                alignment: Alignment.bottomRight,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (_expression.isNotEmpty && _expression != _display)
                      Text(
                        _expression,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          _currencySymbol,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _display,
                          style: theme.textTheme.displayMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            
            // Buttons
            for (final row in buttons)
              Expanded(
                child: Row(
                  children: [
                    for (final btn in row)
                      if (btn.isNotEmpty)
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: FilledButton(
                              onPressed: () => _onButtonPressed(btn),
                              style: FilledButton.styleFrom(
                                backgroundColor: _getButtonColor(btn),
                                foregroundColor: _getButtonTextColor(btn),
                                padding: const EdgeInsets.all(16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Text(
                                btn,
                                style: const TextStyle(fontSize: 24),
                              ),
                            ),
                          ),
                        ),
                    if (row.last.isEmpty) const Spacer(),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
  
  Color _getButtonColor(String btn) {
    if ('+-×÷'.contains(btn)) return AppColors.primary;
    if (btn == '=') return AppColors.success;
    if (btn == 'C' || btn == '⌫') return AppColors.danger;
    return Theme.of(context).colorScheme.surface;
  }
  
  Color _getButtonTextColor(String btn) {
    if ('+-×÷=C⌫'.contains(btn)) return Colors.white;
    return Theme.of(context).colorScheme.onSurface;
  }
}
