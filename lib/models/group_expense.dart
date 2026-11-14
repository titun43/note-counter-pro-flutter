// =============================================================================
// Note Counter Pro - Group Expense Model
// =============================================================================
// Models a "Group Split" group: a set of members sharing expenses that must be
// settled evenly. Each group holds members (name + optional UPI ID for payment
// QR) and a list of expenses (who paid, amount, description, category).
//
// Settlement is computed by GroupSplitService (not stored) from the expense
// list — the app always derives who-owes-whom from current expenses, so edits
// (add/delete/edit) never leave stale settlement data.
// =============================================================================

import 'package:flutter/material.dart' show IconData, Icons;

/// A single expense inside a group.
///
/// [paidBy] must match a member name in the owning group. [category] uses one
/// of [GroupExpenseCategory.keys]. [amount] is stored as a double but entered
/// by the user as a currency string.
class GroupExpense {
  final String id;
  final String paidBy;
  final double amount;
  final String description;
  final String category; // GroupExpenseCategory.keys
  final DateTime date;

  GroupExpense({
    required this.id,
    required this.paidBy,
    required this.amount,
    required this.description,
    required this.category,
    required this.date,
  });

  factory GroupExpense.create({
    required String paidBy,
    required double amount,
    required String description,
    String category = 'misc',
    DateTime? date,
  }) {
    return GroupExpense(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      paidBy: paidBy.trim(),
      amount: amount,
      description: description.trim(),
      category: category,
      date: date ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'paidBy': paidBy,
        'amount': amount,
        'description': description,
        'category': category,
        'date': date.toIso8601String(),
      };

  factory GroupExpense.fromJson(Map<String, dynamic> json) {
    return GroupExpense(
      id: json['id'] as String,
      paidBy: json['paidBy'] as String,
      amount: (json['amount'] as num).toDouble(),
      description: json['description'] as String? ?? '',
      category: json['category'] as String? ?? 'misc',
      date: DateTime.parse(json['date'] as String),
    );
  }

  GroupExpense copyWith({
    String? paidBy,
    double? amount,
    String? description,
    String? category,
  }) {
    return GroupExpense(
      id: id,
      paidBy: paidBy ?? this.paidBy,
      amount: amount ?? this.amount,
      description: description ?? this.description,
      category: category ?? this.category,
      date: date,
    );
  }
}

/// A member of a group. [upiId] is optional and used only to render a payment
/// QR on the settlement screen so others can scan and pay that member.
class GroupMember {
  final String name;
  final String? upiId;

  GroupMember({required this.name, this.upiId});

  Map<String, dynamic> toJson() => {
        'name': name,
        'upiId': upiId,
      };

  factory GroupMember.fromJson(Map<String, dynamic> json) {
    return GroupMember(
      name: json['name'] as String,
      upiId: json['upiId'] as String?,
    );
  }

  GroupMember copyWith({String? name, String? upiId}) {
    return GroupMember(
      name: name ?? this.name,
      upiId: upiId ?? this.upiId,
    );
  }
}

/// A settlement instruction derived from a group's expenses:
/// [from] owes [to] the [amount]. Produced by GroupSplitService.settle().
class GroupSettlement {
  final String from;
  final String to;
  final double amount;

  GroupSettlement({
    required this.from,
    required this.to,
    required this.amount,
  });

  @override
  String toString() => '$from → $to: ₹${amount.toStringAsFixed(2)}';
}

/// A group of people sharing expenses. Holds members and expenses; settlement
/// is always recomputed on demand. [currencySymbol] lets each group keep its
/// own currency (default ₹) for display + share images.
class GroupExpenseGroup {
  final String id;
  final String name;
  final List<GroupMember> members;
  final List<GroupExpense> expenses;
  final String currencySymbol;
  final DateTime createdAt;
  final DateTime updatedAt;

  GroupExpenseGroup({
    required this.id,
    required this.name,
    required this.members,
    required this.expenses,
    this.currencySymbol = '₹',
    required this.createdAt,
    required this.updatedAt,
  });

  factory GroupExpenseGroup.create({
    required String name,
    required List<GroupMember> members,
    String currencySymbol = '₹',
  }) {
    final now = DateTime.now();
    return GroupExpenseGroup(
      id: now.millisecondsSinceEpoch.toString(),
      name: name.trim(),
      members: members,
      expenses: const [],
      currencySymbol: currencySymbol,
      createdAt: now,
      updatedAt: now,
    );
  }

  /// Total of all expenses in the group.
  double get totalExpenses =>
      expenses.fold(0.0, (sum, e) => sum + e.amount);

  /// Per-person share (total ÷ member count). Returns 0 if no members.
  double get perPersonShare {
    if (members.isEmpty) return 0.0;
    return totalExpenses / members.length;
  }

  /// Net balance for a member: positive = they are owed money, negative = they
  /// owe money, zero = settled.
  double balanceFor(String memberName) {
    final paid = expenses
        .where((e) => e.paidBy == memberName)
        .fold(0.0, (sum, e) => sum + e.amount);
    return paid - perPersonShare;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'members': members.map((m) => m.toJson()).toList(),
        'expenses': expenses.map((e) => e.toJson()).toList(),
        'currencySymbol': currencySymbol,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory GroupExpenseGroup.fromJson(Map<String, dynamic> json) {
    return GroupExpenseGroup(
      id: json['id'] as String,
      name: json['name'] as String,
      members: (json['members'] as List)
          .map((e) => GroupMember.fromJson(e as Map<String, dynamic>))
          .toList(),
      expenses: (json['expenses'] as List? ?? [])
          .map((e) => GroupExpense.fromJson(e as Map<String, dynamic>))
          .toList(),
      currencySymbol: json['currencySymbol'] as String? ?? '₹',
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  GroupExpenseGroup copyWith({
    String? name,
    List<GroupMember>? members,
    List<GroupExpense>? expenses,
    String? currencySymbol,
    DateTime? updatedAt,
  }) {
    return GroupExpenseGroup(
      id: id,
      name: name ?? this.name,
      members: members ?? this.members,
      expenses: expenses ?? this.expenses,
      currencySymbol: currencySymbol ?? this.currencySymbol,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }
}

/// Expense category metadata. [key] is stored on GroupExpense; [icon] is the
/// Material icon used in the UI; the localized label is looked up via
/// AppLocalizations using 'groupCategory_<key>'.
class GroupExpenseCategory {
  final String key;
  final IconData icon;

  const GroupExpenseCategory({required this.key, required this.icon});

  static const List<GroupExpenseCategory> all = [
    GroupExpenseCategory(key: 'food', icon: Icons.restaurant),
    GroupExpenseCategory(key: 'transport', icon: Icons.directions_car),
    GroupExpenseCategory(key: 'accommodation', icon: Icons.hotel),
    GroupExpenseCategory(key: 'shopping', icon: Icons.shopping_bag),
    GroupExpenseCategory(key: 'entertainment', icon: Icons.movie),
    GroupExpenseCategory(key: 'misc', icon: Icons.category),
  ];

  static GroupExpenseCategory byKey(String key) {
    return all.firstWhere(
      (c) => c.key == key,
      orElse: () => all.last,
    );
  }
}
