// =============================================================================
// Note Counter Pro - Bills Screen (Rewritten)
// =============================================================================
// Features:
//   - Summary card (total bills, total amount, paid/unpaid/overdue counts)
//   - Filter chips (All / Paid / Unpaid / Overdue)
//   - Search by bill number / customer name
//   - Card-based list (matches khata + settings design language)
//   - Sort by date / amount / status
//   - FAB → Bill Form (create new)
//   - Tap card → Bill Detail Screen
// =============================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/storage_service.dart';
import '../services/premium_service.dart';
import '../services/admob_service.dart';
import '../models/bill.dart';
import '../utils/constants.dart';
import '../utils/app_localizations.dart';
import '../widgets/banner_ad_widget.dart';
import 'bill_form_screen.dart';
import 'bill_detail_screen.dart';
import 'settings_screen.dart';
import 'premium_screen.dart';

class BillsScreen extends StatefulWidget {
  const BillsScreen({super.key});

  @override
  State<BillsScreen> createState() => _BillsScreenState();
}

class _BillsScreenState extends State<BillsScreen> {
  String _searchQuery = '';
  String _filter = 'all'; // all | paid | unpaid | overdue
  String _sortBy = 'date'; // date | amount | status

  /// Open Settings screen via Navigator.push (gear icon tap).
  void _openSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SettingsScreen()),
    );
  }

  /// Try to create a new bill. Free users are capped at 5 bills — show
  /// premium upsell if limit reached. Premium users get unlimited.
  void _createBill() {
    final storage = context.read<StorageService>();
    final isPremium = PremiumService().isPremium;
    final loc = context.loc;

    if (!isPremium && !storage.canCreateBillForFree) {
      // Free user at 5/5 — show premium upsell.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(loc.t('billLimitReached')),
          backgroundColor: AppColors.warning,
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: 'PRO',
            textColor: Colors.white,
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PremiumScreen()),
              );
            },
          ),
        ),
      );
      return;
    }
    // Interstitial at natural break point (AdMob policy compliant).
    AdMobService.showInterstitial();
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const BillFormScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final storage = context.watch<StorageService>();
    final symbol = AppConstants.getCurrencySymbol(storage.defaultCurrency);

    final allBills = storage.bills;

    // === Summary computations ===
    final totalAmount = allBills.fold(0.0, (s, b) => s + b.total);
    final paidCount = allBills.where((b) => b.isPaid).length;
    final unpaidCount =
        allBills.where((b) => !b.isPaid && b.status != 'overdue').length;
    final overdueCount =
        allBills.where((b) => b.status == 'overdue').length;

    // === Apply filters ===
    var filtered = allBills.where((b) {
      // Status filter
      if (_filter == 'paid' && !b.isPaid) return false;
      if (_filter == 'unpaid' && (b.isPaid || b.status == 'overdue')) return false;
      if (_filter == 'overdue' && b.status != 'overdue') return false;
      // Search query
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matches = b.billNumber.toLowerCase().contains(q) ||
            (b.customerName?.toLowerCase().contains(q) ?? false);
        if (!matches) return false;
      }
      return true;
    }).toList();

    // Sort
    switch (_sortBy) {
      case 'amount':
        filtered.sort((a, b) => b.total.compareTo(a.total));
        break;
      case 'status':
        // overdue first, then unpaid, then paid
        filtered.sort((a, b) {
          int rank(String s) =>
              s == 'overdue' ? 0 : (s == 'unpaid' ? 1 : 2);
          return rank(a.status).compareTo(rank(b.status));
        });
        break;
      case 'date':
      default:
        filtered.sort((a, b) => b.date.compareTo(a.date));
    }

    return Scaffold(
      // No AppBar — custom top bar below for consistency with other tabs
      // (Counter, Khata, Smart Pay, Tools all use custom top bars, not
      // AppBar). When this screen was Navigator.push'd (premium-only),
      // AppBar handled the status bar. Now that it's a tab inside
      // MainScaffold (which already provides SafeArea for the banner ad),
      // AppBar was adding a SECOND status-bar padding, pushing content
      // too low. Custom top bar avoids the duplicate padding.
      body: SafeArea(
        top: false, // MainScaffold handles top SafeArea for banner ad
        child: Column(
          children: [
            // === Custom top bar (back-free, since this is a tab) ===
            // Title + gear icon (Settings) + sort PopupMenu
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[900] : Colors.grey[50],
                border: Border(
                  bottom: BorderSide(
                    color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
                    width: 0.5,
                  ),
                ),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 12),
                  Icon(Icons.receipt_long, size: 22, color: const Color(0xFFD4AF37)),
                  const SizedBox(width: 8),
                  Text(
                    loc.t('bills'),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontFamily: 'KhataHandwriting',
                      fontSize: 22,
                    ),
                  ),
                  const Spacer(),
                  // Gear icon → Settings
                  IconButton(
                    icon: const Icon(Icons.settings_outlined),
                    tooltip: loc.t('settings'),
                    onPressed: _openSettings,
                  ),
                  // Sort menu
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.sort),
                    tooltip: loc.t('sortBy'),
                    onSelected: (v) => setState(() => _sortBy = v),
                    itemBuilder: (ctx) => [
                      CheckedPopupMenuItem(
                        value: 'date',
                        checked: _sortBy == 'date',
                        child: Text(loc.t('sortDate')),
                      ),
                      CheckedPopupMenuItem(
                        value: 'amount',
                        checked: _sortBy == 'amount',
                        child: Text(loc.t('sortAmount')),
                      ),
                      CheckedPopupMenuItem(
                        value: 'status',
                        checked: _sortBy == 'status',
                        child: Text(loc.t('sortStatus')),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          // === Summary card ===
          if (allBills.isNotEmpty)
            Container(
              margin: const EdgeInsets.fromLTRB(12, 12, 12, 4),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? [const Color(0xFF16213E), const Color(0xFF1A1A2E)]
                      : [const Color(0xFFFFF8DC), Colors.white],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: const Color(0xFFD4AF37).withOpacity(0.3),
                    width: 1),
                boxShadow: [
                  BoxShadow(
                    color: isDark
                        ? Colors.black.withOpacity(0.25)
                        : Colors.black.withOpacity(0.06),
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: const Color(0xFFD4AF37).withOpacity(0.18),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.receipt_long,
                            color: Color(0xFFD4AF37), size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              loc.t('totalBills'),
                              style: const TextStyle(
                                  fontSize: 11, color: AppColors.textSecondary),
                            ),
                            Text(
                              '${allBills.length}',
                              style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'KhataHandwriting'),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(loc.t('totalAmount'),
                              style: const TextStyle(
                                  fontSize: 11, color: AppColors.textSecondary)),
                          Text(
                            '$symbol${totalAmount.toStringAsFixed(0)}',
                            style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppColors.danger),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _summaryChip(
                          loc.t('paid'),
                          paidCount,
                          AppColors.success),
                      _summaryChip(
                          loc.t('unpaid'),
                          unpaidCount,
                          AppColors.warning),
                      _summaryChip(
                          loc.t('overdue'),
                          overdueCount,
                          AppColors.danger),
                    ],
                  ),
                ],
              ),
            ),

          // === Search bar ===
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: TextField(
              decoration: InputDecoration(
                hintText: loc.t('searchBills'),
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () =>
                            setState(() => _searchQuery = ''),
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(
                      color: const Color(0xFFD4AF37).withOpacity(0.3)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(
                      color: const Color(0xFFD4AF37).withOpacity(0.2)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(
                      color: Color(0xFFD4AF37), width: 1.5),
                ),
                filled: true,
                fillColor:
                    isDark ? const Color(0xFF16213E) : Colors.white,
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              onChanged: (v) => setState(() => _searchQuery = v),
            ),
          ),

          // === Filter chips ===
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              children: [
                _filterChip('all', loc.t('all'), allBills.length),
                _filterChip(
                    'paid', loc.t('paid'), paidCount),
                _filterChip(
                    'unpaid', loc.t('unpaid'), unpaidCount),
                _filterChip(
                    'overdue', loc.t('overdue'), overdueCount),
              ],
            ),
          ),

          // === Bills list ===
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            allBills.isEmpty
                                ? Icons.receipt_long_outlined
                                : Icons.search_off,
                            size: 72,
                            color: AppColors.textSecondary.withOpacity(0.4),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            allBills.isEmpty
                                ? (loc.t('noBills'))
                                : (loc.t('noBillsFound')),
                            style: TextStyle(
                              fontFamily: 'KhataHandwriting',
                              fontSize: 18,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          if (allBills.isEmpty) ...[
                            const SizedBox(height: 12),
                            FilledButton.icon(
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => const BillFormScreen()),
                              ),
                              icon: const Icon(Icons.add),
                              label: Text(loc.t('createBill')),
                            ),
                          ],
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 80),
                    itemCount: filtered.length,
                    itemBuilder: (ctx, i) {
                      final bill = filtered[i];
                      return _billCard(bill, symbol, isDark, loc);
                    },
                  ),
          ),
          const BannerAdWidget(),
        ],
        ),  // close Column
      ),  // close SafeArea
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createBill,
        backgroundColor: const Color(0xFF8B0000),
        foregroundColor: const Color(0xFFD4AF37),
        icon: const Icon(Icons.add),
        label: Text(loc.t('newBill')),
      ),
    );
  }

  Widget _summaryChip(String label, int count, Color color) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 3),
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3), width: 1),
        ),
        child: Column(
          children: [
            Text('$count',
                style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 14)),
            const SizedBox(height: 1),
            Text(label,
                style: TextStyle(color: color, fontSize: 9)),
          ],
        ),
      ),
    );
  }

  Widget _filterChip(String value, String label, int count) {
    final isActive = _filter == value;
    final color = isActive ? const Color(0xFFD4AF37) : AppColors.textSecondary;
    return Container(
      margin: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(
          '$label ($count)',
          style: TextStyle(
            color: isActive ? const Color(0xFF1A1A2E) : color,
            fontWeight: FontWeight.bold,
            fontSize: 11,
          ),
        ),
        selected: isActive,
        onSelected: (_) => setState(() => _filter = value),
        selectedColor: const Color(0xFFD4AF37),
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF16213E)
            : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
              color: isActive
                  ? const Color(0xFFD4AF37)
                  : const Color(0xFFD4AF37).withOpacity(0.3)),
        ),
        showCheckmark: false,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      ),
    );
  }

  Widget _billCard(
      Bill bill, String symbol, bool isDark, AppLocalizations loc) {
    Color statusColor;
    String statusLabel;
    switch (bill.status) {
      case 'paid':
        statusColor = AppColors.success;
        statusLabel = loc.t('paid');
        break;
      case 'overdue':
        statusColor = AppColors.danger;
        statusLabel = loc.t('overdue');
        break;
      default:
        statusColor = AppColors.warning;
        statusLabel = loc.t('unpaid');
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF16213E) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: statusColor.withOpacity(0.25),
            width: 1),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withOpacity(0.2)
                : Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => BillDetailScreen(billId: bill.id)),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.receipt, color: statusColor, size: 20),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            bill.billNumber,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              fontFamily: 'KhataHandwriting',
                            ),
                          ),
                          Text(
                            bill.customerName ??
                                (loc.t('walkInCustomer')),
                            style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '$symbol${bill.total.toStringAsFixed(0)}',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: AppColors.danger),
                        ),
                        const SizedBox(height: 2),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                                color: statusColor.withOpacity(0.5),
                                width: 0.5),
                          ),
                          child: Text(
                            statusLabel,
                            style: TextStyle(
                                color: statusColor,
                                fontSize: 8,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Divider(
                    height: 1,
                    color: isDark
                        ? Colors.white.withOpacity(0.08)
                        : Colors.black.withOpacity(0.06),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      Icon(Icons.event,
                          size: 12, color: AppColors.textSecondary),
                      const SizedBox(width: 4),
                      Text(
                        '${bill.date.day}/${bill.date.month}/${bill.date.year}',
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.textSecondary),
                      ),
                      const SizedBox(width: 12),
                      Icon(Icons.inventory_2_outlined,
                          size: 12, color: AppColors.textSecondary),
                      const SizedBox(width: 4),
                      Text(
                        '${bill.items.length} ${loc.t('items')}',
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.textSecondary),
                      ),
                      if (bill.dueDate != null && !bill.isPaid) ...[
                        const Spacer(),
                        Icon(Icons.event_busy,
                            size: 12,
                            color: bill.status == 'overdue'
                                ? AppColors.danger
                                : AppColors.warning),
                        const SizedBox(width: 4),
                        Text(
                          '${loc.t('due')}: ${bill.dueDate!.day}/${bill.dueDate!.month}',
                          style: TextStyle(
                            fontSize: 11,
                            color: bill.status == 'overdue'
                                ? AppColors.danger
                                : AppColors.warning,
                            fontWeight: bill.status == 'overdue'
                                ? FontWeight.bold
                                : null,
                          ),
                        ),
                      ] else ...[
                        const Spacer(),
                        Icon(Icons.check_circle,
                            size: 12, color: AppColors.success),
                        const SizedBox(width: 4),
                        Text(
                          loc.t('paid'),
                          style: const TextStyle(
                              fontSize: 11, color: AppColors.success),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
