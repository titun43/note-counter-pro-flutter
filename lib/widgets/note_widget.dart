import 'package:flutter/material.dart';

/// A widget that displays a denomination styled like a currency note.
/// No real currency images used - drawn entirely with Flutter widgets.
/// Each currency has its own color scheme and pattern.
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
      height: size * 0.65, // Note aspect ratio (wider than tall)
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color,
            color.withOpacity(0.8),
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
          // Border frame (like real notes have)
          Positioned.fill(
            child: Container(
              margin: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: Colors.white.withOpacity(0.2),
                  width: 0.5,
                ),
              ),
            ),
          ),
          
          // Currency symbol watermark (center, faded)
          Center(
            child: Text(
              currencySymbol,
              style: TextStyle(
                fontSize: size * 0.5,
                color: Colors.white.withOpacity(0.15),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          
          // Value text (top-left corner)
          Positioned(
            top: 4,
            left: 6,
            child: Text(
              '$currencySymbol$value',
              style: TextStyle(
                fontSize: size * 0.22,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          
          // Value text (bottom-right corner, rotated)
          Positioned(
            bottom: 4,
            right: 6,
            child: Transform.rotate(
              angle: 3.14, // 180 degrees
              child: Text(
                '$currencySymbol$value',
                style: TextStyle(
                  fontSize: size * 0.18,
                  color: Colors.white.withOpacity(0.7),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          
          // Currency code (center, small)
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(height: size * 0.1),
                Text(
                  '$value',
                  style: TextStyle(
                    fontSize: size * 0.32,
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
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Get note color based on currency code and value
  /// Colors are inspired by real currency but are our own design
  Color _getNoteColor() {
    // INR colors
    if (currencyCode == 'INR') {
      switch (value) {
        case 2000: return const Color(0xFFFE9929); // Orange
        case 500: return const Color(0xFF5D7EC4); // Stone gray-blue
        case 200: return const Color(0xFFFFD700); // Yellow
        case 100: return const Color(0xFFE5B045); // Lavender-purple
        case 50: return const Color(0xFF40A0E0); // Cyan
        case 20: return const Color(0xFFE07020); // Green-yellow
        case 10: return const Color(0xFF8B5CF6); // Brown
        case 5: return const Color(0xFF6B7280); // Gray
        case 2: return const Color(0xFF10B981); // Green
        case 1: return const Color(0xFFF59E0B); // Amber
        default: return const Color(0xFF6B7280);
      }
    }
    
    // USD colors
    if (currencyCode == 'USD') {
      switch (value) {
        case 100: return const Color(0xFF6B9BD2); // Blue
        case 50: return const Color(0xFFC5A572); // Pink-red
        case 20: return const Color(0xFFB8A88A); // Green
        case 10: return const Color(0xFFD4886B); // Orange
        case 5: return const Color(0xFFA5C8E1); // Purple
        case 2: return const Color(0xFFC0C0C0); // Silver
        case 1: return const Color(0xFF7A8B99); // Gray
        default: return const Color(0xFF6B9BD2);
      }
    }
    
    // EUR colors
    if (currencyCode == 'EUR') {
      switch (value) {
        case 500: return const Color(0xFF8B5CF6); // Purple
        case 200: return const Color(0xFFFFD700); // Yellow
        case 100: return const Color(0xFF5D7EC4); // Green
        case 50: return const Color(0xFFE07020); // Orange
        case 20: return const Color(0xFF40A0E0); // Blue
        case 10: return const Color(0xFFE5B045); // Red
        case 5: return const Color(0xFF6B7280); // Gray
        case 2: return const Color(0xFF10B981); // Green
        case 1: return const Color(0xFF8B5CF6); // Purple
        default: return const Color(0xFF5D7EC4);
      }
    }
    
    // GBP colors
    if (currencyCode == 'GBP') {
      switch (value) {
        case 50: return const Color(0xFFE07020); // Red
        case 20: return const Color(0xFF5D7EC4); // Blue
        case 10: return const Color(0xFF7A8B99); // Brown
        case 5: return const Color(0xFF40A0E0); // Teal
        case 2: return const Color(0xFF6B7280); // Gray
        case 1: return const Color(0xFF10B981); // Green
        default: return const Color(0xFF5D7EC4);
      }
    }
    
    // BDT colors
    if (currencyCode == 'BDT') {
      switch (value) {
        case 1000: return const Color(0xFFE5B045); // Red
        case 500: return const Color(0xFF5D7EC4); // Blue
        case 200: return const Color(0xFFFFD700); // Yellow
        case 100: return Color.fromARGB(255, 180, 160, 140); // Beige
        case 50: return const Color(0xFF40A0E0); // Cyan
        case 20: return const Color(0xFF8B5CF6); // Purple
        case 10: return const Color(0xFFE07020); // Orange
        case 5: return const Color(0xFF6B7280); // Gray
        case 2: return const Color(0xFF10B981); // Green
        case 1: return const Color(0xFFF59E0B); // Amber
        default: return const Color(0xFF5D7EC4);
      }
    }
    
    // NPR colors
    if (currencyCode == 'NPR') {
      switch (value) {
        case 1000: return const Color(0xFF8B5CF6); // Purple
        case 500: return const Color(0xFF10B981); // Green
        case 100: return const Color(0xFF5D7EC4); // Blue
        case 50: return const Color(0xFFE07020); // Orange
        case 20: return const Color(0xFF40A0E0); // Cyan
        case 10: return const Color(0xFFE5B045); // Red
        case 5: return const Color(0xFF6B7280); // Gray
        case 2: return const Color(0xFF10B981); // Green
        case 1: return const Color(0xFFF59E0B); // Amber
        default: return const Color(0xFF5D7EC4);
      }
    }
    
    // Default
    return const Color(0xFF6B7280);
  }
}
