import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/storage_service.dart';
import '../models/customer.dart';
import '../models/entry.dart';
import '../utils/constants.dart';

class CustomerDetailScreen extends StatefulWidget {
  final String customerId;
  
  const CustomerDetailScreen({super.key, required this.customerId});
  
  @override
  State<CustomerDetailScreen> createState() => _CustomerDetailScreenState();
}

class _CustomerDetailScreenState extends State<CustomerDetailScreen> {
  Customer? _customer;
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      setState(() {
        _customer = context.read<StorageService>().getCustomer(widget.customerId);
      });
    });
  }
  
  List<Entry> get _customerEntries {
    final storage = context.read<StorageService>();
    return storage.entries
        .where((e) => e.customerId == widget.customerId)
        .toList();
  }
  
  Future<void> _addTransaction(bool isCredit) async {
    final amountController = TextEditingController();
    final notesController = TextEditingController();
    
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isCredit ? 'Add Credit (Give)' : 'Add Debit (Take)'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: amountController,
              decoration: const InputDecoration(
                labelText: 'Amount *',
                prefixText: '₹ ',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              autofocus: true,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: notesController,
              decoration: const InputDecoration(
                labelText: 'Notes',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (amountController.text.trim().isEmpty) return;
              Navigator.pop(context, true);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    
    if (result == true && _customer != null) {
      final amount = double.parse(amountController.text.trim());
      final storage = context.read<StorageService>();
      
      if (isCredit) {
        _customer!.totalCredit += amount;
      } else {
        _customer!.totalDebit += amount;
      }
      
      await storage.updateCustomer(_customer!);
      
      final entry = Entry.create(
        type: isCredit ? 'cash_out' : 'cash_in',
        amount: amount,
        currency: storage.defaultCurrency,
        customerId: _customer!.id,
        customerName: _customer!.name,
        notes: notesController.text.trim(),
        category: isCredit ? 'credit' : 'debit',
      );
      await storage.addEntry(entry);
      
      setState(() {
        _customer = storage.getCustomer(widget.customerId);
      });
    }
    
    amountController.dispose();
    notesController.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    if (_customer == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    
    final balance = _customer!.balance;
    final entries = _customerEntries;
    
    return Scaffold(
      appBar: AppBar(
        title: Text(_customer!.name),
      ),
      body: Column(
        children: [
          // Balance card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: balance >= 0
                    ? [AppColors.success, AppColors.success.withOpacity(0.7)]
                    : [AppColors.danger, AppColors.danger.withOpacity(0.7)],
              ),
            ),
            child: Column(
              children: [
                Text(
                  'Balance',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '₹ ${balance.abs().toStringAsFixed(2)}',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  balance >= 0 ? '(You will give)' : '(You will take)',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.white.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
          
          // Summary
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          const Text('Total Credit'),
                          const SizedBox(height: 4),
                          Text(
                            '₹${_customer!.totalCredit.toStringAsFixed(2)}',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: AppColors.success,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          const Text('Total Debit'),
                          const SizedBox(height: 4),
                          Text(
                            '₹${_customer!.totalDebit.toStringAsFixed(2)}',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: AppColors.danger,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Transaction history
          Expanded(
            child: entries.isEmpty
                ? Center(
                    child: Text(
                      'No transactions yet',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: entries.length,
                    itemBuilder: (context, index) {
                      final entry = entries[index];
                      final isCredit = entry.category == 'credit';
                      
                      return Card(
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: isCredit
                                ? AppColors.success
                                : AppColors.danger,
                            child: Icon(
                              isCredit ? Icons.arrow_upward : Icons.arrow_downward,
                              color: Colors.white,
                            ),
                          ),
                          title: Text('₹${entry.amount.toStringAsFixed(2)}'),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isCredit ? 'Credit (Given)' : 'Debit (Taken)',
                                style: TextStyle(
                                  color: isCredit
                                      ? AppColors.success
                                      : AppColors.danger,
                                ),
                              ),
                              if (entry.notes != null && entry.notes!.isNotEmpty)
                                Text(entry.notes!),
                              Text(
                                '${entry.date.day}/${entry.date.month}/${entry.date.year}',
                                style: theme.textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.small(
            heroTag: 'credit',
            onPressed: () => _addTransaction(true),
            backgroundColor: AppColors.success,
            child: const Icon(Icons.add, color: Colors.white),
            tooltip: 'Add Credit',
          ),
          const SizedBox(width: 8),
          FloatingActionButton.small(
            heroTag: 'debit',
            onPressed: () => _addTransaction(false),
            backgroundColor: AppColors.danger,
            child: const Icon(Icons.remove, color: Colors.white),
            tooltip: 'Add Debit',
          ),
        ],
      ),
    );
  }
}
