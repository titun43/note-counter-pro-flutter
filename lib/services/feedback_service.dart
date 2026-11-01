// =============================================================================
// Note Counter Pro — Feedback Service (Haptic + Sound)
// =============================================================================
//
// Provides unified tactile + audible feedback for user interactions.
//
// Both channels are independently controlled from Settings:
//   • hapticFeedback (bool, default: true) → device vibration
//   • buttonSound    (bool, default: true) → short UI click sound
//
// If a setting is OFF, that channel is silenced — no exceptions.
//
// Usage:
//   FeedbackService.tap();            // light tap (most buttons)
//   FeedbackService.click();          // medium click (primary action)
//   FeedbackService.success();        // success chime (save / create)
//   FeedbackService.error();          // soft buzz (delete / error)
//
// The service is a singleton. The SharedPreferences instance is injected
// via init() at app start (after StorageService is built) so we never
// block on a fresh prefs lookup for every tap.
// =============================================================================

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Severity / intent of the feedback. Each maps to a distinct haptic
/// pattern and a distinct sound asset.
enum FeedbackType {
  /// Subtle tap — list items, secondary buttons, toggles.
  tap,

  /// Confident click — primary buttons (Save, Create, Submit, Navigate).
  click,

  /// Positive confirmation — successful save / create / send.
  success,

  /// Negative / destructive — delete, error, validation fail.
  error,
}

class FeedbackService {
  FeedbackService._();
  static final FeedbackService _instance = FeedbackService._();
  factory FeedbackService() => _instance;

  // Cached SharedPreferences — injected from main.dart after app start.
  // May be null briefly during cold start; we treat null as "default ON".
  SharedPreferences? _prefs;

  // Single AudioPlayer reused for all SFX. AudioPlayer is cheap to reuse
  // and we never play more than one SFX at a time.
  AudioPlayer? _player;

  // Pre-resolved asset URLs. Avoids path resolution per tap.
  static const Map<FeedbackType, String> _assetFor = {
    FeedbackType.tap: 'sounds/tap.mp3',
    FeedbackType.click: 'sounds/click.mp3',
    FeedbackType.success: 'sounds/success.mp3',
    FeedbackType.error: 'sounds/error.mp3',
  };

  // Volume per feedback type (0.0 – 1.0). Kept conservative so the click
  // is clearly audible without ever being annoying.
  static const Map<FeedbackType, double> _volumeFor = {
    FeedbackType.tap: 0.5,
    FeedbackType.click: 0.7,
    FeedbackType.success: 0.7,
    FeedbackType.error: 0.7,
  };

  bool _initialized = false;
  bool _soundInitFailed = false; // if true, skip sound forever (no audio device)

  /// Inject SharedPreferences and warm up the AudioPlayer.
  /// Safe to call multiple times.
  Future<void> init(SharedPreferences prefs) async {
    _prefs = prefs;
    if (_initialized) return;
    try {
      _player = AudioPlayer(playerId: 'ncp_feedback_sfx');
      await _player!.setReleaseMode(ReleaseMode.stop);
      await _player!.setVolume(0.7);
    } catch (e) {
      debugPrint('FeedbackService audio init failed (non-fatal): $e');
      _soundInitFailed = true;
    } finally {
      _initialized = true;
    }
  }

  // ---------------------------------------------------------------- settings

  bool get _hapticEnabled {
    final v = _prefs?.getBool('hapticFeedback');
    return v ?? true;
  }

  bool get _soundEnabled {
    if (_soundInitFailed) return false;
    final v = _prefs?.getBool('buttonSound');
    return v ?? true;
  }

  // ------------------------------------------------------------------- haptic

  void _hapticFor(FeedbackType type) {
    if (!_hapticEnabled) return;
    try {
      switch (type) {
        case FeedbackType.tap:
          HapticFeedback.selectionClick();
          break;
        case FeedbackType.click:
          HapticFeedback.lightImpact();
          break;
        case FeedbackType.success:
          HapticFeedback.mediumImpact();
          break;
        case FeedbackType.error:
          HapticFeedback.heavyImpact();
          break;
      }
    } catch (_) {
      // Haptics unsupported on this platform — silently ignore.
    }
  }

  // -------------------------------------------------------------------- sound

  void _soundFor(FeedbackType type) {
    if (!_soundEnabled) return;
    final p = _player;
    if (p == null) return;
    // Fire-and-forget — we never block the UI thread on audio.
    p.play(AssetSource(_assetFor[type]!), volume: _volumeFor[type]!)
        .catchError((e) {
      debugPrint('FeedbackService sound failed: $e');
    });
  }

  // -------------------------------------------------------------------- public

  /// Fire both haptic + sound for the given feedback type.
  /// Haptic fires synchronously (instant); sound is async (fire-and-forget).
  void fire([FeedbackType type = FeedbackType.click]) {
    _hapticFor(type);
    _soundFor(type);
  }

  /// Convenience: subtle tap. Use for list items, secondary buttons, toggles.
  void tap() => fire(FeedbackType.tap);

  /// Convenience: confident click. Use for primary buttons (Save, Create).
  void click() => fire(FeedbackType.click);

  /// Convenience: positive confirmation. Use after a successful save/create.
  void success() => fire(FeedbackType.success);

  /// Convenience: destructive / error. Use for delete actions and errors.
  void error() => fire(FeedbackType.error);

  /// Dispose the underlying audio player. Only call on app teardown.
  Future<void> dispose() async {
    try {
      await _player?.dispose();
    } catch (_) {}
  }
}
