import 'package:flutter/material.dart';

/// A widget that displays a denomination styled like a currency note.
/// No real currency images used - drawn entirely with Flutter widgets.
class NoteWidget extends StatelessWidget {
  final int value;
  final String currencyCode;
  final String currencySymbol;
  final double size;

  const NoteWidget({
    super.key,
    required this.value,
    required this.currencyCode,
    required this.currencySymbol,
    this.size = 56,
  });

  @override
  Widget build(BuildContext context) {
    final color = _getNoteColor();
    
    return Container(
      width: size,
      height: size * 0.65,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color,
            color.withOpacity(0.85),
            color,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: Colors.white.withOpacity(0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.4),
            blurRadius: 3,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Inner border frame
          Positioned.fill(
            child: Container(
              margin: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: Colors.white.withOpacity(0.2),
                  width: 0.5,
                ),
              ),
            ),
          ),
          
          // Value text - center, single instance
          Center(
            child: Text(
              '$currencySymbol$value',
              style: TextStyle(
                fontSize: size * 0.28,
                color: Colors.white,
                fontWeight: FontWeight.bold,
                shadows: [
                  Shadow(
                    color: Colors.black.withOpacity(0.3),
                    offset: const Offset(1, 1),
                    blurRadius: 2,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getNoteColor() {
    if (currencyCode == 'INR') {
      switch (value) {
        case 2000: return const Color(0xFFFE9929);
        case 500: return const Color(0xFF5D7EC4);
        case 200: return const Color(0xFFFFD700);
        case 100: return const Color(0xFFE5B045);
        case 50: return const Color(0xFF40A0E0);
        case 20: return const Color(0xFFE07020);
        case 10: return const Color(0xFF8B5CF6);
        case 5: return const Color(0xFF6B7280);
        case 2: return const Color(0xFF10B981);
        case 1: return const Color(0xFFF59E0B);
        default: return const Color(0xFF6B7280);
      }
    }
    if (currencyCode == 'USD') {
      switch (value) {
        case 100: return const Color(0xFF6B9BD2);
        case 50: return const Color(0xFFC5A572);
        case 20: return const Color(0xFFB8A88A);
        case 10: return const Color(0xFFD4886B);
        case 5: return const Color(0xFFA5C8E1);
        case 2: return const Color(0xFFC0C0C0);
        case 1: return const Color(0xFF7A8B99);
        default: return const Color(0xFF6B9BD2);
      }
    }
    if (currencyCode == 'EUR') {
      switch (value) {
        case 500: return const Color(0xFF8B5CF6);
        case 200: return const Color(0xFFFFD700);
        case 100: return const Color(0xFF5D7EC4);
        case 50: return const Color(0xFFE07020);
        case 20: return const Color(0xFF40A0E0);
        case 10: return const Color(0xFFE5B045);
        case 5: return const Color(0xFF6B7280);
        case 2: return const Color(0xFF10B981);
        case 1: return const Color(0xFF8B5CF6);
        default: return const Color(0xFF5D7EC4);
      }
    }
    if (currencyCode == 'GBP') {
      switch (value) {
        case 50: return const Color(0xFFE07020);
        case 20: return const Color(0xFF5D7EC4);
        case 10: return const Color(0xFF7A8B99);
        case 5: return const Color(0xFF40A0E0);
        case 2: return const Color(0xFF6B7280);
        case 1: return const Color(0xFF10B981);
        default: return const Color(0xFF5D7EC4);
      }
    }
    if (currencyCode == 'BDT') {
      switch (value) {
        case 1000: return const Color(0xFFE5B045);
        case 500: return const Color(0xFF5D7EC4);
        case 200: return const Color(0xFFFFD700);
        case 100: return const Color.fromARGB(255, 180, 160, 140);
        case 50: return const Color(0xFF40A0E0);
        case 20: return const Color(0xFF8B5CF6);
        case 10: return const Color(0xFFE07020);
        case 5: return const Color(0xFF6B7280);
        case 2: return const Color(0xFF10B981);
        case 1: return const Color(0xFFF59E0B);
        default: return const Color(0xFF5D7EC4);
      }
    }
    if (currencyCode == 'NPR') {
      switch (value) {
        case 1000: return const Color(0xFF8B5CF6);
        case 500: return const Color(0xFF10B981);
        case 100: return const Color(0xFF5D7EC4);
        case 50: return const Color(0xFFE07020);
        case 20: return const Color(0xFF40A0E0);
        case 10: return const Color(0xFFE5B045);
        case 5: return const Color(0xFF6B7280);
        case 2: return const Color(0xFF10B981);
        case 1: return const Color(0xFFF59E0B);
        default: return const Color(0xFF5D7EC4);
      }
    }
    return const Color(0xFF6B7280);
  }
}
