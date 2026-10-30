// =============================================================================
// Note Counter Pro - EMI Calculator
// =============================================================================
// Calculates monthly EMI for a loan.
// Inputs: Loan Amount, Interest Rate (% per annum), Tenure (months/years)
// Outputs: Monthly EMI, Total Interest, Total Payment
// =============================================================================

import 'package:flutter/material.dart';
import '../utils/constants.dart';
import '../utils/app_localizations.dart';

class EmiCalculator extends StatefulWidget {
  const EmiCalculator({super.key});

  @override
  State<EmiCalculator> createState() => _EmiCalculatorState();
}

class _EmiCalculatorState extends State<EmiCalculator> {
  final _amountController = TextEditingController();
  final _rateController = TextEditingController();
  final _tenureController = TextEditingController();
  bool _tenureInYears = false;

  double _emi = 0;
  double _totalInterest = 0;
  double _totalPayment = 0;
  bool _calculated = false;

  @override
  void dispose() {
    _amountController.dispose();
    _rateController.dispose();
    _tenureController.dispose();
    super.dispose();
  }

  void _calculate() {
    final amount = double.tryParse(_amountController.text.trim());
    final rate = double.tryParse(_rateController.text.trim());
    final tenure = double.tryParse(_tenureController.text.trim());

    if (amount == null || amount <= 0 || rate == null || rate < 0 || tenure == null || tenure <= 0) {
      setState(() => _calculated = false);
      return;
    }

    final months = _tenureInYears ? tenure * 12 : tenure;
    final monthlyRate = rate / 12 / 100;

    double emi;
    if (monthlyRate == 0) {
      emi = amount / months;
    } else {
      emi = amount * monthlyRate * (1 + monthlyRate).pow(months.toInt()) /
          ((1 + monthlyRate).pow(months.toInt()) - 1);
    }

    final totalPayment = emi * months;
    final totalInterest = totalPayment - amount;

    setState(() {
      _emi = emi;
      _totalInterest = totalInterest;
      _totalPayment = totalPayment;
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
    final loc = context.loc;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildInputField(
            controller: _amountController,
            label: loc.t('emiLoanAmount'),
            hint: 'e.g. 500000',
            prefix: '₹',
            icon: Icons.account_balance_wallet,
          ),
          const SizedBox(height: 12),
          _buildInputField(
            controller: _rateController,
            label: loc.t('emiInterestRate'),
            hint: 'e.g. 8.5',
            suffix: '%',
            icon: Icons.percent,
          ),
          const SizedBox(height: 12),
          _buildInputField(
            controller: _tenureController,
            label: '${loc.t('emiTenure')} (${_tenureInYears ? loc.t('emiYears') : loc.t('emiMonths')})',
            hint: _tenureInYears ? 'e.g. 5' : 'e.g. 60',
            icon: Icons.schedule,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              ChoiceChip(
                label: Text(loc.t('emiMonths')),
                selected: !_tenureInYears,
                onSelected: (_) => setState(() => _tenureInYears = false),
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: Text(loc.t('emiYears')),
                selected: _tenureInYears,
                onSelected: (_) => setState(() => _tenureInYears = true),
              ),
            ],
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _calculate,
            icon: const Icon(Icons.calculate),
            label: Text(loc.t('emiCalculate'), style: const TextStyle(fontWeight: FontWeight.bold)),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.bgDark,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
          const SizedBox(height: 20),
          if (_calculated) ...[
            _buildResultCard(
              loc.t('emiMonthlyEmi'),
              _formatCurrency(_emi),
              AppColors.primary,
              isDark,
              theme,
              isLarge: true,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildResultCard(
                    loc.t('emiTotalInterest'),
                    _formatCurrency(_totalInterest),
                    AppColors.danger,
                    isDark,
                    theme,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildResultCard(
                    loc.t('emiTotalPayment'),
                    _formatCurrency(_totalPayment),
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

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required String hint,
    String? prefix,
    String? suffix,
    required IconData icon,
  }) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon),
        prefixText: prefix,
        suffixText: suffix,
        border: const OutlineInputBorder(),
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

extension on num {
  double pow(int exponent) {
    double result = 1;
    for (int i = 0; i < exponent; i++) {
      result *= this.toDouble();
    }
    return result;
  }
}
