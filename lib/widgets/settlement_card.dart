// =============================================================================
// Note Counter Pro - Settlement Card Widget
// =============================================================================
// Renders a self-contained, screenshot-ready settlement summary for a
// GroupExpenseGroup. The parent screen wraps this widget in a Screenshot(
// controller: ...) so it can be captured as a PNG and shared via WhatsApp/SMS.
//
// Theme-aware: the card adapts to the device light/dark setting using the
// app's brand palette (AppColors). Dark mode keeps the premium navy + bright
// gold look; light mode renders a clean white card with readable amber-700
// accents and dark text — so it never appears as a black box in light mode.
// The captured share image therefore matches whatever theme the user is in,
// which is both readable and on-brand either way.
// =============================================================================

import 'package:flutter/material.dart';
import '../models/group_expense.dart';
import '../utils/app_localizations.dart';
import '../utils/constants.dart';

/// Brand color palette for the settlement card, derived from [AppColors].
/// Resolved once in [build] from the device brightness and passed to every
/// helper so colors stay consistent and readable in both themes.
class _CardPalette {
  final Color bg;          // card background
  final Color border;      // outer gold border
  final Color goldAccent;  // gold for icons / titles / section labels (readable on bg)
  final Color divider;     // faint gold divider line
  final Color primary;     // main body text
  final Color secondary;   // subtle / muted text
  final Color amount;      // numeric amount color
  final Color fromCol;     // "owes" (red side)
  final Color toCol;       // "receives" (green side)

  const _CardPalette({
    required this.bg,
    required this.border,
    required this.goldAccent,
    required this.divider,
    required this.primary,
    required this.secondary,
    required this.amount,
    required this.fromCol,
    required this.toCol,
  });

  factory _CardPalette.of(bool isDark) {
    if (isDark) {
      return _CardPalette(
        bg: const Color(0xFF0A0A1A),
        border: AppColors.primary,
        goldAccent: AppColors.primary,            // bright gold pops on navy
        divider: AppColors.primary.withOpacity(0.3),
        primary: Colors.white,
        secondary: const Color(0xFF9CA3AF),
        amount: AppColors.primary,
        fromCol: const Color(0xFFFCA5A5),         // soft red on navy
        toCol: const Color(0xFF86EFAC),           // soft green on navy
      );
    }
    return _CardPalette(
      bg: AppColors.bgCard,                       // clean white
      border: AppColors.primary,                  // gold border
      goldAccent: const Color(0xFFB45309),        // amber-700: readable on white
      divider: AppColors.primary.withOpacity(0.4),
      primary: AppColors.textPrimary,             // #1F2937 dark text
      secondary: AppColors.textSecondary,         // #6B7280 muted text
      amount: const Color(0xFFB45309),            // amber-700 amounts on white
      fromCol: AppColors.danger,                  // #EF4444 red
      toCol: AppColors.success,                   // #10B981 green
    );
  }
}

class SettlementCard extends StatelessWidget {
  final GroupExpenseGroup group;
  final List<GroupSettlement> settlements;
  final AppLocalizations loc;
  final bool isDark;

  const SettlementCard({
    super.key,
    required this.group,
    required this.settlements,
    required this.loc,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final sym = group.currencySymbol;
    final p = _CardPalette.of(isDark);
    return Container(
      width: 360,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: p.bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: p.border, width: 1.5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // === Header ===
          _buildHeader(p),
          const SizedBox(height: 16),
          _divider(p),
          const SizedBox(height: 12),

          // === Expenses list ===
          _sectionLabel(loc.t('totalExpense').toUpperCase(), p),
          const SizedBox(height: 8),
          if (group.expenses.isEmpty)
            _emptyLine(loc.t('noExpenses'), p)
          else
            ...group.expenses.map((e) => _expenseRow(e, sym, p)),
          const SizedBox(height: 12),
          _divider(p),
          const SizedBox(height: 12),

          // === Summary row ===
          _summaryRow(sym, p),
          const SizedBox(height: 12),
          _divider(p),
          const SizedBox(height: 12),

          // === Settlement ===
          _sectionLabel(loc.t('settlement').toUpperCase(), p),
          const SizedBox(height: 8),
          if (settlements.isEmpty)
            _emptyLine(loc.t('noSettlementNeeded'), p)
          else
            ...settlements.map((s) => _settlementRow(s, sym, p)),
          const SizedBox(height: 16),

          // === Footer / branding ===
          _footer(p),
        ],
      ),
    );
  }

  Widget _buildHeader(_CardPalette p) {
    return Row(
      children: [
        Icon(Icons.groups, color: p.goldAccent, size: 28),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                group.name,
                style: TextStyle(
                  color: p.goldAccent,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                _formatDate(group.updatedAt),
                style: TextStyle(color: p.secondary, fontSize: 11),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _divider(_CardPalette p) {
    return Container(
      height: 1,
      color: p.divider,
    );
  }

  Widget _sectionLabel(String text, _CardPalette p) {
    return Text(
      text,
      style: TextStyle(
        color: p.goldAccent,
        fontSize: 11,
        fontWeight: FontWeight.bold,
        letterSpacing: 0.8,
      ),
    );
  }

  Widget _emptyLine(String text, _CardPalette p) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Text(
        text,
        style: TextStyle(color: p.secondary, fontSize: 12),
      ),
    );
  }

  Widget _expenseRow(GroupExpense e, String sym, _CardPalette p) {
    final cat = GroupExpenseCategory.byKey(e.category);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(cat.icon, color: p.secondary, size: 14),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              e.paidBy,
              style: TextStyle(color: p.primary, fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
          if (e.description.isNotEmpty)
            Expanded(
              child: Text(
                e.description,
                style: TextStyle(color: p.secondary, fontSize: 11),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
              ),
            ),
          const SizedBox(width: 8),
          Text(
            '$sym${_fmt(e.amount)}',
            style: TextStyle(color: p.amount, fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(String sym, _CardPalette p) {
    return Row(
      children: [
        _summaryCell(loc.t('totalExpense'), '$sym${_fmt(group.totalExpenses)}', p),
        Container(width: 1, height: 32, color: p.divider),
        _summaryCell(loc.t('members'), '${group.members.length}', p),
        Container(width: 1, height: 32, color: p.divider),
        _summaryCell(loc.t('perPerson'), '$sym${_fmt(group.perPersonShare)}', p),
      ],
    );
  }

  Widget _summaryCell(String label, String value, _CardPalette p) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(color: p.amount, fontSize: 15, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(color: p.secondary, fontSize: 10),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _settlementRow(GroupSettlement s, String sym, _CardPalette p) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Text(
              s.from,
              style: TextStyle(color: p.fromCol, fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
          Icon(Icons.arrow_forward, color: p.secondary, size: 14),
          const SizedBox(width: 6),
          Expanded(
            flex: 4,
            child: Text(
              s.to,
              style: TextStyle(color: p.toCol, fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
          Text(
            '$sym${_fmt(s.amount)}',
            style: TextStyle(color: p.amount, fontSize: 13, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _footer(_CardPalette p) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.calculate, color: p.goldAccent, size: 14),
        const SizedBox(width: 6),
        Text(
          loc.t('calculatedBy'),
          style: TextStyle(color: p.secondary, fontSize: 10),
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
