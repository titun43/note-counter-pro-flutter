import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/storage_service.dart';
import '../models/customer.dart';
import '../models/entry.dart';
import '../utils/constants.dart';
import '../utils/app_localizations.dart';

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
    final loc = context.loc;
    final amountController = TextEditingController();
    final notesController = TextEditingController();
    
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isCredit ? loc.t('addCredit') : loc.t('addDebit')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: amountController,
              decoration: InputDecoration(
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
              decoration: InputDecoration(
                labelText: loc.t('notes_field'),
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(loc.t('cancel')),
          ),
          FilledButton(
            onPressed: () {
              if (amountController.text.trim().isEmpty) return;
              Navigator.pop(context, true);
            },
            child: Text(loc.t('save')),
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
  
  Future<void> _showEntryOptions(Entry entry) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '₹${entry.amount.toStringAsFixed(2)}',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.edit, color: AppColors.info),
              title: const Text('Edit'),
              onTap: () => Navigator.pop(context, 'edit'),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.delete, color: AppColors.danger),
              title: const Text('Delete'),
              onTap: () => Navigator.pop(context, 'delete'),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
    
    if (action == 'edit') {
      await _editEntry(entry);
    } else if (action == 'delete') {
      await _deleteEntry(entry);
    }
  }
  
  Future<void> _editEntry(Entry entry) async {
    final loc = context.loc;
    final amountController = TextEditingController(text: entry.amount.toString());
    final notesController = TextEditingController(text: entry.notes ?? '');
    final isCredit = entry.category == 'credit';
    
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.edit, color: AppColors.info),
            const SizedBox(width: 8),
            const Text('Edit Transaction'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isCredit ? 'Credit (Given)' : 'Debit (Taken)',
              style: TextStyle(
                color: isCredit ? AppColors.success : AppColors.danger,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: amountController,
              decoration: InputDecoration(
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
              decoration: InputDecoration(
                labelText: loc.t('notes_field'),
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(loc.t('cancel')),
          ),
          FilledButton(
            onPressed: () {
              if (amountController.text.trim().isEmpty) return;
              Navigator.pop(context, true);
            },
            child: Text(loc.t('save')),
          ),
        ],
      ),
    );
    
    if (result == true && _customer != null) {
      final newAmount = double.parse(amountController.text.trim());
      final oldAmount = entry.amount;
      final storage = context.read<StorageService>();
      
      // Update customer totals
      if (isCredit) {
        _customer!.totalCredit = _customer!.totalCredit - oldAmount + newAmount;
      } else {
        _customer!.totalDebit = _customer!.totalDebit - oldAmount + newAmount;
      }
      await storage.updateCustomer(_customer!);
      
      // Update entry
      final updatedEntry = Entry(
        id: entry.id,
        date: entry.date,
        type: entry.type,
        amount: newAmount,
        currency: entry.currency,
        customerId: entry.customerId,
        customerName: entry.customerName,
        notes: notesController.text.trim(),
        denominationCounts: entry.denominationCounts,
        category: entry.category,
        createdAt: entry.createdAt,
      );
      await storage.updateEntry(updatedEntry);
      
      setState(() {
        _customer = storage.getCustomer(widget.customerId);
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Transaction updated'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    }
    
    amountController.dispose();
    notesController.dispose();
  }
  
  Future<void> _deleteEntry(Entry entry) async {
    final loc = context.loc;
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.delete, color: AppColors.danger),
            const SizedBox(width: 8),
            const Text('Delete Transaction'),
          ],
        ),
        content: Text('Delete transaction of ₹${entry.amount.toStringAsFixed(2)}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(loc.t('cancel')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    
    if (result == true && _customer != null) {
      final storage = context.read<StorageService>();
      final isCredit = entry.category == 'credit';
      
      // Update customer totals
      if (isCredit) {
        _customer!.totalCredit -= entry.amount;
      } else {
        _customer!.totalDebit -= entry.amount;
      }
      await storage.updateCustomer(_customer!);
      
      // Delete entry
      await storage.deleteEntry(entry.id);
      
      setState(() {
        _customer = storage.getCustomer(widget.customerId);
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Transaction deleted'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
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
                  loc.t('balance'),
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
                          Text(loc.t('totalCredit')),
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
                          Text(loc.t('totalDebit')),
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
                      loc.t('noTransactions'),
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
                          onLongPress: () => _showEntryOptions(entry),
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
