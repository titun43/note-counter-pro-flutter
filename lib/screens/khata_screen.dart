import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/storage_service.dart';
import '../services/contact_picker_service.dart';
import '../services/pdf_service.dart';
import '../services/admob_service.dart';
import '../services/premium_service.dart';
import '../models/customer.dart';
import '../models/entry.dart';
import '../utils/constants.dart';
import '../utils/app_localizations.dart';
import '../widgets/reminder_template_picker.dart';
import '../widgets/send_reminder_to_all_dialog.dart';
import 'customer_detail_screen.dart';
import 'customers_screen.dart';
import 'reminder_history_screen.dart';
import 'bills_screen.dart';
import 'reports_screen.dart';
import 'premium_screen.dart';

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

  /// Open WhatsApp chat with template picker (Idea 1, 2, 8)
  Future<void> _openWhatsApp(String? phone, String name, double balance) async {
    if (phone == null || phone.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.loc.t('noPhoneCustomer'))),
        );
      }
      return;
    }
    // Find the customer object
    final storage = context.read<StorageService>();
    final customer = storage.customers.firstWhere(
      (c) => c.name == name && c.phone == phone,
      orElse: () => Customer.create(name: name, phone: phone),
    );
    final symbol = AppConstants.getCurrencySymbol(storage.defaultCurrency);

    if (!mounted) return;
    await showReminderTemplatePicker(
      context: context,
      customer: customer,
      balance: balance.abs(),
      currencySymbol: symbol,
      channel: 'whatsapp',
    );
  }

  /// Send reminder to all pending customers (Idea 4)
  Future<void> _sendReminderToAll() async {
    final storage = context.read<StorageService>();
    final customers = storage.customers
        .where((c) => c.balance.abs() > 0.01)
        .toList();
    if (customers.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.loc.t('noPendingCustomers'))),
        );
      }
      return;
    }
    if (!mounted) return;
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => SendReminderToAllDialog(
        customers: customers,
        channel: 'whatsapp',
      ),
    );
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

  /// Get sorted and filtered customers (ALL customers — pending + settled + new)
  List<Customer> _getFilteredCustomers(List<Customer> allCustomers) {
    var customers = allCustomers.toList(); // Show ALL customers

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
        top: false, // MainScaffold already handles top padding for banner ad
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
                  // Title row — clean: 1 book icon + title + single overflow menu
                  Row(
                    children: [
                      const Icon(Icons.menu_book, color: Color(0xFFD4AF37), size: 28),
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
                      // Single overflow menu — replaces 4 cluttered icons
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert, color: Color(0xFFD4AF37)),
                        tooltip: loc.t('sortBy'),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                        color: isDark ? const Color(0xFF2C1810) : Colors.white,
                        onSelected: (value) async {
                          switch (value) {
                            case 'sort':
                              _showSortOptions();
                              break;
                            case 'history':
                              if (!mounted) return;
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const ReminderHistoryScreen()),
                              );
                              break;
                            case 'pdf':
                              if (!mounted) return;
                              final storage = context.read<StorageService>();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Generating PDF...'), duration: Duration(seconds: 1)),
                              );
                              await PdfService.generateKhataPdf(storage);
                              break;
                            case 'customers':
                              if (!mounted) return;
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const CustomersScreen()),
                              );
                              break;
                            case 'bills':
                              if (!mounted) return;
                              // Premium gate for Bills
                              if (!PremiumService().isPremium) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const PremiumScreen()),
                                );
                                return;
                              }
                              AdMobService.showInterstitial();
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const BillsScreen()),
                              );
                              break;
                            case 'reports':
                              if (!mounted) return;
                              // Premium gate for Reports
                              if (!PremiumService().isPremium) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const PremiumScreen()),
                                );
                                return;
                              }
                              AdMobService.showInterstitial();
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const ReportsScreen()),
                              );
                              break;
                          }
                        },
                        itemBuilder: (context) => [
                          PopupMenuItem<String>(
                            value: 'sort',
                            child: Row(
                              children: [
                                Icon(_getSortIcon(), size: 20, color: const Color(0xFF8B0000)),
                                const SizedBox(width: 12),
                                Text(loc.t('sortBy')),
                              ],
                            ),
                          ),
                          PopupMenuItem<String>(
                            value: 'history',
                            child: Row(
                              children: [
                                const Icon(Icons.history, size: 20, color: Color(0xFF8B0000)),
                                const SizedBox(width: 12),
                                Text(loc.t('reminderHistory')),
                              ],
                            ),
                          ),
                          PopupMenuItem<String>(
                            value: 'pdf',
                            child: Row(
                              children: [
                                const Icon(Icons.picture_as_pdf, size: 20, color: Color(0xFF8B0000)),
                                const SizedBox(width: 12),
                                const Text('Share PDF'),
                              ],
                            ),
                          ),
                          PopupMenuItem<String>(
                            value: 'customers',
                            child: Row(
                              children: [
                                const Icon(Icons.people, size: 20, color: Color(0xFF8B0000)),
                                const SizedBox(width: 12),
                                Text(loc.t('customers')),
                              ],
                            ),
                          ),
                          PopupMenuItem<String>(
                            value: 'bills',
                            child: Row(
                              children: [
                                const Icon(Icons.receipt_long, size: 20, color: Color(0xFF8B0000)),
                                const SizedBox(width: 12),
                                Text(loc.t('billsInvoices')),
                                const Spacer(),
                                if (!PremiumService().isPremium)
                                  const Icon(Icons.lock, size: 14, color: Color(0xFFD4AF37)),
                              ],
                            ),
                          ),
                          PopupMenuItem<String>(
                            value: 'reports',
                            child: Row(
                              children: [
                                const Icon(Icons.bar_chart, size: 20, color: Color(0xFF8B0000)),
                                const SizedBox(width: 12),
                                Text(loc.t('reportsAnalytics')),
                                const Spacer(),
                                if (!PremiumService().isPremium)
                                  const Icon(Icons.lock, size: 14, color: Color(0xFFD4AF37)),
                              ],
                            ),
                          ),
                        ],
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
                                borderSide: const BorderSide(color: Color(0xFFD4AF37), width: 1.5),
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
                                      '${loc.t('monthlySummary')} - ${_monthName(now.month)} ${now.year}',
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
                                loc.t('allCustomers'),
                                style: TextStyle(
                                  fontFamily: 'KhataHandwriting',
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: textColor,
                                ),
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Send Reminder to All button
                                  if (customers.any((c) => c.balance.abs() > 0.01))
                                    InkWell(
                                      onTap: _sendReminderToAll,
                                      borderRadius: BorderRadius.circular(8),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF25D366).withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: const Color(0xFF25D366), width: 1),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.send, size: 12, color: Color(0xFF25D366)),
                                            const SizedBox(width: 4),
                                            Text(
                                              loc.t('remindAll'),
                                              style: const TextStyle(
                                                color: Color(0xFF25D366),
                                                fontWeight: FontWeight.bold,
                                                fontSize: 11,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  const SizedBox(width: 6),
                                  // Customer count badge
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFD4AF37).withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      '${customers.length}',
                                      style: const TextStyle(
                                        color: Color(0xFFD4AF37),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
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
                                              : loc.t('noCustomers'),
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
                                  padding: const EdgeInsets.fromLTRB(32, 0, 8, 56),
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
      // === FLOATING ADD BUTTON (compact, bahi style) ===
      floatingActionButton: FloatingActionButton.small(
        onPressed: _addCustomer,
        backgroundColor: const Color(0xFF8B0000),
        elevation: 4,
        tooltip: loc.t('addCustomer'),
        child: const Icon(Icons.person_add, color: Color(0xFFD4AF37), size: 22),
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

  String _monthName(int month) {
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
    final isSettled = balance.abs() < 0.01;

    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: isSettled
              ? (isDark
                  ? const Color(0xFF2E7D32).withOpacity(0.12)
                  : const Color(0xFF2E7D32).withOpacity(0.08))
              : (isDark
                  ? const Color(0xFF3E2723).withOpacity(0.55)
                  : Colors.white.withOpacity(0.75)),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSettled
                ? const Color(0xFF2E7D32).withOpacity(0.3)
                : const Color(0xFFD4AF37).withOpacity(0.3),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isDark ? Colors.black.withOpacity(0.25) : Colors.black.withOpacity(0.06),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            // === TOP ROW: avatar + name + meta + balance ===
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Avatar circle with first letter (color-coded)
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    gradient: _avatarGradient(customer.name),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 3,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      _avatarInitial(customer.name),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // Name + meta
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        customer.name,
                        style: TextStyle(
                          fontFamily: 'KhataHandwriting',
                          fontSize: 19,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                          height: 1.1,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          if (hasPhone) ...[
                            Icon(Icons.phone, size: 10, color: textColor.withOpacity(0.5)),
                            const SizedBox(width: 3),
                            Text(
                              maskedPhone,
                              style: TextStyle(
                                fontSize: 10.5,
                                color: textColor.withOpacity(0.55),
                              ),
                            ),
                          ] else ...[
                            Text(
                              context.loc.t('noPhone'),
                              style: TextStyle(
                                fontSize: 10.5,
                                fontStyle: FontStyle.italic,
                                color: textColor.withOpacity(0.4),
                              ),
                            ),
                          ],
                          if (lastDate != null) ...[
                            Container(
                              margin: const EdgeInsets.symmetric(horizontal: 5),
                              width: 3,
                              height: 3,
                              decoration: BoxDecoration(
                                color: textColor.withOpacity(0.4),
                                shape: BoxShape.circle,
                              ),
                            ),
                            Text(
                              '${context.loc.t('lastTxn')} ${lastDate!.day}/${lastDate!.month}',
                              style: TextStyle(
                                fontSize: 10.5,
                                color: textColor.withOpacity(0.55),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                // Balance / Settled badge
                if (isSettled)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2E7D32).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFF2E7D32), width: 0.5),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.check_circle, size: 11, color: Color(0xFF2E7D32)),
                        const SizedBox(width: 3),
                        Text(
                          context.loc.t('settled').toUpperCase(),
                          style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2E7D32),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '$currencySymbol${balance.abs().toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: balanceColor,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        isToGive
                            ? context.loc.t('toGive')
                            : context.loc.t('toTake'),
                        style: TextStyle(
                          fontSize: 8,
                          color: textColor.withOpacity(0.5),
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            // === ACTION ROW: only if phone or whatsapp available ===
            if (hasPhone || onWhatsApp != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.only(top: 8),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: textColor.withOpacity(0.1),
                      width: 0.5,
                      style: BorderStyle.solid,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    if (onWhatsApp != null)
                      Expanded(
                        child: _actionChip(
                          icon: Icons.chat,
                          label: context.loc.t('whatsappCustomer'),
                          color: const Color(0xFF25D366),
                          onTap: onWhatsApp!,
                        ),
                      ),
                    if (onWhatsApp != null && hasPhone)
                      const SizedBox(width: 8),
                    if (hasPhone)
                      Expanded(
                        child: _actionChip(
                          icon: Icons.call,
                          label: context.loc.t('callCustomer'),
                          color: const Color(0xFF1976D2),
                          onTap: onCall!,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Build a small action chip button (WhatsApp / Call)
  Widget _actionChip({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withOpacity(0.3), width: 1),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 10.5,
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Generate consistent gradient color for avatar based on customer name hash
  static const List<List<Color>> _avatarGradients = [
    [Color(0xFFF59E0B), Color(0xFFD97706)], // amber
    [Color(0xFF3B82F6), Color(0xFF1D4ED8)], // blue
    [Color(0xFF10B981), Color(0xFF047857)], // green
    [Color(0xFFEC4899), Color(0xFFBE185D)], // pink
    [Color(0xFF8B5CF6), Color(0xFF6D28D9)], // purple
    [Color(0xFF06B6D4), Color(0xFF0E7490)], // cyan
  ];

  static LinearGradient _avatarGradient(String name) {
    final hash = name.codeUnits.fold(0, (prev, c) => prev + c);
    final palette = _avatarGradients[hash % _avatarGradients.length];
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: palette,
    );
  }

  /// Get the first character of the name (supports Bengali + Latin)
  static String _avatarInitial(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '?';
    // Use first unicode grapheme
    final runes = trimmed.runes;
    final first = runes.first;
    return String.fromCharCode(first).toUpperCase();
  }
}
