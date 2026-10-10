import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/storage_service.dart';
import '../utils/constants.dart';
import 'customer_detail_screen.dart';

class KhataScreen extends StatelessWidget {
  const KhataScreen({super.key});
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final storage = context.watch<StorageService>();
    final customers = storage.customers.where((c) => c.balance != 0).toList();
    
    final totalToGive = customers
        .where((c) => c.balance > 0)
        .fold(0.0, (sum, c) => sum + c.balance);
    
    final totalToTake = customers
        .where((c) => c.balance < 0)
        .fold(0.0, (sum, c) => sum + c.balance.abs());
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Khata (Lend/Borrow)'),
      ),
      body: Column(
        children: [
          // Summary cards
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.danger,
                          AppColors.danger.withOpacity(0.7),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.danger.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.arrow_upward, color: Colors.white, size: 20),
                            const SizedBox(width: 6),
                            Text(
                              'To Give',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '₹${totalToGive.toStringAsFixed(2)}',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'You will pay',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.success,
                          AppColors.success.withOpacity(0.7),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.success.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.arrow_downward, color: Colors.white, size: 20),
                            const SizedBox(width: 6),
                            Text(
                              'To Take',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '₹${totalToTake.toStringAsFixed(2)}',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'You will receive',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // List header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Pending Entries',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${customers.length}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
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
                          size: 80,
                          color: AppColors.textSecondary.withOpacity(0.5),
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
                      final isPositive = balance > 0;
                      
                      return Card(
                        elevation: 3,
                        margin: const EdgeInsets.only(bottom: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
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
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: isPositive
                                        ? AppColors.danger.withOpacity(0.15)
                                        : AppColors.success.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(24),
                                  ),
                                  child: Icon(
                                    isPositive ? Icons.arrow_upward : Icons.arrow_downward,
                                    color: isPositive ? AppColors.danger : AppColors.success,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        customer.name,
                                        style: theme.textTheme.titleMedium?.copyWith(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        isPositive ? 'You will give' : 'You will take',
                                        style: theme.textTheme.bodySmall?.copyWith(
                                          color: isPositive
                                              ? AppColors.danger
                                              : AppColors.success,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  '₹${balance.abs().toStringAsFixed(2)}',
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: isPositive
                                        ? AppColors.danger
                                        : AppColors.success,
                                  ),
                                ),
                              ],
                            ),
                          ),
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
