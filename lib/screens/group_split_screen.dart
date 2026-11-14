// =============================================================================
// Note Counter Pro - Group Split Screen (Group List)
// =============================================================================
// Lists all GroupExpenseGroup objects, lets the user create a new group
// (name + members + optional UPI IDs + currency), and opens a group's detail
// screen on tap. Long-press a group for edit/delete.
//
// Entry points: Tools tab card + Khata 3-dot overflow menu.
// Storage: on-device SharedPreferences via GroupSplitService (no Firebase).
// =============================================================================

import 'package:flutter/material.dart';
import '../models/group_expense.dart';
import '../services/group_split_service.dart';
import '../services/admob_service.dart';
import '../services/feedback_service.dart';
import '../utils/constants.dart';
import '../utils/app_localizations.dart';
import '../widgets/banner_ad_widget.dart';
import 'group_detail_screen.dart';

class GroupSplitScreen extends StatefulWidget {
  const GroupSplitScreen({super.key});

  @override
  State<GroupSplitScreen> createState() => _GroupSplitScreenState();
}

class _GroupSplitScreenState extends State<GroupSplitScreen> {
  final _service = GroupSplitService();

  @override
  void initState() {
    super.initState();
    // Service loads on app startup, but refresh from memory in case this
    // screen is entered before that delayed init completes.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
  }

  void _refresh() {
    setState(() {});
    FeedbackService().tap();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final loc = context.loc;
    final groups = _service.all;

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
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: AppColors.primary),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Icon(Icons.groups, size: 24, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      loc.t('groupSplit'),
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontFamily: 'KhataHandwriting',
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle, color: AppColors.primary),
                    tooltip: loc.t('newGroup'),
                    onPressed: () => _showNewGroupDialog(),
                  ),
                ],
              ),
            ),

            // === Group list ===
            Expanded(
              child: groups.isEmpty
                  ? _buildEmptyState(theme, isDark, loc)
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                      itemCount: groups.length,
                      itemBuilder: (context, i) {
                        final g = groups[i];
                        return _buildGroupCard(g, theme, isDark, loc);
                      },
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          FeedbackService().tap();
          _showNewGroupDialog();
        },
        icon: const Icon(Icons.add, color: Color(0xFF1A1A2E)),
        label: Text(
          loc.t('newGroup'),
          style: const TextStyle(
            color: Color(0xFF1A1A2E),
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: AppColors.primary,
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme, bool isDark, AppLocalizations loc) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.groups_outlined, size: 72, color: AppColors.primary.withOpacity(0.5)),
            const SizedBox(height: 16),
            Text(
              loc.t('noGroups'),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : AppColors.bgDark,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              loc.t('noGroupsDesc'),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupCard(GroupExpenseGroup g, ThemeData theme, bool isDark, AppLocalizations loc) {
    final settlementCount = _service.settle(g).length;
    final sym = g.currencySymbol;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: isDark ? AppColors.bgCardDark : AppColors.bgCard,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
          width: 1,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.group, color: AppColors.primary, size: 22),
        ),
        title: Text(
          g.name,
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(
            children: [
              Icon(Icons.people, size: 13, color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary),
              const SizedBox(width: 4),
              Text(
                '${g.members.length} ${loc.t('memberCount')}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: 12),
              Icon(Icons.payments_outlined, size: 13, color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary),
              const SizedBox(width: 4),
              Text(
                '$sym${g.totalExpenses.toStringAsFixed(0)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        trailing: PopupMenuButton<String>(
          icon: Icon(Icons.more_vert, color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary),
          color: isDark ? const Color(0xFF16213E) : Colors.white,
          onSelected: (value) {
            if (value == 'edit') {
              _showEditGroupDialog(g);
            } else if (value == 'delete') {
              _confirmDelete(g);
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem<String>(
              value: 'edit',
              child: Row(children: [
                const Icon(Icons.edit, size: 20, color: AppColors.info),
                const SizedBox(width: 12),
                Text(loc.t('editGroup')),
              ]),
            ),
            PopupMenuItem<String>(
              value: 'delete',
              child: Row(children: [
                const Icon(Icons.delete, size: 20, color: AppColors.danger),
                const SizedBox(width: 12),
                Text(loc.t('deleteGroup')),
              ]),
            ),
          ],
        ),
        onTap: () {
          FeedbackService().tap();
          AdMobService.showInterstitial();
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => GroupDetailScreen(groupId: g.id)),
          ).then((_) {
            // Refresh on return — data may have changed.
            if (mounted) setState(() {});
          });
        },
        onLongPress: () {
          FeedbackService().tap();
          _confirmDelete(g);
        },
      ),
    );
  }

  // === New / edit group dialog ===========================================

  void _showNewGroupDialog() {
    _showGroupDialog(existing: null);
  }

  void _showEditGroupDialog(GroupExpenseGroup existing) {
    _showGroupDialog(existing: existing);
  }

  void _showGroupDialog({GroupExpenseGroup? existing}) {
    final loc = context.loc;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final nameCtl = TextEditingController(text: existing?.name ?? '');
    final upiCtl = TextEditingController();
    final memberNameCtl = TextEditingController();

    final members = <_MemberEntry>[];
    if (existing != null) {
      members.addAll(existing.members.map((m) => _MemberEntry(name: m.name, upiId: m.upiId ?? '')));
    }
    // Default currency: keep existing or ₹.
    String currency = existing?.currencySymbol ?? '₹';

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
                        Center(
                          child: Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(color: AppColors.textSecondary.withOpacity(0.3), borderRadius: BorderRadius.circular(2))),
                        ),
                        Text(
                          existing == null ? loc.t('newGroup') : loc.t('editGroup'),
                          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 16),

                        // Group name
                        _label(loc.t('groupName'), theme),
                        TextField(
                          controller: nameCtl,
                          decoration: InputDecoration(
                            hintText: loc.t('groupNameHint'),
                            border: const OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Currency selector
                        _label(loc.t('amountLabel'), theme),
                        DropdownButtonFormField<String>(
                          value: currency,
                          decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                          items: const [
                            DropdownMenuItem(value: '₹', child: Text('₹ Indian Rupee')),
                            DropdownMenuItem(value: '\$', child: Text('\$ US Dollar')),
                            DropdownMenuItem(value: '€', child: Text('€ Euro')),
                            DropdownMenuItem(value: '£', child: Text('£ British Pound')),
                            DropdownMenuItem(value: '৳', child: Text('৳ Bangladeshi Taka')),
                            DropdownMenuItem(value: 'रू', child: Text('रू Nepalese Rupee')),
                          ],
                          onChanged: (v) => setSheetState(() => currency = v ?? '₹'),
                        ),
                        const SizedBox(height: 16),

                        // Members section
                        Text(loc.t('members'),
                            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),

                        // Member name input
                        TextField(
                          controller: memberNameCtl,
                          decoration: InputDecoration(
                            labelText: loc.t('memberName'),
                            border: const OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: upiCtl,
                          decoration: InputDecoration(
                            labelText: loc.t('upiIdOptional'),
                            border: const OutlineInputBorder(),
                            isDense: true,
                          ),
                          keyboardType: TextInputType.text,
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () {
                              final name = memberNameCtl.text.trim();
                              if (name.isEmpty) return;
                              if (members.any((m) => m.name.toLowerCase() == name.toLowerCase())) {
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  SnackBar(content: Text(loc.t('duplicateMember')), backgroundColor: AppColors.danger),
                                );
                                return;
                              }
                              setSheetState(() {
                                members.add(_MemberEntry(name: name, upiId: upiCtl.text.trim()));
                              });
                              memberNameCtl.clear();
                              upiCtl.clear();
                              FeedbackService().tap();
                            },
                            icon: const Icon(Icons.person_add, color: AppColors.primary),
                            label: Text(loc.t('addMember')),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Member chips
                        if (members.isNotEmpty)
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: members.asMap().entries.map((entry) {
                              final i = entry.key;
                              final m = entry.value;
                              return Chip(
                                label: Text(m.name),
                                deleteIcon: const Icon(Icons.close, size: 18),
                                onDeleted: () => setSheetState(() => members.removeAt(i)),
                                backgroundColor: AppColors.primary.withOpacity(0.12),
                                side: BorderSide(color: AppColors.primary.withOpacity(0.3)),
                              );
                            }).toList(),
                          ),

                        const SizedBox(height: 20),

                        // Save button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: const Color(0xFF1A1A2E),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            onPressed: () async {
                              if (nameCtl.text.trim().isEmpty) {
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  SnackBar(content: Text(loc.t('nameRequired')), backgroundColor: AppColors.danger),
                                );
                                return;
                              }
                              if (members.isEmpty) {
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  SnackBar(content: Text(loc.t('minMembers')), backgroundColor: AppColors.danger),
                                );
                                return;
                              }
                              final memberObjs = members
                                  .map((m) => GroupMember(name: m.name, upiId: m.upiId.isEmpty ? null : m.upiId))
                                  .toList();
                              if (existing == null) {
                                await _service.createGroup(
                                  name: nameCtl.text,
                                  members: memberObjs,
                                  currencySymbol: currency,
                                );
                              } else {
                                await _service.updateGroup(
                                  existing.id,
                                  name: nameCtl.text,
                                  members: memberObjs,
                                  currencySymbol: currency,
                                );
                              }
                              if (ctx.mounted) Navigator.pop(ctx);
                              _refresh();
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

  void _confirmDelete(GroupExpenseGroup g) {
    final loc = context.loc;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(loc.t('deleteGroup')),
        content: Text(loc.t('confirmDeleteGroup')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(loc.t('cancel'))),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            onPressed: () async {
              await _service.deleteGroup(g.id);
              if (ctx.mounted) Navigator.pop(ctx);
              _refresh();
            },
            child: Text(loc.t('deleteBtn')),
          ),
        ],
      ),
    );
  }

  Widget _label(String text, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(text, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
    );
  }
}

/// Helper for the in-dialog member list (mutable, with optional UPI).
class _MemberEntry {
  final String name;
  final String upiId;
  _MemberEntry({required this.name, this.upiId = ''});
}
