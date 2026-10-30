import 'dart:io';
import 'package:flutter/material.dart';
import 'package:barcode_widget/barcode_widget.dart';
import 'package:share_plus/share_plus.dart';
import 'package:screenshot/screenshot.dart';
import 'package:path_provider/path_provider.dart';
import '../utils/constants.dart';
import '../utils/app_localizations.dart';
import '../widgets/banner_ad_widget.dart';

class BarcodeGeneratorScreen extends StatefulWidget {
  const BarcodeGeneratorScreen({super.key});
  @override
  State<BarcodeGeneratorScreen> createState() => _BarcodeGeneratorScreenState();
}

class _BarcodeGeneratorScreenState extends State<BarcodeGeneratorScreen> {
  final _contentController = TextEditingController();
  final _screenshotController = ScreenshotController();
  int _barcodeType = 0;
  String? _barcodeData;
  final _barcodeTypes = [{'name': 'Code128', 'type': Barcode.code128()}, {'name': 'EAN-13', 'type': Barcode.ean13()}, {'name': 'Code39', 'type': Barcode.code39()}];

  @override
  void dispose() { _contentController.dispose(); super.dispose(); }

  void _generate() {
    final content = _contentController.text.trim();
    if (content.isEmpty) return;
    if (_barcodeType == 1 && (content.length < 12 || content.length > 13 || int.tryParse(content) == null)) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.loc.t('barcodeEan13Error')), backgroundColor: AppColors.danger));
      return;
    }
    setState(() => _barcodeData = content);
  }

  Future<void> _shareBarcode() async {
    if (_barcodeData == null) return;
    try {
      final image = await _screenshotController.capture();
      if (image == null) return;
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/barcode_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(image);
      await Share.shareXFiles([XFile(file.path)], subject: 'Barcode');
    } catch (e) { debugPrint('Share barcode failed: $e'); }
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
        Container(padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4), decoration: BoxDecoration(color: isDark ? Colors.grey[900] : Colors.grey[50], border: Border(bottom: BorderSide(color: isDark ? Colors.grey[800]! : Colors.grey[200]!, width: 0.5))), child: Row(children: [IconButton(icon: const Icon(Icons.arrow_back, size: 22), onPressed: () => Navigator.pop(context)), Text(loc.t('barcodeGenerator'), style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold))])),
        Expanded(child: SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SizedBox(height: 40, child: ListView.separated(scrollDirection: Axis.horizontal, itemCount: _barcodeTypes.length, separatorBuilder: (_, __) => const SizedBox(width: 8), itemBuilder: (context, index) { final type = _barcodeTypes[index]; final isSelected = _barcodeType == index; return ChoiceChip(label: Text(type['name'] as String), selected: isSelected, onSelected: (_) { setState(() { _barcodeType = index; _barcodeData = null; _contentController.clear(); }); }, selectedColor: AppColors.primary, labelStyle: TextStyle(color: isSelected ? AppColors.bgDark : null, fontWeight: FontWeight.bold)); })),
          const SizedBox(height: 16),
          TextField(controller: _contentController, decoration: InputDecoration(labelText: loc.t('barcodeContent'), border: const OutlineInputBorder(), prefixIcon: const Icon(Icons.qr_code_2)), keyboardType: _barcodeType == 1 ? TextInputType.number : TextInputType.text),
          const SizedBox(height: 16),
          FilledButton.icon(onPressed: _generate, icon: const Icon(Icons.qr_code), label: Text(loc.t('qrGenerate'), style: const TextStyle(fontWeight: FontWeight.bold)), style: FilledButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: AppColors.bgDark, padding: const EdgeInsets.symmetric(vertical: 14))),
          const SizedBox(height: 20),
          if (_barcodeData != null) ...[
            Screenshot(controller: _screenshotController, child: Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFD4AF37).withOpacity(0.3))), child: Column(children: [BarcodeWidget(barcode: _barcodeTypes[_barcodeType]['type'] as Barcode, data: _barcodeData!, width: double.infinity, height: 120, color: Colors.black, errorBuilder: (context, error) => Text(error.toString(), style: const TextStyle(color: Colors.red, fontSize: 12))), const SizedBox(height: 8), Text(_barcodeData!, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black))]))),
            const SizedBox(height: 12),
            OutlinedButton.icon(onPressed: _shareBarcode, icon: const Icon(Icons.share), label: Text(loc.t('qrShare')), style: OutlinedButton.styleFrom(foregroundColor: AppColors.info, padding: const EdgeInsets.symmetric(vertical: 12))),
          ],
        ]))),
      ])),
    );
  }
}
