// =============================================================================
// Note Counter Pro - Calculator Screen (Multi-Mode with Bottom Sheet Menu)
// =============================================================================
// Modes: Standard, Scientific, Programmer, Date Calculation
// Converters: 12 types (Currency, Length, Weight, etc.)
// All FREE for all users. Free users see ads (from main.dart top banner),
// premium users don't.
//
// NOTE: This screen does NOT use its own Scaffold — main.dart provides
// the Scaffold with a top banner ad. We use a BottomSheet for mode
// selection instead of a Drawer (Drawer needs its own Scaffold).
// =============================================================================

import 'package:flutter/material.dart';
import '../utils/constants.dart';
import '../services/admob_service.dart';
import '../widgets/banner_ad_widget.dart';
import 'standard_calculator.dart';
import 'scientific_calculator.dart';
import 'programmer_calculator.dart';
import 'date_calculator.dart';
import 'converter_screen.dart';
import 'emi_calculator.dart';
import 'gst_calculator.dart';

class CalculatorScreen extends StatefulWidget {
  final double? initialValue;
  final String currencyCode;
  /// When true, open Currency converter immediately (from Tools tab).
  final bool initialConverter;
  /// When true, open Date Calc mode immediately (from Tools tab).
  final bool initialDateCalc;
  /// When true, open EMI Calculator mode (from Tools tab).
  final bool initialEmi;
  /// When true, open GST Calculator mode (from Tools tab).
  final bool initialGst;

  const CalculatorScreen({
    super.key,
    this.initialValue,
    this.currencyCode = 'INR',
    this.initialConverter = false,
    this.initialDateCalc = false,
    this.initialEmi = false,
    this.initialGst = false,
  });

  @override
  State<CalculatorScreen> createState() => _CalculatorScreenState();
}

class _CalculatorScreenState extends State<CalculatorScreen> {
  // 0=Standard, 1=Scientific, 2=Programmer, 3=Date, 4=EMI, 5=GST
  int _currentMode = 0;
  int _modeChangeCount = 0; // For interstitial ad frequency

  static const _modes = [
    {'icon': Icons.calculate, 'name': 'Standard'},
    {'icon': Icons.science, 'name': 'Scientific'},
    {'icon': Icons.code, 'name': 'Programmer'},
    {'icon': Icons.calendar_today, 'name': 'Date Calc'},
    {'icon': Icons.account_balance, 'name': 'EMI Calc'},
    {'icon': Icons.percent, 'name': 'GST Calc'},
  ];

  static const _converters = [
    {'icon': Icons.currency_exchange, 'name': 'Currency'},
    {'icon': Icons.straighten, 'name': 'Length'},
    {'icon': Icons.scale, 'name': 'Weight & Mass'},
    {'icon': Icons.thermostat, 'name': 'Temperature'},
    {'icon': Icons.bolt, 'name': 'Energy'},
    {'icon': Icons.crop_square, 'name': 'Area'},
    {'icon': Icons.speed, 'name': 'Speed'},
    {'icon': Icons.access_time, 'name': 'Time'},
    {'icon': Icons.flash_on, 'name': 'Power'},
    {'icon': Icons.storage, 'name': 'Data'},
    {'icon': Icons.compress, 'name': 'Pressure'},
    {'icon': Icons.architecture, 'name': 'Angle'},
  ];

  @override
  void initState() {
    super.initState();
    // Handle initial mode from Tools tab
    if (widget.initialDateCalc) {
      _currentMode = 3; // Date Calc mode
    } else if (widget.initialEmi) {
      _currentMode = 4; // EMI Calc mode
    } else if (widget.initialGst) {
      _currentMode = 5; // GST Calc mode
    }
    // For initialConverter, we need to wait for the first frame
    // because we need a BuildContext to call Navigator.push
    if (widget.initialConverter) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ConverterScreen(initialType: 0),
            ),
          );
        }
      });
    }
  }

  void _showMenu() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final theme = Theme.of(context);
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(top: 12, bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey[400],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Title
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Calculator Modes',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // Calculator modes grid
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: GridView.count(
                  crossAxisCount: 4,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  childAspectRatio: 1.0,
                  children: List.generate(_modes.length, (i) {
                    final mode = _modes[i];
                    final selected = i == _currentMode;
                    return GestureDetector(
                      onTap: () {
                        Navigator.pop(ctx);
                        if (i != _currentMode) {
                          _modeChangeCount++;
                          // Show interstitial every 3 mode changes
                          if (_modeChangeCount >= 3) {
                            _modeChangeCount = 0;
                            AdMobService.showInterstitial();
                          }
                          setState(() => _currentMode = i);
                        }
                      },
                      child: Container(
                        margin: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: selected
                              ? AppColors.primary.withOpacity(0.15)
                              : (theme.brightness == Brightness.dark
                                  ? Colors.grey[850]
                                  : Colors.grey[100]),
                          borderRadius: BorderRadius.circular(12),
                          border: selected
                              ? Border.all(color: AppColors.primary, width: 2)
                              : null,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              mode['icon'] as IconData,
                              size: 28,
                              color: selected ? AppColors.primary : null,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              mode['name'] as String,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: selected ? FontWeight.bold : null,
                                color: selected ? AppColors.primary : null,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ),
              ),
              const SizedBox(height: 8),
              const Divider(),
              const SizedBox(height: 4),
              // Converter section
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Converters',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: GridView.count(
                  crossAxisCount: 3,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  childAspectRatio: 2.2,
                  children: List.generate(_converters.length, (i) {
                    final conv = _converters[i];
                    return GestureDetector(
                      onTap: () {
                        Navigator.pop(ctx);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ConverterScreen(initialType: i),
                          ),
                        );
                      },
                      child: Container(
                        margin: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: theme.brightness == Brightness.dark
                              ? Colors.grey[850]
                              : Colors.grey[100],
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(conv['icon'] as IconData, size: 18),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                conv['name'] as String,
                                style: const TextStyle(fontSize: 12),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // If opened via Navigator.push from Tools tab OR Home screen,
    // we need our own Scaffold + SafeArea + BannerAd.
    // Only when we're a tab inside main.dart (no initialValue, no
    // initialEmi/Gst/DateCalc/Converter) do we skip the Scaffold.
    final bool standalone = (widget.initialValue != null && widget.initialValue! > 0) ||
        widget.initialEmi ||
        widget.initialGst ||
        widget.initialDateCalc ||
        widget.initialConverter;

    // For standalone mode, content is just the calculator mode (no top bar —
    // the top bar is built in the standalone Scaffold below).
    // For tab mode (inside main.dart), content includes the top bar.
    Widget content;
    if (standalone) {
      // Standalone: just the calculator mode, no top bar in content
      content = _buildCurrentMode();
    } else {
      // Tab mode: top bar + calculator mode
      content = Column(
        children: [
          // Top bar: menu icon + mode name
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[900] : Colors.grey[50],
              border: Border(
                bottom: BorderSide(
                  color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
                  width: 0.5,
                ),
              ),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.apps, size: 24),
                  onPressed: _showMenu,
                  tooltip: 'Calculator Modes & Converters',
                ),
                Text(
                  _modes[_currentMode]['name'] as String,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
              ],
            ),
          ),
          // Calculator content
          Expanded(
            child: _buildCurrentMode(),
          ),
        ],
      );
    }

    // If standalone (opened from Home/Tools via Navigator.push), wrap with
    // Scaffold + SafeArea + BannerAd + top bar with back button.
    if (standalone) {
      return Scaffold(
        backgroundColor: isDark ? AppColors.bgDark : AppColors.bgLight,
        body: SafeArea(
          child: Column(
            children: [
              const BannerAdWidget(),
              // Top bar with back button for standalone mode
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[900] : Colors.grey[50],
                  border: Border(
                    bottom: BorderSide(
                      color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
                      width: 0.5,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, size: 22),
                      onPressed: () => Navigator.pop(context),
                      tooltip: 'Back',
                    ),
                    IconButton(
                      icon: const Icon(Icons.apps, size: 24),
                      onPressed: _showMenu,
                      tooltip: 'Calculator Modes & Converters',
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
              Expanded(child: content),
            ],
          ),
        ),
      );
    }

    // Otherwise, we're a tab inside main.dart — just return the Column
    return content;
  }

  Widget _buildCurrentMode() {
    switch (_currentMode) {
      case 1:
        return const ScientificCalculator();
      case 2:
        return const ProgrammerCalculator();
      case 3:
        return const DateCalculator();
      case 4:
        return const EmiCalculator();
      case 5:
        return const GstCalculator();
      default:
        return StandardCalculator(
          initialValue: widget.initialValue,
          currencyCode: widget.currencyCode,
        );
    }
  }
}
