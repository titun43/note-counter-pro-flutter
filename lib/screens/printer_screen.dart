// =============================================================================
// Note Counter Pro - Receipt Printer Screen
// =============================================================================
// Premium feature: Connect to ESC/POS thermal printer and print receipts.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/entry.dart';
import '../services/printer_service.dart';
import '../services/premium_service.dart';
import '../services/storage_service.dart';
import '../utils/constants.dart';
import '../utils/app_localizations.dart';
import 'premium_screen.dart';

class PrinterScreen extends StatefulWidget {
  const PrinterScreen({super.key});

  @override
  State<PrinterScreen> createState() => _PrinterScreenState();
}

class _PrinterScreenState extends State<PrinterScreen> {
  final _hostController = TextEditingController();
  final _portController = TextEditingController(text: '9100');
  bool _isConnecting = false;
  bool _isPrinting = false;

  @override
  void dispose() {
    _hostController.dispose();
    _portController.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    final host = _hostController.text.trim();
    final port = int.tryParse(_portController.text.trim()) ?? 9100;
    if (host.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter printer IP address')),
      );
      return;
    }

    setState(() => _isConnecting = true);
    final success = await PrinterService().connect(host: host, port: port);
    setState(() => _isConnecting = false);

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Connected to $host:$port'),
          backgroundColor: AppColors.success,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Connection failed. Check IP and network.'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  Future<void> _testPrint() async {
    setState(() => _isPrinting = true);
    final storage = context.read<StorageService>();

    // Create a test entry
    final testEntry = Entry.create(
      type: 'cash_in',
      amount: 1234.56,
      currency: storage.defaultCurrency,
      notes: 'Test print from Note Counter Pro',
      denominationCounts: {'500': 2, '100': 2, '50': 1, '10': 4},
    );

    final success = await PrinterService().printReceipt(
      entry: testEntry,
      storage: storage,
      customerName: 'Test Customer',
    );

    setState(() => _isPrinting = false);

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🖨️ Test receipt printed!'),
          backgroundColor: AppColors.success,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Print failed. Make sure printer is connected.'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  Future<void> _disconnect() async {
    await PrinterService().disconnect();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Disconnected')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final theme = Theme.of(context);
    final isPremium = PremiumService().isPremium;
    final isConnected = PrinterService().isConnected;

    return Scaffold(
      appBar: AppBar(title: Text(loc.t('printer'))),
      body: !isPremium
          ? _buildPremiumRequired(context)
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.print, size: 56, color: AppColors.primary),
                        const SizedBox(height: 8),
                        Text(
                          loc.t('printerTitle'),
                          style: theme.textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          loc.t('printerDesc'),
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Connection status
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: (isConnected ? AppColors.success : AppColors.danger)
                          .withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isConnected ? Icons.check_circle : Icons.cancel,
                          color: isConnected
                              ? AppColors.success
                              : AppColors.danger,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            isConnected
                                ? '${loc.t('printerConnected')} (${PrinterService().lastConnectedHost})'
                                : loc.t('printerNotConnected'),
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // IP input (only if not connected)
                  if (!isConnected) ...[
                    TextField(
                      controller: _hostController,
                      decoration: InputDecoration(
                        labelText: loc.t('printerIp'),
                        hintText: '192.168.1.100',
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.router),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _portController,
                      decoration: InputDecoration(
                        labelText: loc.t('printerPort'),
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.numbers),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _isConnecting ? null : _connect,
                      icon: _isConnecting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.link),
                      label: Text(loc.t('printerConnect')),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ] else ...[
                    // Connected — show actions
                    FilledButton.icon(
                      onPressed: _isPrinting ? null : _testPrint,
                      icon: _isPrinting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.print),
                      label: Text(loc.t('printerTestPrint')),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.success,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _disconnect,
                      icon: const Icon(Icons.link_off),
                      label: Text(loc.t('printerDisconnect')),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.danger,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),

                  // Help note
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.info_outline,
                                size: 18, color: Colors.grey[700]),
                            const SizedBox(width: 6),
                            Text(
                              loc.t('printerHelpTitle'),
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          loc.t('printerHelp'),
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildPremiumRequired(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.workspace_premium,
                size: 80, color: Color(0xFFD4AF37)),
            const SizedBox(height: 16),
            Text(
              context.loc.t('printerPremiumRequired'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              context.loc.t('cloudBackupPremiumDesc'),
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PremiumScreen()),
              ),
              icon: const Icon(Icons.workspace_premium),
              label: Text(context.loc.t('premiumUpgradeTitle')),
            ),
          ],
        ),
      ),
    );
  }
}
