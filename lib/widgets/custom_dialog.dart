// =============================================================================
// Note Counter Pro — Custom Dialog Widget
// =============================================================================
//
// Premium reusable dialog with:
//   • Gradient/dark header (icon + title + close button)
//   • Modern underline inputs (via global theme)
//   • Premium buttons
//   • Dark/Light mode auto support
//   • Smooth rounded corners (20px)
//
// Usage:
//   showCustomDialog(
//     context: context,
//     title: 'Add Customer',
//     icon: Icons.person_add,
//     iconColor: AppColors.primary,
//     child: MyForm(),
//     actions: [CancelButton, SaveButton],
//   );
//
//   showConfirmationDialog(
//     context: context,
//     title: 'Delete Entry?',
//     message: 'This action cannot be undone.',
//     confirmText: 'Delete',
//     isDanger: true,
//   );
// =============================================================================

import 'package:flutter/material.dart';
import '../utils/constants.dart';

/// Dialog type → determines header gradient color.
enum DialogType {
  normal,    // Dark navy header
  success,   // Green header
  danger,    // Red header
  info,      // Blue header
}

/// Show a premium custom dialog with gradient header.
Future<T?> showCustomDialog<T>({
  required BuildContext context,
  required String title,
  required Widget child,
  IconData? icon,
  Color? iconColor,
  DialogType type = DialogType.normal,
  List<Widget>? actions,
  bool barrierDismissible = true,
}) {
  final theme = Theme.of(context);
  final isDark = theme.brightness == Brightness.dark;

  // Header gradient colors based on dialog type.
  List<Color> headerColors;
  Color headerIconColor;
  Color headerTextColor;

  switch (type) {
    case DialogType.success:
      headerColors = [AppColors.success, const Color(0xFF059669)];
      headerIconColor = Colors.white;
      headerTextColor = Colors.white;
      break;
    case DialogType.danger:
      headerColors = [AppColors.danger, const Color(0xFFDC2626)];
      headerIconColor = Colors.white;
      headerTextColor = Colors.white;
      break;
    case DialogType.info:
      headerColors = [AppColors.info, const Color(0xFF2563EB)];
      headerIconColor = Colors.white;
      headerTextColor = Colors.white;
      break;
    case DialogType.normal:
      headerColors = isDark
          ? [AppColors.bgDarker, AppColors.bgDark]
          : [AppColors.bgDark, const Color(0xFF2A2A4E)];
      headerIconColor = AppColors.primary;
      headerTextColor = Colors.white;
      break;
  }

  // Use provided iconColor override if given (for normal type).
  if (type == DialogType.normal && iconColor != null) {
    headerIconColor = iconColor;
  }

  return showDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    builder: (ctx) => Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        decoration: BoxDecoration(
          color: isDark ? AppColors.bgCardDark : AppColors.bgCard,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 30,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // === HEADER ===
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 8, 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: headerColors,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
              ),
              child: Row(
                children: [
                  if (icon != null) ...[
                    Icon(icon, color: headerIconColor, size: 24),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: headerTextColor,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    icon: Icon(Icons.close, color: headerTextColor.withOpacity(0.7), size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
                ],
              ),
            ),
            // === CONTENT ===
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: child,
              ),
            ),
            // === ACTIONS ===
            if (actions != null && actions.isNotEmpty)
              Container(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: actions,
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

/// Show a premium confirmation dialog (Delete, Confirm, etc).
/// Returns true if user confirms, false/null otherwise.
Future<bool?> showConfirmationDialog({
  required BuildContext context,
  required String title,
  required String message,
  String? confirmText,
  String? cancelText,
  bool isDanger = false,
  IconData? icon,
}) {
  final theme = Theme.of(context);
  final isDark = theme.brightness == Brightness.dark;

  return showCustomDialog<bool>(
    context: context,
    title: title,
    icon: icon ?? (isDanger ? Icons.warning_amber_rounded : Icons.help_outline),
    type: isDanger ? DialogType.danger : DialogType.info,
    child: Text(
      message,
      style: TextStyle(
        fontSize: 14,
        color: isDark ? Colors.white70 : AppColors.textPrimary,
        height: 1.5,
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context, false),
        child: Text(
          cancelText ?? 'Cancel',
          style: TextStyle(
            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      const SizedBox(width: 8),
      FilledButton(
        onPressed: () => Navigator.pop(context, true),
        style: FilledButton.styleFrom(
          backgroundColor: isDanger ? AppColors.danger : AppColors.primary,
          foregroundColor: isDanger ? Colors.white : AppColors.bgDark,
        ),
        child: Text(confirmText ?? 'Confirm'),
      ),
    ],
  );
}
