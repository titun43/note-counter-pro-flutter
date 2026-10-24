// =============================================================================
// Note Counter Pro - Splash Screen (Dart)
// =============================================================================
// Shown AFTER native splash (flutter_native_splash).
// Layout: LT Logo → "Note Counter Pro" → Animation (middle) → "Smart Cash Counter" → version
// =============================================================================

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/storage_service.dart';
import '../utils/app_localizations.dart';
import '../main.dart';

class SplashScreen extends StatefulWidget {
  final VoidCallback onDone;

  const SplashScreen({super.key, required this.onDone});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _bookController;
  late AnimationController _fadeController;
  late Animation<double> _bookAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    // Book opening animation
    _bookController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _bookAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _bookController, curve: Curves.easeOutCubic),
    );

    // Fade in for text below animation
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeIn),
    );

    // Start animations
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _bookController.forward();
    });
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) _fadeController.forward();
    });

    // Navigate after 2.5 seconds
    Future.delayed(const Duration(milliseconds: 2500), () {
      if (mounted) widget.onDone();
    });
  }

  @override
  void dispose() {
    _bookController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0d0505) : const Color(0xFF1A1A2E);
    final goldColor = const Color(0xFFD4AF37);

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(flex: 2),

            // === LT Logo ===
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF8B0000), Color(0xFF5a0000)],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: goldColor.withOpacity(0.4), width: 2),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF8B0000).withOpacity(0.5),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  'LT',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    color: goldColor,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // === App Name ===
            Text(
              'Note Counter Pro',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: goldColor,
                letterSpacing: 1,
              ),
            ),

            const Spacer(flex: 1),

            // === Animation (middle) — Opening Book ===
            SizedBox(
              width: 120,
              height: 100,
              child: AnimatedBuilder(
                animation: _bookAnimation,
                builder: (context, child) {
                  return CustomPaint(
                    painter: _OpeningBookPainter(
                      progress: _bookAnimation.value,
                      goldColor: goldColor,
                      bgColor: bgColor,
                    ),
                  );
                },
              ),
            ),

            const Spacer(flex: 1),

            // === Tagline + Version (fade in) ===
            FadeTransition(
              opacity: _fadeAnimation,
              child: Column(
                children: [
                  // Smart Cash Counter
                  Text(
                    'Smart Cash Counter',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: goldColor.withOpacity(0.85),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Version
                  FutureBuilder<String>(
                    future: _getVersion(),
                    builder: (context, snapshot) {
                      return Text(
                        snapshot.data ?? '',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withOpacity(0.4),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  // Loading indicator
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: goldColor.withOpacity(0.5),
                    ),
                  ),
                ],
              ),
            ),

            const Spacer(flex: 2),
          ],
        ),
      ),
    );
  }

  Future<String> _getVersion() async {
    try {
      return 'v3.22.6';
    } catch (_) {
      return '';
    }
  }
}

/// Custom painter for opening book animation.
/// Book starts closed (cover facing us) and opens to reveal pages.
class _OpeningBookPainter extends CustomPainter {
  final double progress; // 0.0 = closed, 1.0 = fully open
  final Color goldColor;
  final Color bgColor;

  _OpeningBookPainter({
    required this.progress,
    required this.goldColor,
    required this.bgColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;
    final cy = h / 2;

    // Book dimensions
    final bookW = w * 0.7;
    final bookH = h * 0.75;

    // Spine x position (left edge of book)
    final spineX = cx - bookW / 2;
    final topY = cy - bookH / 2;

    // Angle: 0 (closed) to -pi/2 * 0.85 (open)
    final angle = -math.pi / 2 * 0.85 * progress;

    // Draw left page (static, behind)
    final leftPage = Path()
      ..moveTo(spineX, topY)
      ..lineTo(spineX - bookW * 0.5, topY + bookH * 0.05)
      ..lineTo(spineX - bookW * 0.5, topY + bookH * 0.95)
      ..lineTo(spineX, topY + bookH)
      ..close();
    canvas.drawPath(
      leftPage,
      Paint()..color = goldColor.withOpacity(0.15),
    );

    // Draw lines on left page (text lines)
    for (int i = 1; i <= 4; i++) {
      final y = topY + bookH * (0.2 + i * 0.15);
      canvas.drawLine(
        Offset(spineX - bookW * 0.45, y),
        Offset(spineX - bookW * 0.05, y),
        Paint()
          ..color = goldColor.withOpacity(0.2)
          ..strokeWidth = 1,
      );
    }

    // Draw right page (rotates open)
    canvas.save();
    canvas.translate(spineX, cy);
    canvas.rotate(angle);

    // Right page
    final rightPage = Path()
      ..moveTo(0, topY - cy)
      ..lineTo(bookW * 0.5, (topY - cy) + bookH * 0.05)
      ..lineTo(bookW * 0.5, (topY - cy) + bookH * 0.95)
      ..lineTo(0, (topY - cy) + bookH)
      ..close();

    // Page fill
    canvas.drawPath(
      rightPage,
      Paint()..color = goldColor.withOpacity(0.15 * (1 - progress * 0.5)),
    );

    // Page border
    canvas.drawPath(
      rightPage,
      Paint()
        ..color = goldColor.withOpacity(0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    // Text lines on right page (fade out as it opens)
    for (int i = 1; i <= 4; i++) {
      final y = (topY - cy) + bookH * (0.2 + i * 0.15);
      canvas.drawLine(
        Offset(bookW * 0.05, y),
        Offset(bookW * 0.45, y),
        Paint()
          ..color = goldColor.withOpacity(0.2 * (1 - progress))
          ..strokeWidth = 1,
      );
    }

    canvas.restore();

    // Draw spine
    canvas.drawLine(
      Offset(spineX, topY),
      Offset(spineX, topY + bookH),
      Paint()
        ..color = goldColor.withOpacity(0.6)
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(covariant _OpeningBookPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
