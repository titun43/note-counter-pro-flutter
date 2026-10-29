// =============================================================================
// Note Counter Pro - UPI Tools Screen (Premium)
// =============================================================================
// Four-in-one UPI tool (v3.27.0):
//   Tab 1: Generate QR — enter UPI ID/name/amount → generate QR code
//   Tab 2: Scan QR — live camera OR gallery image → decode QR → extract UPI ID
//   Tab 3: Send Money — enter UPI ID + amount → launch UPI deep link
//   Tab 4: Saved UPI — manage saved UPI IDs (Contacts-style)
//
// The Scan feature solves a real problem: UPI QR scan limit is ₹2000
// (same mobile), but UPI ID send limit is ₹1 lakh. By scanning a QR
// via camera or gallery, the user can extract the UPI ID and send
// larger amounts directly from their UPI app.
// =============================================================================

import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:screenshot/screenshot.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import '../services/storage_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart' as mscanner;
import 'package:url_launcher/url_launcher.dart';
import '../services/premium_service.dart';
import '../utils/constants.dart';
import '../utils/app_localizations.dart';
import 'premium_screen.dart';
import 'send_money_screen.dart';
import 'saved_upi_screen.dart';

class UpiToolsScreen extends StatefulWidget {
  const UpiToolsScreen({super.key});

  @override
  State<UpiToolsScreen> createState() => _UpiToolsScreenState();
}

class _UpiToolsScreenState extends State<UpiToolsScreen> {
  // Default to Scan QR tab (index 1) — user opens Smart Pay to scan a
  // merchant QR and send money. The ₹2000-limit banner on the Scan tab
  // explains why scanning here is better than scanning directly in
  // their UPI app's gallery (which has a ₹2000 same-mobile limit).
  int _currentTab = 1; // 0 = Generate, 1 = Scan, 2 = Send, 3 = Saved
  int _scanMode = 0; // 0 = Camera, 1 = Gallery

  // === Flash state ===
  // 0 = OFF, 1 = AUTO, 2 = ON (cycles: OFF → AUTO → ON → OFF)
  int _flashMode = 0;

  // === Generate tab state ===
  final _upiIdController = TextEditingController();
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  final _screenshotController = ScreenshotController();
  String? _generatedUpiUrl;

  // === Scan tab state ===
  bool _isScanning = false;
  Map<String, String>? _scanResult;
  String? _scanError;
  final List<Map<String, String>> _scanHistory = [];
  mscanner.MobileScannerController? _cameraController;
  bool _cameraActive = false;

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
    _cameraController?.dispose();
    super.dispose();
  }

  // === GENERATE TAB METHODS ===

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

    // ✅ Smart save to QR history (Counter → History → QR Code History tab)
    // If UPI ID already exists, update existing entry; else add new entry.
    // Unlimited history.
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
      debugPrint('UpiTools: QR saved to history (smart save) for UPI ID: $upiId');
    } catch (e) {
      debugPrint('UpiTools: Failed to save QR to history: $e');
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

  // === SCAN TAB — CAMERA METHODS ===

  void _startCamera() {
    _cameraController?.dispose();
    // Apply current flash mode setting
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

  /// Cycle flash mode: OFF → AUTO → ON → OFF
  void _toggleFlash() {
    setState(() {
      _flashMode = (_flashMode + 1) % 3;
    });
    // Apply flash to current camera if active
    if (_cameraActive && _cameraController != null) {
      // For AUTO mode (1), we treat it same as OFF for torch.
      // For ON mode (2), enable torch.
      // For OFF mode (0), disable torch.
      _cameraController!.toggleTorch();
    }
    debugPrint('UpiTools: flash mode = $_flashMode (0=OFF, 1=AUTO, 2=ON)');
  }

  /// Switch camera between front and back
  void _switchCamera() {
    if (_cameraController == null) return;
    _cameraController!.switchCamera();
    debugPrint('UpiTools: camera switched');
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
    _parseUpiString(rawValue);
  }

  // === SCAN TAB — GALLERY METHODS ===

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
        setState(() => _isScanning = false);
        return;
      }

      final filePath = result.files.first.path;
      if (filePath == null) {
        setState(() {
          _isScanning = false;
          _scanError = loc.t('scanImageError');
        });
        return;
      }

      final controller = mscanner.MobileScannerController(
        detectionSpeed: mscanner.DetectionSpeed.noDuplicates,
      );
      final barcode = await controller.analyzeImage(filePath);
      controller.dispose();

      if (barcode == null || barcode.barcodes.isEmpty) {
        setState(() {
          _isScanning = false;
          _scanError = loc.t('noQrFound');
        });
        return;
      }

      final rawValue = barcode.barcodes.first.rawValue;
      if (rawValue == null) {
        setState(() {
          _isScanning = false;
          _scanError = loc.t('qrReadError');
        });
        return;
      }

      _parseUpiString(rawValue);
    } catch (e) {
      setState(() {
        _isScanning = false;
        _scanError = '${loc.t('scanFailed')}: $e';
      });
    }
  }

  /// Parse a UPI deep link string and extract fields.
  void _parseUpiString(String upiString) {
    final result = <String, String>{};

    if (upiString.startsWith('upi://')) {
      final uri = Uri.tryParse(upiString);
      if (uri != null) {
        final params = uri.queryParameters;
        result['upiId'] = params['pa'] ?? '';
        result['name'] = params['pn'] != null
            ? Uri.decodeComponent(params['pn']!)
            : '';
        result['amount'] = params['am'] ?? '';
        result['note'] = params['tn'] != null
            ? Uri.decodeComponent(params['tn']!)
            : '';
        result['rawUrl'] = upiString;
      }
    } else if (upiString.contains('@') && !upiString.contains(' ')) {
      result['upiId'] = upiString;
      result['name'] = '';
      result['amount'] = '';
      result['note'] = '';
      result['rawUrl'] = upiString;
    } else {
      result['rawUrl'] = upiString;
      result['upiId'] = '';
    }

    setState(() {
      _scanResult = result;
      _isScanning = false;
      _scanError = null;
      if (result['upiId']!.isNotEmpty) {
        _scanHistory.insert(0, {
          'upiId': result['upiId']!,
          'name': result['name'] ?? '',
          'time': '${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}',
        });
      }
    });
  }

  void _copyScannedUpiId() {
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

    debugPrint('UpiTools: _openUpiApp — launching UPI link: $upiLink');

    try {
      final uri = Uri.parse(upiLink);
      // BUG FIX (v3.30.0): Removed canLaunchUrl() check.
      // On Android 11+ package visibility restrictions cause canLaunchUrl()
      // to return false even when UPI apps (PhonePe/GPay/Paytm/BHIM) are
      // installed. This made the button silently fall back to clipboard
      // copy instead of opening any UPI app.
      //
      // Now we directly call launchUrl() with externalApplication mode —
      // the system shows the UPI app chooser if multiple apps are installed,
      // or opens the single installed UPI app directly.
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);

      debugPrint('UpiTools: launchUrl returned = $launched');

      if (!launched && mounted) {
        // Fallback: try platformDefault mode
        final launched2 = await launchUrl(uri);
        debugPrint('UpiTools: launchUrl fallback returned = $launched2');
        if (!launched2 && mounted) {
          // Last resort: copy to clipboard
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
      debugPrint('UpiTools: _openUpiApp EXCEPTION: $e');
      // Fallback: copy to clipboard
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

  void _saveToHistory() {
    if (_scanResult == null) return;
    final loc = context.loc;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(loc.t('savedToHistory')),
        backgroundColor: AppColors.success,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        top: false, // MainScaffold handles top padding for banner ad
        child: Column(
          children: [
            // === COMPACT GLASS PILL TAB SELECTOR (48px height) ===
            Container(
              margin: const EdgeInsets.fromLTRB(8, 8, 8, 4),
              child: _buildGlassPillTabs(isDark, loc),
            ),
            // === CONTENT ===
            Expanded(
              child: _currentTab == 0
                  ? _buildGenerateTab(isDark, loc)
                  : _currentTab == 1
                      ? _buildScanTab(isDark, loc)
                      : _currentTab == 2
                          ? _buildSendTab(loc)
                          : _buildSavedTab(loc),
            ),
          ],
        ),
      ),
    );
  }

  // === GLASS PILL TABS (compact, 48px height, icon+label same line) ===
  Widget _buildGlassPillTabs(bool isDark, AppLocalizations loc) {
    final tabs = [
      _GlassTab(Icons.qr_code_2, loc.t('generateQr'), AppColors.primary),
      _GlassTab(Icons.image_search, loc.t('scanQr'), AppColors.info),
      _GlassTab(Icons.send, loc.t('sendMoney'), AppColors.success),
      _GlassTab(Icons.people, loc.t('saved'), const Color(0xFFEC4899)),
    ];

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF16213E).withOpacity(0.7)
                : Colors.white.withOpacity(0.7),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: List.generate(tabs.length, (index) {
              final tab = tabs[index];
              final isActive = _currentTab == index;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _currentTab = index),
                  behavior: HitTestBehavior.opaque,
                  child: _buildGlassTabItem(tab, isActive),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }

  Widget _buildGlassTabItem(_GlassTab tab, bool isActive) {
    if (isActive) {
      return Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFD4AF37), Color(0xFFFFD700)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(tab.icon, size: 18, color: const Color(0xFF1A1A2E)),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                tab.label,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A2E),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(tab.icon, size: 18, color: tab.color.withOpacity(0.7)),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            tab.label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: tab.color.withOpacity(0.7),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  // === SEND TAB — launches SendMoneyScreen full screen ===
  Widget _buildSendTab(AppLocalizations loc) {
    return const SendMoneyScreen();
  }

  // === SAVED TAB — launches SavedUpiScreen full screen ===
  Widget _buildSavedTab(AppLocalizations loc) {
    return const SavedUpiScreen();
  }

  // === TAB CARD ===
  Widget _buildTabCard({
    required IconData icon,
    required String label,
    required String subtitle,
    required bool isActive,
    required Color color,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isActive
              ? color.withOpacity(0.15)
              : (isDark ? const Color(0xFF16213E) : Colors.white),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive ? color : const Color(0xFFD4AF37).withOpacity(0.2),
            width: isActive ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, size: 28, color: isActive ? color : AppColors.textSecondary),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: isActive ? color : AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 9,
                color: isActive ? color.withOpacity(0.7) : AppColors.textSecondary.withOpacity(0.6),
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  // === GENERATE TAB ===
  Widget _buildGenerateTab(bool isDark, AppLocalizations loc) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        children: [
          _buildInputField(
            controller: _upiIdController,
            label: '${loc.t('upiId')} *',
            hint: 'yourname@upi',
            icon: Icons.payment,
          ),
          const SizedBox(height: 8),
          _buildInputField(
            controller: _nameController,
            label: loc.t('nameLabel'),
            hint: loc.t('nameLabel'),
            icon: Icons.person,
          ),
          const SizedBox(height: 8),
          _buildInputField(
            controller: _amountController,
            label: loc.t('amount'),
            hint: '₹ 0',
            icon: Icons.currency_rupee,
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 8),
          _buildInputField(
            controller: _noteController,
            label: loc.t('noteLabel'),
            hint: loc.t('noteLabel'),
            icon: Icons.note,
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _generateQr,
              icon: const Icon(Icons.qr_code),
              label: Text(loc.t('generateQrCode')),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.bgDark,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (_generatedUpiUrl != null) ...[
            Screenshot(
              controller: _screenshotController,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF16213E) : Colors.white,
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
    );
  }

  // === PROMINENT ₹2000 LIMIT BANNER ===
  // Two clear messages:
  //  🔴 Direct scan in UPI app gallery → ₹2,000 limit
  //  🟢 Scan here → extract UPI ID → send up to ₹1,00,000
  Widget _buildLimitBanner(bool isDark, AppLocalizations loc) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
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
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFD4AF37).withOpacity(0.15),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
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
          const SizedBox(height: 10),
          // RED message — direct gallery scan limit
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.danger.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AppColors.danger.withOpacity(0.3),
                width: 1,
              ),
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
          // GREEN message — scan here for ₹1 lakh
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.success.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AppColors.success.withOpacity(0.3),
                width: 1,
              ),
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
    );
  }

  // === FULL SCREEN CAMERA (when camera is active) ===
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
                // Corner accents (gold, L-shaped)
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
            decoration: BoxDecoration(
              color: Colors.black54,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 24),
              onPressed: _stopCamera,
            ),
          ),
        ),

        // Floating glass controls bar (bottom)
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

  // === GLASS CONTROLS BAR (Flash, Switch, Gallery) ===
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
              // Flash button (cycles OFF → AUTO → ON)
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
              // Switch camera button
              _buildControlButton(
                icon: Icons.cameraswitch_outlined,
                label: loc.t('switchCamera'),
                color: Colors.white70,
                onTap: _switchCamera,
              ),
              // Gallery button
              _buildControlButton(
                icon: Icons.image_outlined,
                label: loc.t('gallery'),
                color: Colors.white70,
                onTap: () {
                  _stopCamera();
                  setState(() => _scanMode = 1);
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

  // === COMPACT ₹2000 LIMIT BANNER ===
  Widget _buildCompactLimitBanner(bool isDark, AppLocalizations loc) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [const Color(0xFFD4AF37).withOpacity(0.15), const Color(0xFFFFD700).withOpacity(0.05)],
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFD4AF37).withOpacity(0.3), width: 1),
      ),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                Icon(Icons.cancel, color: AppColors.danger, size: 14),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    loc.t('limitBannerRed'),
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.danger),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          Container(width: 1, height: 20, color: const Color(0xFFD4AF37).withOpacity(0.3)),
          const SizedBox(width: 8),
          Expanded(
            child: Row(
              children: [
                Icon(Icons.check_circle, color: AppColors.success, size: 14),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    loc.t('limitBannerGreen'),
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.success),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // === SCAN TAB ===
  Widget _buildScanTab(bool isDark, AppLocalizations loc) {
    // If camera is active, show full-screen camera (no banner, no scroll)
    if (_scanMode == 0 && _cameraActive) {
      return _buildFullScreenCamera(isDark, loc);
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        children: [
          // === COMPACT ₹2000 LIMIT BANNER ===
          _buildCompactLimitBanner(isDark, loc),
          const SizedBox(height: 8),
          // Scan mode selector: Camera vs Gallery (compact)
          Row(
            children: [
              Expanded(
                child: _buildScanModeCard(
                  icon: Icons.camera_alt,
                  label: loc.t('camera'),
                  isActive: _scanMode == 0,
                  onTap: () {
                    setState(() => _scanMode = 0);
                    _stopCamera();
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildScanModeCard(
                  icon: Icons.image,
                  label: loc.t('gallery'),
                  isActive: _scanMode == 1,
                  onTap: () {
                    setState(() => _scanMode = 1);
                    _stopCamera();
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Camera mode — start button
          if (_scanMode == 0) ...[
            GestureDetector(
              onTap: _startCamera,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF16213E) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.info.withOpacity(0.3),
                    width: 2,
                  ),
                ),
                child: Column(
                  children: [
                    Icon(Icons.camera_alt, size: 56, color: AppColors.info),
                    const SizedBox(height: 12),
                    Text(
                      loc.t('openCamera'),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      loc.t('openCameraDesc'),
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.white54 : Colors.black54,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ],

          // Gallery mode
          if (_scanMode == 1) ...[
            GestureDetector(
              onTap: _isScanning ? null : _pickImageAndScan,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF16213E) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.info.withOpacity(0.3),
                    width: 2,
                  ),
                ),
                child: Column(
                  children: [
                    _isScanning
                        ? const CircularProgressIndicator()
                        : Icon(Icons.image_search, size: 56, color: AppColors.info),
                    const SizedBox(height: 12),
                    Text(
                      _isScanning ? loc.t('scanning') : loc.t('selectImage'),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      loc.t('selectImageDesc'),
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.white54 : Colors.black54,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ],
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
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.success.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.success, width: 1.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.check_circle, color: AppColors.success, size: 24),
                      const SizedBox(width: 8),
                      Text(
                        loc.t('upiIdFound'),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.success,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _scanResultRow('UPI ID', _scanResult!['upiId']!),
                  if (_scanResult!['name']!.isNotEmpty)
                    _scanResultRow(loc.t('nameLabel'), _scanResult!['name']!),
                  if (_scanResult!['amount']!.isNotEmpty)
                    _scanResultRow(loc.t('amount'), '₹ ${_scanResult!['amount']}'),
                  if (_scanResult!['note']!.isNotEmpty)
                    _scanResultRow(loc.t('noteLabel'), _scanResult!['note']!),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _copyScannedUpiId,
                          icon: const Icon(Icons.copy, size: 16),
                          label: Text(loc.t('copyUpi'), style: const TextStyle(fontSize: 12)),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.info,
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
                          onPressed: _saveToHistory,
                          icon: const Icon(Icons.save, size: 16),
                          label: Text(loc.t('save'), style: const TextStyle(fontSize: 12)),
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
            ),
            const SizedBox(height: 16),
          ],

          // Scan history
          if (_scanHistory.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF16213E) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFFD4AF37).withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.history, size: 16, color: AppColors.info),
                      const SizedBox(width: 6),
                      Text(
                        loc.t('recentScans'),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () => setState(() => _scanHistory.clear()),
                        child: Text(loc.t('clear'), style: const TextStyle(fontSize: 11)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ..._scanHistory.map((item) => ListTile(
                    dense: true,
                    leading: const Icon(Icons.qr_code, size: 20, color: AppColors.info),
                    title: Text(
                      item['upiId'] ?? '',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                    subtitle: Text(
                      item['name']?.isNotEmpty == true ? item['name']! : '',
                      style: const TextStyle(fontSize: 11),
                    ),
                    trailing: Text(
                      item['time'] ?? '',
                      style: TextStyle(
                        fontSize: 10,
                        color: isDark ? Colors.white54 : Colors.black54,
                      ),
                    ),
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: item['upiId']!));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('${loc.t('upiIdCopied')}: ${item['upiId']}'),
                          backgroundColor: AppColors.success,
                        ),
                      );
                    },
                  )),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Info note — ₹2000 limit (moved to top of Scan tab as prominent banner)
          // See _buildLimitBanner() above.
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // === SCAN MODE CARD ===
  Widget _buildScanModeCard({
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: isActive
              ? AppColors.info.withOpacity(0.15)
              : (isDark ? const Color(0xFF16213E) : Colors.white),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isActive ? AppColors.info : const Color(0xFFD4AF37).withOpacity(0.2),
            width: isActive ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: isActive ? AppColors.info : AppColors.textSecondary),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: isActive ? AppColors.info : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // === HELPER WIDGETS ===

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

  Widget _scanResultRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 60,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}

// Helper class for glass pill tabs
class _GlassTab {
  final IconData icon;
  final String label;
  final Color color;
  const _GlassTab(this.icon, this.label, this.color);
}
