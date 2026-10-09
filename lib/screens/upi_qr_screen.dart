import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:screenshot/screenshot.dart';
import 'package:path_provider/path_provider.dart';
import '../services/admob_service.dart';
import '../services/storage_service.dart';
import '../utils/constants.dart';
import '../utils/app_localizations.dart';

class UpiQrScreen extends StatefulWidget {
  const UpiQrScreen({super.key});

  @override
  State<UpiQrScreen> createState() => _UpiQrScreenState();
}

class _UpiQrScreenState extends State<UpiQrScreen> {
  final _upiIdController = TextEditingController();
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  String? _upiUrl;
  final ScreenshotController _screenshotController = ScreenshotController();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
  }

  void _generateQr() async {
    final upiId = _upiIdController.text.trim();
    if (upiId.isEmpty || !upiId.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid UPI ID'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    final name = _nameController.text.trim();
    final amount = _amountController.text.trim();
    final note = _noteController.text.trim();

    var url = 'upi://pay?pa=${Uri.encodeComponent(upiId)}';
    if (name.isNotEmpty) url += '&pn=${Uri.encodeComponent(name)}';
    if (amount.isNotEmpty && double.tryParse(amount) != null && double.parse(amount) > 0) {
      url += '&am=${Uri.encodeComponent(amount)}';
    }
    if (note.isNotEmpty) url += '&tn=${Uri.encodeComponent(note)}';
    url += '&cu=INR';

    setState(() {
      _upiUrl = url;
    });

    // Wait for QR to render, then capture and save
    await Future.delayed(const Duration(milliseconds: 500));
    await _captureAndSaveQr(name, upiId, amount, note);

    // Show interstitial ad after QR generation
    AdMobService.showInterstitial();
  }

  /// Capture QR as image and save to history
  Future<void> _captureAndSaveQr(
      String name, String upiId, String amount, String note) async {
    if (_upiUrl == null) return;

    setState(() {
      _isSaving = true;
    });

    try {
      // Capture the QR card as image
      final Uint8List? imageBytes =
          await _screenshotController.capture(delay: const Duration(milliseconds: 10));
      String? imagePath;

      if (imageBytes != null) {
        // Save image to app documents directory
        final dir = await getApplicationDocumentsDirectory();
        final qrDir = Directory('${dir.path}/qr_images');
        if (!await qrDir.exists()) {
          await qrDir.create(recursive: true);
        }
        final now = DateTime.now();
        final timestamp = now.millisecondsSinceEpoch;
        final file = File('${qrDir.path}/qr_$timestamp.png');
        await file.writeAsBytes(imageBytes);
        imagePath = file.path;
        debugPrint('QR image saved: $imagePath');
      }

      // Save to history
      if (mounted) {
        final storage = context.read<StorageService>();
        await storage.addQrHistory({
          'name': name,
          'upiId': upiId,
          'amount': amount,
          'note': note,
          'payeeName': name,
          'upiUrl': _upiUrl!,
          'imagePath': imagePath ?? '',
          'timestamp': DateTime.now().toIso8601String(),
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('QR saved to history!'),
              backgroundColor: AppColors.success,
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('QR save failed: $e');
      // Still save to history without image
      if (mounted) {
        final storage = context.read<StorageService>();
        await storage.addQrHistory({
          'name': name,
          'upiId': upiId,
          'amount': amount,
          'note': note,
          'payeeName': name,
          'upiUrl': _upiUrl!,
          'imagePath': '',
          'timestamp': DateTime.now().toIso8601String(),
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _shareQr() async {
    if (_upiUrl == null) return;

    final name = _nameController.text.trim();
    final amount = _amountController.text.trim();

    // Capture QR as image and share
    try {
      final Uint8List? imageBytes =
          await _screenshotController.capture(delay: const Duration(milliseconds: 10));
      if (imageBytes != null) {
        final tempDir = await getTemporaryDirectory();
        final now = DateTime.now();
        final filename = 'qr-${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}.png';
        final file = File('${tempDir.path}/$filename');
        await file.writeAsBytes(imageBytes);

        final shareText = 'Pay via UPI\n'
            '${name.isNotEmpty ? 'Name: $name\n' : ''}'
            '${amount.isNotEmpty ? 'Amount: ₹$amount\n' : ''}'
            'UPI ID: ${_upiIdController.text.trim()}';

        await Share.shareXFiles(
          [XFile(file.path)],
          subject: 'UPI QR - $name',
          text: shareText,
        );
        return;
      }
    } catch (e) {
      debugPrint('Share image failed: $e');
    }

    // Fallback to text share
    final shareText = 'Pay via UPI\n'
        '${name.isNotEmpty ? 'Name: $name\n' : ''}'
        '${amount.isNotEmpty ? 'Amount: ₹$amount\n' : ''}'
        'UPI Link: $_upiUrl';
    await Share.share(shareText, subject: 'UPI Payment');
  }

  Future<void> _openInUpiApp() async {
    if (_upiUrl == null) return;

    final uri = Uri.parse(_upiUrl!);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No UPI app found'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _upiIdController.dispose();
    _nameController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(loc.t('upiQrCode'))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _upiIdController,
              decoration: InputDecoration(
                labelText: 'Your UPI ID *',
                hintText: 'yourname@upi',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.payment),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: loc.t('payeeName'),
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.person),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _amountController,
              decoration: const InputDecoration(
                labelText: 'Amount (₹)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.currency_rupee),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _noteController,
              decoration: const InputDecoration(
                labelText: 'Note (optional)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.note),
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _isSaving ? null : _generateQr,
              icon: _isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.qr_code),
              label: Text(_isSaving ? 'Saving...' : loc.t('generateQr')),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.all(16),
              ),
            ),
            if (_upiUrl != null) ...[
              const SizedBox(height: 24),
              // QR Card wrapped in Screenshot widget
              Screenshot(
                controller: _screenshotController,
                child: Container(
                  color: Colors.white,
                  padding: const EdgeInsets.all(20),
                  child: Card(
                    elevation: 0,
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          // QR Code
                          Container(
                            padding: const EdgeInsets.all(16),
                            color: Colors.white,
                            child: QrImageView(
                              data: _upiUrl!,
                              version: QrVersions.auto,
                              size: 200,
                              gapless: true,
                            ),
                          ),
                          const SizedBox(height: 16),
                          // App name
                          Text(
                            'Note Counter Pro',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 8),
                          // Amount
                          if (_amountController.text.isNotEmpty)
                            Text(
                              '₹ ${_amountController.text}',
                              style: theme.textTheme.headlineSmall?.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          if (_nameController.text.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              _nameController.text,
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: Colors.black54,
                              ),
                            ),
                          ],
                          if (_upiIdController.text.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              _upiIdController.text,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: Colors.black54,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _shareQr,
                icon: const Icon(Icons.share),
                label: const Text('Share QR Image'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                ),
              ),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: _openInUpiApp,
                icon: const Icon(Icons.open_in_new),
                label: Text(loc.t('openInUpiApp')),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                  backgroundColor: AppColors.info,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
