import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/storage_service.dart';
import '../services/contact_picker_service.dart';
import '../models/customer.dart';
import '../models/entry.dart';
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
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String _sortBy = 'recent'; // 'balance', 'name', 'recent', 'date'

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

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
              loc.t('addCustomer'),
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.contact_phone, color: AppColors.info, size: 32),
              title: Text(loc.t('pickFromContacts')),
              subtitle: Text(loc.t('pickFromContacts')),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.pop(context, true),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.person_add, color: AppColors.success, size: 32),
              title: Text(loc.t('manualAdd')),
              subtitle: Text(loc.t('manualAdd')),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.pop(context, false),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );

    if (result == true) {
      // Pick from contacts
      try {
        final contact = await ContactPickerService.pickContact();
        if (contact != null && mounted) {
          await _manualAdd(
            initialName: contact['name'] ?? '',
            initialPhone: contact['phone'] ?? '',
          );
        }
      } catch (e) {
        debugPrint('Contact pick failed: $e');
      }
    } else if (result == false) {
      await _manualAdd();
    }
  }

  Future<void> _manualAdd({
    String? initialName,
    String? initialPhone,
  }) async {
    final loc = context.loc;
    final nameController = TextEditingController(text: initialName ?? '');
    final phoneController = TextEditingController(text: initialPhone ?? '');
    final emailController = TextEditingController();
    final addressController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.person_add, color: AppColors.primary),
            const SizedBox(width: 8),
            Text(loc.t('addCustomer')),
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
        content: Text('${loc.t('delete')} "${customer.name}"?'),
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

      final customerEntries =
          storage.entries.where((e) => e.customerId == customer.id).toList();
      for (final entry in customerEntries) {
        await storage.deleteEntry(entry.id);
      }

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

  /// Open phone dialer
  Future<void> _callCustomer(String? phone) async {
    if (phone == null || phone.isEmpty) return;
    final cleanPhone = phone.replaceAll(RegExp(r'[^\d+]'), '');
    final uri = Uri.parse('tel:$cleanPhone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  /// Open WhatsApp chat
  Future<void> _openWhatsApp(String? phone, String name, double balance) async {
    if (phone == null || phone.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.loc.t('noPhone'))),
        );
      }
      return;
    }
    final loc = context.loc;
    final cleanPhone = phone.replaceAll(RegExp(r'[^\d]'), '');
    // Remove leading 0 if present and add country code 91 for India
    String waPhone = cleanPhone;
    if (waPhone.startsWith('0')) {
      waPhone = '91${waPhone.substring(1)}';
    } else if (!waPhone.startsWith('91') && waPhone.length == 10) {
      waPhone = '91$waPhone';
    }
    final symbol = AppConstants.getCurrencySymbol(
        context.read<StorageService>().defaultCurrency);
    final msg = loc.t('reminderMsg',
        params: {'name': name, 'amount': '$symbol${balance.abs().toStringAsFixed(2)}'});
    final uri = Uri.parse('https://wa.me/$waPhone?text=${Uri.encodeComponent(msg)}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  /// Get sort icon based on current sort
  IconData _getSortIcon() {
    switch (_sortBy) {
      case 'balance':
        return Icons.sort;
      case 'name':
        return Icons.sort_by_alpha;
      case 'date':
        return Icons.calendar_today;
      default:
        return Icons.access_time;
    }
  }

  /// Show sort options
  void _showSortOptions() {
    final loc = context.loc;
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              loc.t('sortBy'),
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            RadioListTile<String>(
              value: 'recent',
              groupValue: _sortBy,
              title: Text(loc.t('sortRecent')),
              onChanged: (v) => Navigator.pop(context, v),
            ),
            RadioListTile<String>(
              value: 'balance',
              groupValue: _sortBy,
              title: Text(loc.t('sortBalance')),
              onChanged: (v) => Navigator.pop(context, v),
            ),
            RadioListTile<String>(
              value: 'name',
              groupValue: _sortBy,
              title: Text(loc.t('sortName')),
              onChanged: (v) => Navigator.pop(context, v),
            ),
            RadioListTile<String>(
              value: 'date',
              groupValue: _sortBy,
              title: Text(loc.t('sortDate')),
              onChanged: (v) => Navigator.pop(context, v),
            ),
          ],
        ),
      ),
    ).then((value) {
      if (value != null) {
        setState(() {
          _sortBy = value;
        });
      }
    });
  }

  /// Get sorted and filtered customers
  List<Customer> _getFilteredCustomers(List<Customer> allCustomers) {
    var customers = allCustomers.where((c) => c.balance != 0).toList();

    // Filter by search query
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      customers = customers.where((c) {
        return c.name.toLowerCase().contains(q) ||
            (c.phone?.toLowerCase().contains(q) ?? false) ||
            (c.notes?.toLowerCase().contains(q) ?? false);
      }).toList();
    }

    // Sort
    switch (_sortBy) {
      case 'balance':
        customers.sort((a, b) => b.balance.abs().compareTo(a.balance.abs()));
        break;
      case 'name':
        customers.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        break;
      case 'date':
        customers.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      case 'recent':
      default:
        // Sort by updatedAt (most recently modified first)
        customers.sort((a, b) {
          final aDate = a.updatedAt ?? a.createdAt;
          final bDate = b.updatedAt ?? b.createdAt;
          return bDate.compareTo(aDate);
        });
        break;
    }

    return customers;
  }

  /// Get last transaction date for customer
  DateTime? _getLastTxnDate(String customerId, List<Entry> entries) {
    final customerEntries =
        entries.where((e) => e.customerId == customerId).toList();
    if (customerEntries.isEmpty) return null;
    customerEntries.sort((a, b) => b.date.compareTo(a.date));
    return customerEntries.first.date;
  }

  /// Mask phone number for privacy (show only last 2 digits)
  String _maskPhone(String? phone) {
    if (phone == null || phone.isEmpty) return '';
    if (phone.length <= 4) return phone;
    return '${'•' * (phone.length - 2)}${phone.substring(phone.length - 2)}';
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final storage = context.watch<StorageService>();

    final allCustomers = storage.customers;
    final customers = _getFilteredCustomers(allCustomers);
    final allEntries = storage.entries;

    final totalToGive = customers
        .where((c) => c.balance > 0)
        .fold(0.0, (sum, c) => sum + c.balance);
    final totalToTake = customers
        .where((c) => c.balance < 0)
        .fold(0.0, (sum, c) => sum + c.balance.abs());

    // Monthly summary data
    final now = DateTime.now();
    final monthEntries = allEntries.where((e) {
      return e.date.month == now.month &&
          e.date.year == now.year &&
          e.customerId != null;
    }).toList();
    final monthGiven =
        monthEntries.where((e) => e.category == 'credit').fold(0.0, (s, e) => s + e.amount);
    final monthTaken =
        monthEntries.where((e) => e.category == 'debit').fold(0.0, (s, e) => s + e.amount);
    final newCustomersThisMonth = allCustomers.where((c) {
      return c.createdAt.month == now.month && c.createdAt.year == now.year;
    }).length;

    final currencySymbol =
        AppConstants.getCurrencySymbol(storage.defaultCurrency);

    // Khata book colors
    final paperColor = isDark ? const Color(0xFF2C1810) : const Color(0xFFFFF8DC);
    final ruledLineColor = isDark
        ? const Color(0xFF5D4037).withOpacity(0.3)
        : const Color(0xFFB0C4DE).withOpacity(0.5);
    final marginLineColor = const Color(0xFFD32F2F).withOpacity(0.4);
    final textColor = isDark ? const Color(0xFFF5E6D3) : const Color(0xFF1A1A1A);

    return Scaffold(
      backgroundColor: paperColor,
      body: SafeArea(
        child: Column(
          children: [
            // === KHATA HARD COVER HEADER ===
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isDark
                      ? [const Color(0xFF3E2723), const Color(0xFF1B0F0A)]
                      : [const Color(0xFF8B0000), const Color(0xFFA0522D)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Title row
                  Row(
                    children: [
                      const Icon(Icons.menu_book, color: const Color(0xFFD4AF37), size: 28),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          loc.t('myKhata'),
                          style: TextStyle(
                            color: const Color(0xFFD4AF37),
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'KhataHandwriting',
                          ),
                        ),
                      ),
                      // Sort button
                      IconButton(
                        icon: Icon(_getSortIcon(), color: const Color(0xFFD4AF37)),
                        onPressed: _showSortOptions,
                        tooltip: loc.t('sortBy'),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                      ),
                      // View all customers
                      IconButton(
                        icon: const Icon(Icons.people, color: const Color(0xFFD4AF37)),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const CustomersScreen()),
                            );
                          },
                        },
                        tooltip: loc.t('customers'),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Stats row
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFD4AF37).withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _coverStat(
                          '${customers.length}',
                          loc.t('customersCount'),
                          const Color(0xFFD4AF37),
                        ),
                        Container(width: 1, height: 30, color: const Color(0xFFD4AF37).withOpacity(0.3)),
                        _coverStat(
                          '$currencySymbol${totalToGive.toStringAsFixed(0)}',
                          loc.t('toGive'),
                          Colors.red[200]!,
                        ),
                        Container(width: 1, height: 30, color: const Color(0xFFD4AF37).withOpacity(0.3)),
                        _coverStat(
                          '$currencySymbol${totalToTake.toStringAsFixed(0)}',
                          loc.t('toTake'),
                          Colors.green[200]!,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // === PAPER PAGE AREA (with ruled lines and red margin) ===
            Expanded(
              child: Container(
                // Paper background
                color: paperColor,
                child: Stack(
                  children: [
                    // Red margin line (vertical, left side)
                    Positioned(
                      left: 24,
                      top: 0,
                      bottom: 0,
                      child: Container(
                        width: 1.5,
                        color: marginLineColor,
                      ),
                    ),
                    // Ruled horizontal lines (subtle)
                    Positioned.fill(
                      child: CustomPaint(
                        painter: RuledLinesPainter(ruledLineColor),
                      ),
                    ),
                    // Content
                    Column(
                      children: [
                        // === SEARCH BAR ===
                        Padding(
                          padding: const EdgeInsets.fromLTRB(32, 8, 12, 4),
                          child: TextField(
                            controller: _searchController,
                            onChanged: (v) => setState(() => _searchQuery = v),
                            style: TextStyle(
                              fontFamily: 'KhataHandwriting',
                              color: textColor,
                              fontSize: 16,
                            ),
                            decoration: InputDecoration(
                              hintText: loc.t('searchCustomer'),
                              hintStyle: TextStyle(
                                fontFamily: 'KhataHandwriting',
                                color: textColor.withOpacity(0.4),
                                fontSize: 14,
                              ),
                              prefixIcon: Icon(Icons.search, color: textColor.withOpacity(0.5), size: 20),
                              filled: true,
                              fillColor: isDark
                                  ? Colors.white.withOpacity(0.05)
                                  : Colors.white.withOpacity(0.5),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide.none,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: textColor.withOpacity(0.1)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: const Color(0xFFD4AF37), width: 1.5),
                              ),
                              isDense: true,
                              suffixIcon: _searchQuery.isNotEmpty
                                  ? IconButton(
                                      icon: Icon(Icons.clear, size: 18, color: textColor.withOpacity(0.5)),
                                      onPressed: () {
                                        _searchController.clear();
                                        setState(() => _searchQuery = '');
                                      },
                                    )
                                  : null,
                            ),
                          ),
                        ),

                        // === MONTHLY SUMMARY CARD ===
                        if (_searchQuery.isEmpty)
                          Container(
                            margin: const EdgeInsets.fromLTRB(32, 4, 12, 4),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF3E2723).withOpacity(0.5)
                                  : Colors.white.withOpacity(0.7),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: const Color(0xFFD4AF37).withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.calendar_month, size: 16, color: textColor.withOpacity(0.7)),
                                    const SizedBox(width: 6),
                                    Text(
                                      '${loc.t('monthlySummary')} - ${_monthName(now.month, loc)} ${now.year}',
                                      style: TextStyle(
                                        fontFamily: 'KhataHandwriting',
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: textColor,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _summaryItem(
                                        '${monthEntries.length}',
                                        loc.t('totalTransactions'),
                                        textColor,
                                      ),
                                    ),
                                    Expanded(
                                      child: _summaryItem(
                                        '$currencySymbol${monthGiven.toStringAsFixed(0)}',
                                        loc.t('amountGiven'),
                                        const Color(0xFFC62828),
                                      ),
                                    ),
                                    Expanded(
                                      child: _summaryItem(
                                        '$currencySymbol${monthTaken.toStringAsFixed(0)}',
                                        loc.t('amountTaken'),
                                        const Color(0xFF2E7D32),
                                      ),
                                    ),
                                    Expanded(
                                      child: _summaryItem(
                                        '$newCustomersThisMonth',
                                        loc.t('newCustomers'),
                                        textColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                        // === SECTION HEADER ===
                        Padding(
                          padding: const EdgeInsets.fromLTRB(32, 8, 12, 4),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                loc.t('pendingEntries'),
                                style: TextStyle(
                                  fontFamily: 'KhataHandwriting',
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: textColor,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFD4AF37).withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '${customers.length}',
                                  style: TextStyle(
                                    color: const Color(0xFFD4AF37),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // === CUSTOMER LIST (khata entries) ===
                        Expanded(
                          child: customers.isEmpty
                              ? Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(32),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.menu_book_outlined,
                                          size: 80,
                                          color: textColor.withOpacity(0.3),
                                        ),
                                        const SizedBox(height: 16),
                                        Text(
                                          _searchQuery.isNotEmpty
                                              ? 'No customers found'
                                              : loc.t('noPendingEntries'),
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontFamily: 'KhataHandwriting',
                                            fontSize: 16,
                                            color: textColor.withOpacity(0.5),
                                          ),
                                        ),
                                        if (_searchQuery.isEmpty) ...[
                                          const SizedBox(height: 16),
                                          ElevatedButton.icon(
                                            onPressed: _addCustomer,
                                            icon: const Icon(Icons.person_add),
                                            label: Text(loc.t('addCustomer')),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: const Color(0xFF8B0000),
                                              foregroundColor: const Color(0xFFD4AF37),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                )
                              : ListView.builder(
                                  padding: const EdgeInsets.fromLTRB(32, 0, 8, 80),
                                  itemCount: customers.length,
                                  itemBuilder: (context, index) {
                                    final customer = customers[index];
                                    final balance = customer.balance;
                                    final isToGive = balance > 0; // We owe them
                                    final lastDate = _getLastTxnDate(customer.id, allEntries);
                                    final hasPhone = customer.phone != null && customer.phone!.isNotEmpty;

                                    return _KhataEntry(
                                      serialNo: index + 1,
                                      customer: customer,
                                      balance: balance,
                                      isToGive: isToGive,
                                      lastDate: lastDate,
                                      hasPhone: hasPhone,
                                      maskedPhone: _maskPhone(customer.phone),
                                      currencySymbol: currencySymbol,
                                      textColor: textColor,
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => CustomerDetailScreen(
                                              customerId: customer.id,
                                              pageNo: index + 1,
                                            ),
                                          ),
                                        );
                                      },
                                      onLongPress: () => _showCustomerOptions(customer),
                                      onCall: hasPhone ? () => _callCustomer(customer.phone) : null,
                                      onWhatsApp: isToGive
                                          ? () => _openWhatsApp(customer.phone, customer.name, balance)
                                          : null,
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      // === FLOATING ADD BUTTON (bahi style) ===
      floatingActionButton: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF8B0000), Color(0xFFA0522D)],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF8B0000).withOpacity(0.4),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: FloatingActionButton.extended(
          onPressed: _addCustomer,
          backgroundColor: Colors.transparent,
          elevation: 0,
          icon: const Icon(Icons.person_add, color: const Color(0xFFD4AF37)),
          label: Text(
            loc.t('addCustomer'),
            style: const TextStyle(
              color: const Color(0xFFD4AF37),
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _coverStat(String value, String label, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            color: color.withOpacity(0.7),
            fontSize: 10,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _summaryItem(String value, String label, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            color: color.withOpacity(0.6),
            fontSize: 9,
          ),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  String _monthName(int month, AppLocalizations loc) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    if (month >= 1 && month <= 12) return months[month - 1];
    return '';
  }
}

/// Custom painter to draw ruled horizontal lines (like a notebook page)
class RuledLinesPainter extends CustomPainter {
  final Color color;
  RuledLinesPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 0.5;

    const lineSpacing = 32.0;
    for (double y = lineSpacing; y < size.height; y += lineSpacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Khata entry widget — looks like a handwritten line in a bahi khata
class _KhataEntry extends StatelessWidget {
  final int serialNo;
  final Customer customer;
  final double balance;
  final bool isToGive;
  final DateTime? lastDate;
  final bool hasPhone;
  final String maskedPhone;
  final String currencySymbol;
  final Color textColor;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback? onCall;
  final VoidCallback? onWhatsApp;

  const _KhataEntry({
    required this.serialNo,
    required this.customer,
    required this.balance,
    required this.isToGive,
    required this.lastDate,
    required this.hasPhone,
    required this.maskedPhone,
    required this.currencySymbol,
    required this.textColor,
    required this.onTap,
    required this.onLongPress,
    this.onCall,
    this.onWhatsApp,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final balanceColor = isToGive ? const Color(0xFFC62828) : const Color(0xFF2E7D32);

    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Serial number (handwritten style)
            SizedBox(
              width: 28,
              child: Text(
                '$serialNo.',
                style: TextStyle(
                  fontFamily: 'KhataHandwriting',
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: textColor.withOpacity(0.6),
                ),
              ),
            ),
            // Customer info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name + balance row
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          customer.name,
                          style: TextStyle(
                            fontFamily: 'KhataHandwriting',
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '$currencySymbol${balance.abs().toStringAsFixed(2)}',
                        style: TextStyle(
                          fontFamily: 'KhataHandwriting',
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: balanceColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  // Subtitle: phone + last txn
                  Row(
                    children: [
                      if (hasPhone) ...[
                        Icon(Icons.phone, size: 11, color: textColor.withOpacity(0.5)),
                        const SizedBox(width: 4),
                        Text(
                          maskedPhone,
                          style: TextStyle(
                            fontSize: 11,
                            color: textColor.withOpacity(0.5),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ] else ...[
                        Text(
                          context.loc.t('noPhone'),
                          style: TextStyle(
                            fontSize: 11,
                            fontStyle: FontStyle.italic,
                            color: textColor.withOpacity(0.4),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      if (lastDate != null) ...[
                        Text(
                          '${context.loc.t('lastTxn')} ${lastDate!.day}/${lastDate!.month}',
                          style: TextStyle(
                            fontSize: 11,
                            color: textColor.withOpacity(0.5),
                          ),
                        ),
                      ],
                    ],
                  ),
                  // Action buttons row (small)
                  if (hasPhone || onWhatsApp != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (hasPhone)
                          InkWell(
                            onTap: onCall,
                            borderRadius: BorderRadius.circular(4),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.call, size: 12, color: Colors.blue[700]),
                                  const SizedBox(width: 2),
                                  Text(
                                    context.loc.t('callCustomer'),
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.blue[700],
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        if (hasPhone && onWhatsApp != null)
                          const SizedBox(width: 12),
                        if (onWhatsApp != null)
                          InkWell(
                            onTap: onWhatsApp,
                            borderRadius: BorderRadius.circular(4),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.chat, size: 12, color: Colors.green[700]),
                                  const SizedBox(width: 2),
                                  Text(
                                    context.loc.t('whatsappCustomer'),
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.green[700],
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            // Chevron
            Icon(
              Icons.chevron_right,
              size: 18,
              color: textColor.withOpacity(0.3),
            ),
          ],
        ),
      ),
    );
  }
}
