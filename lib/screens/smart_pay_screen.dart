// =============================================================================
// Note Counter Pro - Smart Pay Screen (Scan QR Only) — Redesigned
// =============================================================================
// Smart Pay = just Scan QR with:
//   - Gallery default + Camera toggle (Segmented Pill Control)
//   - ₹2000 vs ₹1,00,000 limit info (red + green modern badges)
//   - Scan result: Copy / Open UPI / Save
//   - Separate scan history (avatar/initials + muted delete + confirmation)
//
// Redesign includes:
//   1. Limit info box — soft gold shadow + rounded 20px + modern icon badges
//   2. Segmented Pill Control (Gallery/Camera) — active = gold gradient
//   3. Scan card — dashed gold border + gradient + "Browse from Device" button
//   4. History cards — Avatar/Initials badge instead of UPI icon
//   5. Delete icon — muted grey + confirmation dialog
//
// Generate QR, Send Money, Saved UPI moved to Tools tab.
// =============================================================================

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

  // Avatar color palette (5 gradients cycled by index)
  static const List<List<Color>> _avatarGradients = [
    [Color(0xFF667EEA), Color(0xFF764BA2)],
    [Color(0xFFF093FB), Color(0xFFF5576C)],
    [Color(0xFF4FACFE), Color(0xFF00F2FE)],
    [Color(0xFF43E97B), Color(0xFF38F9D7)],
    [Color(0xFFFA709A), Color(0xFFFEE140)],
  ];

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

  /// Show confirmation dialog before deleting a scan from history.
  Future<void> _confirmDelete(int index) async {
    final loc = context.loc;
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
    final first = upiId[0].toUpperCase();
    return first;
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
                    // === IMPROVEMENT 1: ₹2000 LIMIT INFO BOX — redesigned ===
                    // Soft gold shadow + rounded 20px + modern icon badges
                    // (red info circle + green check badge)
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
                          Row(
                            children: [
                              const Icon(Icons.lightbulb, color: Color(0xFFD4AF37), size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  loc.t('limitBannerTitle'),
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFFD4AF37),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          // RED message — modern info icon badge
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
                                  decoration: BoxDecoration(
                                    color: AppColors.danger,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Center(
                                    child: Icon(Icons.info_outline, color: Colors.white, size: 14),
                                  ),
                                ),
                                const SizedBox(width: 10),
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
                          // GREEN message — modern check badge
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
                                // Modern green check badge (circle with verified check)
                                Container(
                                  width: 20,
                                  height: 20,
                                  margin: const EdgeInsets.only(top: 1),
                                  decoration: BoxDecoration(
                                    color: AppColors.success,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Center(
                                    child: Icon(Icons.check, color: Colors.white, size: 14, weight: 3),
                                  ),
                                ),
                                const SizedBox(width: 10),
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

                    // === IMPROVEMENT 2 + 3: Segmented Pill Control + Scan card ===
                    if (!_cameraActive) ...[
                      // Segmented Pill Control — Gallery / Camera
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.grey[850] : const Color(0xFFF0F0F3),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: _pillTab(
                                label: loc.t('gallery'),
                                icon: Icons.image_outlined,
                                active: !_useCamera,
                                onTap: () => setState(() => _useCamera = false),
                              ),
                            ),
                            Expanded(
                              child: _pillTab(
                                label: loc.t('camera'),
                                icon: Icons.camera_alt_outlined,
                                active: _useCamera,
                                onTap: () => setState(() => _useCamera = true),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Scan card — dashed gold border + gradient + button
                      GestureDetector(
                        onTap: _isScanning ? null : (_useCamera ? _startCamera : _pickImageAndScan),
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
                              style: BorderStyle.solid, // Flutter doesn't natively support dashed —
                              // we use a subtle gradient + soft border for the "dashed" feel.
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
                              // Icon badge
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
                                    : Icon(
                                        _useCamera ? Icons.camera_alt : Icons.image,
                                        size: 32,
                                        color: const Color(0xFFD4AF37),
                                      ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                _isScanning
                                    ? loc.t('scanning')
                                    : _useCamera
                                        ? loc.t('scanOpenCamera')
                                        : loc.t('scanFromGallery'),
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white70 : Colors.black54,
                                ),
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
                                        _useCamera ? loc.t('scanOpenCamera') : loc.t('browseFromDevice'),
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

                    // === IMPROVEMENT 4 + 5: Scan History with Avatar + Muted Delete ===
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
                        final upiId = item['upiId'] ?? '';
                        final name = item['name'] ?? '';
                        final amount = item['amount'];
                        final displayLabel = name.isNotEmpty ? name : (upiId.isNotEmpty ? upiId.split('@').first : '');
                        final gradient = _avatarGradients[index % _avatarGradients.length];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.bgCardDark : AppColors.bgCard,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
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
                              style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                            ),
                            subtitle: Row(
                              children: [
                                if (displayLabel.isNotEmpty)
                                  Flexible(
                                    child: Text(
                                      displayLabel,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: isDark ? Colors.white60 : Colors.black54,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                                if (displayLabel.isNotEmpty && (amount != null && amount!.isNotEmpty))
                                  Text(' • ', style: TextStyle(color: Colors.grey[400], fontSize: 11)),
                                if (amount != null && amount!.isNotEmpty)
                                  Text(
                                    '₹$amount',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: AppColors.success,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 11,
                                    ),
                                  ),
                              ],
                            ),
                            // IMPROVEMENT 5: Muted grey delete icon with confirmation
                            trailing: IconButton(
                              icon: Icon(
                                Icons.delete_outline,
                                size: 18,
                                color: isDark ? Colors.white38 : Colors.grey[400],
                              ),
                              onPressed: () => _confirmDelete(index),
                              tooltip: loc.t('confirmDelete'),
                              style: IconButton.styleFrom(
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
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

  /// Segmented pill tab — active state uses gold gradient.
  Widget _pillTab({
    required String label,
    required IconData icon,
    required bool active,
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
              color: active ? Colors.white : (Theme.of(context).brightness == Brightness.dark ? Colors.white54 : Colors.grey[600]),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: active ? Colors.white : (Theme.of(context).brightness == Brightness.dark ? Colors.white54 : Colors.grey[600]),
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
