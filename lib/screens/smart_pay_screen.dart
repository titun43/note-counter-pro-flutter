// =============================================================================
// Note Counter Pro - Smart Pay Screen (Scan QR Only)
// =============================================================================
// Smart Pay = just Scan QR with:
//   - Gallery default + Camera toggle
//   - ₹2000 limit info (Option A — full text)
//   - Scan result: Copy / Open UPI / Save
//   - Separate scan history (not Counter QR history)
// =============================================================================
// Generate QR, Send Money, Saved UPI moved to Tools tab.
// =============================================================================

import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart' as mscanner;
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import '../services/premium_service.dart';
import '../services/storage_service.dart';
import '../services/saved_upi_service.dart';
import '../services/admob_service.dart';
import '../utils/constants.dart';
import '../utils/app_localizations.dart';
import '../widgets/banner_ad_widget.dart';
import '../models/saved_upi.dart';
import 'premium_screen.dart';

class SmartPayScreen extends StatefulWidget {
  const SmartPayScreen({super.key});

  @override
  State<SmartPayScreen> createState() => _SmartPayScreenState();
}

class _SmartPayScreenState extends State<SmartPayScreen> {
  bool _useCamera = false; // Gallery default, Camera toggle
  mscanner.MobileScannerController? _cameraController;
  bool _cameraActive = false;
  Map<String, String>? _scanResult;
  bool _isScanning = false;

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
    _cameraController?.dispose();
    super.dispose();
  }

  void _startCamera() {
    _cameraController?.dispose();
    _cameraController = mscanner.MobileScannerController(
      detectionSpeed: mscanner.DetectionSpeed.noDuplicates,
      facing: mscanner.CameraFacing.back,
      autoStart: true,
    );
    setState(() {
      _cameraActive = true;
      _scanResult = null;
    });
  }

  void _stopCamera() {
    _cameraController?.dispose();
    _cameraController = null;
    setState(() => _cameraActive = false);
  }

  void _onDetect(mscanner.BarcodeCapture capture) {
    if (capture.barcodes.isEmpty) return;
    final rawValue = capture.barcodes.first.rawValue;
    if (rawValue == null || rawValue.isEmpty) return;
    _stopCamera();
    _processScanResult(rawValue);
  }

  Future<void> _pickImageAndScan() async {
    setState(() => _isScanning = true);
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.image);
      if (result != null && result.files.single.path != null) {
        final controller = mscanner.MobileScannerController(
          detectionSpeed: mscanner.DetectionSpeed.noDuplicates,
        );
        final capture = await controller.analyzeImage(result.files.single.path!);
        if (capture != null && capture.barcodes.isNotEmpty) {
          final rawValue = capture.barcodes.first.rawValue;
          if (rawValue != null && rawValue.isNotEmpty) {
            _processScanResult(rawValue);
          }
        }
        controller.dispose();
      }
    } catch (e) {
      debugPrint('Gallery scan failed: $e');
    }
    setState(() => _isScanning = false);
  }

  void _processScanResult(String rawValue) {
    String upiId = '';
    String name = '';
    String amount = '';
    String note = '';

    if (rawValue.startsWith('upi://')) {
      final uri = Uri.parse(rawValue);
      upiId = uri.queryParameters['pa'] ?? '';
      name = uri.queryParameters['pn'] ?? '';
      amount = uri.queryParameters['am'] ?? '';
      note = uri.queryParameters['tn'] ?? '';
    } else if (rawValue.contains('@')) {
      upiId = rawValue;
    } else {
      upiId = rawValue;
    }

    final result = {
      'upiId': upiId,
      'name': name,
      'amount': amount,
      'note': note,
      'rawUrl': rawValue,
      'timestamp': DateTime.now().toIso8601String(),
    };

    setState(() => _scanResult = result);

    // Save to scan history (separate from Counter QR history)
    try {
      context.read<StorageService>().addUpiScanHistory(result);
    } catch (e) {
      debugPrint('Save scan history failed: $e');
    }
  }

  void _copyUpiId() {
    if (_scanResult == null) return;
    Clipboard.setData(ClipboardData(text: _scanResult!['upiId']!));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.loc.t('upiIdCopied')), backgroundColor: AppColors.success),
    );
  }

  void _openUpiApp() {
    if (_scanResult == null) return;
    final rawUrl = _scanResult!['rawUrl']!;
    String upiLink;
    if (rawUrl.startsWith('upi://')) {
      upiLink = rawUrl;
    } else {
      upiLink = 'upi://pay?pa=$rawUrl';
    }
    AdMobService.showInterstitial();
    try {
      launchUrl(Uri.parse(upiLink), mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('Open UPI failed: $e');
    }
  }

  void _saveUpiId() {
    if (_scanResult == null) return;
    final upiId = _scanResult!['upiId']!;
    final name = _scanResult!['name']!;
    if (upiId.isEmpty) return;
    final savedUpi = SavedUpi.create(upiId: upiId, name: name.isEmpty ? upiId.split('@').first : name);
    SavedUpiService().add(savedUpi).then((success) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? context.loc.t('saved') : context.loc.t('upiAlreadyExists')),
            backgroundColor: success ? AppColors.success : AppColors.warning,
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final loc = context.loc;
    final storage = context.watch<StorageService>();
    final scanHistory = storage.upiScanHistory;

    return Scaffold(
      backgroundColor: isDark ? AppColors.bgDark : AppColors.bgLight,
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            const BannerAdWidget(),
            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // === ₹2000 LIMIT INFO (Option A — full text) ===
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: isDark
                              ? [const Color(0xFF1F2937), const Color(0xFF111827)]
                              : [const Color(0xFFFFF7ED), const Color(0xFFFFEDD5)],
                        ),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: const Color(0xFFD4AF37).withOpacity(0.5),
                          width: 2,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.lightbulb, color: Color(0xFFD4AF37), size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  loc.t('smartPayScanTitle'),
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFFD4AF37),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          // RED message
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              color: AppColors.danger.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.danger.withOpacity(0.3)),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.cancel, color: AppColors.danger, size: 16),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    loc.t('limitBannerRed'),
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.danger,
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          // GREEN message
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              color: AppColors.success.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.success.withOpacity(0.3)),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.check_circle, color: AppColors.success, size: 16),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    loc.t('limitBannerGreen'),
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.success,
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // === Camera active ===
                    if (_cameraActive) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: SizedBox(
                          height: 300,
                          width: double.infinity,
                          child: Stack(
                            children: [
                              mscanner.MobileScanner(
                                controller: _cameraController!,
                                onDetect: _onDetect,
                              ),
                              Center(
                                child: Container(
                                  width: 200,
                                  height: 200,
                                  decoration: BoxDecoration(
                                    border: Border.all(color: const Color(0xFFD4AF37), width: 2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                              Positioned(
                                top: 8,
                                right: 8,
                                child: IconButton(
                                  icon: const Icon(Icons.close, color: Colors.white),
                                  onPressed: _stopCamera,
                                  style: IconButton.styleFrom(backgroundColor: Colors.black54),
                                ),
                              ),
                              Positioned(
                                bottom: 8,
                                left: 0,
                                right: 0,
                                child: Center(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(20)),
                                    child: Text(loc.t('scanAlignQr'), style: const TextStyle(color: Colors.white, fontSize: 12)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],

                    // === Scan button + toggle ===
                    if (!_cameraActive) ...[
                      // Toggle switch
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.bgCardDark : AppColors.bgCard,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            Icon(_useCamera ? Icons.camera_alt : Icons.image, size: 20, color: AppColors.primary),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _useCamera ? loc.t('camera') : loc.t('gallery'),
                                style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                              ),
                            ),
                            Switch(
                              value: _useCamera,
                              onChanged: (value) {
                                setState(() => _useCamera = value);
                              },
                              activeColor: AppColors.primary,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Scan button
                      GestureDetector(
                        onTap: _isScanning ? null : (_useCamera ? _startCamera : _pickImageAndScan),
                        child: Container(
                          padding: const EdgeInsets.all(32),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.bgCardDark : AppColors.bgCard,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.primary.withOpacity(0.3), width: 2),
                          ),
                          child: Column(
                            children: [
                              _isScanning
                                  ? const CircularProgressIndicator()
                                  : Icon(_useCamera ? Icons.camera_alt : Icons.image, size: 56, color: AppColors.primary),
                              const SizedBox(height: 12),
                              Text(
                                _isScanning
                                    ? loc.t('scanning')
                                    : _useCamera
                                        ? loc.t('scanOpenCamera')
                                        : loc.t('scanFromGallery'),
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],

                    // === Scan result ===
                    if (_scanResult != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.success.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.success.withOpacity(0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.check_circle, color: AppColors.success, size: 20),
                                const SizedBox(width: 8),
                                Text(loc.t('upiIdFound'), style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.success)),
                              ],
                            ),
                            const SizedBox(height: 12),
                            if (_scanResult!['upiId']!.isNotEmpty)
                              _resultRow('UPI ID', _scanResult!['upiId']!, theme, isDark),
                            if (_scanResult!['name']!.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              _resultRow(loc.t('payeeName'), _scanResult!['name']!, theme, isDark),
                            ],
                            if (_scanResult!['amount']!.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              _resultRow(loc.t('amount'), '₹${_scanResult!['amount']!}', theme, isDark),
                            ],
                            const SizedBox(height: 12),
                            // Buttons
                            Row(
                              children: [
                                Expanded(child: OutlinedButton.icon(onPressed: _copyUpiId, icon: const Icon(Icons.copy, size: 16), label: Text(loc.t('scanCopy')))),
                                const SizedBox(width: 8),
                                Expanded(child: FilledButton.icon(onPressed: _openUpiApp, icon: const Icon(Icons.payment, size: 16), label: Text(loc.t('openUpi')))),
                                const SizedBox(width: 8),
                                Expanded(child: OutlinedButton.icon(onPressed: _saveUpiId, icon: const Icon(Icons.save, size: 16), label: Text(loc.t('save')))),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextButton.icon(
                        onPressed: () { setState(() => _scanResult = null); },
                        icon: const Icon(Icons.refresh),
                        label: Text(loc.t('scanAgain')),
                      ),
                    ],

                    // === Scan History (separate) ===
                    if (scanHistory.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Icon(Icons.history, size: 18, color: AppColors.primary),
                          const SizedBox(width: 8),
                          Text(loc.t('scanHistory'), style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold, color: AppColors.primary)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ...scanHistory.take(10).toList().asMap().entries.map((entry) {
                        final index = entry.key;
                        final item = entry.value;
                        return Card(
                          margin: const EdgeInsets.only(bottom: 4),
                          color: isDark ? AppColors.bgCardDark : AppColors.bgCard,
                          child: ListTile(
                            leading: const Icon(Icons.qr_code_scanner, size: 20, color: AppColors.info),
                            title: Text(item['upiId'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
                            subtitle: Text(item['amount'] != null && item['amount']!.isNotEmpty ? '₹${item['amount']}' : '', style: const TextStyle(fontSize: 11)),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.danger),
                              onPressed: () => storage.deleteUpiScanHistory(index),
                            ),
                            onTap: () { setState(() => _scanResult = Map<String, String>.from(item)); },
                          ),
                        );
                      }),
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

  Widget _resultRow(String label, String value, ThemeData theme, bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: theme.textTheme.bodySmall?.copyWith(color: isDark ? Colors.white70 : Colors.black54)),
        Text(value, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
      ],
    );
  }
}
