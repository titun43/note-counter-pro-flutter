import 'dart:io';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:screenshot/screenshot.dart';
import 'package:path_provider/path_provider.dart';
import '../utils/constants.dart';
import '../utils/app_localizations.dart';
import '../widgets/banner_ad_widget.dart';

class QrGeneratorScreen extends StatefulWidget {
  const QrGeneratorScreen({super.key});
  @override
  State<QrGeneratorScreen> createState() => _QrGeneratorScreenState();
}

class _QrGeneratorScreenState extends State<QrGeneratorScreen> {
  int _typeIndex = 0;
  final _contentController = TextEditingController();
  final _wifiSsidController = TextEditingController();
  final _wifiPasswordController = TextEditingController();
  final _screenshotController = ScreenshotController();
  String? _qrData;

  final _types = [
    {'icon': Icons.text_fields, 'name': 'Text'},
    {'icon': Icons.link, 'name': 'URL'},
    {'icon': Icons.wifi, 'name': 'WiFi'},
    {'icon': Icons.phone, 'name': 'Phone'},
    {'icon': Icons.email, 'name': 'Email'},
  ];

  @override
  void dispose() {
    _contentController.dispose();
    _wifiSsidController.dispose();
    _wifiPasswordController.dispose();
    super.dispose();
  }

  void _generateQr() {
    String data;
    switch (_typeIndex) {
      case 1:
        final url = _contentController.text.trim();
        if (url.isEmpty) return;
        data = url.startsWith('http') ? url : 'https://$url';
        break;
      case 2:
        final ssid = _wifiSsidController.text.trim();
        final password = _wifiPasswordController.text.trim();
        if (ssid.isEmpty) return;
        data = 'WIFI:T:WPA;S:$ssid;P:$password;;';
        break;
      case 3:
        final phone = _contentController.text.trim();
        if (phone.isEmpty) return;
        data = 'tel:$phone';
        break;
      case 4:
        final email = _contentController.text.trim();
        if (email.isEmpty) return;
        data = 'mailto:$email';
        break;
      default:
        final text = _contentController.text.trim();
        if (text.isEmpty) return;
        data = text;
    }
    setState(() => _qrData = data);
  }

  Future<void> _shareQr() async {
    if (_qrData == null) return;
    try {
      final image = await _screenshotController.capture();
      if (image == null) return;
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/qr_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(image);
      await Share.shareXFiles([XFile(file.path)], subject: 'QR Code');
    } catch (e) { debugPrint('Share QR failed: $e'); }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final loc = context.loc;
    return Scaffold(
      backgroundColor: isDark ? AppColors.bgDark : AppColors.bgLight,
      body: SafeArea(child: Column(children: [
        const BannerAdWidget(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          decoration: BoxDecoration(color: isDark ? Colors.grey[900] : Colors.grey[50], border: Border(bottom: BorderSide(color: isDark ? Colors.grey[800]! : Colors.grey[200]!, width: 0.5))),
          child: Row(children: [
            IconButton(icon: const Icon(Icons.arrow_back, size: 22), onPressed: () => Navigator.pop(context)),
            Text(loc.t('qrGenerator'), style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          ]),
        ),
        Expanded(child: SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SizedBox(height: 40, child: ListView.separated(scrollDirection: Axis.horizontal, itemCount: _types.length, separatorBuilder: (_, __) => const SizedBox(width: 8), itemBuilder: (context, index) {
            final type = _types[index];
            final isSelected = _typeIndex == index;
            return ChoiceChip(label: Row(mainAxisSize: MainAxisSize.min, children: [Icon(type['icon'] as IconData, size: 16), const SizedBox(width: 4), Text(type['name'] as String)]), selected: isSelected, onSelected: (_) { setState(() { _typeIndex = index; _qrData = null; _contentController.clear(); _wifiSsidController.clear(); _wifiPasswordController.clear(); }); }, selectedColor: AppColors.primary, labelStyle: TextStyle(color: isSelected ? AppColors.bgDark : null, fontWeight: FontWeight.bold));
          })),
          const SizedBox(height: 16),
          if (_typeIndex == 2) ...[
            TextField(controller: _wifiSsidController, decoration: InputDecoration(labelText: loc.t('qrWifiSsid'), prefixIcon: const Icon(Icons.wifi), border: const OutlineInputBorder())),
            const SizedBox(height: 12),
            TextField(controller: _wifiPasswordController, decoration: InputDecoration(labelText: loc.t('qrWifiPassword'), prefixIcon: const Icon(Icons.lock), border: const OutlineInputBorder()), obscureText: true),
          ] else ...[
            TextField(controller: _contentController, decoration: InputDecoration(labelText: _typeIndex == 0 ? loc.t('qrTypeText') : _typeIndex == 1 ? loc.t('qrTypeUrl') : _typeIndex == 3 ? loc.t('qrTypePhone') : loc.t('qrTypeEmail'), border: const OutlineInputBorder()), maxLines: _typeIndex == 0 ? 3 : 1),
          ],
          const SizedBox(height: 16),
          FilledButton.icon(onPressed: _generateQr, icon: const Icon(Icons.qr_code), label: Text(loc.t('qrGenerate'), style: const TextStyle(fontWeight: FontWeight.bold)), style: FilledButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: AppColors.bgDark, padding: const EdgeInsets.symmetric(vertical: 14))),
          const SizedBox(height: 20),
          if (_qrData != null) ...[
            Screenshot(controller: _screenshotController, child: Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: isDark ? AppColors.bgCardDark : AppColors.bgCard, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFD4AF37).withOpacity(0.3))), child: Column(children: [QrImageView(data: _qrData!, version: QrVersions.auto, size: 200, backgroundColor: Colors.white), const SizedBox(height: 12), Text(loc.t('qrScanMe'), style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : Colors.black54))]))),
            const SizedBox(height: 12),
            OutlinedButton.icon(onPressed: _shareQr, icon: const Icon(Icons.share), label: Text(loc.t('qrShare')), style: OutlinedButton.styleFrom(foregroundColor: AppColors.info, padding: const EdgeInsets.symmetric(vertical: 12))),
          ],
        ]))),
      ])),
    );
  }
}
