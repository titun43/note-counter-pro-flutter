class Entry {
  final String id;
  final DateTime date;
  final String type;
  final double amount;
  final String currency;
  final String? customerId;
  final String? customerName;
  final String? notes;
  final Map<String, int>? denominationCounts;
  final String? category;
  final DateTime createdAt;
  
  Entry({
    required this.id,
    required this.date,
    required this.type,
    required this.amount,
    required this.currency,
    this.customerId,
    this.customerName,
    this.notes,
    this.denominationCounts,
    this.category,
    required this.createdAt,
  });
  
  factory Entry.create({
    required String type,
    required double amount,
    required String currency,
    String? customerId,
    String? customerName,
    String? notes,
    Map<String, int>? denominationCounts,
    String? category,
  }) {
    final now = DateTime.now();
    return Entry(
      id: now.millisecondsSinceEpoch.toString(),
      date: now,
      type: type,
      amount: amount,
      currency: currency,
      customerId: customerId,
      customerName: customerName,
      notes: notes,
      denominationCounts: denominationCounts,
      category: category,
      createdAt: now,
    );
  }
  
  Map<String, dynamic> toJson() => {
    'id': id,
    'date': date.toIso8601String(),
    'type': type,
    'amount': amount,
    'currency': currency,
    'customerId': customerId,
    'customerName': customerName,
    'notes': notes,
    'denominationCounts': denominationCounts,
    'category': category,
    'createdAt': createdAt.toIso8601String(),
  };
  
  factory Entry.fromJson(Map<String, dynamic> json) => Entry(
    id: json['id'] as String,
    date: DateTime.parse(json['date'] as String),
    type: json['type'] as String,
    amount: (json['amount'] as num).toDouble(),
    currency: json['currency'] as String,
    customerId: json['customerId'] as String?,
    customerName: json['customerName'] as String?,
    notes: json['notes'] as String?,
    denominationCounts: json['denominationCounts'] != null
        ? Map<String, int>.from(json['denominationCounts'] as Map)
        : null,
    category: json['category'] as String?,
    createdAt: DateTime.parse(json['createdAt'] as String),
  );
}
