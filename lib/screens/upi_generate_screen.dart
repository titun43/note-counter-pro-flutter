// =============================================================================
// Note Counter Pro - UPI Generate QR Screen (Standalone) — v3.36.0
// =============================================================================
// Standalone "Generate QR (UPI)" screen accessible from the Tools tab.
//
// Extracted from the old UpiToolsScreen's Generate tab. Wrapped in its own
// Scaffold with a back button + BannerAdWidget.
//
// Features:
//   - Enter UPI ID / Name / Amount / Note → generate UPI payment QR
//   - Smart save to Counter's QR History (addQrHistorySmart)
//   - Share QR image + Copy UPI ID
//   - Dark/Light mode + 3 languages (en/bn/hi)
// =============================================================================

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:screenshot/screenshot.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import '../services/storage_service.dart';
import '../services/premium_service.dart';
import '../utils/constants.dart';
import '../utils/app_localizations.dart';
import '../widgets/banner_ad_widget.dart';
import 'premium_screen.dart';

class UpiGenerateScreen extends StatefulWidget {
  const UpiGenerateScreen({super.key});

  @override
  State<UpiGenerateScreen> createState() => _UpiGenerateScreenState();
}

class _UpiGenerateScreenState extends State<UpiGenerateScreen> {
  final _upiIdController = TextEditingController();
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  final _screenshotController = ScreenshotController();
  String? _generatedUpiUrl;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!PremiumService().isPremium && mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const PremiumScreen()),
        );
      }
    });
  }

  @override
  void dispose() {
    _upiIdController.dispose();
    _nameController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _generateQr() {
    final upiId = _upiIdController.text.trim();
    final loc = context.loc;
    if (upiId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(loc.t('enterUpiId')),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    final name = _nameController.text.trim();
    final amount = _amountController.text.trim();
    final note = _noteController.text.trim();

    final params = <String>[];
    params.add('pa=$upiId');
    if (name.isNotEmpty) params.add('pn=${Uri.encodeComponent(name)}');
    if (amount.isNotEmpty) params.add('am=$amount');
    if (note.isNotEmpty) params.add('tn=${Uri.encodeComponent(note)}');

    final upiUrl = 'upi://pay?${params.join('&')}';

    setState(() {
      _generatedUpiUrl = upiUrl;
    });

    // ✅ Smart save to Counter's QR History (addQrHistorySmart)
    try {
      final storage = context.read<StorageService>();
      storage.addQrHistorySmart({
        'upiId': upiId,
        'name': name,
        'amount': amount,
        'note': note,
        'url': upiUrl,
        'timestamp': DateTime.now().toIso8601String(),
      });
      debugPrint('UpiGenerate: QR saved to Counter QR history (smart save) for UPI ID: $upiId');
    } catch (e) {
      debugPrint('UpiGenerate: Failed to save QR to history: $e');
    }
  }

  Future<void> _shareQrImage() async {
    if (_generatedUpiUrl == null) return;
    try {
      final image = await _screenshotController.capture();
      if (image == null) return;
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/upi_qr_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(image);
      await Share.shareXFiles([XFile(file.path)], subject: 'UPI QR Code');
    } catch (e) {
      debugPrint('Share QR failed: $e');
    }
  }

  void _copyUpiId() {
    final upiId = _upiIdController.text.trim();
    if (upiId.isEmpty) return;
    Clipboard.setData(ClipboardData(text: upiId));
    final loc = context.loc;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(loc.t('upiIdCopied')),
        backgroundColor: AppColors.success,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final loc = context.loc;

    return Scaffold(
      backgroundColor: isDark ? AppColors.bgDark : AppColors.bgLight,
      body: SafeArea(
        child: Column(
          children: [
            // Banner ad (standalone screen)
            const BannerAdWidget(),
            // Header bar with back button + title
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[900] : Colors.grey[50],
                border: Border(
                  bottom: BorderSide(
                    color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
                    width: 0.5,
                  ),
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, size: 22),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Icon(Icons.qr_code_2, size: 22, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Text(
                    loc.t('upiGenerateQr'),
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildInputField(
                      controller: _upiIdController,
                      label: '${loc.t('upiId')} *',
                      hint: 'yourname@upi',
                      icon: Icons.payment,
                    ),
                    const SizedBox(height: 10),
                    _buildInputField(
                      controller: _nameController,
                      label: loc.t('nameLabel'),
                      hint: loc.t('nameLabel'),
                      icon: Icons.person,
                    ),
                    const SizedBox(height: 10),
                    _buildInputField(
                      controller: _amountController,
                      label: loc.t('amount'),
                      hint: '₹ 0',
                      icon: Icons.currency_rupee,
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 10),
                    _buildInputField(
                      controller: _noteController,
                      label: loc.t('noteLabel'),
                      hint: loc.t('noteLabel'),
                      icon: Icons.note,
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _generateQr,
                      icon: const Icon(Icons.qr_code),
                      label: Text(
                        loc.t('generateQrCode'),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.bgDark,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (_generatedUpiUrl != null) ...[
                      Screenshot(
                        controller: _screenshotController,
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.bgCardDark : AppColors.bgCard,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: const Color(0xFFD4AF37).withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: Column(
                            children: [
                              if (_nameController.text.isNotEmpty)
                                Text(
                                  _nameController.text,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.white : Colors.black,
                                  ),
                                ),
                              const SizedBox(height: 8),
                              QrImageView(
                                data: _generatedUpiUrl!,
                                version: QrVersions.auto,
                                size: 200,
                                backgroundColor: Colors.white,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _upiIdController.text,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: isDark ? Colors.white70 : Colors.black54,
                                ),
                              ),
                              if (_amountController.text.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  '₹ ${_amountController.text}',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.white : Colors.black,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _shareQrImage,
                              icon: const Icon(Icons.share, size: 18),
                              label: Text(loc.t('share')),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _copyUpiId,
                              icon: const Icon(Icons.copy, size: 18),
                              label: Text(loc.t('copyUpi')),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, size: 20),
        border: const OutlineInputBorder(),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
      keyboardType: keyboardType,
    );
  }
}
