import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart' as mscanner;
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import '../utils/constants.dart';
import '../utils/app_localizations.dart';
import '../services/storage_service.dart';
import '../widgets/banner_ad_widget.dart';

class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({super.key});
  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  mscanner.MobileScannerController? _cameraController;
  bool _cameraActive = false;
  Map<String, String>? _scanResult;
  bool _isScanning = false;

  @override
  void dispose() { _cameraController?.dispose(); super.dispose(); }

  void _startCamera() {
    _cameraController?.dispose();
    _cameraController = mscanner.MobileScannerController(detectionSpeed: mscanner.DetectionSpeed.noDuplicates, facing: mscanner.CameraFacing.back, autoStart: true);
    setState(() { _cameraActive = true; _scanResult = null; });
  }

  void _stopCamera() { _cameraController?.dispose(); _cameraController = null; setState(() => _cameraActive = false); }

  void _onDetect(mscanner.BarcodeCapture capture) {
    if (capture.barcodes.isEmpty) return;
    final rawValue = capture.barcodes.first.rawValue;
    if (rawValue == null || rawValue.isEmpty) return;
    _stopCamera();
    final type = _detectType(rawValue);
    setState(() { _scanResult = {'content': rawValue, 'type': type, 'timestamp': DateTime.now().toIso8601String()}; });
    try { context.read<StorageService>().addScanHistory(_scanResult!); } catch (e) { debugPrint('Save scan history failed: $e'); }
  }

  String _detectType(String value) {
    if (value.startsWith('http://') || value.startsWith('https://')) return 'URL';
    if (value.startsWith('tel:')) return 'Phone';
    if (value.startsWith('mailto:')) return 'Email';
    if (value.startsWith('WIFI:')) return 'WiFi';
    if (value.startsWith('upi://')) return 'UPI';
    return 'Text';
  }

  Future<void> _pickImageAndScan() async {
    setState(() => _isScanning = true);
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.image);
      if (result != null && result.files.single.path != null) {
        final controller = mscanner.MobileScannerController(detectionSpeed: mscanner.DetectionSpeed.noDuplicates);
        final capture = await controller.analyzeImage(result.files.single.path!);
        if (capture != null && capture.barcodes.isNotEmpty) {
          final rawValue = capture.barcodes.first.rawValue;
          if (rawValue != null && rawValue.isNotEmpty) {
            final type = _detectType(rawValue);
            setState(() { _scanResult = {'content': rawValue, 'type': type, 'timestamp': DateTime.now().toIso8601String()}; });
            try { context.read<StorageService>().addScanHistory(_scanResult!); } catch (e) { debugPrint('Save scan history failed: $e'); }
          }
        }
        controller.dispose();
      }
    } catch (e) { debugPrint('Gallery scan failed: $e'); }
    setState(() => _isScanning = false);
  }

  void _copyResult() {
    if (_scanResult == null) return;
    Clipboard.setData(ClipboardData(text: _scanResult!['content']!));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.loc.t('scanCopied')), backgroundColor: AppColors.success));
  }

  void _openResult() {
    if (_scanResult == null) return;
    final content = _scanResult!['content']!;
    final type = _scanResult!['type'];
    if (type == 'URL' || type == 'UPI' || type == 'Phone' || type == 'Email') launchUrl(Uri.parse(content), mode: LaunchMode.externalApplication);
  }

  IconData _getIconForType(String type) {
    switch (type) { case 'URL': return Icons.link; case 'Phone': return Icons.phone; case 'Email': return Icons.email; case 'WiFi': return Icons.wifi; case 'UPI': return Icons.payment; default: return Icons.text_fields; }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final loc = context.loc;
    final storage = context.watch<StorageService>();
    final history = storage.scanHistory;
    return Scaffold(
      backgroundColor: isDark ? AppColors.bgDark : AppColors.bgLight,
      body: SafeArea(child: Column(children: [
        const BannerAdWidget(),
        Container(padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4), decoration: BoxDecoration(color: isDark ? Colors.grey[900] : Colors.grey[50], border: Border(bottom: BorderSide(color: isDark ? Colors.grey[800]! : Colors.grey[200]!, width: 0.5))), child: Row(children: [IconButton(icon: const Icon(Icons.arrow_back, size: 22), onPressed: () => Navigator.pop(context)), Text(loc.t('qrScanner'), style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold))])),
        Expanded(child: SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (!_cameraActive && _scanResult == null) ...[
            GestureDetector(onTap: _startCamera, child: Container(padding: const EdgeInsets.all(32), decoration: BoxDecoration(color: isDark ? AppColors.bgCardDark : AppColors.bgCard, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.info.withOpacity(0.3), width: 2)), child: Column(children: [Icon(Icons.camera_alt, size: 56, color: AppColors.info), const SizedBox(height: 12), Text(loc.t('scanOpenCamera'), style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black))]))),
            const SizedBox(height: 12),
            GestureDetector(onTap: _isScanning ? null : _pickImageAndScan, child: Container(padding: const EdgeInsets.all(32), decoration: BoxDecoration(color: isDark ? AppColors.bgCardDark : AppColors.bgCard, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.success.withOpacity(0.3), width: 2)), child: Column(children: [_isScanning ? const CircularProgressIndicator() : Icon(Icons.image, size: 56, color: AppColors.success), const SizedBox(height: 12), Text(_isScanning ? loc.t('scanning') : loc.t('scanFromGallery'), style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black))]))),
          ],
          if (_cameraActive) ...[
            ClipRRect(borderRadius: BorderRadius.circular(16), child: SizedBox(height: 300, width: double.infinity, child: Stack(children: [mscanner.MobileScanner(controller: _cameraController!, onDetect: _onDetect), Center(child: Container(width: 200, height: 200, decoration: BoxDecoration(border: Border.all(color: AppColors.primary, width: 2), borderRadius: BorderRadius.circular(12))),), Positioned(top: 8, right: 8, child: IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: _stopCamera, style: IconButton.styleFrom(backgroundColor: Colors.black54))), Positioned(bottom: 8, left: 0, right: 0, child: Center(child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(20)), child: Text(loc.t('scanAlignQr'), style: const TextStyle(color: Colors.white, fontSize: 12)))))]))),
          ],
          if (_scanResult != null) ...[
            Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: AppColors.success.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.success.withOpacity(0.3))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [const Icon(Icons.check_circle, color: AppColors.success, size: 20), const SizedBox(width: 8), Text('${loc.t('scanType')}: ${_scanResult!['type']}', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.success))]), const SizedBox(height: 8), Text(_scanResult!['content']!, style: theme.textTheme.bodyMedium?.copyWith(color: isDark ? Colors.white : Colors.black)), const SizedBox(height: 12), Row(children: [Expanded(child: OutlinedButton.icon(onPressed: _copyResult, icon: const Icon(Icons.copy, size: 16), label: Text(loc.t('scanCopy')))), if (['URL', 'Phone', 'Email', 'UPI'].contains(_scanResult!['type'])) ...[const SizedBox(width: 8), Expanded(child: FilledButton.icon(onPressed: _openResult, icon: const Icon(Icons.open_in_new, size: 16), label: Text(loc.t('scanOpen'))))]])])),
            const SizedBox(height: 12),
            TextButton.icon(onPressed: () { setState(() => _scanResult = null); _startCamera(); }, icon: const Icon(Icons.refresh), label: Text(loc.t('scanAgain'))),
          ],
          const SizedBox(height: 20),
          if (history.isNotEmpty) ...[
            Row(children: [Icon(Icons.history, size: 18, color: AppColors.primary), const SizedBox(width: 8), Text(loc.t('scanHistory'), style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold, color: AppColors.primary))]),
            const SizedBox(height: 8),
            ...history.take(10).toList().asMap().entries.map((entry) { final index = entry.key; final item = entry.value; return Card(margin: const EdgeInsets.only(bottom: 4), color: isDark ? AppColors.bgCardDark : AppColors.bgCard, child: ListTile(leading: Icon(_getIconForType(item['type'] ?? 'Text'), size: 20, color: AppColors.info), title: Text(item['content'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)), subtitle: Text(item['type'] ?? '', style: const TextStyle(fontSize: 11)), trailing: IconButton(icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.danger), onPressed: () => storage.deleteScanHistory(index)), onTap: () => setState(() => _scanResult = Map<String, String>.from(item)))); }),
          ],
        ]))),
      ])),
    );
  }
}
