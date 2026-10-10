class Customer {
  final String id;
  String name;
  String? phone;
  String? email;
  String? address;
  String? notes;
  double totalCredit;
  double totalDebit;
  final DateTime createdAt;
  DateTime? updatedAt;
  
  Customer({
    required this.id,
    required this.name,
    this.phone,
    this.email,
    this.address,
    this.notes,
    this.totalCredit = 0,
    this.totalDebit = 0,
    required this.createdAt,
    this.updatedAt,
  });
  
  double get balance => totalCredit - totalDebit;
  
  factory Customer.create({
    required String name,
    String? phone,
    String? email,
    String? address,
    String? notes,
  }) {
    final now = DateTime.now();
    return Customer(
      id: now.millisecondsSinceEpoch.toString(),
      name: name,
      phone: phone,
      email: email,
      address: address,
      notes: notes,
      createdAt: now,
      updatedAt: now,
    );
  }
  
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'phone': phone,
    'email': email,
    'address': address,
    'notes': notes,
    'totalCredit': totalCredit,
    'totalDebit': totalDebit,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt?.toIso8601String(),
  };
  
  factory Customer.fromJson(Map<String, dynamic> json) => Customer(
    id: json['id'] as String,
    name: json['name'] as String,
    phone: json['phone'] as String?,
    email: json['email'] as String?,
    address: json['address'] as String?,
    notes: json['notes'] as String?,
    totalCredit: (json['totalCredit'] as num?)?.toDouble() ?? 0,
    totalDebit: (json['totalDebit'] as num?)?.toDouble() ?? 0,
    createdAt: DateTime.parse(json['createdAt'] as String),
    updatedAt: json['updatedAt'] != null
        ? DateTime.parse(json['updatedAt'] as String)
        : null,
  );
  
  Customer copyWith({
    String? name,
    String? phone,
    String? email,
    String? address,
    String? notes,
    double? totalCredit,
    double? totalDebit,
    DateTime? updatedAt,
  }) {
    return Customer(
      id: id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      address: address ?? this.address,
      notes: notes ?? this.notes,
      totalCredit: totalCredit ?? this.totalCredit,
      totalDebit: totalDebit ?? this.totalDebit,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
