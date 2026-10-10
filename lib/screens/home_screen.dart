import 'package:flutter/material.dart';
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
  final Map<int, int> _denominationCounts = {};
  String _transactionType = 'Payable'; // 'Payable' or 'Receivable'
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
    });
  }
  
  @override
  void dispose() {
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
  
  double get _cashTotal {
    double total = 0;
    _denominationCounts.forEach((value, count) {
      total += value * count;
    });
    return total;
  }
  
  double get _otherAmount {
    return double.tryParse(_otherAmountController.text) ?? 0;
  }
  
  double get _onlineAmount {
    return double.tryParse(_onlineAmountController.text) ?? 0;
  }
  
  double get _grandTotal {
    return _cashTotal + _otherAmount + _onlineAmount;
  }
  
  int get _totalNotes {
    return _denominationCounts.values.fold(0, (sum, count) => sum + count);
  }
  
  void _incrementCount(int value) {
    setState(() {
      _denominationCounts[value] = (_denominationCounts[value] ?? 0) + 1;
    });
  }
  
  void _decrementCount(int value) {
    setState(() {
      final current = _denominationCounts[value] ?? 0;
      if (current > 0) {
        _denominationCounts[value] = current - 1;
        if (_denominationCounts[value] == 0) {
          _denominationCounts.remove(value);
        }
      }
    });
  }
  
  void _setCount(int value, int count) {
    setState(() {
      if (count <= 0) {
        _denominationCounts.remove(value);
      } else {
        _denominationCounts[value] = count;
      }
    });
  }
  
  void _reset() {
    setState(() {
      _denominationCounts.clear();
      _targetAmountController.clear();
      _otherAmountController.clear();
      _onlineAmountController.clear();
    });
  }
  
  void _changeCurrency(String? currencyCode) {
    if (currencyCode == null || currencyCode == _selectedCurrency) return;
    setState(() {
      _selectedCurrency = currencyCode;
      _denominationCounts.clear();
      // Save to storage
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
    _denominationCounts.forEach((value, count) {
      denominationMap[value.toString()] = count;
    });
    
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
        builder: (_) => CalculatorScreen(initialValue: _grandTotal),
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Note Counter Pro'),
        actions: [
          IconButton(
            icon: const Icon(Icons.cleaning_services),
            onPressed: _reset,
            tooltip: 'Reset',
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'upi') {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const UpiQrScreen()),
                );
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'upi',
                child: ListTile(
                  leading: Icon(Icons.qr_code),
                  title: Text('UPI QR Code'),
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // === TOP: Currency selector + Summary ===
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: isDark ? AppColors.bgCardDark : AppColors.bgCard,
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedCurrency,
                    decoration: const InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      border: OutlineInputBorder(),
                    ),
                    items: AppConstants.currencies.map((currency) {
                      return DropdownMenuItem<String>(
                        value: currency['code'],
                        child: Text('${currency['code']} - ${currency['name']}'),
                      );
                    }).toList(),
                    onChanged: _changeCurrency,
                  ),
                ),
                const SizedBox(width: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Column(
                      children: [
                        Text(
                          '$_totalNotes',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                        Text(
                          'Notes',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Card(
                  color: AppColors.primary,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Column(
                      children: [
                        Text(
                          '$_currencySymbol${_grandTotal.toStringAsFixed(0)}',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.bgDark,
                          ),
                        ),
                        Text(
                          'Total',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.bgDark,
                          ),
                        ),
                      ],
                    ),
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
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
            ),
          ),
          
          // === DENOMINATION LIST (vertical, scrollable) ===
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              itemCount: _denominations.length,
              itemBuilder: (context, index) {
                final denom = _denominations[index];
                final value = denom['value'] as int;
                final name = denom['name'] as String;
                final color = Color(denom['color'] as int);
                final count = _denominationCounts[value] ?? 0;
                final subtotal = value * count;
                
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    child: Row(
                      children: [
                        // Denomination button (colored)
                        Container(
                          width: 72,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(8),
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
                        // Count display
                        Container(
                          width: 50,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.bgDarker : Colors.grey[200],
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '$count',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
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
                  tooltip: 'Send to Calculator',
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
