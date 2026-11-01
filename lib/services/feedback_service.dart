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
// LATENCY OPTIMIZATION:
//   • Each sound is pre-loaded into its OWN AudioPlayer at init time.
//   • Players use PlayerMode.lowLatency → on Android this routes through
//     SoundPool (the OS-native low-latency SFX engine). First-play
//     latency is typically <50ms; subsequent plays are near-instant.
//   • To replay a sound that's already loaded, we seek(0) + resume()
//     instead of calling play() with a fresh source — this skips
//     source resolution and gets the sound out faster.
//
// Usage:
//   FeedbackService.tap();            // light tap (most buttons)
//   FeedbackService.click();          // medium click (primary action)
//   FeedbackService.success();        // success chime (save / create)
//   FeedbackService.error();          // soft buzz (delete / error)
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
  SharedPreferences? _prefs;

  // One pre-loaded AudioPlayer PER sound type.
  // Pre-loading is the key to low latency: the asset is decoded into PCM
  // once, at init, so play() is just "start playback" (no decode delay).
  final Map<FeedbackType, AudioPlayer> _players = {};

  // Pre-resolved asset paths.
  static const Map<FeedbackType, String> _assetFor = {
    FeedbackType.tap: 'sounds/tap.mp3',
    FeedbackType.click: 'sounds/click.mp3',
    FeedbackType.success: 'sounds/success.mp3',
    FeedbackType.error: 'sounds/error.mp3',
  };

  // Volume per feedback type (0.0 – 1.0). Kept conservative so the click
  // is clearly audible without ever being annoying.
  static const Map<FeedbackType, double> _volumeFor = {
    FeedbackType.tap: 0.55,
    FeedbackType.click: 0.75,
    FeedbackType.success: 0.75,
    FeedbackType.error: 0.80, // louder so delete is clearly heard
  };

  bool _initialized = false;
  bool _soundInitFailed = false; // if true, skip sound forever (no audio device)

  /// Inject SharedPreferences and pre-load all sound assets.
  /// Safe to call multiple times.
  Future<void> init(SharedPreferences prefs) async {
    _prefs = prefs;
    if (_initialized) return;

    try {
      // Pre-load each sound into its own low-latency player.
      // On Android, PlayerMode.lowLatency uses SoundPool (OS-native SFX
      // engine) — first-play latency <50ms, subsequent plays instant.
      for (final type in FeedbackType.values) {
        try {
          final player = AudioPlayer(playerId: 'ncp_${type.name}');
          // PlayerMode.lowLatency → SoundPool on Android (low-latency SFX).
          // Must be set via setPlayerMode() — the `mode` constructor param
          // was removed in audioplayers 4.x.
          try {
            await player.setPlayerMode(PlayerMode.lowLatency);
          } catch (_) {
            // PlayerMode API may differ across versions — default mode still works.
          }
          await player.setReleaseMode(ReleaseMode.stop);
          await player.setVolume(_volumeFor[type]!);
          // Pre-load the source (decodes MP3 → PCM in memory).
          await player.setSource(AssetSource(_assetFor[type]!));
          _players[type] = player;
        } catch (e) {
          debugPrint('FeedbackService: failed to pre-load ${type.name}: $e');
        }
      }
      if (_players.isEmpty) {
        _soundInitFailed = true;
      }
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
    final p = _players[type];
    if (p == null) return;

    // For instant replay of an already-loaded sound:
    //   1. seek(Duration.zero) — rewind to start
    //   2. resume()            — start playback (no source resolution)
    // This is faster than calling play(AssetSource(...)) again because
    // the source is already decoded in memory.
    //
    // We don't await these — fire-and-forget so the UI thread never
    // blocks on audio. Errors are silently swallowed (sound is best-effort).
    p.seek(Duration.zero).then((_) {
      return p.resume();
    }).catchError((e) {
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

  /// Dispose all underlying audio players. Only call on app teardown.
  Future<void> dispose() async {
    for (final p in _players.values) {
      try {
        await p.dispose();
      } catch (_) {}
    }
    _players.clear();
  }
}
