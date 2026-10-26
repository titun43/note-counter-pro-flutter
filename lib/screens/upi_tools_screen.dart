// =============================================================================
// Note Counter Pro - UPI Tools Screen (Premium)
// =============================================================================
// Two-in-one UPI tool:
//   Tab 1: Generate QR — enter UPI ID/name/amount → generate QR code
//   Tab 2: Scan QR — live camera OR gallery image → decode QR → extract UPI ID
//
// The Scan feature solves a real problem: UPI QR scan limit is ₹2000
// (same mobile), but UPI ID send limit is ₹1 lakh. By scanning a QR
// via camera or gallery, the user can extract the UPI ID and send
// larger amounts directly from their UPI app.
// =============================================================================

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:screenshot/screenshot.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart' as mscanner;
import 'package:url_launcher/url_launcher.dart';
import '../services/premium_service.dart';
import '../utils/constants.dart';
import '../utils/app_localizations.dart';
import 'premium_screen.dart';

class UpiToolsScreen extends StatefulWidget {
  const UpiToolsScreen({super.key});

  @override
  State<UpiToolsScreen> createState() => _UpiToolsScreenState();
}

class _UpiToolsScreenState extends State<UpiToolsScreen> {
  int _currentTab = 0; // 0 = Generate, 1 = Scan
  int _scanMode = 0; // 0 = Camera, 1 = Gallery

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

    setState(() {
      _generatedUpiUrl = 'upi://pay?${params.join('&')}';
    });
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
    _cameraController = mscanner.MobileScannerController(
      detectionSpeed: mscanner.DetectionSpeed.noDuplicates,
      facing: mscanner.CameraFacing.back,
    );
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

    try {
      final uri = Uri.parse(upiLink);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        // Fallback: copy to clipboard and show snackbar
        await Clipboard.setData(ClipboardData(text: upiLink));
        if (mounted) {
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
      debugPrint('Open UPI app failed: $e');
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
      appBar: AppBar(
        title: Text(
          loc.t('upiTools'),
          style: const TextStyle(fontFamily: 'KhataHandwriting', fontSize: 22),
        ),
      ),
      body: Column(
        children: [
          // === TAB SELECTOR ===
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: _buildTabCard(
                    icon: Icons.qr_code_2,
                    label: loc.t('generateQr'),
                    subtitle: loc.t('generatePaymentQr'),
                    isActive: _currentTab == 0,
                    color: AppColors.primary,
                    onTap: () => setState(() => _currentTab = 0),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildTabCard(
                    icon: Icons.image_search,
                    label: loc.t('scanQr'),
                    subtitle: loc.t('scanQrDesc'),
                    isActive: _currentTab == 1,
                    color: AppColors.info,
                    onTap: () => setState(() => _currentTab = 1),
                  ),
                ),
              ],
            ),
          ),
          // === CONTENT ===
          Expanded(
            child: _currentTab == 0
                ? _buildGenerateTab(isDark, loc)
                : _buildScanTab(isDark, loc),
          ),
        ],
      ),
    );
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

  // === SCAN TAB ===
  Widget _buildScanTab(bool isDark, AppLocalizations loc) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        children: [
          // Scan mode selector: Camera vs Gallery
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

          // Camera mode
          if (_scanMode == 0) ...[
            if (!_cameraActive) ...[
              // Start camera button
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
            ] else ...[
              // Live camera preview
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: SizedBox(
                  height: 300,
                  width: double.infinity,
                  child: Stack(
                    children: [
                      mscanner.MobileScanner(
                        controller: _cameraController!,
                        onDetect: _onCameraDetect,
                      ),
                      // Overlay frame
                      Center(
                        child: Container(
                          width: 200,
                          height: 200,
                          decoration: BoxDecoration(
                            border: Border.all(color: AppColors.info, width: 2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      // Stop button
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.close, color: Colors.white),
                            onPressed: _stopCamera,
                          ),
                        ),
                      ),
                      // Scanning text
                      Positioned(
                        bottom: 8,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              loc.t('scanning'),
                              style: const TextStyle(color: Colors.white, fontSize: 12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
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

          // Info note — ₹2000 limit
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.warning.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.warning.withOpacity(0.3), width: 1),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: AppColors.warning, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    loc.t('upiLimitInfo'),
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                  ),
                ),
              ],
            ),
          ),
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
