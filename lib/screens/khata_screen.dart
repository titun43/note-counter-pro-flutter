import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/storage_service.dart';
import '../models/customer.dart';
import '../utils/constants.dart';
import 'customer_detail_screen.dart';

class KhataScreen extends StatefulWidget {
  const KhataScreen({super.key});
  
  @override
  State<KhataScreen> createState() => _KhataScreenState();
}

class _KhataScreenState extends State<KhataScreen> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final storage = context.read<StorageService>();
    final customers = storage.customers
        .where((c) => c.balance != 0)
        .toList();
    
    final totalToGive = customers
        .where((c) => c.balance > 0)
        .fold(0.0, (sum, c) => sum + c.balance);
    
    final totalToTake = customers
        .where((c) => c.balance < 0)
        .fold(0.0, (sum, c) => sum + c.balance.abs());
    
    return Scaffold(
      appBar: AppBar(title: const Text('Khata (Lend/Borrow)')),
      body: Column(
        children: [
          // Summary
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Card(
                    color: AppColors.success.withOpacity(0.1),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          const Text('To Give'),
                          const SizedBox(height: 4),
                          Text(
                            '₹${totalToGive.toStringAsFixed(2)}',
                            style: theme.textTheme.titleLarge?.copyWith(
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
                    color: AppColors.danger.withOpacity(0.1),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          const Text('To Take'),
                          const SizedBox(height: 4),
                          Text(
                            '₹${totalToTake.toStringAsFixed(2)}',
                            style: theme.textTheme.titleLarge?.copyWith(
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
          
          // List
          Expanded(
            child: customers.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.account_balance_wallet_outlined,
                          size: 64,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No pending entries',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Add credit/debit from customer details',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: customers.length,
                    itemBuilder: (context, index) {
                      final customer = customers[index];
                      final balance = customer.balance;
                      
                      return Card(
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: balance > 0
                                ? AppColors.success
                                : AppColors.danger,
                            child: Icon(
                              balance > 0
                                  ? Icons.arrow_upward
                                  : Icons.arrow_downward,
                              color: Colors.white,
                            ),
                          ),
                          title: Text(customer.name),
                          subtitle: Text(
                            balance > 0 ? 'You will give' : 'You will take',
                            style: TextStyle(
                              color: balance > 0
                                  ? AppColors.success
                                  : AppColors.danger,
                            ),
                          ),
                          trailing: Text(
                            '₹${balance.abs().toStringAsFixed(2)}',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: balance > 0
                                  ? AppColors.success
                                  : AppColors.danger,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => CustomerDetailScreen(
                                  customerId: customer.id,
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
