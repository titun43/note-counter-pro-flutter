// =============================================================================
// Note Counter Pro - Product Form Screen (Add / Edit)
// =============================================================================
// Full form for creating or editing a product in inventory:
//   - Product name, barcode (with scan button), category
//   - Sale price, purchase price (optional)
//   - GST %, HSN code
//   - Unit (pcs/kg/ltr/gm/mtr), opening stock
//   - Low-stock alert threshold
//   - Description (optional)
//
// Barcode scan uses mobile_scanner (same package as Smart Pay / QR scanner).
// On save:
//   - Free user: hard-capped at 5 products (PremiumService check + defensive
//     cap in StorageService.addProduct).
//   - Interstitial ad shown after save (natural break point — AdMob policy).
// =============================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mobile_scanner/mobile_scanner.dart' as mscanner;
import '../services/storage_service.dart';
import '../services/admob_service.dart';
import '../services/premium_service.dart';
import '../models/product.dart';
import '../utils/constants.dart';
import '../utils/app_localizations.dart';
import '../widgets/banner_ad_widget.dart';
import 'premium_screen.dart';

class ProductFormScreen extends StatefulWidget {
  /// Pass an existing product to edit; leave null to create new.
  final Product? existingProduct;

  const ProductFormScreen({super.key, this.existingProduct});

  @override
  State<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends State<ProductFormScreen> {
  final _nameController = TextEditingController();
  final _barcodeController = TextEditingController();
  final _categoryController = TextEditingController();
  final _salePriceController = TextEditingController();
  final _purchasePriceController = TextEditingController();
  final _gstController = TextEditingController();
  final _hsnController = TextEditingController();
  final _stockController = TextEditingController();
  final _lowStockController = TextEditingController();
  final _descriptionController = TextEditingController();
  String _unit = 'pcs';

  bool get _isEditing => widget.existingProduct != null;

  @override
  void initState() {
    super.initState();
    if (widget.existingProduct != null) {
      final p = widget.existingProduct!;
      _nameController.text = p.name;
      _barcodeController.text = p.barcode ?? '';
      _categoryController.text = p.category ?? '';
      _salePriceController.text = p.salePrice.toStringAsFixed(2);
      _purchasePriceController.text = p.purchasePrice?.toStringAsFixed(2) ?? '';
      _gstController.text = p.gstPercent?.toStringAsFixed(0) ?? '';
      _hsnController.text = p.hsnCode ?? '';
      _stockController.text = p.stock.toString();
      _lowStockController.text = p.lowStockThreshold.toString();
      _descriptionController.text = p.description ?? '';
      _unit = p.unit;
    } else {
      // Sensible defaults for new product
      _stockController.text = '0';
      _lowStockController.text = '5';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _barcodeController.dispose();
    _categoryController.dispose();
    _salePriceController.dispose();
    _purchasePriceController.dispose();
    _gstController.dispose();
    _hsnController.dispose();
    _stockController.dispose();
    _lowStockController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  /// Open mobile_scanner sheet and return the scanned barcode string.
  Future<void> _scanBarcode() async {
    String? scanned = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => const _BarcodeScannerSheet(),
        fullscreenDialog: true,
      ),
    );
    if (scanned != null && scanned.isNotEmpty) {
      setState(() => _barcodeController.text = scanned);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.loc.t('barcodeScanned')),
            backgroundColor: AppColors.success,
            duration: const Duration(seconds: 1),
          ),
        );
      }
    }
  }

  bool get _canSave {
    if (_nameController.text.trim().isEmpty) return false;
    final sale = double.tryParse(_salePriceController.text.trim());
    if (sale == null || sale <= 0) return false;
    final stock = int.tryParse(_stockController.text.trim());
    if (stock == null || stock < 0) return false;
    return true;
  }

  Future<void> _save() async {
    if (!_canSave) return;
    final storage = context.read<StorageService>();
    final loc = context.loc;

    // Premium/free limit check (only when adding new)
    if (!_isEditing) {
      final isPremium = PremiumService().isPremium;
      if (!isPremium && !storage.canAddProduct) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(loc.t('productLimitReached')),
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
    }

    final name = _nameController.text.trim();
    final barcode = _barcodeController.text.trim().isEmpty ? null : _barcodeController.text.trim();
    final category = _categoryController.text.trim().isEmpty ? null : _categoryController.text.trim();
    final sale = double.parse(_salePriceController.text.trim());
    final purchase = double.tryParse(_purchasePriceController.text.trim());
    final gst = double.tryParse(_gstController.text.trim());
    final hsn = _hsnController.text.trim().isEmpty ? null : _hsnController.text.trim();
    final stock = int.parse(_stockController.text.trim());
    final lowStock = int.tryParse(_lowStockController.text.trim()) ?? 5;
    final desc = _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim();

    if (_isEditing) {
      final updated = widget.existingProduct!.copyWith(
        name: name,
        barcode: barcode,
        category: category,
        salePrice: sale,
        purchasePrice: purchase,
        gstPercent: gst,
        hsnCode: hsn,
        unit: _unit,
        stock: stock,
        lowStockThreshold: lowStock,
        description: desc,
        updatedAt: DateTime.now(),
      );
      await storage.updateProduct(updated);
    } else {
      final product = Product.create(
        name: name,
        barcode: barcode,
        category: category,
        salePrice: sale,
        purchasePrice: purchase,
        gstPercent: gst,
        hsnCode: hsn,
        unit: _unit,
        stock: stock,
        lowStockThreshold: lowStock,
        description: desc,
      );
      final ok = await storage.addProduct(product);
      if (!ok) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(loc.t('productLimitReached')),
              backgroundColor: AppColors.warning,
            ),
          );
        }
        return;
      }
    }

    // Interstitial at natural break point (AdMob policy compliant).
    AdMobService.showInterstitial();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isEditing ? loc.t('productUpdated') : loc.t('productSaved')),
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
                    tooltip: 'Back',
                  ),
                  Text(
                    _isEditing ? loc.t('editProduct') : loc.t('addProduct'),
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
                    // Product name
                    _label(loc.t('productName') + ' *', theme),
                    TextField(
                      controller: _nameController,
                      decoration: _inputDecoration(isDark, hint: 'e.g. Sunlight Soap 200g'),
                      textCapitalization: TextCapitalization.words,
                    ),
                    const SizedBox(height: 12),

                    // Barcode + scan button
                    _label(loc.t('barcode'), theme),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _barcodeController,
                            decoration: _inputDecoration(isDark, hint: 'e.g. 8901234567890'),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
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
                          child: IconButton(
                            icon: const Icon(Icons.qr_code_scanner, color: Colors.white, size: 22),
                            onPressed: _scanBarcode,
                            tooltip: loc.t('scanBarcode'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Category
                    _label(loc.t('category'), theme),
                    TextField(
                      controller: _categoryController,
                      decoration: _inputDecoration(isDark, hint: 'e.g. Grocery'),
                      textCapitalization: TextCapitalization.words,
                    ),
                    const SizedBox(height: 12),

                    // Sale price + Purchase price
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _label(loc.t('salePrice') + ' * ₹', theme),
                              TextField(
                                controller: _salePriceController,
                                decoration: _inputDecoration(isDark, hint: '0.00'),
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _label(loc.t('purchasePrice') + ' ₹', theme),
                              TextField(
                                controller: _purchasePriceController,
                                decoration: _inputDecoration(isDark, hint: '0.00'),
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // GST + HSN
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _label(loc.t('gstPercentShort'), theme),
                              TextField(
                                controller: _gstController,
                                decoration: _inputDecoration(isDark, hint: '0'),
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _label(loc.t('hsnCode'), theme),
                              TextField(
                                controller: _hsnController,
                                decoration: _inputDecoration(isDark, hint: 'optional'),
                                keyboardType: TextInputType.text,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Unit + Opening stock
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _label(loc.t('unit'), theme),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                decoration: BoxDecoration(
                                  color: isDark ? AppColors.bgCardDark : AppColors.bgCard,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: isDark ? Colors.grey[700]! : Colors.grey[300]!),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: _unit,
                                    isExpanded: true,
                                    items: ['pcs', 'kg', 'gm', 'ltr', 'mtr']
                                        .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                                        .toList(),
                                    onChanged: (v) => setState(() => _unit = v ?? 'pcs'),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _label(loc.t('openingStock') + ' *', theme),
                              TextField(
                                controller: _stockController,
                                decoration: _inputDecoration(isDark, hint: '0'),
                                keyboardType: TextInputType.number,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Low stock threshold
                    _label(loc.t('lowStockAlert'), theme),
                    TextField(
                      controller: _lowStockController,
                      decoration: _inputDecoration(isDark, hint: '5'),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 12),

                    // Description
                    _label(loc.t('description'), theme),
                    TextField(
                      controller: _descriptionController,
                      decoration: _inputDecoration(isDark, hint: 'optional notes...'),
                      maxLines: 2,
                      textCapitalization: TextCapitalization.sentences,
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
                          onTap: _canSave ? _save : null,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.save, color: Colors.white, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  loc.t('saveProduct'),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
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

  Widget _label(String text, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        text,
        style: theme.textTheme.bodySmall?.copyWith(
          fontWeight: FontWeight.bold,
          color: theme.brightness == Brightness.dark ? Colors.white70 : Colors.black54,
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(bool isDark, {required String hint}) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: isDark ? AppColors.bgCardDark : AppColors.bgCard,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: isDark ? Colors.grey[700]! : Colors.grey[300]!),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: isDark ? Colors.grey[700]! : Colors.grey[300]!),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFD4AF37), width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    );
  }
}

// =============================================================================
// Barcode Scanner Sheet — reuses mobile_scanner for product barcode scan.
// =============================================================================

class _BarcodeScannerSheet extends StatefulWidget {
  const _BarcodeScannerSheet();

  @override
  State<_BarcodeScannerSheet> createState() => _BarcodeScannerSheetState();
}

class _BarcodeScannerSheetState extends State<_BarcodeScannerSheet> {
  final mscanner.MobileScannerController _controller = mscanner.MobileScannerController(
    detectionSpeed: mscanner.DetectionSpeed.noDuplicates,
    facing: mscanner.CameraFacing.back,
    autoStart: true,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Scan Barcode'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: mscanner.MobileScanner(
        controller: _controller,
        onDetect: (capture) {
          if (capture.barcodes.isEmpty) return;
          final raw = capture.barcodes.first.rawValue;
          if (raw != null && raw.isNotEmpty) {
            _controller.stop();
            Navigator.pop(context, raw);
          }
        },
      ),
    );
  }
}
