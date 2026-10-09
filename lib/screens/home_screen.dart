import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/storage_service.dart';
import '../utils/constants.dart';
import '../models/entry.dart';
import 'upi_qr_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _selectedCurrency = 'INR';
  final Map<int, int> _denominationCounts = {};
  
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
  
  List<Map<String, dynamic>> get _denominations {
    return AppConstants.inrDenominations;
  }
  
  double get _total {
    double total = 0;
    _denominationCounts.forEach((value, count) {
      total += value * count;
    });
    return total;
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
  
  void _reset() {
    setState(() {
      _denominationCounts.clear();
    });
  }
  
  Future<void> _saveEntry() async {
    if (_totalNotes == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add some notes first!')),
      );
      return;
    }
    
    final storage = context.read<StorageService>();
    final denominationMap = <String, int>{};
    _denominationCounts.forEach((value, count) {
      denominationMap[value.toString()] = count;
    });
    
    final entry = Entry.create(
      type: 'counter',
      amount: _total,
      currency: _selectedCurrency,
      notes: 'Counted $_totalNotes notes',
      denominationCounts: denominationMap,
    );
    
    await storage.addEntry(entry);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Saved! Total: ₹${_total.toStringAsFixed(2)}'),
          backgroundColor: AppColors.success,
        ),
      );
      _reset();
    }
  }
  
  String get _currencySymbol {
    final currency = AppConstants.currencies.firstWhere(
      (c) => c['code'] == _selectedCurrency,
      orElse: () => {'symbol': '₹'},
    );
    return currency['symbol']!;
  }
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Note Counter Pro'),
        actions: [
          IconButton(
            icon: const Icon(Icons.cleaning_services),
            onPressed: _reset,
            tooltip: 'Reset',
          ),
          IconButton(
            icon: const Icon(Icons.qr_code),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const UpiQrScreen()),
              );
            },
            tooltip: 'UPI QR',
          ),
        ],
      ),
      body: Column(
        children: [
          // Total Display
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primary, AppColors.primaryDark],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              children: [
                Text(
                  'Total Amount',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.bgDark.withOpacity(0.8),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '$_currencySymbol ${_total.toStringAsFixed(2)}',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    color: AppColors.bgDark,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$_totalNotes notes',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.bgDark.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),
          
          // Denomination Grid
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 1.6,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: _denominations.length,
              itemBuilder: (context, index) {
                final denom = _denominations[index];
                final value = denom['value'] as int;
                final name = denom['name'] as String;
                final count = _denominationCounts[value] ?? 0;
                final subtotal = value * count;
                
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              name,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '× $count',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: AppColors.primaryDark,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '₹$subtotal',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                            Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.remove_circle_outline),
                                  onPressed: count > 0
                                      ? () => _decrementCount(value)
                                      : null,
                                  iconSize: 24,
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.add_circle),
                                  onPressed: () => _incrementCount(value),
                                  color: AppColors.primary,
                                  iconSize: 28,
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          
          // Save Button
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _saveEntry,
                icon: const Icon(Icons.save),
                label: const Text('Save Count'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
