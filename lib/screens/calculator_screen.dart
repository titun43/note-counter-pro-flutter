import 'package:flutter/material.dart';
import '../utils/constants.dart';

class CalculatorScreen extends StatefulWidget {
  const CalculatorScreen({super.key});
  
  @override
  State<CalculatorScreen> createState() => _CalculatorScreenState();
}

class _CalculatorScreenState extends State<CalculatorScreen> {
  String _display = '0';
  String _expression = '';
  final List<String> _history = [];
  
  void _onButtonPressed(String value) {
    setState(() {
      if (value == 'C') {
        _display = '0';
        _expression = '';
      } else if (value == '=') {
        try {
          final result = _evaluate(_expression);
          _history.insert(0, '$_expression = $result');
          _display = result.toString();
          _expression = result.toString();
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
    // Simple evaluation using dart's expression evaluation
    // For production, use a proper expression parser
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
    
    // First pass: multiplication and division
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
    
    // Second pass: addition and subtraction
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
    
    final buttons = [
      ['C', '⌫', '÷', '×'],
      ['7', '8', '9', '-'],
      ['4', '5', '6', '+'],
      ['1', '2', '3', '='],
      ['0', '.', '00', ''],
    ];
    
    return Scaffold(
      appBar: AppBar(title: const Text('Calculator')),
      body: Column(
        children: [
          // History
          if (_history.isNotEmpty)
            Container(
              height: 80,
              padding: const EdgeInsets.all(8),
              child: ListView.builder(
                itemCount: _history.length > 3 ? 3 : _history.length,
                itemBuilder: (context, index) {
                  return Text(
                    _history[index],
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.end,
                  );
                },
              ),
            ),
          
          // Display
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(24),
              alignment: Alignment.bottomRight,
              child: Text(
                _display,
                style: theme.textTheme.displayMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
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
