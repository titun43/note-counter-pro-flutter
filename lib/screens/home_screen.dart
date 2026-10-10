import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/storage_service.dart';
import '../utils/constants.dart';
import '../models/entry.dart';
import 'calculator_screen.dart';
import 'upi_qr_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _selectedCurrency = 'INR';
  final Map<int, TextEditingController> _countControllers = {};
  String _transactionType = 'Payable';
  final TextEditingController _targetAmountController = TextEditingController();
  final TextEditingController _otherAmountController = TextEditingController();
  final TextEditingController _onlineAmountController = TextEditingController();
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final storage = context.read<StorageService>();
      setState(() {
        _selectedCurrency = storage.defaultCurrency;
      });
      _initCountControllers();
    });
  }
  
  void _initCountControllers() {
    final denoms = AppConstants.getDenominations(_selectedCurrency);
    for (final denom in denoms) {
      final value = denom['value'] as int;
      if (!_countControllers.containsKey(value)) {
        _countControllers[value] = TextEditingController(text: '0');
      }
    }
  }
  
  void _clearCountControllers() {
    for (final controller in _countControllers.values) {
      controller.dispose();
    }
    _countControllers.clear();
  }
  
  @override
  void dispose() {
    _clearCountControllers();
    _targetAmountController.dispose();
    _otherAmountController.dispose();
    _onlineAmountController.dispose();
    super.dispose();
  }
  
  List<Map<String, dynamic>> get _denominations {
    return AppConstants.getDenominations(_selectedCurrency);
  }
  
  String get _currencySymbol {
    return AppConstants.getCurrencySymbol(_selectedCurrency);
  }
  
  int _getCount(int value) {
    final controller = _countControllers[value];
    if (controller == null) return 0;
    return int.tryParse(controller.text) ?? 0;
  }
  
  double get _cashTotal {
    double total = 0;
    for (final denom in _denominations) {
      final value = denom['value'] as int;
      total += value * _getCount(value);
    }
    return total;
  }
  
  double get _otherAmount {
    return double.tryParse(_otherAmountController.text) ?? 0;
  }
  
  double get _onlineAmount {
    return double.tryParse(_onlineAmountController.text) ?? 0;
  }
  
  double get _targetAmount {
    return double.tryParse(_targetAmountController.text) ?? 0;
  }
  
  double get _grandTotal {
    return _cashTotal + _otherAmount + _onlineAmount;
  }
  
  double get _difference {
    return _grandTotal - _targetAmount;
  }
  
  bool get _hasTarget {
    return _targetAmount > 0;
  }
  
  int get _totalNotes {
    int total = 0;
    for (final denom in _denominations) {
      total += _getCount(denom['value'] as int);
    }
    return total;
  }
  
  void _incrementCount(int value) {
    final controller = _countControllers[value];
    if (controller == null) return;
    final current = int.tryParse(controller.text) ?? 0;
    controller.text = '${current + 1}';
    setState(() {});
  }
  
  void _decrementCount(int value) {
    final controller = _countControllers[value];
    if (controller == null) return;
    final current = int.tryParse(controller.text) ?? 0;
    if (current > 0) {
      controller.text = '${current - 1}';
      setState(() {});
    }
  }
  
  void _onCountChanged(int value) {
    setState(() {});
  }
  
  void _reset() {
    for (final controller in _countControllers.values) {
      controller.text = '0';
    }
    _targetAmountController.clear();
    _otherAmountController.clear();
    _onlineAmountController.clear();
    setState(() {});
  }
  
  void _changeCurrency(String? currencyCode) {
    if (currencyCode == null || currencyCode == _selectedCurrency) return;
    setState(() {
      _selectedCurrency = currencyCode;
      _clearCountControllers();
      _initCountControllers();
      context.read<StorageService>().setDefaultCurrency(currencyCode);
    });
  }
  
  Future<void> _saveEntry(bool isCashIn) async {
    if (_grandTotal == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add some amount first!')),
      );
      return;
    }
    
    final storage = context.read<StorageService>();
    final denominationMap = <String, int>{};
    for (final denom in _denominations) {
      final value = denom['value'] as int;
      final count = _getCount(value);
      if (count > 0) {
        denominationMap[value.toString()] = count;
      }
    }
    
    final entry = Entry.create(
      type: isCashIn ? 'cash_in' : 'cash_out',
      amount: _grandTotal,
      currency: _selectedCurrency,
      notes: '$_transactionType - $_totalNotes notes'
          '${_otherAmount > 0 ? ' + Other: $_currencySymbol$_otherAmount' : ''}'
          '${_onlineAmount > 0 ? ' + Online: $_currencySymbol$_onlineAmount' : ''}',
      denominationCounts: denominationMap,
      category: _transactionType.toLowerCase(),
    );
    
    await storage.addEntry(entry);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${isCashIn ? "Cash In" : "Cash Out"}: $_currencySymbol${_grandTotal.toStringAsFixed(2)} saved!'),
          backgroundColor: isCashIn ? AppColors.success : AppColors.danger,
        ),
      );
      _reset();
    }
  }
  
  void _sendToCalculator() {
    if (_grandTotal == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add some amount first!')),
      );
      return;
    }
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CalculatorScreen(
          initialValue: _grandTotal,
          currencyCode: _selectedCurrency,
        ),
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Scaffold(
      body: SafeArea(
        child: Column(
        children: [
          // === TOP: Currency + Notes + Clear + Total (compact, one row) ===
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            color: isDark ? AppColors.bgCardDark : AppColors.bgCard,
            child: Row(
              children: [
                // Currency selector (compact)
                Expanded(
                  flex: 3,
                  child: DropdownButtonFormField<String>(
                    value: _selectedCurrency,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      border: OutlineInputBorder(),
                    ),
                    items: AppConstants.currencies.map((currency) {
                      return DropdownMenuItem<String>(
                        value: currency['code'],
                        child: Text(
                          currency['code']!,
                          style: const TextStyle(fontSize: 13),
                        ),
                      );
                    }).toList(),
                    onChanged: _changeCurrency,
                  ),
                ),
                const SizedBox(width: 4),
                // Notes count
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.bgDarker : Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.textSecondary.withOpacity(0.3)),
                  ),
                  child: Column(
                    children: [
                      Text(
                        '$_totalNotes',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                      Text(
                        'Notes',
                        style: theme.textTheme.bodySmall?.copyWith(fontSize: 10),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                // Clear button (moved here from AppBar)
                IconButton(
                  onPressed: _reset,
                  icon: const Icon(Icons.cleaning_services),
                  color: AppColors.danger,
                  tooltip: 'Clear',
                  iconSize: 22,
                  padding: const EdgeInsets.all(6),
                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                ),
                const SizedBox(width: 4),
                // Grand Total
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      Text(
                        '$_currencySymbol${_grandTotal.toStringAsFixed(0)}',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.bgDark,
                        ),
                      ),
                      Text(
                        'Total',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.bgDark,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // === TRANSACTION TYPE TOGGLE ===
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _transactionType = 'Payable'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: _transactionType == 'Payable'
                            ? AppColors.danger.withOpacity(0.2)
                            : (isDark ? AppColors.bgCardDark : AppColors.bgCard),
                        borderRadius: const BorderRadius.horizontal(left: Radius.circular(8)),
                        border: Border.all(
                          color: _transactionType == 'Payable'
                              ? AppColors.danger
                              : AppColors.textSecondary,
                        ),
                      ),
                      child: Text(
                        'Payable',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: _transactionType == 'Payable'
                              ? AppColors.danger
                              : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _transactionType = 'Receivable'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: _transactionType == 'Receivable'
                            ? AppColors.success.withOpacity(0.2)
                            : (isDark ? AppColors.bgCardDark : AppColors.bgCard),
                        borderRadius: const BorderRadius.horizontal(right: Radius.circular(8)),
                        border: Border.all(
                          color: _transactionType == 'Receivable'
                              ? AppColors.success
                              : AppColors.textSecondary,
                        ),
                      ),
                      child: Text(
                        'Receivable',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: _transactionType == 'Receivable'
                              ? AppColors.success
                              : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // === TARGET AMOUNT ===
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: TextField(
              controller: _targetAmountController,
              decoration: InputDecoration(
                labelText: 'Target Amount',
                prefixText: '$_currencySymbol ',
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
              onChanged: (_) => setState(() {}),
            ),
          ),
          
          // === TARGET vs ACTUAL COMPARISON ===
          if (_hasTarget)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _difference >= 0
                    ? AppColors.success.withOpacity(0.15)
                    : AppColors.danger.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _difference >= 0
                      ? AppColors.success
                      : AppColors.danger,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _difference >= 0 ? Icons.check_circle : Icons.warning,
                    color: _difference >= 0 ? AppColors.success : AppColors.danger,
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _difference >= 0 ? 'Target Reached!' : 'Short of Target',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: _difference >= 0 ? AppColors.success : AppColors.danger,
                          ),
                        ),
                        Text(
                          _difference >= 0
                              ? 'Surplus: $_currencySymbol${_difference.toStringAsFixed(2)}'
                              : 'Need: $_currencySymbol${_difference.abs().toStringAsFixed(2)} more',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: _difference >= 0 ? AppColors.success : AppColors.danger,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Target',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      Text(
                        '$_currencySymbol${_targetAmount.toStringAsFixed(2)}',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Actual: $_currencySymbol${_grandTotal.toStringAsFixed(2)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: _difference >= 0 ? AppColors.success : AppColors.danger,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          
          // === OTHER + ONLINE AMOUNT ===
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _otherAmountController,
                    decoration: InputDecoration(
                      labelText: 'Other Amount',
                      prefixText: '$_currencySymbol ',
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _onlineAmountController,
                    decoration: InputDecoration(
                      labelText: 'Online Amount',
                      prefixText: '$_currencySymbol ',
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
            ),
          ),
          
          // === DENOMINATION LIST (vertical, scrollable, inline editable) ===
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              itemCount: _denominations.length,
              itemBuilder: (context, index) {
                final denom = _denominations[index];
                final value = denom['value'] as int;
                final name = denom['name'] as String;
                final color = Color(denom['color'] as int);
                final count = _getCount(value);
                final subtotal = value * count;
                
                // Ensure controller exists
                if (!_countControllers.containsKey(value)) {
                  _countControllers[value] = TextEditingController(text: '0');
                }
                
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    child: Row(
                      children: [
                        // Denomination button (colored)
                        Container(
                          width: 72,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(
                                color: color.withOpacity(0.4),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Text(
                            name,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Minus button
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline),
                          onPressed: count > 0 ? () => _decrementCount(value) : null,
                          color: AppColors.danger,
                          iconSize: 28,
                        ),
                        // Count display - INLINE EDITABLE TextField
                        // User can tap directly and type number with keyboard
                        // No dialog box needed
                        Container(
                          width: 56,
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.bgDarker : Colors.grey[100],
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: AppColors.primary,
                              width: 1.5,
                            ),
                          ),
                          child: TextField(
                            controller: _countControllers[value],
                            textAlign: TextAlign.center,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                            keyboardType: TextInputType.number,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            decoration: const InputDecoration(
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(vertical: 8),
                              border: InputBorder.none,
                            ),
                            onChanged: (_) => _onCountChanged(value),
                            onTap: () {
                              // Select all text when tapped for easy editing
                              _countControllers[value]!.selection = TextSelection(
                                baseOffset: 0,
                                extentOffset: _countControllers[value]!.text.length,
                              );
                            },
                          ),
                        ),
                        // Plus button
                        IconButton(
                          icon: const Icon(Icons.add_circle),
                          onPressed: () => _incrementCount(value),
                          color: AppColors.success,
                          iconSize: 28,
                        ),
                        const Spacer(),
                        // Subtotal
                        Text(
                          '$_currencySymbol$subtotal',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          
          // === ACTION BUTTONS ROW ===
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? AppColors.bgCardDark : AppColors.bgCard,
              border: Border(
                top: BorderSide(color: AppColors.textSecondary.withOpacity(0.3)),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => _saveEntry(true),
                    icon: const Icon(Icons.south, size: 18),
                    label: const Text('Save In', style: TextStyle(fontSize: 13)),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.success,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _sendToCalculator,
                  icon: const Icon(Icons.calculate),
                  color: AppColors.info,
                  tooltip: 'Calculator',
                ),
                IconButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const UpiQrScreen()),
                    );
                  },
                  icon: const Icon(Icons.qr_code),
                  color: AppColors.primary,
                  tooltip: 'UPI QR',
                ),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => _saveEntry(false),
                    icon: const Icon(Icons.north, size: 18),
                    label: const Text('Save Out', style: TextStyle(fontSize: 13)),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.danger,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // === SUMMARY FOOTER ===
          Container(
            padding: const EdgeInsets.all(12),
            color: isDark ? AppColors.bgDarker : Colors.grey[100],
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _summaryBox(
                        'CASH TOTAL',
                        '$_currencySymbol${_cashTotal.toStringAsFixed(2)}',
                        Colors.amber[100]!,
                        isDark,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: _summaryBox(
                        'OTHER',
                        '$_currencySymbol${_otherAmount.toStringAsFixed(2)}',
                        Colors.cyan[100]!,
                        isDark,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: _summaryBox(
                        'ONLINE',
                        '$_currencySymbol${_onlineAmount.toStringAsFixed(2)}',
                        Colors.purple[100]!,
                        isDark,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'GRAND TOTAL',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '$_currencySymbol ${_grandTotal.toStringAsFixed(2)}',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
        ),
      ),
    );
  }
  
  Widget _summaryBox(String label, String value, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: BoxDecoration(
        color: isDark ? color.withOpacity(0.15) : color,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white70 : Colors.black54,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}
