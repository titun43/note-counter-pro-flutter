// =============================================================================
// Note Counter Pro - Group Detail Screen (Expenses + Settlement)
// =============================================================================
// Shows one GroupExpenseGroup: summary, expense list (add/edit/delete), and
// the auto-computed settlement. Provides three share paths:
//   1. Share Image — capture the SettlementCard as PNG → WhatsApp (and others).
//   2. Share SMS — plain-text settlement summary → SMS app (multi-recipient).
//   3. Export PDF — GroupSplitPdfService generates a settlement PDF.
// Tapping a settlement row opens a UPI payment QR for the receiver (if they
// have a UPI ID), so the debtor can scan and pay directly.
// =============================================================================

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import '../models/group_expense.dart';
import '../services/group_split_service.dart';
import '../services/admob_service.dart';
import '../services/feedback_service.dart';
import '../services/group_split_pdf_service.dart';
import '../utils/constants.dart';
import '../utils/app_localizations.dart';
import '../widgets/banner_ad_widget.dart';
import '../widgets/settlement_card.dart';

class GroupDetailScreen extends StatefulWidget {
  final String groupId;
  const GroupDetailScreen({super.key, required this.groupId});

  @override
  State<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends State<GroupDetailScreen> {
  final _service = GroupSplitService();
  final _screenshotController = ScreenshotController();
  final _pdfService = GroupSplitPdfService();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final loc = context.loc;
    final group = _service.getById(widget.groupId);

    if (group == null) {
      return Scaffold(
        backgroundColor: isDark ? AppColors.bgDark : AppColors.bgLight,
        appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
        body: Center(child: Text(loc.t('noGroups'))),
      );
    }

    final settlements = _service.settle(group);
    final sym = group.currencySymbol;

    return Scaffold(
      backgroundColor: isDark ? AppColors.bgDark : AppColors.bgLight,
      body: SafeArea(
        // top: true (default) — pushes BannerAd below the system status bar
        // so it no longer overlaps the mobile clock/time. Matches the pattern
        // used by other standalone pushed screens (calculator_screen, etc.).
        child: Column(
          children: [
            const BannerAdWidget(),
            // === Header ===
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: AppColors.primary),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          group.name,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            fontFamily: 'KhataHandwriting',
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '${group.members.length} ${loc.t("memberCount")} · '
                          '$sym${group.totalExpenses.toStringAsFixed(0)} ${loc.t("totalExpense")}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, color: AppColors.primary),
                    color: isDark ? const Color(0xFF16213E) : Colors.white,
                    onSelected: (v) {
                      if (v == 'image') _shareImage(group, settlements);
                      else if (v == 'sms') _shareSms(group, settlements);
                      else if (v == 'pdf') _exportPdf(group, settlements);
                    },
                    itemBuilder: (ctx) => [
                      PopupMenuItem(value: 'image', child: _menuRow(Icons.image, loc.t('shareImage'))),
                      PopupMenuItem(value: 'sms', child: _menuRow(Icons.sms, loc.t('shareSms'))),
                      PopupMenuItem(value: 'pdf', child: _menuRow(Icons.picture_as_pdf, loc.t('exportPdf'))),
                    ],
                  ),
                ],
              ),
            ),

            // === Body ===
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Summary card
                    _buildSummaryCard(group, settlements, theme, isDark, loc, sym),
                    const SizedBox(height: 16),

                    // Settlement section — the SettlementCard is shown
                    // visibly AND wrapped in a Screenshot controller so the
                    // "Share Image" button can capture exactly what the user
                    // sees. Tappable settlement tiles (for UPI QR payment)
                    // follow below.
                    _sectionTitle(loc.t('settlement'), Icons.balance, theme),
                    const SizedBox(height: 8),
                    Screenshot(
                      controller: _screenshotController,
                      child: SettlementCard(
                        group: group,
                        settlements: settlements,
                        loc: loc,
                        isDark: isDark,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (settlements.isEmpty)
                      _infoCard(loc.t('noSettlementNeeded'), Icons.check_circle, AppColors.success, isDark, theme)
                    else
                      ...settlements.map((s) => _settlementTile(s, group, sym, theme, isDark, loc)),
                    const SizedBox(height: 16),

                    // Expenses section
                    Row(
                      children: [
                        Expanded(child: _sectionTitle(loc.t('totalExpense'), Icons.receipt_long, theme)),
                        TextButton.icon(
                          onPressed: () => _showAddExpenseDialog(group),
                          icon: const Icon(Icons.add, color: AppColors.primary),
                          label: Text(loc.t('addExpense'), style: const TextStyle(color: AppColors.primary)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (group.expenses.isEmpty)
                      _infoCard(loc.t('noExpensesDesc'), Icons.receipt_outlined, AppColors.textSecondary, isDark, theme)
                    else
                      ...group.expenses.map((e) => _expenseTile(e, group, sym, theme, isDark, loc)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          FeedbackService().tap();
          _showAddExpenseDialog(group);
        },
        icon: const Icon(Icons.add, color: Color(0xFF1A1A2E)),
        label: Text(loc.t('addExpense'), style: const TextStyle(color: Color(0xFF1A1A2E), fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.primary,
      ),
    );
  }

  // === Widgets ===========================================================

  Widget _menuRow(IconData icon, String label) {
    return Row(children: [Icon(icon, size: 20), const SizedBox(width: 12), Text(label)]);
  }

  Widget _sectionTitle(String text, IconData icon, ThemeData theme) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(width: 8),
        Text(text, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: AppColors.primary)),
      ],
    );
  }

  Widget _buildSummaryCard(GroupExpenseGroup g, List<GroupSettlement> settlements,
      ThemeData theme, bool isDark, AppLocalizations loc, String sym) {
    // Theme-aware palette matching the app's brand (amber/gold + navy).
    // Dark mode keeps the premium navy→black gradient with bright gold accents.
    // Light mode uses a clean white→faint-amber card with readable dark/gold
    // text — previously the light branch also used dark navy colors, making the
    // whole card appear black in light mode.
    final gradientColors = isDark
        ? [const Color(0xFF16213E), const Color(0xFF0A0A1A)]
        : [AppColors.bgCard, AppColors.primary.withOpacity(0.10)];
    final totalColor = isDark ? AppColors.primary : const Color(0xFFB45309); // amber-700: readable on white
    final membersColor = isDark ? Colors.white : AppColors.textPrimary;
    final perPersonColor = isDark ? const Color(0xFF86EFAC) : AppColors.success;
    final labelColor = isDark ? AppColors.textSecondaryDark : AppColors.textSecondary;
    final dividerColor = AppColors.primary.withOpacity(isDark ? 0.3 : 0.4);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: dividerColor),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _summaryCell(loc.t('totalExpense'), '$sym${_fmt(g.totalExpenses)}', totalColor, labelColor),
          _vDivider(dividerColor),
          _summaryCell(loc.t('members'), '${g.members.length}', membersColor, labelColor),
          _vDivider(dividerColor),
          _summaryCell(loc.t('perPerson'), '$sym${_fmt(g.perPersonShare)}', perPersonColor, labelColor),
        ],
      ),
    );
  }

  Widget _summaryCell(String label, String value, Color valueColor, Color labelColor) {
    return Expanded(
      child: Column(
        children: [
          Text(value, style: TextStyle(color: valueColor, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(color: labelColor, fontSize: 10), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _vDivider(Color color) => Container(width: 1, height: 36, color: color);

  Widget _infoCard(String text, IconData icon, Color color, bool isDark, ThemeData theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: (isDark ? AppColors.bgCardDark : AppColors.bgCard),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(width: 12),
        Expanded(child: Text(text, style: theme.textTheme.bodyMedium)),
      ]),
    );
  }

  Widget _settlementTile(GroupSettlement s, GroupExpenseGroup g, String sym, ThemeData theme, bool isDark, AppLocalizations loc) {
    final receiver = g.members.where((m) => m.name == s.to).first;
    final hasUpi = receiver.upiId != null && receiver.upiId!.isNotEmpty;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: isDark ? AppColors.bgCardDark : AppColors.bgCard,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: const CircleAvatar(backgroundColor: Color(0x22EF4444), child: Icon(Icons.arrow_outward, color: AppColors.danger, size: 18)),
        title: RichText(
          text: TextSpan(
            style: theme.textTheme.bodyLarge,
            children: [
              TextSpan(text: s.from, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.danger)),
              TextSpan(text: '  →  ', style: TextStyle(color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary)),
              TextSpan(text: s.to, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.success)),
            ],
          ),
        ),
        subtitle: hasUpi ? Text(loc.t('scanToPay'), style: const TextStyle(color: AppColors.info, fontSize: 11)) : null,
        trailing: Text(
          '$sym${_fmt(s.amount)}',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.primary),
        ),
        onTap: () {
          FeedbackService().tap();
          if (hasUpi) {
            _showUpiQrDialog(s, receiver.upiId!, sym, loc);
          }
        },
      ),
    );
  }

  Widget _expenseTile(GroupExpense e, GroupExpenseGroup g, String sym, ThemeData theme, bool isDark, AppLocalizations loc) {
    final cat = GroupExpenseCategory.byKey(e.category);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: isDark ? AppColors.bgCardDark : AppColors.bgCard,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 40, height: 40,
          decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
          child: Icon(cat.icon, color: AppColors.primary, size: 20),
        ),
        title: Text(e.description.isEmpty ? loc.t('groupCategory_${e.category}') : e.description,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text('${e.paidBy} · ${loc.t("groupCategory_${e.category}")} · ${_formatDate(e.date)}',
            style: TextStyle(color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary, fontSize: 11)),
        trailing: Text('$sym${_fmt(e.amount)}', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
        onLongPress: () {
          FeedbackService().tap();
          _showExpenseOptions(e, g, loc);
        },
      ),
    );
  }

  // === Add / edit / delete expense =======================================

  void _showAddExpenseDialog(GroupExpenseGroup g) => _showExpenseDialog(g, null);

  void _showExpenseDialog(GroupExpenseGroup g, GroupExpense? existing) {
    final loc = context.loc;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final amountCtl = TextEditingController(text: existing == null ? '' : _fmt(existing.amount));
    final descCtl = TextEditingController(text: existing?.description ?? '');
    String paidBy = existing?.paidBy ?? g.members.first.name;
    String category = existing?.category ?? 'misc';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Container(
              padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
              decoration: BoxDecoration(
                color: isDark ? AppColors.bgCardDark : AppColors.bgCard,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SafeArea(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(child: Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(color: AppColors.textSecondary.withOpacity(0.3), borderRadius: BorderRadius.circular(2)))),
                        Text(existing == null ? loc.t('addExpense') : loc.t('editExpense'),
                            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 16),

                        // Who paid
                        _label(loc.t('whoPaid'), theme),
                        DropdownButtonFormField<String>(
                          value: paidBy,
                          decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                          items: g.members.map((m) => DropdownMenuItem(value: m.name, child: Text(m.name))).toList(),
                          onChanged: (v) => setSheetState(() => paidBy = v ?? paidBy),
                        ),
                        const SizedBox(height: 12),

                        // Amount
                        _label(loc.t('amountLabel'), theme),
                        TextField(
                          controller: amountCtl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(hintText: loc.t('enterAmount'), border: const OutlineInputBorder(), isDense: true),
                        ),
                        const SizedBox(height: 12),

                        // Description
                        _label(loc.t('descriptionLabel'), theme),
                        TextField(
                          controller: descCtl,
                          decoration: InputDecoration(hintText: loc.t('enterDescription'), border: const OutlineInputBorder(), isDense: true),
                        ),
                        const SizedBox(height: 12),

                        // Category
                        _label(loc.t('categoryLabel'), theme),
                        Wrap(
                          spacing: 8,
                          children: GroupExpenseCategory.all.map((c) {
                            final selected = c.key == category;
                            return ChoiceChip(
                              label: Row(mainAxisSize: MainAxisSize.min, children: [
                                Icon(c.icon, size: 16),
                                const SizedBox(width: 4),
                                Text(loc.t('groupCategory_${c.key}')),
                              ]),
                              selected: selected,
                              selectedColor: AppColors.primary,
                              labelStyle: TextStyle(color: selected ? const Color(0xFF1A1A2E) : null),
                              onSelected: (_) => setSheetState(() => category = c.key),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 20),

                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: const Color(0xFF1A1A2E),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            onPressed: () async {
                              final amt = double.tryParse(amountCtl.text.trim());
                              if (amt == null || amt <= 0) {
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  SnackBar(content: Text(loc.t('enterAmount')), backgroundColor: AppColors.danger));
                                return;
                              }
                              if (existing == null) {
                                await _service.addExpense(g.id, GroupExpense.create(
                                  paidBy: paidBy, amount: amt, description: descCtl.text, category: category));
                              } else {
                                await _service.updateExpense(g.id, existing.id, existing.copyWith(
                                  paidBy: paidBy, amount: amt, description: descCtl.text, category: category));
                              }
                              AdMobService.showInterstitial();
                              if (ctx.mounted) Navigator.pop(ctx);
                              setState(() {});
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(loc.t('expenseAdded')), backgroundColor: AppColors.success));
                            },
                            child: Text(loc.t('saveBtn'), style: const TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showExpenseOptions(GroupExpense e, GroupExpenseGroup g, AppLocalizations loc) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).brightness == Brightness.dark ? AppColors.bgCardDark : AppColors.bgCard,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(leading: const Icon(Icons.edit, color: AppColors.info), title: Text(loc.t('editExpense')),
              onTap: () { Navigator.pop(ctx); _showExpenseDialog(g, e); }),
            ListTile(leading: const Icon(Icons.delete, color: AppColors.danger), title: Text(loc.t('deleteExpense')),
              onTap: () async {
                Navigator.pop(ctx);
                await _service.deleteExpense(g.id, e.id);
                setState(() {});
              }),
          ],
        ),
      ),
    );
  }

  // === UPI payment QR dialog =============================================

  void _showUpiQrDialog(GroupSettlement s, String upiId, String sym, AppLocalizations loc) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final upiUrl = 'upi://pay?pa=${Uri.encodeComponent(upiId)}'
        '&pn=${Uri.encodeComponent(s.to)}'
        '&am=${s.amount.toStringAsFixed(2)}'
        '&tn=${Uri.encodeComponent("Settlement ${s.from} → ${s.to}")}'
        '&cu=INR';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppColors.bgCardDark : AppColors.bgCard,
        title: Text(loc.t('scanToPay'), textAlign: TextAlign.center),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${s.from} → ${s.to}', style: theme.textTheme.bodyMedium),
            const SizedBox(height: 4),
            Text('$sym${_fmt(s.amount)}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.primary)),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.white,
              child: QrImageView(data: upiUrl, version: QrVersions.auto, size: 200, gapless: true),
            ),
            const SizedBox(height: 12),
            Text(upiId, style: theme.textTheme.bodySmall?.copyWith(color: AppColors.info)),
          ],
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text(loc.t('cancel')))],
      ),
    );
  }

  // === Share: image / sms / pdf ==========================================

  Future<void> _shareImage(GroupExpenseGroup g, List<GroupSettlement> settlements) async {
    final loc = context.loc;
    try {
      final Uint8List? bytes = await _screenshotController.capture(delay: const Duration(milliseconds: 50));
      if (bytes == null) return;
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/settlement_${g.id}.png');
      await file.writeAsBytes(bytes);
      await Share.shareXFiles(
        [XFile(file.path)],
        subject: '${loc.t("settlement")} - ${g.name}',
        text: '${g.name} — ${loc.t("settlement")}',
      );
      AdMobService.showInterstitial();
    } catch (e) {
      debugPrint('share image failed: $e');
    }
  }

  Future<void> _shareSms(GroupExpenseGroup g, List<GroupSettlement> settlements) async {
    final loc = context.loc;
    final sym = g.currencySymbol;
    final buf = StringBuffer();
    buf.writeln('${g.name} — ${loc.t("settlement")}');
    buf.writeln('${loc.t("totalExpense")}: $sym${_fmt(g.totalExpenses)}');
    buf.writeln('${loc.t("perPerson")}: $sym${_fmt(g.perPersonShare)}');
    buf.writeln('---');
    if (settlements.isEmpty) {
      buf.writeln(loc.t('noSettlementNeeded'));
    } else {
      for (final s in settlements) {
        buf.writeln('${s.from} → ${s.to}: $sym${_fmt(s.amount)}');
      }
    }
    buf.writeln('— ${loc.t("calculatedBy")}');
    await Share.share(buf.toString(), subject: '${loc.t("settlement")} - ${g.name}');
    AdMobService.showInterstitial();
  }

  Future<void> _exportPdf(GroupExpenseGroup g, List<GroupSettlement> settlements) async {
    final loc = context.loc;
    try {
      final file = await _pdfService.generate(g, settlements, loc);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loc.t('pdfGenerated')), backgroundColor: AppColors.success));
      await Share.shareXFiles([XFile(file.path)], subject: '${loc.t("settlement")} - ${g.name}');
      AdMobService.showInterstitial();
    } catch (e) {
      debugPrint('pdf export failed: $e');
    }
  }

  // === Helpers ===========================================================

  Widget _label(String text, ThemeData theme) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(text, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)));

  String _fmt(double v) => v == v.roundToDouble() ? v.round().toString() : v.toStringAsFixed(2);

  String _formatDate(DateTime d) {
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${d.day} ${months[d.month - 1]}';
  }
}
