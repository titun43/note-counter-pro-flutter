// =============================================================================
// Note Counter Pro - Flutter Splash Screen (Code-based)
// =============================================================================
// Pure Flutter widget splash — NO image, NO native splash text.
// Uses Flutter Text widgets = crystal clear on all screen sizes.
//
// Design: Idea 5 — Pure Text Splash (No Icon)
//   - Pure dark background (#0A0A1A)
//   - "Note Counter Pro" (white, bold, large)
//   - Gold underline
//   - "Professional Cash Manager" (gold, medium)
//   - "🔒 100% Secure" (gold, large)
//   - "Lokhnath Technical" (white, medium)
// =============================================================================

import 'package:flutter/material.dart';

class SplashScreen extends StatefulWidget {
  final Widget nextScreen;

  const SplashScreen({super.key, required this.nextScreen});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeIn,
    );

    _controller.forward();

    // Navigate to next screen after 1 second
    Future.delayed(const Duration(seconds: 1), () {
      _navigateToNext();
    });
  }

  void _navigateToNext() {
    if (_navigated || !mounted) return;
    _navigated = true;

    // Use pushAndRemoveUntil to completely remove splash from stack
    Navigator.of(context).pushAndRemoveUntil(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            widget.nextScreen,
        transitionsBuilder:
            (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 400),
      ),
      (route) => false, // Remove ALL previous routes (splash)
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A1A),
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Column(
            children: [
              const Spacer(flex: 3),
              // App Name
              const Text(
                'Note Counter Pro',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontFamily: 'Inter',
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8),
              // Gold underline
              Container(
                width: 200,
                height: 2,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFD4AF37), Color(0xFFFFD700)],
                  ),
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
              const SizedBox(height: 12),
              // Tagline
              const Text(
                'Professional Cash Manager',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFFD4AF37),
                  fontFamily: 'Inter',
                ),
              ),
              const Spacer(flex: 4),
              // 100% Secure
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.lock, color: Color(0xFFD4AF37), size: 20),
                  SizedBox(width: 8),
                  Text(
                    '100% Secure',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFD4AF37),
                      fontFamily: 'Inter',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Developer
              const Text(
                'Lokhnath Technical',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: Colors.white70,
                  fontFamily: 'Inter',
                ),
              ),
              const Spacer(flex: 1),
            ],
          ),
        ),
      ),
    );
  }
}
