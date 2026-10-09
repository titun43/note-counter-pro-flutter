import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/storage_service.dart';
import '../models/customer.dart';
import '../utils/constants.dart';
import 'customer_detail_screen.dart';

class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key});
  
  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  
  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
  
  List<Customer> get _filteredCustomers {
    final storage = context.read<StorageService>();
    final customers = storage.customers;
    if (_searchQuery.isEmpty) return customers;
    return customers
        .where((c) => c.name.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();
  }
  
  Future<void> _showAddCustomerDialog() async {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final emailController = TextEditingController();
    
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Customer'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Name *',
                  border: OutlineInputBorder(),
                ),
                autofocus: true,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneController,
                decoration: const InputDecoration(
                  labelText: 'Phone',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (nameController.text.trim().isEmpty) return;
              Navigator.pop(context, true);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    
    if (result == true) {
      final storage = context.read<StorageService>();
      final customer = Customer.create(
        name: nameController.text.trim(),
        phone: phoneController.text.trim(),
        email: emailController.text.trim(),
      );
      await storage.addCustomer(customer);
    }
    
    nameController.dispose();
    phoneController.dispose();
    emailController.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Customers'),
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search customers...',
                prefixIcon: const Icon(Icons.search),
                border: const OutlineInputBorder(),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
              ),
              onChanged: (value) {
                setState(() => _searchQuery = value);
              },
            ),
          ),
          
          // Customer list
          Expanded(
            child: Consumer<StorageService>(
              builder: (context, storage, child) {
                final customers = _filteredCustomers;
                
                if (customers.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.people_outline, size: 64, color: AppColors.textSecondary),
                        const SizedBox(height: 16),
                        Text(
                          'No customers yet',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        FilledButton.icon(
                          onPressed: _showAddCustomerDialog,
                          icon: const Icon(Icons.add),
                          label: const Text('Add Customer'),
                        ),
                      ],
                    ),
                  );
                }
                
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: customers.length,
                  itemBuilder: (context, index) {
                    final customer = customers[index];
                    final balance = customer.balance;
                    final hasBalance = balance != 0;
                    
                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppColors.primary,
                          child: Text(
                            customer.name.isNotEmpty
                                ? customer.name[0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                              color: AppColors.bgDark,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text(customer.name),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (customer.phone != null && customer.phone!.isNotEmpty)
                              Text(customer.phone!),
                            if (hasBalance)
                              Text(
                                'Balance: ₹${balance.abs().toStringAsFixed(2)} ${balance > 0 ? '(Credit)' : '(Debit)'}',
                                style: TextStyle(
                                  color: balance > 0
                                      ? AppColors.success
                                      : AppColors.danger,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                          ],
                        ),
                        trailing: const Icon(Icons.chevron_right),
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
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddCustomerDialog,
        child: const Icon(Icons.person_add),
      ),
    );
  }
}
