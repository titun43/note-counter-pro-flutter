// =============================================================================
// Note Counter Pro - Product Model
// =============================================================================
// Inventory product with barcode, pricing, GST, stock tracking, and
// low-stock alert threshold.
//
// Used by:
//   - InventoryScreen (list, add, edit, delete)
//   - ProductFormScreen (create/edit form)
//   - StockAdjustScreen (manual stock +/- /recount)
//   - BillFormScreen (scan barcode → auto-fill item, qty++)
//   - StorageService (persistence + stock auto-deduct on bill save)
// =============================================================================

class Product {
  final String id;
  String name;
  String? barcode;
  String? category;
  double salePrice;
  double? purchasePrice;
  double? gstPercent;
  String? hsnCode;
  String unit; // 'pcs', 'kg', 'ltr', 'gm', 'mtr'
  int stock;
  int lowStockThreshold;
  String? description;
  final DateTime createdAt;
  DateTime updatedAt;

  Product({
    required this.id,
    required this.name,
    this.barcode,
    this.category,
    required this.salePrice,
    this.purchasePrice,
    this.gstPercent,
    this.hsnCode,
    this.unit = 'pcs',
    required this.stock,
    this.lowStockThreshold = 5,
    this.description,
    required this.createdAt,
    required this.updatedAt,
  });

  /// True if stock is at or below the low-stock threshold.
  bool get isLowStock => stock > 0 && stock <= lowStockThreshold;

  /// True if no stock remains.
  bool get isOutOfStock => stock <= 0;

  /// Total value of current stock based on purchase price (fallback to sale price).
  double get stockValue => stock * (purchasePrice ?? salePrice);

  /// Profit per unit (sale - purchase). 0 if purchase price unknown.
  double get profitPerUnit => purchasePrice != null ? salePrice - purchasePrice! : 0;

  factory Product.create({
    required String name,
    String? barcode,
    String? category,
    required double salePrice,
    double? purchasePrice,
    double? gstPercent,
    String? hsnCode,
    String unit = 'pcs',
    required int stock,
    int lowStockThreshold = 5,
    String? description,
  }) {
    final now = DateTime.now();
    return Product(
      id: now.millisecondsSinceEpoch.toString(),
      name: name,
      barcode: barcode,
      category: category,
      salePrice: salePrice,
      purchasePrice: purchasePrice,
      gstPercent: gstPercent,
      hsnCode: hsnCode,
      unit: unit,
      stock: stock,
      lowStockThreshold: lowStockThreshold,
      description: description,
      createdAt: now,
      updatedAt: now,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'barcode': barcode,
        'category': category,
        'salePrice': salePrice,
        'purchasePrice': purchasePrice,
        'gstPercent': gstPercent,
        'hsnCode': hsnCode,
        'unit': unit,
        'stock': stock,
        'lowStockThreshold': lowStockThreshold,
        'description': description,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory Product.fromJson(Map<String, dynamic> json) => Product(
        id: json['id'] as String,
        name: json['name'] as String,
        barcode: json['barcode'] as String?,
        category: json['category'] as String?,
        salePrice: (json['salePrice'] as num).toDouble(),
        purchasePrice: (json['purchasePrice'] as num?)?.toDouble(),
        gstPercent: (json['gstPercent'] as num?)?.toDouble(),
        hsnCode: json['hsnCode'] as String?,
        unit: json['unit'] as String? ?? 'pcs',
        stock: (json['stock'] as num).toInt(),
        lowStockThreshold: (json['lowStockThreshold'] as num?)?.toInt() ?? 5,
        description: json['description'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
      );

  Product copyWith({
    String? name,
    String? barcode,
    String? category,
    double? salePrice,
    double? purchasePrice,
    double? gstPercent,
    String? hsnCode,
    String? unit,
    int? stock,
    int? lowStockThreshold,
    String? description,
    DateTime? updatedAt,
  }) {
    return Product(
      id: id,
      name: name ?? this.name,
      barcode: barcode ?? this.barcode,
      category: category ?? this.category,
      salePrice: salePrice ?? this.salePrice,
      purchasePrice: purchasePrice ?? this.purchasePrice,
      gstPercent: gstPercent ?? this.gstPercent,
      hsnCode: hsnCode ?? this.hsnCode,
      unit: unit ?? this.unit,
      stock: stock ?? this.stock,
      lowStockThreshold: lowStockThreshold ?? this.lowStockThreshold,
      description: description ?? this.description,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }
}
