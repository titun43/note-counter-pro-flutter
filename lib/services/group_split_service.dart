// =============================================================================
// Note Counter Pro - Group Split Service
// =============================================================================
// Persists GroupExpenseGroup objects in SharedPreferences as a JSON list and
// computes the minimum-transaction settlement for a group on demand.
//
// No Firebase / cloud backend: all data lives on-device. One user manages the
// group and shares the rendered settlement image/PDF via WhatsApp/SMS — the
// recipients never need the app.
//
// Settlement algorithm: greedy min-transactions.
//   1. Compute each member's balance = (they paid) - (per-person share).
//      Positive = creditor (owed), negative = debtor (owes).
//   2. Repeatedly pair the largest debtor with the largest creditor, transfer
//      min(|debtor|, creditor), update balances, drop settled members.
//   3. Continue until everyone is ~0 (within a tiny epsilon for float math).
// This produces the minimum number of payment transactions to settle the group.
// =============================================================================

import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/group_expense.dart';

class GroupSplitService {
  static const String _prefsKey = 'group_split_groups';

  static final GroupSplitService _instance = GroupSplitService._();
  factory GroupSplitService() => _instance;
  GroupSplitService._();

  final List<GroupExpenseGroup> _groups = [];

  List<GroupExpenseGroup> get all => List.unmodifiable(_groups);

  /// Load groups from SharedPreferences. Call once at app startup.
  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw != null && raw.isNotEmpty) {
        final list = jsonDecode(raw) as List;
        _groups
          ..clear()
          ..addAll(list
              .map((e) => GroupExpenseGroup.fromJson(e as Map<String, dynamic>))
              .toList());
      }
      debugPrint('GroupSplitService: loaded ${_groups.length} groups');
    } catch (e) {
      debugPrint('GroupSplitService init failed: $e');
    }
  }

  GroupExpenseGroup? getById(String id) {
    try {
      return _groups.firstWhere((g) => g.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Create a new group. Returns the created group. Requires at least one
  /// member; duplicate member names (case-insensitive) are rejected.
  Future<GroupExpenseGroup?> createGroup({
    required String name,
    required List<GroupMember> members,
    String currencySymbol = '₹',
  }) async {
    if (name.trim().isEmpty || members.isEmpty) return null;
    // De-duplicate member names case-insensitively.
    final seen = <String>{};
    final unique = <GroupMember>[];
    for (final m in members) {
      final key = m.name.trim().toLowerCase();
      if (key.isEmpty || seen.contains(key)) continue;
      seen.add(key);
      unique.add(m);
    }
    if (unique.isEmpty) return null;

    final group = GroupExpenseGroup.create(
      name: name,
      members: unique,
      currencySymbol: currencySymbol,
    );
    _groups.insert(0, group);
    await _persist();
    return group;
  }

  /// Rename a group and/or replace its member list (preserves expenses that
  /// still reference an existing member name).
  Future<void> updateGroup(
    String id, {
    String? name,
    List<GroupMember>? members,
    String? currencySymbol,
  }) async {
    final i = _groups.indexWhere((g) => g.id == id);
    if (i == -1) return;
    _groups[i] = _groups[i].copyWith(
      name: name?.trim(),
      members: members,
      currencySymbol: currencySymbol,
      updatedAt: DateTime.now(),
    );
    await _persist();
  }

  /// Delete a group by id.
  Future<void> deleteGroup(String id) async {
    _groups.removeWhere((g) => g.id == id);
    await _persist();
  }

  /// Add an expense to a group. [paidBy] must match an existing member name.
  Future<void> addExpense(String groupId, GroupExpense expense) async {
    final i = _groups.indexWhere((g) => g.id == groupId);
    if (i == -1) return;
    final group = _groups[i];
    if (!group.members.any((m) => m.name == expense.paidBy)) {
      debugPrint('GroupSplitService.addExpense: paidBy "${expense.paidBy}" '
          'is not a member of group "${group.name}"');
      return;
    }
    _groups[i] = group.copyWith(
      expenses: [...group.expenses, expense],
      updatedAt: DateTime.now(),
    );
    await _persist();
  }

  /// Replace an expense by id.
  Future<void> updateExpense(
    String groupId,
    String expenseId,
    GroupExpense updated,
  ) async {
    final i = _groups.indexWhere((g) => g.id == groupId);
    if (i == -1) return;
    final group = _groups[i];
    final expenses = group.expenses.map((e) {
      return e.id == expenseId ? updated : e;
    }).toList();
    _groups[i] = group.copyWith(expenses: expenses, updatedAt: DateTime.now());
    await _persist();
  }

  /// Remove an expense by id.
  Future<void> deleteExpense(String groupId, String expenseId) async {
    final i = _groups.indexWhere((g) => g.id == groupId);
    if (i == -1) return;
    final group = _groups[i];
    _groups[i] = group.copyWith(
      expenses: group.expenses.where((e) => e.id != expenseId).toList(),
      updatedAt: DateTime.now(),
    );
    await _persist();
  }

  /// Compute the minimum-transaction settlement for a group. Returns a list of
  /// "from owes to amount" instructions. Empty list = everyone is settled.
  List<GroupSettlement> settle(GroupExpenseGroup group) {
    if (group.members.isEmpty || group.expenses.isEmpty) return const [];

    // Round balances to 2 decimals to avoid float dust (e.g. 0.0000001).
    final balances = <String, double>{};
    for (final m in group.members) {
      balances[m.name] =
          double.parse(group.balanceFor(m.name).toStringAsFixed(2));
    }

    final settlements = <GroupSettlement>[];
    const epsilon = 0.009; // tolerate sub-cent rounding

    while (true) {
      // Debtors (owe) sorted most-negative first; creditors (owed) largest first.
      final debtors = balances.entries
          .where((e) => e.value < -epsilon)
          .toList()
        ..sort((a, b) => a.value.compareTo(b.value)); // asc → most negative first
      final creditors = balances.entries
          .where((e) => e.value > epsilon)
          .toList()
        ..sort((a, b) => b.value.compareTo(a.value)); // desc → largest first

      if (debtors.isEmpty || creditors.isEmpty) break;

      final debtor = debtors.first;
      final creditor = creditors.first;
      final transfer = math.min(-debtor.value, creditor.value);

      settlements.add(GroupSettlement(
        from: debtor.key,
        to: creditor.key,
        amount: double.parse(transfer.toStringAsFixed(2)),
      ));

      balances[debtor.key] =
          double.parse((debtor.value + transfer).toStringAsFixed(2));
      balances[creditor.key] =
          double.parse((creditor.value - transfer).toStringAsFixed(2));
    }

    return settlements;
  }

  /// Total amount a member is owed (sum of incoming settlements) minus what
  /// they owe (outgoing). Positive = net they receive.
  double netReceived(GroupExpenseGroup group, String memberName) {
    final settlements = settle(group);
    double net = 0.0;
    for (final s in settlements) {
      if (s.to == memberName) net += s.amount;
      if (s.from == memberName) net -= s.amount;
    }
    return net;
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = jsonEncode(_groups.map((g) => g.toJson()).toList());
      await prefs.setString(_prefsKey, raw);
    } catch (e) {
      debugPrint('GroupSplitService persist failed: $e');
    }
  }
}
