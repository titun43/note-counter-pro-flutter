// =============================================================================
// Note Counter Pro - UPI Tools Screen (Scan Only) — v3.36.0
// =============================================================================
// Smart Pay = Scan QR ONLY.
//   - ₹2000 limit info banner (Option A — full text, multi-line)
//   - One button with toggle switch: Gallery (default) ↔ Camera
//   - Gallery: FilePicker → decode QR → show result
//   - Camera: full screen camera (flash toggle + camera switch + glass bar)
//   - Scan result card: Copy UPI ID / Open UPI / Save to Saved UPI
//   - Scan history (SEPARATE from Counter's QR History) — SharedPreferences
//     key 'upiScanHistory' (managed by StorageService)
//
// No glass pill tabs. No AppBar. Clean layout.
// =============================================================================

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart' as mscanner;
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import '../services/storage_service.dart';
import '../services/saved_upi_service.dart';
import '../services/admob_service.dart';
import '../utils/constants.dart';
import '../utils/app_localizations.dart';
import '../models/saved_upi.dart';
import 'settings_screen.dart';

class UpiToolsScreen extends StatefulWidget {
  const UpiToolsScreen({super.key});

  @override
  State<UpiToolsScreen> createState() => _UpiToolsScreenState();
}

class _UpiToolsScreenState extends State<UpiToolsScreen> {
  // false = Gallery (default), true = Camera
  bool _useCamera = false;

  // Flash state: 0 = OFF, 1 = AUTO, 2 = ON (cycles OFF → AUTO → ON → OFF)
  int _flashMode = 0;

  mscanner.MobileScannerController? _cameraController;
  bool _cameraActive = false;

  bool _isScanning = false;
  Map<String, String>? _scanResult;
  String? _scanError;

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  // === CAMERA METHODS ===

  void _startCamera() {
    _cameraController?.dispose();
    _cameraController = mscanner.MobileScannerController(
      detectionSpeed: mscanner.DetectionSpeed.noDuplicates,
      facing: mscanner.CameraFacing.back,
      autoStart: true,
    );
    // Apply torch if flash is ON
    if (_flashMode == 2) {
      Future.delayed(const Duration(milliseconds: 500), () {
        _cameraController?.toggleTorch();
      });
    }
    setState(() {
      _cameraActive = true;
      _scanResult = null;
      _scanError = null;
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

  /// Cycle flash mode: OFF → AUTO → ON → OFF
  void _toggleFlash() {
    setState(() {
      _flashMode = (_flashMode + 1) % 3;
    });
    if (_cameraActive && _cameraController != null) {
      _cameraController!.toggleTorch();
    }
  }

  /// Switch camera between front and back
  void _switchCamera() {
    if (_cameraController == null) return;
    _cameraController!.switchCamera();
  }

  // === GALLERY METHOD ===

  Future<void> _pickImageAndScan() async {
    final loc = context.loc;
    setState(() {
      _isScanning = true;
      _scanResult = null;
      _scanError = null;
    });

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) {
        if (mounted) setState(() => _isScanning = false);
        return;
      }

      final filePath = result.files.first.path;
      if (filePath == null) {
        if (mounted) {
          setState(() {
            _isScanning = false;
            _scanError = loc.t('scanImageError');
          });
        }
        return;
      }

      final controller = mscanner.MobileScannerController(
        detectionSpeed: mscanner.DetectionSpeed.noDuplicates,
      );
      final capture = await controller.analyzeImage(filePath);
      controller.dispose();

      if (capture == null || capture.barcodes.isEmpty) {
        if (mounted) {
          setState(() {
            _isScanning = false;
            _scanError = loc.t('noQrFound');
          });
        }
        return;
      }

      final rawValue = capture.barcodes.first.rawValue;
      if (rawValue == null || rawValue.isEmpty) {
        if (mounted) {
          setState(() {
            _isScanning = false;
            _scanError = loc.t('qrReadError');
          });
        }
        return;
      }

      _processScanResult(rawValue);
    } catch (e) {
      if (mounted) {
        setState(() {
          _isScanning = false;
          _scanError = '${loc.t('scanFailed')}: $e';
        });
      }
    }
  }

  // === RESULT PARSER ===

  void _processScanResult(String rawValue) {
    String upiId = '';
    String name = '';
    String amount = '';
    String note = '';

    if (rawValue.startsWith('upi://')) {
      final uri = Uri.tryParse(rawValue);
      if (uri != null) {
        final params = uri.queryParameters;
        upiId = params['pa'] ?? '';
        name = params['pn'] != null ? Uri.decodeComponent(params['pn']!) : '';
        amount = params['am'] ?? '';
        note = params['tn'] != null ? Uri.decodeComponent(params['tn']!) : '';
      }
    } else if (rawValue.contains('@') && !rawValue.contains(' ')) {
      upiId = rawValue;
    } else {
      // Not a UPI QR — show raw content as upiId placeholder
      upiId = rawValue;
    }

    final result = {
      'upiId': upiId,
      'name': name,
      'amount': amount,
      'note': note,
      'rawUrl': rawValue.startsWith('upi://') ? rawValue : (upiId.contains('@') ? 'upi://pay?pa=$upiId' : rawValue),
      'timestamp': DateTime.now().toIso8601String(),
    };

    setState(() {
      _scanResult = result;
      _isScanning = false;
      _scanError = null;
    });

    // Save to UPI scan history (separate from Counter's QR History)
    try {
      context.read<StorageService>().addUpiScanHistory(result);
    } catch (e) {
      debugPrint('Save UPI scan history failed: $e');
    }
  }

  // === RESULT ACTIONS ===

  void _copyUpiId() {
    final upiId = _scanResult?['upiId'];
    if (upiId == null || upiId.isEmpty) return;
    Clipboard.setData(ClipboardData(text: upiId));
    final loc = context.loc;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${loc.t('upiIdCopied')}: $upiId'),
        backgroundColor: AppColors.success,
      ),
    );
  }

  Future<void> _openUpiApp() async {
    final rawUrl = _scanResult?['rawUrl'];
    if (rawUrl == null) return;

    String upiLink;
    if (rawUrl.startsWith('upi://')) {
      upiLink = rawUrl;
    } else {
      upiLink = 'upi://pay?pa=$rawUrl';
    }

    AdMobService.showInterstitial();

    try {
      final uri = Uri.parse(upiLink);
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched && mounted) {
        final launched2 = await launchUrl(uri);
        if (!launched2 && mounted) {
          await Clipboard.setData(ClipboardData(text: upiLink));
          final loc = context.loc;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(loc.t('upiLinkCopied')),
              backgroundColor: AppColors.info,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('UPI launch failed: $e');
      await Clipboard.setData(ClipboardData(text: upiLink));
      if (mounted) {
        final loc = context.loc;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(loc.t('upiLinkCopied')),
            backgroundColor: AppColors.info,
          ),
        );
      }
    }
  }

  void _saveUpiId() {
    if (_scanResult == null) return;
    final upiId = _scanResult!['upiId']!;
    if (upiId.isEmpty) return;
    final name = _scanResult!['name']?.isNotEmpty == true
        ? _scanResult!['name']!
        : (upiId.contains('@') ? upiId.split('@').first : upiId);
    final newUpi = SavedUpi.create(upiId: upiId, name: name, group: 'other');
    SavedUpiService().add(newUpi).then((success) {
      if (!mounted) return;
      final loc = context.loc;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? loc.t('scanSavedSuccess') : loc.t('upiAlreadyExists')),
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

    // If camera is active, show full screen camera (no banner, no scroll)
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
              // === Top bar with title + gear icon ===
              // Settings is no longer a tab — gear icon opens SettingsScreen.
              Row(
                children: [
                  Icon(Icons.bolt, size: 24, color: const Color(0xFFD4AF37)),
                  const SizedBox(width: 8),
                  Text(
                    loc.t('upiTools'),
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontFamily: 'KhataHandwriting',
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.settings_outlined),
                    tooltip: loc.t('settings'),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const SettingsScreen()),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // ₹2000 Info Banner (Option A — full text, multi-line)
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

              // Scan error
              if (_scanError != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.danger.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.danger, width: 1),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: AppColors.danger, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _scanError!,
                          style: const TextStyle(color: AppColors.danger, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Scan result
              if (_scanResult != null && _scanResult!['upiId']!.isNotEmpty) ...[
                _buildScanResult(isDark, loc, theme),
                const SizedBox(height: 12),
              ],

              // Scan history (separate from Counter's QR History)
              _buildScanHistory(isDark, loc, theme, storage, scanHistory),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  // === ₹2000 INFO BANNER — redesigned (soft gold shadow + rounded 20px + modern icon badges) ===
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
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFD4AF37).withOpacity(0.5),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFD4AF37).withOpacity(isDark ? 0.18 : 0.22),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title line (lightbulb + limitInfoFull1)
          Row(
            children: [
              const Icon(Icons.lightbulb, color: Color(0xFFD4AF37), size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  loc.t('limitInfoFull1'),
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFFD4AF37),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // RED block — modern info badge + limitInfoFull2 + limitInfoFull3
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.danger.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.danger.withOpacity(0.25)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Modern red info badge (circle with 'i')
                Container(
                  width: 20,
                  height: 20,
                  margin: const EdgeInsets.only(top: 1),
                  decoration: const BoxDecoration(
                    color: AppColors.danger,
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Icon(Icons.info_outline, color: Colors.white, size: 14),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        loc.t('limitInfoFull2'),
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.danger,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        loc.t('limitInfoFull3'),
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.danger,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // GREEN block — modern check badge + limitInfoFull4 + limitInfoFull5
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.success.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.success.withOpacity(0.25)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Modern green check badge (circle with check)
                Container(
                  width: 20,
                  height: 20,
                  margin: const EdgeInsets.only(top: 1),
                  decoration: const BoxDecoration(
                    color: AppColors.success,
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Icon(Icons.check, color: Colors.white, size: 14),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        loc.t('limitInfoFull4'),
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.success,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        loc.t('limitInfoFull5'),
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.success,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // === SEGMENTED PILL CONTROL (Gallery / Camera) — replaces Switch ===
  Widget _buildToggleSwitch(bool isDark, AppLocalizations loc, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[850] : const Color(0xFFF0F0F3),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: _pillTab(
              label: loc.t('scanGalleryMode'),
              icon: Icons.image_outlined,
              active: !_useCamera,
              isDark: isDark,
              onTap: () {
                setState(() {
                  _useCamera = false;
                  _scanResult = null;
                  _scanError = null;
                  _stopCamera();
                });
              },
            ),
          ),
          Expanded(
            child: _pillTab(
              label: loc.t('scanCameraMode'),
              icon: Icons.camera_alt_outlined,
              active: _useCamera,
              isDark: isDark,
              onTap: () {
                setState(() {
                  _useCamera = true;
                  _scanResult = null;
                  _scanError = null;
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Single segmented pill tab — active state uses gold gradient + shadow
  Widget _pillTab({
    required String label,
    required IconData icon,
    required bool active,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          gradient: active
              ? const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFD4AF37), Color(0xFFB8941F)],
                )
              : null,
          borderRadius: BorderRadius.circular(10),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: const Color(0xFFD4AF37).withOpacity(0.35),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: active
                  ? Colors.white
                  : (isDark ? Colors.white54 : Colors.grey[600]),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: active
                      ? Colors.white
                      : (isDark ? Colors.white54 : Colors.grey[600]),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // === GALLERY BUTTON — redesigned with gradient + icon badge + Browse button ===
  Widget _buildGalleryButton(bool isDark, AppLocalizations loc) {
    return GestureDetector(
      onTap: _isScanning ? null : _pickImageAndScan,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [AppColors.bgCardDark, const Color(0xFF2A2418)]
                : [Colors.white, const Color(0xFFFFF7ED)],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: const Color(0xFFD4AF37).withOpacity(0.5),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFD4AF37).withOpacity(0.10),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          children: [
            // Icon badge (rounded square with gold gradient)
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFFFF7ED), Color(0xFFFFEDD5)],
                ),
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFD4AF37).withOpacity(0.20),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: _isScanning
                  ? const CircularProgressIndicator(color: Color(0xFFD4AF37))
                  : const Icon(Icons.image, size: 32, color: Color(0xFFD4AF37)),
            ),
            const SizedBox(height: 12),
            Text(
              _isScanning ? loc.t('scanning') : loc.t('scanSelectImage'),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white70 : Colors.black54,
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
            const SizedBox(height: 16),
            // Modern "Browse from Device" button
            if (!_isScanning)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFD4AF37), Color(0xFFB8941F)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFD4AF37).withOpacity(0.35),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.folder_open, color: Colors.white, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      loc.t('browseFromDevice'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  // === CAMERA BUTTON ===
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
              loc.t('scanOpenCamera2'),
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

  // === SCAN RESULT CARD ===
  Widget _buildScanResult(bool isDark, AppLocalizations loc, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.success.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.success.withOpacity(0.4), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.check_circle, color: AppColors.success, size: 22),
              const SizedBox(width: 8),
              Text(
                loc.t('scanUpiFound'),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.success,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _resultRow('UPI ID', _scanResult!['upiId'] ?? '', theme),
          if (_scanResult!['name']?.isNotEmpty == true)
            _resultRow(loc.t('payeeName'), _scanResult!['name']!, theme),
          if (_scanResult!['amount']?.isNotEmpty == true)
            _resultRow(loc.t('amount'), '₹${_scanResult!['amount']}', theme),
          if (_scanResult!['note']?.isNotEmpty == true)
            _resultRow(loc.t('noteLabel'), _scanResult!['note']!, theme),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _copyUpiId,
                  icon: const Icon(Icons.copy, size: 16),
                  label: Text(loc.t('copyUpi'), style: const TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _openUpiApp,
                  icon: const Icon(Icons.payment, size: 16),
                  label: Text(loc.t('openUpi'), style: const TextStyle(fontSize: 12)),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.success,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _saveUpiId,
                  icon: const Icon(Icons.save, size: 16),
                  label: Text(loc.t('scanSave'), style: const TextStyle(fontSize: 12)),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.bgDark,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
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
          SizedBox(
            width: 70,
            child: Text(
              '$label: ',
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  // === SCAN HISTORY — redesigned (Avatar badge + muted delete + confirmation) ===
  // Avatar color palette (5 gradients cycled by index)
  static const List<List<Color>> _avatarGradients = [
    [Color(0xFF667EEA), Color(0xFF764BA2)],
    [Color(0xFFF093FB), Color(0xFFF5576C)],
    [Color(0xFF4FACFE), Color(0xFF00F2FE)],
    [Color(0xFF43E97B), Color(0xFF38F9D7)],
    [Color(0xFFFA709A), Color(0xFFFEE140)],
  ];

  /// Show confirmation dialog before deleting a scan from history.
  Future<void> _confirmDelete(int index, AppLocalizations loc) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: AppColors.danger, size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                loc.t('confirmDeleteTitle'),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Text(loc.t('confirmDeleteMsg'), style: const TextStyle(fontSize: 13)),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(loc.t('cancelDelete')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(loc.t('confirmDelete')),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      context.read<StorageService>().deleteUpiScanHistory(index);
    }
  }

  /// Generate initials from UPI ID (e.g. 'saurav@okhdfc' → 'S').
  String _initials(String upiId) {
    if (upiId.isEmpty) return '?';
    return upiId[0].toUpperCase();
  }

  Widget _buildScanHistory(
      bool isDark, AppLocalizations loc, ThemeData theme, StorageService storage, List<Map<String, String>> history) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.history, size: 18, color: AppColors.primary),
            const SizedBox(width: 8),
            Text(
              loc.t('scanHistoryTitle'),
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (history.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? AppColors.bgCardDark : AppColors.bgCard,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: (isDark ? AppColors.textSecondaryDark : AppColors.textSecondary).withOpacity(0.2),
              ),
            ),
            child: Column(
              children: [
                Icon(Icons.history_toggle_off, size: 36,
                    color: (isDark ? AppColors.textSecondaryDark : AppColors.textSecondary).withOpacity(0.5)),
                const SizedBox(height: 8),
                Text(
                  loc.t('scanNoHistory'),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          )
        else
          // Unlimited history list (max height + scroll for clean layout)
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 400),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: history.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final item = history[index];
                final upiId = item['upiId'] ?? '';
                final name = item['name'] ?? '';
                final amount = item['amount'];
                final displayLabel = name.isNotEmpty
                    ? name
                    : (upiId.isNotEmpty ? upiId.split('@').first : '');
                final gradient = _avatarGradients[index % _avatarGradients.length];
                return Container(
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.bgCardDark : AppColors.bgCard,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withOpacity(0.05)
                          : Colors.black.withOpacity(0.05),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 3,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    // IMPROVEMENT 4: Avatar / Initials badge
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: gradient,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.12),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          _initials(upiId.isNotEmpty ? upiId : displayLabel),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                    title: Text(
                      upiId,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Row(
                      children: [
                        if (displayLabel.isNotEmpty)
                          Flexible(
                            child: Text(
                              displayLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? Colors.white60 : Colors.black54,
                              ),
                            ),
                          ),
                        if (displayLabel.isNotEmpty && (amount?.isNotEmpty == true))
                          Text(' · ', style: TextStyle(color: Colors.grey[400], fontSize: 11)),
                        if (amount?.isNotEmpty == true)
                          Text(
                            '₹$amount',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.success,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                      ],
                    ),
                    // IMPROVEMENT 5: Muted grey delete icon with confirmation dialog
                    trailing: IconButton(
                      icon: Icon(
                        Icons.delete_outline,
                        size: 18,
                        color: isDark ? Colors.white38 : Colors.grey[400],
                      ),
                      onPressed: () => _confirmDelete(index, loc),
                      tooltip: loc.t('confirmDelete'),
                      style: IconButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    onTap: () {
                      setState(() {
                        _scanResult = Map<String, String>.from(item);
                        _scanError = null;
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(loc.t('scanUpiFound')),
                          backgroundColor: AppColors.success,
                          duration: const Duration(seconds: 1),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  // === FULL SCREEN CAMERA (with flash toggle + camera switch + glass controls bar) ===
  Widget _buildFullScreenCamera(bool isDark, AppLocalizations loc) {
    return Stack(
      children: [
        // Camera fills entire screen
        mscanner.MobileScanner(
          controller: _cameraController!,
          onDetect: _onCameraDetect,
        ),

        // Gold gradient scan frame overlay
        Center(
          child: Container(
            width: 240,
            height: 240,
            decoration: BoxDecoration(
              border: Border.all(
                color: const Color(0xFFD4AF37),
                width: 2,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Stack(
              children: [
                ..._buildScanFrameCorners(),
              ],
            ),
          ),
        ),

        // Hint text below frame
        Positioned(
          top: 0,
          bottom: 0,
          left: 0,
          right: 0,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              const SizedBox(height: 80),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  loc.t('alignQrHere'),
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
              const SizedBox(height: 100),
            ],
          ),
        ),

        // Close button (top-right)
        Positioned(
          top: 16,
          right: 16,
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.black54,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 24),
              onPressed: _stopCamera,
            ),
          ),
        ),

        // Floating glass controls bar (bottom) — Flash, Switch camera
        Positioned(
          bottom: 32,
          left: 16,
          right: 16,
          child: _buildGlassControlsBar(loc),
        ),
      ],
    );
  }

  List<Widget> _buildScanFrameCorners() {
    const corner = Color(0xFFFFD700);
    const size = 24.0;
    const width = 3.0;
    return [
      Positioned(top: -2, left: -2, child: Container(width: size, height: size, decoration: const BoxDecoration(border: Border(top: BorderSide(color: corner, width: width), left: BorderSide(color: corner, width: width))))),
      Positioned(top: -2, right: -2, child: Container(width: size, height: size, decoration: const BoxDecoration(border: Border(top: BorderSide(color: corner, width: width), right: BorderSide(color: corner, width: width))))),
      Positioned(bottom: -2, left: -2, child: Container(width: size, height: size, decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: corner, width: width), left: BorderSide(color: corner, width: width))))),
      Positioned(bottom: -2, right: -2, child: Container(width: size, height: size, decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: corner, width: width), right: BorderSide(color: corner, width: width))))),
    ];
  }

  // === GLASS CONTROLS BAR (Flash + Switch camera) ===
  Widget _buildGlassControlsBar(AppLocalizations loc) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.5),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildControlButton(
                icon: _flashMode == 0
                    ? Icons.flash_off
                    : _flashMode == 1
                        ? Icons.flash_auto
                        : Icons.flash_on,
                label: _flashMode == 0
                    ? 'Off'
                    : _flashMode == 1
                        ? 'Auto'
                        : 'On',
                color: _flashMode > 0 ? const Color(0xFFD4AF37) : Colors.white70,
                onTap: _toggleFlash,
              ),
              _buildControlButton(
                icon: Icons.cameraswitch_outlined,
                label: loc.t('switchCamera'),
                color: Colors.white70,
                onTap: _switchCamera,
              ),
              _buildControlButton(
                icon: Icons.image_outlined,
                label: loc.t('scanGalleryMode'),
                color: Colors.white70,
                onTap: () {
                  _stopCamera();
                  setState(() => _useCamera = false);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
