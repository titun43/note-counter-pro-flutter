// =============================================================================
// Note Counter Pro - Calculator Screen (Multi-Mode with Drawer)
// =============================================================================
// Modes: Standard, Scientific, Programmer, Date Calculation
// Converters: 12 types (Currency, Length, Weight, etc.)
// All FREE for all users. Free users see ads, premium users don't.
// =============================================================================

import 'package:flutter/material.dart';
import '../utils/constants.dart';
import 'standard_calculator.dart';
import 'scientific_calculator.dart';
import 'programmer_calculator.dart';
import 'date_calculator.dart';
import 'converter_screen.dart';

class CalculatorScreen extends StatefulWidget {
  final double? initialValue;
  final String currencyCode;

  const CalculatorScreen({
    super.key,
    this.initialValue,
    this.currencyCode = 'INR',
  });

  @override
  State<CalculatorScreen> createState() => _CalculatorScreenState();
}

class _CalculatorScreenState extends State<CalculatorScreen> {
  int _currentMode = 0; // 0=Standard, 1=Scientific, 2=Programmer, 3=Date

  static const _modes = [
    {'icon': Icons.calculate, 'name': 'Standard'},
    {'icon': Icons.science, 'name': 'Scientific'},
    {'icon': Icons.code, 'name': 'Programmer'},
    {'icon': Icons.calendar_today, 'name': 'Date Calc'},
  ];

  void _navigateToConverter(int index) {
    Navigator.pop(context); // close drawer
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ConverterScreen(initialType: index),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      drawer: _buildDrawer(context, theme),
      body: SafeArea(
        child: Column(
          children: [
            // Top bar with menu icon
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  Builder(
                    builder: (context) => IconButton(
                      icon: const Icon(Icons.menu, size: 28),
                      onPressed: () => Scaffold.of(context).openDrawer(),
                      tooltip: 'Calculator Modes',
                    ),
                  ),
                  Text(
                    _modes[_currentMode]['name'] as String,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  if (widget.initialValue != null && widget.initialValue! > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.info.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${AppConstants.getCurrencySymbol(widget.currencyCode)}${widget.initialValue!.toStringAsFixed(2)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.info,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // Calculator content
            Expanded(
              child: _buildCurrentMode(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentMode() {
    switch (_currentMode) {
      case 1:
        return const ScientificCalculator();
      case 2:
        return const ProgrammerCalculator();
      case 3:
        return const DateCalculator();
      default:
        return StandardCalculator(
          initialValue: widget.initialValue,
          currencyCode: widget.currencyCode,
        );
    }
  }

  Widget _buildDrawer(BuildContext context, ThemeData theme) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 40, 16, 16),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary,
            ),
            child: Text(
              'Calculator',
              style: theme.textTheme.headlineSmall?.copyWith(
                color: theme.colorScheme.onPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 8),
          _sectionHeader('CALCULATOR'),
          ..._modes.asMap().entries.map((entry) {
            final i = entry.key;
            final mode = entry.value;
            return ListTile(
              leading: Icon(mode['icon'] as IconData,
                  color: i == _currentMode ? theme.colorScheme.primary : null),
              title: Text(mode['name'] as String,
                  style: i == _currentMode
                      ? TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.primary)
                      : null),
              selected: i == _currentMode,
              onTap: () {
                setState(() => _currentMode = i);
                Navigator.pop(context);
              },
            );
          }),
          const Divider(),
          _sectionHeader('CONVERTER'),
          _converterItem(Icons.currency_exchange, 'Currency', 0),
          _converterItem(Icons.straighten, 'Length', 1),
          _converterItem(Icons.scale, 'Weight & Mass', 2),
          _converterItem(Icons.thermostat, 'Temperature', 3),
          _converterItem(Icons.bolt, 'Energy', 4),
          _converterItem(Icons.crop_square, 'Area', 5),
          _converterItem(Icons.speed, 'Speed', 6),
          _converterItem(Icons.access_time, 'Time', 7),
          _converterItem(Icons.flash_on, 'Power', 8),
          _converterItem(Icons.storage, 'Data', 9),
          _converterItem(Icons.compress, 'Pressure', 10),
          _converterItem(Icons.architecture, 'Angle', 11),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.grey,
          letterSpacing: 1,
        ),
      ),
    );
  }

  Widget _converterItem(IconData icon, String name, int index) {
    return ListTile(
      leading: Icon(icon, size: 22),
      title: Text(name, style: const TextStyle(fontSize: 14)),
      onTap: () => _navigateToConverter(index),
    );
  }
}
