// =============================================================================
// Note Counter Pro - GST Calculator
// =============================================================================
// Calculates GST for a given amount.
// Modes: Add GST (base → total), Remove GST (total → base)
// Slabs: 0%, 3%, 5%, 12%, 18%, 28%
// =============================================================================

import 'package:flutter/material.dart';
import '../utils/constants.dart';

class GstCalculator extends StatefulWidget {
  const GstCalculator({super.key});

  @override
  State<GstCalculator> createState() => _GstCalculatorState();
}

class _GstCalculatorState extends State<GstCalculator> {
  final _amountController = TextEditingController();
  double _gstRate = 18;
  bool _addGst = true; // true = add GST, false = remove GST

  double _gstAmount = 0;
  double _baseAmount = 0;
  double _totalAmount = 0;
  bool _calculated = false;

  static const _slabs = [0, 3, 5, 12, 18, 28];

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  void _calculate() {
    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) {
      setState(() => _calculated = false);
      return;
    }

    double baseAmount, gstAmount, totalAmount;
    if (_addGst) {
      // Add GST: amount is base, calculate GST + total
      baseAmount = amount;
      gstAmount = amount * _gstRate / 100;
      totalAmount = baseAmount + gstAmount;
    } else {
      // Remove GST: amount is total, calculate base + GST
      totalAmount = amount;
      baseAmount = amount / (1 + _gstRate / 100);
      gstAmount = totalAmount - baseAmount;
    }

    setState(() {
      _baseAmount = baseAmount;
      _gstAmount = gstAmount;
      _totalAmount = totalAmount;
      _calculated = true;
    });
  }

  String _formatCurrency(double value) {
    return '₹${value.toStringAsFixed(2)}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Mode toggle
          Row(
            children: [
              Expanded(
                child: ChoiceChip(
                  label: const Text('Add GST', textAlign: TextAlign.center),
                  selected: _addGst,
                  onSelected: (_) => setState(() => _addGst = true),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ChoiceChip(
                  label: const Text('Remove GST', textAlign: TextAlign.center),
                  selected: !_addGst,
                  onSelected: (_) => setState(() => _addGst = false),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Amount
          TextField(
            controller: _amountController,
            keyboardType: TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: _addGst ? 'Base Amount (excl. GST)' : 'Total Amount (incl. GST)',
              hintText: 'e.g. 1000',
              prefixText: '₹ ',
              prefixIcon: const Icon(Icons.currency_rupee),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          // GST Slab
          Text(
            'GST Rate',
            style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: _slabs.map((slab) {
              return ChoiceChip(
                label: Text('$slab%'),
                selected: _gstRate == slab.toDouble(),
                onSelected: (_) => setState(() => _gstRate = slab.toDouble()),
                selectedColor: AppColors.primary,
                labelStyle: TextStyle(
                  color: _gstRate == slab.toDouble() ? AppColors.bgDark : null,
                  fontWeight: FontWeight.bold,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          // Calculate
          FilledButton.icon(
            onPressed: _calculate,
            icon: const Icon(Icons.calculate),
            label: const Text('Calculate', style: TextStyle(fontWeight: FontWeight.bold)),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.bgDark,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
          const SizedBox(height: 20),
          // Results
          if (_calculated) ...[
            _buildResultCard(
              'GST Amount ($_gstRate%)',
              _formatCurrency(_gstAmount),
              AppColors.danger,
              isDark,
              theme,
              isLarge: true,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildResultCard(
                    'Base Amount',
                    _formatCurrency(_baseAmount),
                    AppColors.info,
                    isDark,
                    theme,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildResultCard(
                    'Total Amount',
                    _formatCurrency(_totalAmount),
                    AppColors.success,
                    isDark,
                    theme,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildResultCard(
    String label,
    String value,
    Color color,
    bool isDark,
    ThemeData theme, {
    bool isLarge = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: isDark ? Colors.white70 : Colors.black54,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: isLarge ? 24 : 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
