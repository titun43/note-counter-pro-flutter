// =============================================================================
// Note Counter Pro - Inventory Screen (List)
// =============================================================================
// Main inventory screen:
//   - 3 stat cards (Products / Stock Value / Low Stock)
//   - Premium upsell banner (free users at 5/5 product cap)
//   - Search bar (name + barcode) with scan-shortcut button
//   - Product cards with avatar/initials, name, barcode, price, stock badge
//   - Quick actions: Edit / Stock Adjust / Delete (with confirmation)
//
// Premium gating:
//   - Free users: hard-capped at 5 products (StorageService.canAddProduct)
//   - Premium users: unlimited
//   - Inventory tab itself is accessible to all — premium gate is on
//     adding new products beyond the free cap.
//
// Dark/Light mode: every component checks isDark.
// Ads: BannerAdWidget at top; interstitial on delete (action-gated).
// =============================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/storage_service.dart';
import '../services/admob_service.dart';
import '../services/premium_service.dart';
import '../models/product.dart';
import '../utils/constants.dart';
import '../utils/app_localizations.dart';
import '../widgets/banner_ad_widget.dart';
import 'product_form_screen.dart';
import 'stock_adjust_screen.dart';
import 'premium_screen.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Avatar gradient palette — cycles by index for visual variety.
  static const List<List<Color>> _avatarGradients = [
    [Color(0xFF667EEA), Color(0xFF764BA2)],
    [Color(0xFFF093FB), Color(0xFFF5576C)],
    [Color(0xFF4FACFE), Color(0xFF00F2FE)],
    [Color(0xFF43E97B), Color(0xFF38F9D7)],
    [Color(0xFFFA709A), Color(0xFFFEE140)],
  ];

  List<Product> _filterProducts(List<Product> all) {
    if (_searchQuery.isEmpty) return all;
    final q = _searchQuery.toLowerCase();
    return all.where((p) {
      return p.name.toLowerCase().contains(q) ||
          (p.barcode?.toLowerCase().contains(q) ?? false) ||
          (p.category?.toLowerCase().contains(q) ?? false);
    }).toList();
  }

  String _initials(Product p) {
    if (p.name.isEmpty) return '?';
    return p.name[0].toUpperCase();
  }

  Future<void> _addProduct() async {
    final storage = context.read<StorageService>();
    final isPremium = PremiumService().isPremium;
    if (!isPremium && !storage.canAddProduct) {
      // Free user at 5/5 — show premium upsell.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.loc.t('productLimitReached')),
            backgroundColor: AppColors.warning,
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
      }
      return;
    }
    // Interstitial before opening form (natural break point — AdMob policy).
    AdMobService.showInterstitial();
    if (!mounted) return;
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const ProductFormScreen()),
    );
    if (changed == true) {
      // StorageService notifies listeners → screen auto-rebuilds.
    }
  }

  Future<void> _editProduct(Product p) async {
    AdMobService.showInterstitial();
    if (!mounted) return;
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => ProductFormScreen(existingProduct: p)),
    );
  }

  Future<void> _adjustStock(Product p) async {
    AdMobService.showInterstitial();
    if (!mounted) return;
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => StockAdjustScreen(product: p)),
    );
  }

  Future<void> _confirmDelete(Product p) async {
    final loc = context.loc;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: AppColors.danger, size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                loc.t('confirmDeleteTitle'),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Text(loc.t('confirmDeleteMsg'), style: const TextStyle(fontSize: 13)),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(loc.t('cancelDelete')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(loc.t('confirmDelete')),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await context.read<StorageService>().deleteProduct(p.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(loc.t('productDeleted')),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final loc = context.loc;
    final storage = context.watch<StorageService>();
    final allProducts = storage.products;
    final filtered = _filterProducts(allProducts);
    final isPremium = PremiumService().isPremium;

    // Stats
    final totalProducts = allProducts.length;
    final stockValue = allProducts.fold<double>(0, (s, p) => s + p.stockValue);
    final lowStockCount = allProducts.where((p) => p.isLowStock).length;

    return Scaffold(
      backgroundColor: isDark ? AppColors.bgDark : AppColors.bgLight,
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            const BannerAdWidget(),
            // Top bar
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
                  IconButton(
                    icon: const Icon(Icons.arrow_back, size: 22),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Text(
                    loc.t('inventory'),
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  Container(
                    margin: const EdgeInsets.only(right: 4),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFFD4AF37), Color(0xFFB8941F)],
                      ),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFD4AF37).withOpacity(0.3),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: _addProduct,
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          child: Row(
                            children: [
                              Icon(Icons.add, color: Colors.white, size: 18),
                              SizedBox(width: 4),
                              Text(
                                'Add',
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Stats row
                    Row(
                      children: [
                        Expanded(
                          child: _statCard(
                            label: loc.t('totalProducts'),
                            value: totalProducts.toString(),
                            gradient: const [Color(0xFFEFF6FF), Color(0xFFDBEAFE)],
                            border: const Color(0xFFBFDBFE),
                            valueColor: const Color(0xFF2563EB),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _statCard(
                            label: loc.t('stockValue'),
                            value: '₹${_formatCompact(stockValue)}',
                            gradient: const [Color(0xFFECFDF5), Color(0xFFD1FAE5)],
                            border: const Color(0xFFA7F3D0),
                            valueColor: const Color(0xFF059669),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _statCard(
                            label: loc.t('lowStockCount'),
                            value: lowStockCount.toString(),
                            gradient: const [Color(0xFFFEF2F2), Color(0xFFFEE2E2)],
                            border: const Color(0xFFFECACA),
                            valueColor: const Color(0xFFDC2626),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Free-user premium banner
                    if (!isPremium)
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFFD4AF37), Color(0xFFFFD700)],
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.workspace_premium, color: Color(0xFF1A1A2E), size: 22),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                loc.t('freeProductLimitMsg'),
                                style: const TextStyle(
                                  color: Color(0xFF1A1A2E),
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const PremiumScreen()),
                                );
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1A1A2E),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  'PRO',
                                  style: TextStyle(
                                    color: Color(0xFFFFD700),
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Search bar
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.bgCardDark : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: isDark ? Colors.grey[700]! : Colors.grey[300]!),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.search, size: 18, color: isDark ? Colors.white54 : Colors.grey[500]),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              decoration: InputDecoration(
                                hintText: loc.t('searchProductOrBarcode'),
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: EdgeInsets.zero,
                              ),
                              style: TextStyle(
                                fontSize: 14,
                                color: isDark ? Colors.white : Colors.black,
                              ),
                              onChanged: (v) => setState(() => _searchQuery = v),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Icon(Icons.qr_code_scanner, size: 18, color: const Color(0xFFD4AF37)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Section label
                    Text(
                      '${loc.t('allProducts')} ($totalProducts)',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white60 : Colors.black54,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Empty state
                    if (filtered.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.bgCardDark : AppColors.bgCard,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: (isDark ? Colors.white24 : Colors.black12),
                          ),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              totalProducts == 0 ? Icons.inventory_2_outlined : Icons.search_off,
                              size: 48,
                              color: isDark ? Colors.white38 : Colors.grey[400],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              totalProducts == 0
                                  ? loc.t('addProduct')
                                  : loc.t('productNotFound'),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white70 : Colors.black54,
                              ),
                            ),
                            if (totalProducts == 0) ...[
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                onPressed: _addProduct,
                                icon: const Icon(Icons.add, size: 18),
                                label: Text(loc.t('addProduct')),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFD4AF37),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                              ),
                            ],
                          ],
                        ),
                      )
                    else
                      // Product list
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final p = filtered[index];
                          final originalIndex = allProducts.indexOf(p);
                          final gradient = _avatarGradients[originalIndex % _avatarGradients.length];
                          return _productCard(p, gradient, isDark, theme, loc);
                        },
                      ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statCard({
    required String label,
    required String value,
    required List<Color> gradient,
    required Color border,
    required Color valueColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradient,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: valueColor,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: Color(0xFF666666),
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _productCard(
    Product p,
    List<Color> gradient,
    bool isDark,
    ThemeData theme,
    AppLocalizations loc,
  ) {
    final isLow = p.isLowStock;
    final isOut = p.isOutOfStock;

    return Container(
      decoration: BoxDecoration(
        color: isOut
            ? (isDark ? const Color(0xFF2A1414) : const Color(0xFFFEF2F2))
            : isLow
                ? (isDark ? const Color(0xFF2A1F0F) : const Color(0xFFFFFBFB))
                : (isDark ? AppColors.bgCardDark : Colors.white),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isOut
              ? AppColors.danger
              : isLow
                  ? const Color(0xFFFECACA)
                  : (isDark ? Colors.white10 : Colors.black.withOpacity(0.05)),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            // Row 1: avatar + name + barcode + stock badge
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: gradient,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.12),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      _initials(p),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Wrap(
                        spacing: 6,
                        runSpacing: 2,
                        children: [
                          if (p.barcode != null && p.barcode!.isNotEmpty)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.qr_code, size: 10, color: Color(0xFF2563EB)),
                                const SizedBox(width: 2),
                                Text(
                                  p.barcode!,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: Color(0xFF2563EB),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          if (p.category != null && p.category!.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                p.category!,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: isDark ? Colors.white70 : Colors.black54,
                                ),
                              ),
                            ),
                          Text(
                            p.unit,
                            style: TextStyle(
                              fontSize: 10,
                              color: isDark ? Colors.white54 : Colors.black45,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Stock badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isOut
                        ? AppColors.danger
                        : isLow
                            ? const Color(0xFFFEE2E2)
                            : const Color(0xFFD1FAE5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    isOut
                        ? loc.t('outOfStock')
                        : isLow
                            ? '${loc.t('stockLabel')}: ${p.stock} ⚠️'
                            : '${loc.t('stockLabel')}: ${p.stock}',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: isOut
                          ? Colors.white
                          : isLow
                              ? AppColors.danger
                              : const Color(0xFF059669),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Row 2: price + actions
            Container(
              padding: const EdgeInsets.only(top: 8),
              decoration: const BoxDecoration(
                border: Border(
                  top: BorderSide(color: Color(0x0F000000), width: 1, style: BorderStyle.solid),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      p.purchasePrice != null
                          ? '₹${p.salePrice.toStringAsFixed(2)}  (Buy ₹${p.purchasePrice!.toStringAsFixed(0)})'
                          : '₹${p.salePrice.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFD4AF37),
                      ),
                    ),
                  ),
                  // Edit
                  _iconBtn(Icons.edit_outlined, isDark, onTap: () => _editProduct(p), tooltip: loc.t('editProduct')),
                  // Adjust
                  _iconBtn(Icons.tune, isDark, onTap: () => _adjustStock(p), tooltip: loc.t('stockAdjust')),
                  // Delete
                  _iconBtn(Icons.delete_outline, isDark,
                      danger: true, onTap: () => _confirmDelete(p), tooltip: loc.t('confirmDelete')),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _iconBtn(
    IconData icon,
    bool isDark, {
    required VoidCallback onTap,
    required String tooltip,
    bool danger = false,
  }) {
    return Container(
      width: 32,
      height: 32,
      margin: const EdgeInsets.only(left: 4),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(8),
      ),
      child: IconButton(
        icon: Icon(
          icon,
          size: 16,
          color: danger
              ? (isDark ? Colors.white38 : Colors.grey[400])
              : (isDark ? Colors.white54 : Colors.grey[600]),
        ),
        onPressed: onTap,
        tooltip: tooltip,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      ),
    );
  }

  /// Compact currency format — e.g. 18500 → "18.5K", 125000 → "1.25L"
  String _formatCompact(double v) {
    if (v >= 10000000) return '${(v / 10000000).toStringAsFixed(2)}Cr';
    if (v >= 100000) return '${(v / 100000).toStringAsFixed(2)}L';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
    return v.toStringAsFixed(0);
  }
}
