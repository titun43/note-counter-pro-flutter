// =============================================================================
// Note Counter Pro — Animated Update Dialog (CheQ-inspired)
// =============================================================================
//
// Premium update dialog with:
//   • Mixed typography headline (gold accent on app name)
//   • Floating phone illustration with subtle tilt + sparkles + glow
//   • Single gold-gradient CTA button (no "Later" — close = dismiss)
//   • Tiny version info at the bottom
//
// Animations (all looped, 60fps, lightweight):
//   1. Phone floats up-down + 2° tilt (3s loop)
//   2. Sparkles twinkle around phone (staggered)
//   3. Soft glow pulses underneath phone (3s loop)
//   4. App icon pulses on phone screen (2s loop)
//   5. Dialog scales+fades in on appear (one-shot)
//
// Brand colors: gold gradient (#FFD700 → #D4AF37) on dark navy bg.
// Works in both light and dark mode (dialog itself is always on a
// dark gradient surface so the gold pops).
// =============================================================================

import 'package:flutter/material.dart';

class AnimatedUpdateDialog extends StatefulWidget {
  final String version; // e.g. "v3.46.0"
  final String size; // e.g. "15 MB"
  final VoidCallback onUpdate;

  const AnimatedUpdateDialog({
    super.key,
    required this.version,
    required this.size,
    required this.onUpdate,
  });

  @override
  State<AnimatedUpdateDialog> createState() => _AnimatedUpdateDialogState();
}

class _AnimatedUpdateDialogState extends State<AnimatedUpdateDialog>
    with TickerProviderStateMixin {
  late final AnimationController _floatController; // phone floating
  late final AnimationController _glowController; // glow pulse
  late final AnimationController _iconController; // app icon pulse
  late final AnimationController _entryController; // dialog entry
  late final AnimationController _sparkleController; // sparkles

  @override
  void initState() {
    super.initState();
    // Phone floating + tilt — 3s loop
    _floatController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat(reverse: true);

    // Glow pulse — 3s loop (synced with float)
    _glowController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat(reverse: true);

    // App icon breathing — 2s loop
    _iconController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    // Sparkles — 2s loop
    _sparkleController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();

    // Dialog entry — one-shot, 500ms
    _entryController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    )..forward();
  }

  @override
  void dispose() {
    _floatController.dispose();
    _glowController.dispose();
    _iconController.dispose();
    _sparkleController.dispose();
    _entryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: ScaleTransition(
        scale: CurvedAnimation(
          parent: _entryController,
          curve: Curves.easeOutBack,
        ),
        child: FadeTransition(
          opacity: CurvedAnimation(
            parent: _entryController,
            curve: Curves.easeOut,
          ),
          child: _buildDialog(),
        ),
      ),
    );
  }

  Widget _buildDialog() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
      decoration: BoxDecoration(
        // Dark gradient background so gold pops in both light & dark modes
        gradient: const LinearGradient(
          colors: [Color(0xFF16213E), Color(0xFF0A0A1A)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFFD4AF37).withOpacity(0.25),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.6),
            blurRadius: 30,
            offset: const Offset(0, 12),
          ),
          BoxShadow(
            color: const Color(0xFFD4AF37).withOpacity(0.15),
            blurRadius: 40,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Close button (top right)
          Align(
            alignment: Alignment.topRight,
            child: _buildCloseButton(),
          ),
          // Headline
          _buildHeadline(),
          const SizedBox(height: 20),
          // Phone illustration with floating animation
          _buildPhoneIllustration(),
          const SizedBox(height: 24),
          // CTA button
          _buildCtaButton(),
          const SizedBox(height: 12),
          // Version info (tiny)
          _buildVersionInfo(),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------- close btn

  Widget _buildCloseButton() {
    return Material(
      color: Colors.white.withOpacity(0.08),
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).pop(),
        child: Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          child: const Icon(
            Icons.close,
            color: Color(0xFF9CA3AF),
            size: 18,
          ),
        ),
      ),
    );
  }

  // ----------------------------------------------------------------- headline

  Widget _buildHeadline() {
    return Column(
      children: [
        Text(
          'Discover the new',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Colors.white.withOpacity(0.85),
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: 4),
        // Gold gradient text — Note Counter Pro
        ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [Color(0xFFFFD700), Color(0xFFD4AF37)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ).createShader(bounds),
          child: const Text(
            'Note Counter Pro',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -0.5,
            ),
          ),
        ),
      ],
    );
  }

  // ----------------------------------------------------- phone illustration

  Widget _buildPhoneIllustration() {
    return SizedBox(
      width: 160,
      height: 220,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Glow underneath phone (pulses)
          Positioned(
            bottom: 0,
            child: AnimatedBuilder(
              animation: _glowController,
              builder: (context, _) {
                return Transform.scale(
                  scale: 1.0 - _glowController.value * 0.15,
                  child: Opacity(
                    opacity: 0.4 + _glowController.value * 0.3,
                    child: Container(
                      width: 120,
                      height: 16,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFD700),
                        borderRadius: BorderRadius.circular(100),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFFD700).withOpacity(0.6),
                            blurRadius: 24,
                            spreadRadius: 4,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          // Sparkles (4 staggered)
          ..._buildSparkles(),
          // Phone with floating + tilt animation
          AnimatedBuilder(
            animation: _floatController,
            builder: (context, child) {
              // Float up by 12px at peak, tilt ±2°
              final offset = _floatController.value * 12.0;
              final tilt = (_floatController.value * 2 - 1) * 0.035; // ~2°
              return Transform.translate(
                offset: Offset(0, -offset),
                child: Transform.rotate(
                  angle: tilt,
                  child: child,
                ),
              );
            },
            child: _buildPhone(),
          ),
        ],
      ),
    );
  }

  Widget _buildPhone() {
    return Container(
      width: 130,
      height: 200,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A1A2E), Color(0xFF2A2A4E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFD4AF37), width: 2.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Notch
          Positioned(
            top: 4,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                width: 32,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFF0A0A1A),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
          // Screen
          Positioned.fill(
            top: 14,
            child: Container(
              margin: const EdgeInsets.only(top: 4),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0A0A1A), Color(0xFF1A1A2E)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // App icon (pulses)
                  AnimatedBuilder(
                    animation: _iconController,
                    builder: (context, child) {
                      final scale = 1.0 + _iconController.value * 0.08;
                      return Transform.scale(
                        scale: scale,
                        child: child,
                      );
                    },
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFFD700), Color(0xFFD4AF37)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFFD700).withOpacity(0.5),
                            blurRadius: 12,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Text(
                          '🧮',
                          style: TextStyle(fontSize: 22),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'NOTE COUNTER',
                    style: TextStyle(
                      color: Color(0xFFFFD700),
                      fontSize: 8,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'PRO',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.5),
                      fontSize: 7,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ----------------------------------------------------------------- sparkles

  List<Widget> _buildSparkles() {
    // 4 sparkles at different positions, staggered twinkle.
    // Each sparkle's opacity is driven by _sparkleController with a phase offset.
    final positions = [
      const Offset(-60, -90), // top-left
      const Offset(60, -60), // top-right
      const Offset(-55, 60), // bottom-left
      const Offset(55, 85), // bottom-right
    ];
    final icons = ['✨', '⭐', '✨', '⭐'];
    final delays = [0.0, 0.25, 0.5, 0.75];

    return List.generate(4, (i) {
      return Positioned(
        left: 80 + positions[i].dx, // center 80 = half of width 160
        top: 110 + positions[i].dy, // center 110 = half of height 220
        child: AnimatedBuilder(
          animation: _sparkleController,
          builder: (context, _) {
            // Staggered phase: each sparkle peaks at different time.
            final phase = (_sparkleController.value + delays[i]) % 1.0;
            // 0 → 0.5 → 0 opacity curve (peak in the middle)
            final opacity = phase < 0.5
                ? (phase * 2)
                : ((1 - phase) * 2);
            final scale = 0.5 + opacity * 0.7;
            return Opacity(
              opacity: opacity,
              child: Transform.scale(
                scale: scale,
                child: Text(
                  icons[i],
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            );
          },
        ),
      );
    });
  }

  // ------------------------------------------------------------------- CTA btn

  Widget _buildCtaButton() {
    return SizedBox(
      width: double.infinity,
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFFD700), Color(0xFFD4AF37)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFFD700).withOpacity(0.4),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () {
              widget.onUpdate();
              Navigator.of(context).pop();
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 15),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Text(
                    'UPDATE NOW',
                    style: TextStyle(
                      color: Color(0xFF1A1A2E),
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                  SizedBox(width: 8),
                  Icon(
                    Icons.arrow_forward,
                    color: Color(0xFF1A1A2E),
                    size: 18,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------ version info

  Widget _buildVersionInfo() {
    return Text(
      '${widget.version}  ·  ${widget.size}',
      style: TextStyle(
        color: const Color(0xFF9CA3AF),
        fontSize: 11,
        letterSpacing: 0.5,
      ),
    );
  }
}
