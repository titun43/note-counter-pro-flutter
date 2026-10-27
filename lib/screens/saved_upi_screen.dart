// =============================================================================
// Note Counter Pro - Saved UPI IDs Screen (Contacts)
// =============================================================================
// Shows user-saved UPI IDs grouped by category (Favorites/Business/Family/Other).
// Tap a contact → opens Send Money pre-filled.
// Long-press → edit/delete.
// =============================================================================

import 'package:flutter/material.dart';
import '../services/admob_service.dart';
import '../services/saved_upi_service.dart';
import '../utils/constants.dart';
import '../utils/app_localizations.dart';
import '../models/saved_upi.dart';
import 'send_money_screen.dart';

class SavedUpiScreen extends StatefulWidget {
  const SavedUpiScreen({super.key});

  @override
  State<SavedUpiScreen> createState() => _SavedUpiScreenState();
}

class _SavedUpiScreenState extends State<SavedUpiScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final loc = context.loc;

    final allUpis = SavedUpiService().all;
    final filtered = _searchQuery.isEmpty
        ? allUpis
        : allUpis
            .where((u) =>
                u.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                u.upiId.toLowerCase().contains(_searchQuery.toLowerCase()))
            .toList();

    // Group filtered UPIs
    final Map<String, List<SavedUpi>> grouped = {};
    for (final group in SavedUpiService.groups) {
      grouped[group] = filtered.where((u) => u.group == group).toList();
    }

    return Scaffold(
      backgroundColor: isDark ? AppColors.bgDark : AppColors.bgLight,
      appBar: AppBar(
        title: Text(loc.t('savedUpiIds')),
        backgroundColor: const Color(0xFFD4AF37),
        foregroundColor: const Color(0xFF1A1A2E),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add),
            tooltip: loc.t('addNewUpi'),
            onPressed: () => _showAddEditDialog(),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Search bar
            Padding(
              padding: const EdgeInsets.all(12),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: loc.t('searchByNameOrUpi'),
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  border: const OutlineInputBorder(),
                  filled: true,
                  fillColor: isDark ? AppColors.bgCardDark : AppColors.bgCard,
                ),
                onChanged: (value) => setState(() => _searchQuery = value),
              ),
            ),

            // List
            Expanded(
              child: filtered.isEmpty
                  ? _buildEmptyState(loc, theme)
                  : ListView(
                      padding: const EdgeInsets.only(bottom: 80),
                      children: SavedUpiService.groups.map((group) {
                        final items = grouped[group]!;
                        if (items.isEmpty) return const SizedBox.shrink();
                        return _buildGroup(group, items, theme, isDark, loc);
                      }).toList(),
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddEditDialog(),
        icon: const Icon(Icons.add),
        label: Text(loc.t('addNewUpi')),
        backgroundColor: const Color(0xFFD4AF37),
        foregroundColor: const Color(0xFF1A1A2E),
      ),
    );
  }

  Widget _buildEmptyState(AppLocalizations loc, ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.contact_mail_outlined,
              size: 72,
              color: AppColors.textSecondary.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              loc.t('noSavedUpi'),
              style: theme.textTheme.titleMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              loc.t('noSavedUpiDesc'),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroup(
    String group,
    List<SavedUpi> items,
    ThemeData theme,
    bool isDark,
    AppLocalizations loc,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
          child: Row(
            children: [
              Icon(_groupIcon(group), size: 18, color: _groupColor(group)),
              const SizedBox(width: 6),
              Text(
                loc.t('group_$group'),
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: _groupColor(group),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '(${items.length})',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        ...items.map((upi) => _buildUpiItem(upi, theme, isDark, loc)),
      ],
    );
  }

  Widget _buildUpiItem(
    SavedUpi upi,
    ThemeData theme,
    bool isDark,
    AppLocalizations loc,
  ) {
    final initial = upi.name.isNotEmpty ? upi.name[0].toUpperCase() : '?';
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      color: isDark ? AppColors.bgCardDark : AppColors.bgCard,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        leading: CircleAvatar(
          backgroundColor: _groupColor(upi.group),
          child: Text(
            initial,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          upi.name,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          upi.upiId,
          style: theme.textTheme.bodySmall?.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.send, color: Color(0xFFD4AF37)),
              tooltip: loc.t('sendMoney'),
              onPressed: () {
                AdMobService.showInterstitial();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SendMoneyScreen(prefillUpi: upi),
                  ),
                );
              },
            ),
            PopupMenuButton<String>(
              icon: Icon(
                Icons.more_vert,
                color: AppColors.textSecondary,
              ),
              onSelected: (value) {
                if (value == 'edit') {
                  _showAddEditDialog(existing: upi);
                } else if (value == 'delete') {
                  _showDeleteConfirm(upi);
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      const Icon(Icons.edit, size: 18),
                      const SizedBox(width: 8),
                      Text(loc.t('edit')),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      const Icon(Icons.delete, size: 18, color: AppColors.danger),
                      const SizedBox(width: 8),
                      Text(loc.t('delete'),
                          style: const TextStyle(color: AppColors.danger)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        onTap: () {
          AdMobService.showInterstitial();
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => SendMoneyScreen(prefillUpi: upi),
            ),
          );
        },
      ),
    );
  }

  IconData _groupIcon(String group) {
    switch (group) {
      case 'favorites':
        return Icons.star;
      case 'business':
        return Icons.store;
      case 'family':
        return Icons.family_restroom;
      default:
        return Icons.person;
    }
  }

  Color _groupColor(String group) {
    switch (group) {
      case 'favorites':
        return AppColors.warning;
      case 'business':
        return AppColors.info;
      case 'family':
        return AppColors.success;
      default:
        return AppColors.textSecondary;
    }
  }

  void _showAddEditDialog({SavedUpi? existing}) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => _AddEditUpiDialog(existing: existing),
    );

    if (result == null) return;
    final loc = context.loc;

    if (existing == null) {
      // Add new
      final newUpi = SavedUpi.create(
        upiId: result['upiId'] as String,
        name: result['name'] as String,
        phone: result['phone'] as String?,
        group: result['group'] as String? ?? 'other',
      );
      final success = await SavedUpiService().add(newUpi);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success
              ? '${loc.t('saved')} ${result['name']}'
              : loc.t('upiAlreadyExists')),
          backgroundColor: success ? AppColors.success : AppColors.warning,
        ),
      );
      // Show interstitial after a successful save
      if (success) {
        AdMobService.showInterstitial();
      }
    } else {
      // Update existing
      final updated = existing.copyWith(
        upiId: result['upiId'] as String,
        name: result['name'] as String,
        phone: result['phone'] as String?,
        group: result['group'] as String? ?? existing.group,
      );
      await SavedUpiService().update(updated);
    }
    setState(() {});
  }

  void _showDeleteConfirm(SavedUpi upi) {
    final loc = context.loc;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(loc.t('deleteUpi')),
        content: Text('${loc.t('deleteConfirmUpi')} "${upi.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(loc.t('cancel')),
          ),
          FilledButton(
            onPressed: () async {
              await SavedUpiService().delete(upi.id);
              if (!mounted) return;
              Navigator.pop(ctx, true);
              setState(() {});
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(loc.t('upiDeleted')),
                  backgroundColor: AppColors.danger,
                ),
              );
            },
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.danger,
            ),
            child: Text(loc.t('delete')),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Add/Edit UPI dialog
// =============================================================================
class _AddEditUpiDialog extends StatefulWidget {
  final SavedUpi? existing;
  const _AddEditUpiDialog({this.existing});

  @override
  State<_AddEditUpiDialog> createState() => _AddEditUpiDialogState();
}

class _AddEditUpiDialogState extends State<_AddEditUpiDialog> {
  final _upiIdController = TextEditingController();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  String _group = 'other';

  @override
  void initState() {
    super.initState();
    if (widget.existing != null) {
      _upiIdController.text = widget.existing!.upiId;
      _nameController.text = widget.existing!.name;
      _phoneController.text = widget.existing!.phone ?? '';
      _group = widget.existing!.group;
    }
  }

  @override
  void dispose() {
    _upiIdController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return AlertDialog(
      title: Text(widget.existing == null
          ? loc.t('addNewUpi')
          : loc.t('editUpi')),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _upiIdController,
              decoration: InputDecoration(
                labelText: '${loc.t('upiId')} *',
                hintText: 'example@oksbi',
                prefixIcon: const Icon(Icons.alternate_email),
                border: const OutlineInputBorder(),
              ),
              keyboardType: TextInputType.emailAddress,
              autofocus: widget.existing == null,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: '${loc.t('name')} *',
                prefixIcon: const Icon(Icons.person_outline),
                border: const OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _phoneController,
              decoration: InputDecoration(
                labelText: loc.t('phoneOptional'),
                prefixIcon: const Icon(Icons.phone_outlined),
                border: const OutlineInputBorder(),
              ),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _group,
              decoration: InputDecoration(
                labelText: loc.t('group'),
                prefixIcon: const Icon(Icons.folder_outlined),
                border: const OutlineInputBorder(),
              ),
              items: SavedUpiService.groups.map((g) {
                return DropdownMenuItem(
                  value: g,
                  child: Row(
                    children: [
                      Icon(_groupIcon(g), size: 18, color: _groupColor(g)),
                      const SizedBox(width: 8),
                      Text(loc.t('group_$g')),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _group = value);
                }
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(loc.t('cancel')),
        ),
        FilledButton(
          onPressed: () {
            if (_upiIdController.text.trim().isEmpty ||
                _nameController.text.trim().isEmpty) return;
            Navigator.pop(context, {
              'upiId': _upiIdController.text.trim(),
              'name': _nameController.text.trim(),
              'phone': _phoneController.text.trim().isEmpty
                  ? null
                  : _phoneController.text.trim(),
              'group': _group,
            });
          },
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFD4AF37),
            foregroundColor: const Color(0xFF1A1A2E),
          ),
          child: Text(loc.t('save')),
        ),
      ],
    );
  }

  IconData _groupIcon(String group) {
    switch (group) {
      case 'favorites':
        return Icons.star;
      case 'business':
        return Icons.store;
      case 'family':
        return Icons.family_restroom;
      default:
        return Icons.person;
    }
  }

  Color _groupColor(String group) {
    switch (group) {
      case 'favorites':
        return AppColors.warning;
      case 'business':
        return AppColors.info;
      case 'family':
        return AppColors.success;
      default:
        return AppColors.textSecondary;
    }
  }
}
