import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/constants.dart';

class ConverterScreen extends StatefulWidget {
  final int initialType;
  const ConverterScreen({super.key, this.initialType = 0});

  @override
  State<ConverterScreen> createState() => _ConverterScreenState();
}

class _ConverterScreenState extends State<ConverterScreen> {
  late int _type;
  String _fromUnit = '';
  String _toUnit = '';
  final _inputController = TextEditingController(text: '1');
  double _result = 0;
  Map<String, double>? _currencyRates;
  bool _loadingRates = false;

  static const _converterTypes = [
    'Currency', 'Length', 'Weight & Mass', 'Temperature',
    'Energy', 'Area', 'Speed', 'Time',
    'Power', 'Data', 'Pressure', 'Angle',
  ];

  static const _units = {
    'Currency': {'INR (₹)': 1.0, 'USD (\$)': 0.012, 'EUR (€)': 0.011, 'GBP (£)': 0.0095, 'JPY (¥)': 1.8, 'AUD (\$)': 0.018, 'CAD (\$)': 0.016, 'CNY (¥)': 0.085, 'RUB (₽)': 1.1, 'AED (د.إ)': 0.044},
    'Length': {'Meter': 1.0, 'Kilometer': 0.001, 'Centimeter': 100.0, 'Millimeter': 1000.0, 'Mile': 0.000621371, 'Yard': 1.09361, 'Foot': 3.28084, 'Inch': 39.3701, 'Nautical Mile': 0.000539957},
    'Weight & Mass': {'Kilogram': 1.0, 'Gram': 1000.0, 'Milligram': 1000000.0, 'Metric Ton': 0.001, 'Pound': 2.20462, 'Ounce': 35.274, 'Quintal': 0.01, 'Carat': 5000.0},
    'Temperature': {'Celsius': 1.0, 'Fahrenheit': 1.0, 'Kelvin': 1.0},
    'Energy': {'Joule': 1.0, 'Kilojoule': 0.001, 'Calorie': 0.239006, 'Kilocalorie': 0.000239006, 'kWh': 0.000000277778, 'BTU': 0.000947817, 'Electronvolt': 6.242e+18},
    'Area': {'Square Meter': 1.0, 'Square Kilometer': 0.000001, 'Square Centimeter': 10000.0, 'Acre': 0.000247105, 'Hectare': 0.0001, 'Square Foot': 10.7639, 'Square Mile': 0.000000386102, 'Square Yard': 1.19599},
    'Speed': {'m/s': 1.0, 'km/h': 3.6, 'mph': 2.23694, 'Knot': 1.94384, 'Mach': 0.002939},
    'Time': {'Second': 1.0, 'Millisecond': 1000.0, 'Minute': 0.0166667, 'Hour': 0.000277778, 'Day': 0.0000115741, 'Week': 0.00000165344, 'Month': 5.526e-8, 'Year': 3.171e-8},
    'Power': {'Watt': 1.0, 'Kilowatt': 0.001, 'Megawatt': 0.000001, 'Horsepower': 0.00134102, 'BTU/h': 3.41214, 'Cal/sec': 0.239006},
    'Data': {'Byte': 1.0, 'Bit': 8.0, 'Kilobyte': 0.001, 'Megabyte': 0.000001, 'Gigabyte': 0.000000001, 'Terabyte': 0.000000000001, 'Petabyte': 0.000000000000001},
    'Pressure': {'Pascal': 1.0, 'Kilopascal': 0.001, 'Bar': 0.00001, 'PSI': 0.000145038, 'Atmosphere': 0.00000986923, 'mmHg': 0.00750062},
    'Angle': {'Degree': 1.0, 'Radian': 0.0174533, 'Gradian': 1.11111, 'Turn': 0.00277778},
  };

  @override
  void initState() {
    super.initState();
    _type = widget.initialType;
    final unitsList = _units[_converterTypes[_type]]!.keys.toList();
    _fromUnit = unitsList.first;
    _toUnit = unitsList.length > 1 ? unitsList[1] : unitsList.first;
    _convert();
    if (_type == 0) _loadCurrencyRates();
  }

  Future<void> _loadCurrencyRates() async {
    setState(() => _loadingRates = true);
    try {
      // Check cache (1 hour)
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString('currency_rates');
      final cachedTime = prefs.getInt('currency_rates_time') ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;

      if (cached != null && (now - cachedTime) < 3600000) {
        final data = jsonDecode(cached) as Map<String, dynamic>;
        setState(() {
          _currencyRates = data['rates'].cast<String, double>();
          _loadingRates = false;
        });
        _convert();
        return;
      }

      // Free API — exchangerate-api.com (free tier)
      final response = await http.get(Uri.parse('https://open.er-api.com/v6/latest/INR'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final rates = (data['rates'] as Map).cast<String, double>();
        await prefs.setString('currency_rates', jsonEncode({'rates': rates}));
        await prefs.setInt('currency_rates_time', now);
        setState(() {
          _currencyRates = rates;
          _loadingRates = false;
        });
        _convert();
      }
    } catch (e) {
      // Use hardcoded rates as fallback
      setState(() => _loadingRates = false);
    }
  }

  void _convert() {
    final input = double.tryParse(_inputController.text) ?? 0;
    final typeName = _converterTypes[_type];

    if (typeName == 'Temperature') {
      _result = _convertTemperature(input, _fromUnit, _toUnit);
    } else if (typeName == 'Currency' && _currencyRates != null) {
      // INR-based rates
      final fromRate = _currencyRates![_fromUnit.split(' ').first] ?? 1.0;
      final toRate = _currencyRates![_toUnit.split(' ').first] ?? 1.0;
      // Convert: input * (1/fromRate) * toRate (INR base)
      _result = input / fromRate * toRate;
    } else {
      final units = _units[typeName]!;
      final fromFactor = units[_fromUnit] ?? 1.0;
      final toFactor = units[_toUnit] ?? 1.0;
      _result = input / fromFactor * toFactor;
    }
    setState(() {});
  }

  double _convertTemperature(double val, String from, String to) {
    double celsius;
    if (from == 'Celsius') celsius = val;
    else if (from == 'Fahrenheit') celsius = (val - 32) * 5 / 9;
    else celsius = val - 273.15;

    if (to == 'Celsius') return celsius;
    if (to == 'Fahrenheit') return celsius * 9 / 5 + 32;
    return celsius + 273.15;
  }

  void _changeType(int index) {
    setState(() {
      _type = index;
      final unitsList = _units[_converterTypes[_type]]!.keys.toList();
      _fromUnit = unitsList.first;
      _toUnit = unitsList.length > 1 ? unitsList[1] : unitsList.first;
    });
    _convert();
    if (index == 0 && _currencyRates == null) _loadCurrencyRates();
  }

  void _swap() {
    setState(() {
      final tmp = _fromUnit;
      _fromUnit = _toUnit;
      _toUnit = tmp;
    });
    _convert();
  }

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final typeName = _converterTypes[_type];
    final unitsList = _units[typeName]!.keys.toList();

    return Scaffold(
      appBar: AppBar(
        title: Text('$typeName Converter'),
        actions: [
          if (typeName == 'Currency')
            IconButton(
              icon: _loadingRates
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.refresh),
              onPressed: _loadingRates ? null : _loadCurrencyRates,
              tooltip: 'Refresh Rates',
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Converter type chips
            SizedBox(
              height: 40,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _converterTypes.length,
                itemBuilder: (ctx, i) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Text(_converterTypes[i], style: const TextStyle(fontSize: 12)),
                      selected: _type == i,
                      onSelected: (_) => _changeType(i),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),
            // From
            _unitDropdown('From', _fromUnit, unitsList, (v) {
              _fromUnit = v;
              _convert();
            }),
            const SizedBox(height: 8),
            TextField(
              controller: _inputController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.input),
              ),
              onChanged: (_) => _convert(),
            ),
            const SizedBox(height: 12),
            // Swap button
            Center(
              child: IconButton(
                icon: const Icon(Icons.swap_vert, size: 32),
                onPressed: _swap,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 12),
            // To
            _unitDropdown('To', _toUnit, unitsList, (v) {
              _toUnit = v;
              _convert();
            }),
            const SizedBox(height: 8),
            // Result
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primary.withOpacity(0.3)),
              ),
              child: Column(
                children: [
                  Text(
                    _result.toStringAsFixed(4).replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), ''),
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                  Text(_toUnit, style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey)),
                ],
              ),
            ),
            if (typeName == 'Currency') ...[
              const SizedBox(height: 12),
              Text(
                _currencyRates != null
                    ? '📡 Live rates (cached 1 hour)'
                    : '⚠️ Using estimated rates. Tap refresh for live rates.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: _currencyRates != null ? AppColors.success : AppColors.warning,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _unitDropdown(String label, String value, List<String> items, Function(String) onChanged) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      items: items.map((u) => DropdownMenuItem(value: u, child: Text(u, style: const TextStyle(fontSize: 14)))).toList(),
      onChanged: (v) => v != null ? onChanged(v) : null,
    );
  }
}
