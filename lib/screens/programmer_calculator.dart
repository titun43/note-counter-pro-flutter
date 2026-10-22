import 'package:flutter/material.dart';
import '../utils/constants.dart';

class ProgrammerCalculator extends StatefulWidget {
  const ProgrammerCalculator({super.key});

  @override
  State<ProgrammerCalculator> createState() => _ProgrammerCalculatorState();
}

class _ProgrammerCalculatorState extends State<ProgrammerCalculator> {
  int _base = 10; // 10=DEC, 16=HEX, 8=OCT, 2=BIN
  String _display = '0';
  String _expression = '';

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
      } else if (value == 'AND' || value == 'OR' || value == 'XOR' || value == 'NOT') {
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
      if (expr.contains(' AND ')) {
        final parts = expr.split(' AND ');
        final a = int.parse(parts[0], radix: _base);
        final b = int.parse(parts[1], radix: _base);
        _display = (a & b).toRadixString(_base).toUpperCase();
      } else if (expr.contains(' OR ')) {
        final parts = expr.split(' OR ');
        final a = int.parse(parts[0], radix: _base);
        final b = int.parse(parts[1], radix: _base);
        _display = (a | b).toRadixString(_base).toUpperCase();
      } else if (expr.contains(' XOR ')) {
        final parts = expr.split(' XOR ');
        final a = int.parse(parts[0], radix: _base);
        final b = int.parse(parts[1], radix: _base);
        _display = (a ^ b).toRadixString(_base).toUpperCase();
      } else if (expr.contains(' NOT ')) {
        final a = int.parse(expr.replaceAll('NOT ', ''), radix: _base);
        _display = (~a).toRadixString(_base).toUpperCase();
      } else {
        final val = int.parse(expr, radix: _base);
        _display = val.toRadixString(_base).toUpperCase();
      }
      _expression = _display;
    } catch (_) {
      _display = 'Error';
    }
  }

  void _changeBase(int base) {
    setState(() {
      try {
        final val = _expression.isNotEmpty ? int.parse(_expression, radix: _base) : 0;
        _base = base;
        _display = val.toRadixString(base).toUpperCase();
        _expression = _display;
      } catch (_) {
        _base = base;
        _display = '0';
        _expression = '';
      }
    });
  }

  String _getOtherBases() {
    try {
      final val = int.parse(_expression.isNotEmpty ? _expression : '0', radix: _base);
      return 'DEC: ${val}\nHEX: ${val.toRadixString(16).toUpperCase()}\n'
             'OCT: ${val.toRadixString(8)}\nBIN: ${val.toRadixString(2)}';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Determine which buttons to show based on base
    List<String> hexDigits = ['A', 'B', 'C', 'D', 'E', 'F'];
    List<String> activeDigits;
    if (_base == 16) {
      activeDigits = ['0','1','2','3','4','5','6','7','8','9','A','B','C','D','E','F'];
    } else if (_base == 10) {
      activeDigits = ['0','1','2','3','4','5','6','7','8','9'];
    } else if (_base == 8) {
      activeDigits = ['0','1','2','3','4','5','6','7'];
    } else {
      activeDigits = ['0','1'];
    }

    return Column(
      children: [
        // Base selector
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            children: [
              _baseButton('DEC', 10),
              _baseButton('HEX', 16),
              _baseButton('OCT', 8),
              _baseButton('BIN', 2),
            ],
          ),
        ),
        // Multi-base display
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          margin: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: (isDark ? Colors.grey[850] : Colors.grey[100]),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            _getOtherBases(),
            style: TextStyle(fontSize: 11, fontFamily: 'monospace', color: Colors.grey[600]),
          ),
        ),
        // Main display
        Expanded(
          flex: 1,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
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
        // Bitwise ops
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: ['AND', 'OR', 'XOR', 'NOT', '<<', '>>'].map((op) {
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(2),
                  child: ElevatedButton(
                    onPressed: () => _onButton(op),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      backgroundColor: AppColors.info.withOpacity(0.15),
                      foregroundColor: AppColors.info,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(op, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        // Digit buttons
        Expanded(
          flex: 3,
          child: GridView.count(
            crossAxisCount: 4,
            padding: const EdgeInsets.all(4),
            childAspectRatio: 1.5,
            children: [
              'C', '⌫', '', '=',
              ...activeDigits,
            ].map((label) {
              if (label.isEmpty) return const SizedBox();
              return Padding(
                padding: const EdgeInsets.all(2),
                child: ElevatedButton(
                  onPressed: () => _onButton(label),
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.zero,
                    backgroundColor: _btnColor(label, isDark),
                    foregroundColor: _btnTextColor(label),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(label, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _baseButton(String label, int base) {
    final active = _base == base;
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: ElevatedButton(
          onPressed: () => _changeBase(base),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 8),
            backgroundColor: active ? AppColors.primary : null,
            foregroundColor: active ? Colors.white : null,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          ),
          child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }

  Color? _btnColor(String label, bool isDark) {
    if (label == 'C' || label == '⌫') return Colors.red.withOpacity(0.2);
    if (label == '=') return AppColors.primary;
    return isDark ? Colors.grey[850] : Colors.grey[100];
  }

  Color _btnTextColor(String label) {
    if (label == '=') return Colors.white;
    if (label == 'C' || label == '⌫') return Colors.red;
    return Colors.black87;
  }
}
