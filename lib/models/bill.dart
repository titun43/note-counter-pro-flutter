class BillItem {
  String name;
  int quantity;
  double price;
  double? gstPercent;

  BillItem({
    required this.name,
    required this.quantity,
    required this.price,
    this.gstPercent,
  });

  double get subtotal => quantity * price;
  double get gstAmount => gstPercent != null ? subtotal * gstPercent! / 100 : 0;
  double get total => subtotal + gstAmount;

  Map<String, dynamic> toJson() => {
        'name': name,
        'quantity': quantity,
        'price': price,
        'gstPercent': gstPercent,
      };

  factory BillItem.fromJson(Map<String, dynamic> json) => BillItem(
        name: json['name'] as String,
        quantity: (json['quantity'] as num).toInt(),
        price: (json['price'] as num).toDouble(),
        gstPercent: json['gstPercent'] != null
            ? (json['gstPercent'] as num).toDouble()
            : null,
      );

  BillItem copyWith({
    String? name,
    int? quantity,
    double? price,
    double? gstPercent,
  }) {
    return BillItem(
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      price: price ?? this.price,
      gstPercent: gstPercent ?? this.gstPercent,
    );
  }
}

class Bill {
  final String id;
  final String billNumber;
  final DateTime date;
  final String? customerId;
  final String? customerName;
  final String? customerPhone;
  List<BillItem> items;
  double discountPercent;
  String currency;
  String? notes;
  final DateTime createdAt;
  DateTime? dueDate;

  /// Payment status — true if bill has been fully paid.
  /// Defaults to false for backward compatibility (pre-v3.24 bills).
  bool isPaid;
  DateTime? paidAt;

  Bill({
    required this.id,
    required this.billNumber,
    required this.date,
    this.customerId,
    this.customerName,
    this.customerPhone,
    required this.items,
    this.discountPercent = 0,
    required this.currency,
    this.notes,
    required this.createdAt,
    this.dueDate,
    this.isPaid = false,
    this.paidAt,
  });

  double get subtotal => items.fold(0, (sum, item) => sum + item.subtotal);
  double get totalGst => items.fold(0, (sum, item) => sum + item.gstAmount);
  double get discountAmount => (subtotal + totalGst) * discountPercent / 100;
  double get total => subtotal + totalGst - discountAmount;

  /// Status: 'paid' | 'unpaid' | 'overdue'
  String get status {
    if (isPaid) return 'paid';
    if (dueDate != null && dueDate!.isBefore(DateTime.now())) return 'overdue';
    return 'unpaid';
  }

  /// Mark this bill as paid now (or at given time).
  void markPaid([DateTime? when]) {
    isPaid = true;
    paidAt = when ?? DateTime.now();
  }

  /// Mark this bill as unpaid (revert).
  void markUnpaid() {
    isPaid = false;
    paidAt = null;
  }

  factory Bill.create({
    required String billNumber,
    String? customerId,
    String? customerName,
    String? customerPhone,
    required List<BillItem> items,
    double discountPercent = 0,
    required String currency,
    String? notes,
    DateTime? dueDate,
  }) {
    final now = DateTime.now();
    return Bill(
      id: now.millisecondsSinceEpoch.toString(),
      billNumber: billNumber,
      date: now,
      customerId: customerId,
      customerName: customerName,
      customerPhone: customerPhone,
      items: items,
      discountPercent: discountPercent,
      currency: currency,
      notes: notes,
      createdAt: now,
      dueDate: dueDate,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'billNumber': billNumber,
        'date': date.toIso8601String(),
        'customerId': customerId,
        'customerName': customerName,
        'customerPhone': customerPhone,
        'items': items.map((e) => e.toJson()).toList(),
        'discountPercent': discountPercent,
        'currency': currency,
        'notes': notes,
        'createdAt': createdAt.toIso8601String(),
        'dueDate': dueDate?.toIso8601String(),
        'isPaid': isPaid,
        'paidAt': paidAt?.toIso8601String(),
      };

  factory Bill.fromJson(Map<String, dynamic> json) => Bill(
        id: json['id'] as String,
        billNumber: json['billNumber'] as String,
        date: DateTime.parse(json['date'] as String),
        customerId: json['customerId'] as String?,
        customerName: json['customerName'] as String?,
        customerPhone: json['customerPhone'] as String?,
        items: (json['items'] as List)
            .map((e) => BillItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        discountPercent: (json['discountPercent'] as num?)?.toDouble() ?? 0,
        currency: json['currency'] as String,
        notes: json['notes'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String),
        dueDate: json['dueDate'] != null
            ? DateTime.parse(json['dueDate'] as String)
            : null,
        isPaid: (json['isPaid'] as bool?) ?? false,
        paidAt: json['paidAt'] != null
            ? DateTime.parse(json['paidAt'] as String)
            : null,
      );

  Bill copyWith({
    String? billNumber,
    DateTime? date,
    String? customerId,
    String? customerName,
    String? customerPhone,
    List<BillItem>? items,
    double? discountPercent,
    String? currency,
    String? notes,
    DateTime? dueDate,
    bool? isPaid,
    DateTime? paidAt,
  }) {
    return Bill(
      id: id,
      billNumber: billNumber ?? this.billNumber,
      date: date ?? this.date,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      items: items ?? this.items,
      discountPercent: discountPercent ?? this.discountPercent,
      currency: currency ?? this.currency,
      notes: notes ?? this.notes,
      createdAt: createdAt,
      dueDate: dueDate ?? this.dueDate,
      isPaid: isPaid ?? this.isPaid,
      paidAt: paidAt ?? this.paidAt,
    );
  }
}
