import 'package:flutter/material.dart';
import '../utils/constants.dart';

class DateCalculator extends StatefulWidget {
  const DateCalculator({super.key});

  @override
  State<DateCalculator> createState() => _DateCalculatorState();
}

class _DateCalculatorState extends State<DateCalculator> {
  DateTime _fromDate = DateTime.now();
  DateTime _toDate = DateTime.now().add(const Duration(days: 7));
  int _addDays = 0;
  int _addMonths = 0;
  int _addYears = 0;
  DateTime _baseDate = DateTime.now();
  DateTime? _resultDate;

  Future<void> _pickDate(BuildContext context, bool isFrom) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isFrom ? _fromDate : _toDate,
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        if (isFrom) {
          _fromDate = picked;
        } else {
          _toDate = picked;
        }
      });
    }
  }

  Future<void> _pickBaseDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _baseDate,
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _baseDate = picked);
    }
  }

  void _calculateAddSubtract() {
    setState(() {
      final newYear = _baseDate.year + _addYears;
      final newMonth = _baseDate.month + _addMonths;
      // Normalize month overflow/underflow (e.g. month 13 → year+1, month 1)
      final normalizedYear = newYear + ((newMonth - 1) ~/ 12);
      final normalizedMonth = ((newMonth - 1) % 12) + 1;
      // Cap the day to the number of days in the target month.
      // This prevents DateTime from auto-rolling over (e.g. Feb 30 → Mar 2).
      final daysInTargetMonth = DateTime(normalizedYear, normalizedMonth + 1, 0).day;
      final cappedDay = _baseDate.day.clamp(1, daysInTargetMonth);
      _resultDate = DateTime(
        normalizedYear,
        normalizedMonth,
        cappedDay + _addDays,
      );
    });
  }

  Map<String, int> _diffBreakdown(DateTime from, DateTime to) {
    final fromDt = DateTime(from.year, from.month, from.day);
    final toDt = DateTime(to.year, to.month, to.day);
    final days = toDt.difference(fromDt).inDays;
    final weeks = days ~/ 7;
    final months = (to.year - from.year) * 12 + (to.month - from.month);
    final years = to.year - from.year;
    final hours = days * 24;
    final minutes = hours * 60;
    return {
      'days': days,
      'weeks': weeks,
      'months': months,
      'years': years,
      'hours': hours,
      'minutes': minutes,
    };
  }

  String _fmtDate(DateTime d) {
    return '${d.day}/${d.month}/${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final diff = _diffBreakdown(_fromDate, _toDate);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // === Difference ===
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Date Difference', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _dateField('From', _fromDate, () => _pickDate(context, true))),
                      const SizedBox(width: 8),
                      Expanded(child: _dateField('To', _toDate, () => _pickDate(context, false))),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _diffRow('Years', diff['years']!),
                  _diffRow('Months', diff['months']!),
                  _diffRow('Weeks', diff['weeks']!),
                  _diffRow('Days', diff['days']!),
                  _diffRow('Hours', diff['hours']!),
                  _diffRow('Minutes', diff['minutes']!),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // === Add/Subtract ===
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Add / Subtract', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  _dateField('Base Date', _baseDate, () => _pickBaseDate(context)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _numField('Days', _addDays, (v) => _addDays = v)),
                      const SizedBox(width: 8),
                      Expanded(child: _numField('Months', _addMonths, (v) => _addMonths = v)),
                      const SizedBox(width: 8),
                      Expanded(child: _numField('Years', _addYears, (v) => _addYears = v)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _calculateAddSubtract,
                    icon: const Icon(Icons.calculate),
                    label: const Text('Calculate'),
                  ),
                  if (_resultDate != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.success.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Result: ${_fmtDate(_resultDate!)}',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.success,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dateField(String label, DateTime date, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          prefixIcon: const Icon(Icons.calendar_today, size: 18),
        ),
        child: Text(_fmtDate(date), style: const TextStyle(fontSize: 14)),
      ),
    );
  }

  Widget _numField(String label, int value, Function(int) onChanged) {
    return TextField(
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
      keyboardType: TextInputType.number,
      controller: TextEditingController(text: value.toString()),
      onChanged: (v) => onChanged(int.tryParse(v) ?? 0),
    );
  }

  Widget _diffRow(String label, int value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value.toString(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        ],
      ),
    );
  }
}
