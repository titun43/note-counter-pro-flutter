import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/storage_service.dart';
import '../models/bill.dart';
import '../utils/constants.dart';
import '../utils/app_localizations.dart';
import '../widgets/banner_ad_widget.dart';

class BillsScreen extends StatefulWidget {
  const BillsScreen({super.key});
  
  @override
  State<BillsScreen> createState() => _BillsScreenState();
}

class _BillsScreenState extends State<BillsScreen> {
  Future<void> _createBill() async {
    final storage = context.read<StorageService>();
    final bill = Bill.create(
      billNumber: storage.nextBillNumber,
      items: [
        BillItem(name: 'Item 1', quantity: 1, price: 0),
      ],
      currency: storage.defaultCurrency,
    );
    await storage.addBill(bill);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Bill ${bill.billNumber} created'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(title: Text(loc.t('bills'))),
      body: Column(
        children: [
          Expanded(
            child: Consumer<StorageService>(
              builder: (context, storage, child) {
                final bills = storage.bills;
          
          if (bills.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.receipt_long_outlined,
                    size: 64,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    loc.t('noBills'),
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            );
          }
          
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: bills.length,
            itemBuilder: (context, index) {
              final bill = bills[index];
              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppColors.primary,
                    child: const Icon(Icons.receipt, color: AppColors.bgDark),
                  ),
                  title: Text(bill.billNumber),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (bill.customerName != null)
                        Text(bill.customerName!),
                      Text(
                        '${bill.date.day}/${bill.date.month}/${bill.date.year}',
                      ),
                    ],
                  ),
                  trailing: Text(
                    '₹${bill.total.toStringAsFixed(2)}',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryDark,
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
          ),
          const BannerAdWidget(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createBill,
        child: const Icon(Icons.add),
      ),
    );
  }
}
