// =============================================================================
// Note Counter Pro - Settlement Card Widget
// =============================================================================
// Renders a self-contained, screenshot-ready settlement summary for a
// GroupExpenseGroup. The parent screen wraps this widget in a Screenshot(
// controller: ...) so it can be captured as a PNG and shared via WhatsApp/SMS.
//
// The card uses a fixed dark-navy + gold theme (matching the app's brand)
// regardless of the device light/dark setting, so the shared image always
// looks consistent and readable on any recipient's phone.
// =============================================================================

import 'package:flutter/material.dart';
import '../models/group_expense.dart';
import '../utils/app_localizations.dart';

class SettlementCard extends StatelessWidget {
  final GroupExpenseGroup group;
  final List<GroupSettlement> settlements;
  final AppLocalizations loc;

  const SettlementCard({
    super.key,
    required this.group,
    required this.settlements,
    required this.loc,
  });

  @override
  Widget build(BuildContext context) {
    final sym = group.currencySymbol;
    return Container(
      width: 360,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0A1A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD4AF37), width: 1.5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // === Header ===
          _buildHeader(),
          const SizedBox(height: 16),
          _divider(),
          const SizedBox(height: 12),

          // === Expenses list ===
          _sectionLabel(loc.t('totalExpense').toUpperCase()),
          const SizedBox(height: 8),
          if (group.expenses.isEmpty)
            _emptyLine(loc.t('noExpenses'))
          else
            ...group.expenses.map((e) => _expenseRow(e, sym)),
          const SizedBox(height: 12),
          _divider(),
          const SizedBox(height: 12),

          // === Summary row ===
          _summaryRow(sym),
          const SizedBox(height: 12),
          _divider(),
          const SizedBox(height: 12),

          // === Settlement ===
          _sectionLabel(loc.t('settlement').toUpperCase()),
          const SizedBox(height: 8),
          if (settlements.isEmpty)
            _emptyLine(loc.t('noSettlementNeeded'))
          else
            ...settlements.map((s) => _settlementRow(s, sym)),
          const SizedBox(height: 16),

          // === Footer / branding ===
          _footer(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        const Icon(Icons.groups, color: Color(0xFFD4AF37), size: 28),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                group.name,
                style: const TextStyle(
                  color: Color(0xFFD4AF37),
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                _formatDate(group.updatedAt),
                style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 11),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _divider() {
    return Container(
      height: 1,
      color: const Color(0xFFD4AF37).withOpacity(0.3),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: Color(0xFFD4AF37),
        fontSize: 11,
        fontWeight: FontWeight.bold,
        letterSpacing: 0.8,
      ),
    );
  }

  Widget _emptyLine(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Text(
        text,
        style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 12),
      ),
    );
  }

  Widget _expenseRow(GroupExpense e, String sym) {
    final cat = GroupExpenseCategory.byKey(e.category);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(cat.icon, color: const Color(0xFF9CA3AF), size: 14),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              e.paidBy,
              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
          if (e.description.isNotEmpty)
            Expanded(
              child: Text(
                e.description,
                style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 11),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
              ),
            ),
          const SizedBox(width: 8),
          Text(
            '$sym${_fmt(e.amount)}',
            style: const TextStyle(color: Color(0xFFFBBF24), fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(String sym) {
    return Row(
      children: [
        _summaryCell(loc.t('totalExpense'), '$sym${_fmt(group.totalExpenses)}'),
        Container(width: 1, height: 32, color: const Color(0xFFD4AF37).withOpacity(0.3)),
        _summaryCell(loc.t('members'), '${group.members.length}'),
        Container(width: 1, height: 32, color: const Color(0xFFD4AF37).withOpacity(0.3)),
        _summaryCell(loc.t('perPerson'), '$sym${_fmt(group.perPersonShare)}'),
      ],
    );
  }

  Widget _summaryCell(String label, String value) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(color: Color(0xFFFBBF24), fontSize: 15, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 10),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _settlementRow(GroupSettlement s, String sym) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Text(
              s.from,
              style: const TextStyle(color: Color(0xFFFCA5A5), fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
          const Icon(Icons.arrow_forward, color: Color(0xFF9CA3AF), size: 14),
          const SizedBox(width: 6),
          Expanded(
            flex: 4,
            child: Text(
              s.to,
              style: const TextStyle(color: Color(0xFF86EFAC), fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
          Text(
            '$sym${_fmt(s.amount)}',
            style: const TextStyle(color: Color(0xFFFBBF24), fontSize: 13, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _footer() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.calculate, color: Color(0xFFD4AF37), size: 14),
        const SizedBox(width: 6),
        Text(
          loc.t('calculatedBy'),
          style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 10),
        ),
      ],
    );
  }

  String _fmt(double v) {
    if (v == v.roundToDouble()) return v.round().toString();
    return v.toStringAsFixed(2);
  }

  String _formatDate(DateTime d) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }
}
