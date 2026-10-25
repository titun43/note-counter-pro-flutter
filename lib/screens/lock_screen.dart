import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import '../utils/constants.dart';

class LockScreen extends StatefulWidget {
  final VoidCallback onUnlocked;

  const LockScreen({super.key, required this.onUnlocked});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  final LocalAuthentication _localAuth = LocalAuthentication();
  bool _isAuthenticating = false;

  @override
  void initState() {
    super.initState();
    // Auto-trigger biometric on load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _authenticate();
    });
  }

  Future<void> _authenticate() async {
    if (_isAuthenticating) return;
    _isAuthenticating = true;

    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      final isDeviceSupported = await _localAuth.isDeviceSupported();

      if (canCheck && isDeviceSupported) {
        final didAuth = await _localAuth.authenticate(
          localizedReason: 'Please authenticate to unlock Note Counter Pro',
          options: const AuthenticationOptions(
            biometricOnly: false,
            stickyAuth: true,
          ),
        );

        if (didAuth && mounted) {
          widget.onUnlocked();
        }
      } else {
        // No biometric available - just unlock
        if (mounted) {
          widget.onUnlocked();
        }
      }
    } catch (e) {
      // Auth failed or cancelled - stay on lock screen
      if (mounted) {
        setState(() {});
      }
    } finally {
      _isAuthenticating = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // CRITICAL: PopScope prevents the user from dismissing the lock
    // screen with the system back button. Without this, a user could
    // bypass app lock by pressing back on Android.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        // Block all back navigation — user MUST authenticate.
      },
      child: Scaffold(
        body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.bgDark,
              AppColors.bgDarker,
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // App logo
                Image.asset(
                  'assets/icons/app_logo.png',
                  width: 80,
                  height: 80,
                  errorBuilder: (context, error, child) => const Icon(
                    Icons.lock,
                    size: 64,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 24),

                // App name
                Text(
                  'Note Counter Pro',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'App is locked',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white54,
                  ),
                ),
                const SizedBox(height: 40),

                // Lock icon
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(40),
                    border: Border.all(
                      color: AppColors.primary,
                      width: 2,
                    ),
                  ),
                  child: const Icon(
                    Icons.fingerprint,
                    size: 48,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 24),

                // Unlock button
                FilledButton.icon(
                  onPressed: _isAuthenticating ? null : _authenticate,
                  icon: const Icon(Icons.lock_open),
                  label: Text(_isAuthenticating ? 'Authenticating...' : 'Unlock'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.bgDark,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Hint text
                Text(
                  'Tap unlock and use your fingerprint or PIN',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.white38,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
      ),
    );
  }
}
