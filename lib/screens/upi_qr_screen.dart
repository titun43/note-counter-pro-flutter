import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
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
  
  @override
  void initState() {
    super.initState();
    _loadSavedSettings();
  }
  
  void _loadSavedSettings() {
    final storage = context.read<StorageService>();
    // Try to load from prefs
    final savedUpiId = storage.toString(); // placeholder
    // In real implementation, use SharedPreferences directly
  }
  
  Future<void> _generateQr() async {
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
    
    // Save to QR history
    final storage = context.read<StorageService>();
    await storage.addQrHistory({
      'upiId': upiId,
      'name': name,
      'amount': amount,
      'note': note,
      'time': DateTime.now().toIso8601String(),
    });
    
    // Show interstitial ad after QR generation
    AdMobService.showInterstitial();
  }
  
  Future<void> _shareQr() async {
    if (_upiUrl == null) return;
    
    final name = _nameController.text.trim();
    final amount = _amountController.text.trim();
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
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.payment),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: loc.t('payeeName'),
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _amountController,
              decoration: InputDecoration(
                labelText: 'Amount (₹)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.currency_rupee),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _noteController,
              decoration: InputDecoration(
                labelText: 'Note (optional)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.note),
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _generateQr,
              icon: const Icon(Icons.qr_code),
              label: Text(loc.t('generateQr')),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.all(16),
              ),
            ),
            if (_upiUrl != null) ...[
              const SizedBox(height: 24),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
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
                      if (_amountController.text.isNotEmpty)
                        Text(
                          '₹ ${_amountController.text}',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      if (_nameController.text.isNotEmpty)
                        Text(
                          _nameController.text,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _shareQr,
                icon: const Icon(Icons.share),
                label: const Text('Share QR'),
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
