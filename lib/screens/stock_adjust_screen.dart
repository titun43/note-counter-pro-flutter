// =============================================================================
// Note Counter Pro - Stock Adjust Screen
// =============================================================================
// Three adjustment modes:
//   - Purchase (stock in): adds to current stock
//   - Damage (loss): subtracts from current stock
//   - Manual (recount): sets absolute stock value
//
// Shows:
//   - Current stock + low-stock threshold + last updated
//   - Adjustment-type segmented selector
//   - Quantity input + optional note
//   - "New stock after update" preview
//
// Low-stock alert banner appears at top when the product is currently low.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/storage_service.dart';
import '../services/admob_service.dart';
import '../models/product.dart';
import '../utils/constants.dart';
import '../utils/app_localizations.dart';
import '../widgets/banner_ad_widget.dart';

class StockAdjustScreen extends StatefulWidget {
  final Product product;

  const StockAdjustScreen({super.key, required this.product});

  @override
  State<StockAdjustScreen> createState() => _StockAdjustScreenState();
}

class _StockAdjustScreenState extends State<StockAdjustScreen> {
  /// 0 = Purchase (stock in), 1 = Damage (loss), 2 = Manual (recount)
  int _type = 0;
  final _qtyController = TextEditingController(text: '1');
  final _noteController = TextEditingController();

  @override
  void dispose() {
    _qtyController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  int get _currentStock => widget.product.stock;

  int get _newStock {
    final qty = int.tryParse(_qtyController.text.trim()) ?? 0;
    switch (_type) {
      case 0:
        return _currentStock + qty; // purchase
      case 1:
        return _currentStock - qty; // damage
      case 2:
      default:
        return qty; // manual recount
    }
  }

  Future<void> _save() async {
    final storage = context.read<StorageService>();
    final loc = context.loc;
    final qty = int.tryParse(_qtyController.text.trim()) ?? 0;
    if (qty < 0) return;

    switch (_type) {
      case 0:
        await storage.adjustStock(widget.product.id, qty); // +
        break;
      case 1:
        await storage.adjustStock(widget.product.id, -qty); // −
        break;
      case 2:
      default:
        await storage.setStock(widget.product.id, qty); // =
        break;
    }

    // Interstitial at natural break point.
    AdMobService.showInterstitial();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(loc.t('stockAdjusted')),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final loc = context.loc;
    final isLow = widget.product.isLowStock || widget.product.isOutOfStock;

    return Scaffold(
      backgroundColor: isDark ? AppColors.bgDark : AppColors.bgLight,
      body: SafeArea(
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
                    loc.t('stockAdjust'),
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
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
                    // Low-stock banner
                    if (isLow)
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFFDC2626), Color(0xFFB91C1C)],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.danger.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 22),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '${widget.product.name}: ${widget.product.isOutOfStock ? loc.t('outOfStock') : loc.t('lowStockWarn')}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Product summary card
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.bgCardDark : AppColors.bgCard,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: isDark ? Colors.grey[700]! : Colors.grey[300]!),
                      ),
                      child: Column(
                        children: [
                          _summaryRow(loc.t('productName'), widget.product.name, isDark, bold: true),
                          const SizedBox(height: 8),
                          _summaryRow(
                            loc.t('currentStock'),
                            '$_currentStock ${widget.product.unit}',
                            isDark,
                            color: isLow ? AppColors.danger : null,
                          ),
                          const SizedBox(height: 6),
                          _summaryRow(
                            loc.t('lowStockThresholdLabel'),
                            '${widget.product.lowStockThreshold} ${widget.product.unit}',
                            isDark,
                            color: AppColors.danger,
                          ),
                          const SizedBox(height: 6),
                          _summaryRow(
                            loc.t('lastUpdated'),
                            _formatDate(widget.product.updatedAt),
                            isDark,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Adjustment type
                    _label(loc.t('adjustmentType'), theme),
                    Row(
                      children: [
                        Expanded(child: _typeButton(0, Icons.add_circle_outline, loc.t('stockInPurchase'), AppColors.success, isDark)),
                        const SizedBox(width: 6),
                        Expanded(child: _typeButton(1, Icons.remove_circle_outline, loc.t('stockOutDamage'), AppColors.danger, isDark)),
                        const SizedBox(width: 6),
                        Expanded(child: _typeButton(2, Icons.edit, loc.t('stockRecount'), AppColors.info, isDark)),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Quantity
                    _label(loc.t('quantity') + ' *', theme),
                    TextField(
                      controller: _qtyController,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: isDark ? AppColors.bgCardDark : AppColors.bgCard,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: isDark ? Colors.grey[700]! : Colors.grey[300]!),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xFFD4AF37), width: 2),
                        ),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 12),

                    // Note
                    _label(loc.t('note'), theme),
                    TextField(
                      controller: _noteController,
                      decoration: InputDecoration(
                        hintText: 'e.g. Purchased from wholesaler',
                        filled: true,
                        fillColor: isDark ? AppColors.bgCardDark : AppColors.bgCard,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: isDark ? Colors.grey[700]! : Colors.grey[300]!),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xFFD4AF37), width: 2),
                        ),
                      ),
                      textCapitalization: TextCapitalization.sentences,
                    ),
                    const SizedBox(height: 16),

                    // New stock preview
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: _newStock < 0
                              ? [const Color(0xFFFEE2E2), const Color(0xFFFECACA)]
                              : [const Color(0xFFECFDF5), const Color(0xFFD1FAE5)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _newStock < 0 ? AppColors.danger : AppColors.success,
                          width: 1.5,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            loc.t('newStockAfterUpdate'),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: isDark ? Colors.white70 : Colors.black54,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$_currentStock → $_newStock ${widget.product.unit}',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: _newStock < 0 ? AppColors.danger : AppColors.success,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Save button
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFFD4AF37), Color(0xFFB8941F)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFD4AF37).withOpacity(0.35),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: _save,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.check_circle, color: Colors.white, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  loc.t('updateStock'),
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
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
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} hr ago';
    if (diff.inDays < 7) return '${diff.inDays} day${diff.inDays > 1 ? 's' : ''} ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  Widget _label(String text, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: theme.textTheme.bodySmall?.copyWith(
          fontWeight: FontWeight.bold,
          color: theme.brightness == Brightness.dark ? Colors.white70 : Colors.black54,
        ),
      ),
    );
  }

  Widget _summaryRow(String label, String value, bool isDark, {bool bold = false, Color? color}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isDark ? Colors.white60 : Colors.black54,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: bold ? FontWeight.bold : FontWeight.w600,
            color: color ?? (isDark ? Colors.white : Colors.black87),
          ),
        ),
      ],
    );
  }

  Widget _typeButton(int index, IconData icon, String label, Color color, bool isDark) {
    final active = _type == index;
    return GestureDetector(
      onTap: () => setState(() {
        _type = index;
        // For manual recount, default the qty field to current stock
        if (index == 2) {
          _qtyController.text = _currentStock.toString();
        } else {
          _qtyController.text = '1';
        }
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        decoration: BoxDecoration(
          color: active
              ? color.withOpacity(0.12)
              : (isDark ? AppColors.bgCardDark : AppColors.bgCard),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: active ? color : (isDark ? Colors.grey[700]! : Colors.grey[300]!),
            width: active ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: active ? color : (isDark ? Colors.white54 : Colors.grey[600]), size: 20),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: active
                    ? color
                    : (isDark ? Colors.white54 : Colors.grey[600]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
