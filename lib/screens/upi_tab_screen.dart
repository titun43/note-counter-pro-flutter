// =============================================================================
// Note Counter Pro - Smart Pay Tab (Scan QR Only)
// =============================================================================
// Smart Pay = Scan QR with Gallery default + Camera toggle.
// ₹2000 limit info (Option A — full text).
// Scan result: Copy / Open UPI / Save buttons.
// Scan history (separate from Generate QR history).
// Premium feature — free users see lock screen.
// =============================================================================

import 'dart:io';
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
import 'premium_screen.dart';
import '../models/saved_upi.dart';

class UpiTabScreen extends StatefulWidget {
  const UpiTabScreen({super.key});

  @override
  State<UpiTabScreen> createState() => _UpiTabScreenState();
}

class _UpiTabScreenState extends State<UpiTabScreen> {
  bool _useCamera = false; // false = Gallery (default), true = Camera
  mscanner.MobileScannerController? _cameraController;
  bool _cameraActive = false;
  Map<String, String>? _scanResult;
  bool _isScanning = false;

  @override
  void initState() {
    super.initState();
    PremiumService().addListener(_onPremiumChanged);
  }

  @override
  void dispose() {
    PremiumService().removeListener(_onPremiumChanged);
    _cameraController?.dispose();
    super.dispose();
  }

  void _onPremiumChanged() {
    if (mounted) setState(() {});
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

  void _onCameraDetect(mscanner.BarcodeCapture capture) {
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
    // Parse UPI data
    String upiId = '';
    String name = '';
    String amount = '';

    if (rawValue.startsWith('upi://')) {
      final uri = Uri.parse(rawValue);
      upiId = uri.queryParameters['pa'] ?? '';
      name = uri.queryParameters['pn'] ?? '';
      amount = uri.queryParameters['am'] ?? '';
    } else if (rawValue.contains('@')) {
      upiId = rawValue;
    }

    if (upiId.isEmpty) {
      // Not a UPI QR — show raw content
      upiId = rawValue;
    }

    setState(() {
      _scanResult = {
        'upiId': upiId,
        'name': name,
        'amount': amount,
        'rawUrl': rawValue,
        'timestamp': DateTime.now().toIso8601String(),
      };
    });

    // Save to scan history (separate from Generate QR history)
    try {
      context.read<StorageService>().addUpiScanHistory(_scanResult!);
    } catch (e) {
      debugPrint('Save UPI scan history failed: $e');
    }
  }

  void _copyUpiId() {
    if (_scanResult == null) return;
    Clipboard.setData(ClipboardData(text: _scanResult!['upiId']!));
    final loc = context.loc;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(loc.t('upiIdCopied')), backgroundColor: AppColors.success),
    );
  }

  void _openUpiApp() {
    if (_scanResult == null) return;
    final rawUrl = _scanResult!['rawUrl']!;
    String upiLink;
    if (rawUrl.startsWith('upi://')) {
      upiLink = rawUrl;
    } else {
      upiLink = 'upi://pay?pa=${_scanResult!['upiId']}';
    }
    AdMobService.showInterstitial();
    launchUrl(Uri.parse(upiLink), mode: LaunchMode.externalApplication).catchError((e) {
      debugPrint('UPI launch failed: $e');
    });
  }

  void _saveUpiId() {
    if (_scanResult == null) return;
    final upiId = _scanResult!['upiId']!;
    final name = _scanResult!['name']?.isNotEmpty == true ? _scanResult!['name']! : upiId.split('@').first;
    final newUpi = SavedUpi.create(upiId: upiId, name: name, group: 'other');
    SavedUpiService().add(newUpi).then((success) {
      final loc = context.loc;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? '${loc.t('saved')} $name' : loc.t('upiAlreadyExists')),
          backgroundColor: success ? AppColors.success : AppColors.warning,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final loc = context.loc;

    // Free users see lock screen
    if (!PremiumService().isPremium) {
      return _buildLockScreen(isDark, loc, theme);
    }

    // If camera is active, show full screen camera
    if (_useCamera && _cameraActive) {
      return _buildFullScreenCamera(isDark, loc);
    }

    final storage = context.watch<StorageService>();
    final scanHistory = storage.upiScanHistory;

    return Scaffold(
      backgroundColor: isDark ? AppColors.bgDark : AppColors.bgLight,
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ₹2000 Info Banner (Option A — full text)
              _buildLimitBanner(isDark, loc, theme),
              const SizedBox(height: 16),

              // Toggle switch (Gallery / Camera)
              _buildToggleSwitch(isDark, loc, theme),
              const SizedBox(height: 12),

              // Scan button (Gallery or Camera based on toggle)
              if (!_useCamera)
                _buildGalleryButton(isDark, loc)
              else
                _buildCameraButton(isDark, loc),

              const SizedBox(height: 16),

              // Scan result
              if (_scanResult != null) ...[
                _buildScanResult(isDark, loc, theme),
                const SizedBox(height: 12),
              ],

              // Scan history (separate)
              if (scanHistory.isNotEmpty) ...[
                Row(
                  children: [
                    Icon(Icons.history, size: 18, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Text(
                      loc.t('upiScanHistory'),
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
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
                      leading: Icon(Icons.qr_code_scanner, size: 20, color: AppColors.info),
                      title: Text(
                        item['upiId'] ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13),
                      ),
                      subtitle: Text(
                        item['amount'] != null && item['amount']!.isNotEmpty
                            ? '₹${item['amount']}'
                            : loc.t('upiId'),
                        style: const TextStyle(fontSize: 11),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.danger),
                        onPressed: () => storage.deleteUpiScanHistory(index),
                      ),
                      onTap: () {
                        setState(() {
                          _scanResult = Map<String, String>.from(item);
                        });
                      },
                    ),
                  );
                }),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // === ₹2000 Info Banner (Option A — full text) ===
  Widget _buildLimitBanner(bool isDark, AppLocalizations loc, ThemeData theme) {
    return Container(
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
              Text(
                loc.t('smartPayScanTitle'),
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFFD4AF37),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // RED message
          Row(
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
          const SizedBox(height: 8),
          // GREEN message
          Row(
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
        ],
      ),
    );
  }

  // === Toggle Switch (Gallery / Camera) ===
  Widget _buildToggleSwitch(bool isDark, AppLocalizations loc, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? AppColors.bgCardDark : AppColors.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.image, size: 20, color: !_useCamera ? AppColors.primary : AppColors.textSecondary),
          const SizedBox(width: 8),
          Text(loc.t('gallery'), style: TextStyle(
            fontWeight: !_useCamera ? FontWeight.bold : FontWeight.normal,
            color: !_useCamera ? AppColors.primary : AppColors.textSecondary,
          )),
          const Spacer(),
          Switch(
            value: _useCamera,
            onChanged: (value) {
              setState(() {
                _useCamera = value;
                _scanResult = null;
                if (!value) _stopCamera();
              });
            },
            activeColor: AppColors.primary,
          ),
          const SizedBox(width: 8),
          Text(loc.t('camera'), style: TextStyle(
            fontWeight: _useCamera ? FontWeight.bold : FontWeight.normal,
            color: _useCamera ? AppColors.primary : AppColors.textSecondary,
          )),
          const SizedBox(width: 8),
          Icon(Icons.camera_alt, size: 20, color: _useCamera ? AppColors.primary : AppColors.textSecondary),
        ],
      ),
    );
  }

  // === Gallery Button ===
  Widget _buildGalleryButton(bool isDark, AppLocalizations loc) {
    return GestureDetector(
      onTap: _isScanning ? null : _pickImageAndScan,
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
                : Icon(Icons.image, size: 56, color: AppColors.primary),
            const SizedBox(height: 12),
            Text(
              _isScanning ? loc.t('scanning') : loc.t('smartPayGalleryBtn'),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              loc.t('smartPayGalleryDesc'),
              style: TextStyle(
                fontSize: 11,
                color: isDark ? Colors.white54 : Colors.black54,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // === Camera Button ===
  Widget _buildCameraButton(bool isDark, AppLocalizations loc) {
    return GestureDetector(
      onTap: _startCamera,
      child: Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: isDark ? AppColors.bgCardDark : AppColors.bgCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.info.withOpacity(0.3), width: 2),
        ),
        child: Column(
          children: [
            Icon(Icons.camera_alt, size: 56, color: AppColors.info),
            const SizedBox(height: 12),
            Text(
              loc.t('smartPayCameraBtn'),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              loc.t('smartPayCameraDesc'),
              style: TextStyle(
                fontSize: 11,
                color: isDark ? Colors.white54 : Colors.black54,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // === Scan Result ===
  Widget _buildScanResult(bool isDark, AppLocalizations loc, ThemeData theme) {
    return Container(
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
              Text(
                loc.t('upiIdFound'),
                style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.success),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _resultRow('UPI ID', _scanResult!['upiId'] ?? '', theme),
          if (_scanResult!['name']?.isNotEmpty == true)
            _resultRow(loc.t('payeeName'), _scanResult!['name']!, theme),
          if (_scanResult!['amount']?.isNotEmpty == true)
            _resultRow(loc.t('amount'), '₹${_scanResult!['amount']}', theme),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _copyUpiId,
                  icon: const Icon(Icons.copy, size: 16),
                  label: Text(loc.t('copyUpi')),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _openUpiApp,
                  icon: const Icon(Icons.payment, size: 16),
                  label: Text(loc.t('openUpi')),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _saveUpiId,
                  icon: const Icon(Icons.save, size: 16),
                  label: Text(loc.t('save')),
                  style: FilledButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: AppColors.bgDark),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _resultRow(String label, String value, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text('$label: ', style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold)),
          Expanded(child: Text(value, style: theme.textTheme.bodySmall)),
        ],
      ),
    );
  }

  // === Full Screen Camera ===
  Widget _buildFullScreenCamera(bool isDark, AppLocalizations loc) {
    return Stack(
      children: [
        mscanner.MobileScanner(
          controller: _cameraController!,
          onDetect: _onCameraDetect,
        ),
        Center(
          child: Container(
            width: 240,
            height: 240,
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFD4AF37), width: 2),
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
        Positioned(
          top: 16,
          right: 16,
          child: Container(
            decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 24),
              onPressed: _stopCamera,
            ),
          ),
        ),
        Positioned(
          bottom: 32,
          left: 16,
          right: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(20)),
            child: Text(
              loc.t('scanAlignQr'),
              style: const TextStyle(color: Colors.white, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ],
    );
  }

  // === Lock Screen (Free Users) ===
  Widget _buildLockScreen(bool isDark, AppLocalizations loc, ThemeData theme) {
    return Scaffold(
      backgroundColor: isDark ? AppColors.bgDark : AppColors.bgLight,
      body: SafeArea(
        top: false,
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Color(0xFFD4AF37), Color(0xFFFFD700)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFD4AF37).withOpacity(0.4),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.lock, size: 50, color: Color(0xFF1A1A2E)),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.bolt, color: Color(0xFFD4AF37), size: 28),
                    const SizedBox(width: 8),
                    Text(
                      loc.t('upiTools'),
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFFD4AF37),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD4AF37).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFD4AF37)),
                  ),
                  child: const Text(
                    'PRO',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFD4AF37),
                      letterSpacing: 1,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  loc.t('upiPremiumLockDesc'),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const PremiumScreen()));
                    },
                    icon: const Icon(Icons.workspace_premium, size: 22),
                    label: Text(loc.t('getPremium'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFD4AF37),
                      foregroundColor: const Color(0xFF1A1A2E),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
