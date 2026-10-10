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
    quantity: json['quantity'] as int,
    price: (json['price'] as num).toDouble(),
    gstPercent: json['gstPercent'] != null
        ? (json['gstPercent'] as num).toDouble()
        : null,
  );
}

class Bill {
  final String id;
  final String billNumber;
  final DateTime date;
  final String? customerId;
  final String? customerName;
  List<BillItem> items;
  double discountPercent;
  String currency;
  String? notes;
  final DateTime createdAt;
  DateTime? dueDate;
  
  Bill({
    required this.id,
    required this.billNumber,
    required this.date,
    this.customerId,
    this.customerName,
    required this.items,
    this.discountPercent = 0,
    required this.currency,
    this.notes,
    required this.createdAt,
    this.dueDate,
  });
  
  double get subtotal => items.fold(0, (sum, item) => sum + item.subtotal);
  double get totalGst => items.fold(0, (sum, item) => sum + item.gstAmount);
  double get discountAmount => (subtotal + totalGst) * discountPercent / 100;
  double get total => subtotal + totalGst - discountAmount;
  
  factory Bill.create({
    required String billNumber,
    String? customerId,
    String? customerName,
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
    'items': items.map((e) => e.toJson()).toList(),
    'discountPercent': discountPercent,
    'currency': currency,
    'notes': notes,
    'createdAt': createdAt.toIso8601String(),
    'dueDate': dueDate?.toIso8601String(),
  };
  
  factory Bill.fromJson(Map<String, dynamic> json) => Bill(
    id: json['id'] as String,
    billNumber: json['billNumber'] as String,
    date: DateTime.parse(json['date'] as String),
    customerId: json['customerId'] as String?,
    customerName: json['customerName'] as String?,
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
  );
}
