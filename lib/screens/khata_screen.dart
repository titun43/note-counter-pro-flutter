import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/storage_service.dart';
import '../services/contact_picker_service.dart';
import '../models/customer.dart';
import '../utils/constants.dart';
import '../utils/app_localizations.dart';
import 'customer_detail_screen.dart';
import 'customers_screen.dart';

class KhataScreen extends StatefulWidget {
  const KhataScreen({super.key});
  
  @override
  State<KhataScreen> createState() => _KhataScreenState();
}

class _KhataScreenState extends State<KhataScreen> {
  Future<void> _addCustomer() async {
    final loc = context.loc;
    
    final result = await showModalBottomSheet<bool>(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Add Customer',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.contact_phone, color: AppColors.info, size: 32),
              title: Text(loc.t('pickFromContacts')),
              subtitle: Text('Pick from phone contacts'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.pop(context, true),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.person_add, color: AppColors.success, size: 32),
              title: Text(loc.t('manualAdd')),
              subtitle: Text('Enter details manually'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.pop(context, false),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
    
    if (result == true) {
      await _pickFromContacts();
    } else if (result == false) {
      await _manualAdd();
    }
  }
  
  Future<void> _pickFromContacts() async {
    final loc = context.loc;
    try {
      final contact = await ContactPickerService.pickContact();
      
      if (contact != null) {
        final name = contact['name'] ?? '';
        final phone = contact['phone'] ?? '';
        
        if (name.isNotEmpty) {
          final storage = context.read<StorageService>();
          final customer = Customer.create(
            name: name,
            phone: phone.replaceAll(RegExp(r'[^\d+]'), ''),
          );
          await storage.addCustomer(customer);
          
          if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('${loc.t('saved')} $name'),
                backgroundColor: AppColors.success,
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }
  
  Future<void> _showCustomerOptions(Customer customer) async {
    final loc = context.loc;
    
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              customer.name,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.edit, color: AppColors.info),
              title: Text(loc.t('edit')),
              onTap: () => Navigator.pop(context, 'edit'),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.delete, color: AppColors.danger),
              title: Text(loc.t('delete')),
              onTap: () => Navigator.pop(context, 'delete'),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
    
    if (action == 'edit') {
      await _editCustomer(customer);
    } else if (action == 'delete') {
      await _deleteCustomer(customer);
    }
  }
  
  Future<void> _editCustomer(Customer customer) async {
    final loc = context.loc;
    final nameController = TextEditingController(text: customer.name);
    final phoneController = TextEditingController(text: customer.phone ?? '');
    final emailController = TextEditingController(text: customer.email ?? '');
    final addressController = TextEditingController(text: customer.address ?? '');
    
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.edit, color: AppColors.info),
            const SizedBox(width: 8),
            Text(loc.t('edit')),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: '${loc.t('name')} *',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.person),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneController,
                decoration: InputDecoration(
                  labelText: loc.t('phone'),
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.phone),
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: emailController,
                decoration: InputDecoration(
                  labelText: loc.t('email'),
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.email),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: addressController,
                decoration: InputDecoration(
                  labelText: loc.t('address'),
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.location_on),
                ),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(loc.t('cancel')),
          ),
          FilledButton(
            onPressed: () {
              if (nameController.text.trim().isEmpty) return;
              Navigator.pop(context, true);
            },
            child: Text(loc.t('save')),
          ),
        ],
      ),
    );
    
    if (result == true) {
      final storage = context.read<StorageService>();
      final updated = customer.copyWith(
        name: nameController.text.trim(),
        phone: phoneController.text.trim(),
        email: emailController.text.trim(),
        address: addressController.text.trim(),
        updatedAt: DateTime.now(),
      );
      await storage.updateCustomer(updated);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${loc.t('saved')} ${nameController.text}'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    }
    
    nameController.dispose();
    phoneController.dispose();
    emailController.dispose();
    addressController.dispose();
  }
  
  Future<void> _deleteCustomer(Customer customer) async {
    final loc = context.loc;
    
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.delete, color: AppColors.danger),
            const SizedBox(width: 8),
            Text(loc.t('delete')),
          ],
        ),
        content: Text('Delete "${customer.name}"? This will also delete all related transactions.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(loc.t('cancel')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(context, true),
            child: Text(loc.t('delete')),
          ),
        ],
      ),
    );
    
    if (result == true) {
      final storage = context.read<StorageService>();
      
      // Delete all entries related to this customer
      final customerEntries = storage.entries.where((e) => e.customerId == customer.id).toList();
      for (final entry in customerEntries) {
        await storage.deleteEntry(entry.id);
      }
      
      // Delete the customer
      await storage.deleteCustomer(customer.id);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${customer.name} ${loc.t('delete')}'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }
  
  Future<void> _manualAdd() async {
    final loc = context.loc;
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final emailController = TextEditingController();
    final addressController = TextEditingController();
    
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.person_add, color: AppColors.primary),
            const SizedBox(width: 8),
            Text('Add Customer'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: '${loc.t('name')} *',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.person),
                ),
                autofocus: true,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneController,
                decoration: InputDecoration(
                  labelText: loc.t('phone'),
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.phone),
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: emailController,
                decoration: InputDecoration(
                  labelText: loc.t('email'),
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.email),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: addressController,
                decoration: InputDecoration(
                  labelText: loc.t('address'),
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.location_on),
                ),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(loc.t('cancel')),
          ),
          FilledButton(
            onPressed: () {
              if (nameController.text.trim().isEmpty) return;
              Navigator.pop(context, true);
            },
            child: Text(loc.t('save')),
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
        address: addressController.text.trim(),
      );
      await storage.addCustomer(customer);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${loc.t('saved')} ${nameController.text}'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    }
    
    nameController.dispose();
    phoneController.dispose();
    emailController.dispose();
    addressController.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
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
        title: Text('${loc.t('khata')} (Lend/Borrow)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.people),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CustomersScreen()),
              );
            },
            tooltip: loc.t('customers'),
          ),
          IconButton(
            icon: const Icon(Icons.person_add),
            onPressed: _addCustomer,
            tooltip: loc.t('addCustomer'),
          ),
        ],
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
                              loc.t('toGive'),
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
                          loc.t('youWillPay'),
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
                              loc.t('toTake'),
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
                          loc.t('youWillReceive'),
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
                  loc.t('pendingEntries'),
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
                          loc.t('noPendingEntries'),
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: _addCustomer,
                          icon: const Icon(Icons.person_add),
                          label: Text(loc.t('addCustomer')),
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
                          onLongPress: () => _showCustomerOptions(customer),
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
                                        isPositive ? loc.t('youWillPay') : loc.t('youWillReceive'),
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addCustomer,
        icon: const Icon(Icons.person_add),
        label: Text(loc.t('addCustomer')),
      ),
    );
  }
}
