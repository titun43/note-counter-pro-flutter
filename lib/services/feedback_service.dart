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
// SOUND PLAYBACK STRATEGY (SIMPLEST POSSIBLE — most reliable):
//
//   • Single shared AudioPlayer.
//   • Each fire() calls play(AssetSource) directly.
//   • NO stop(), NO pre-loading, NO setSourceAsset, NO seek/resume.
//   • audioplayers internally caches decoded assets, so the first tap
//     of each sound has ~100ms latency but subsequent taps are fast.
//   • play() automatically stops any currently-playing sound on the
//     same player and starts the new one — so rapid taps naturally
//     retrigger without us calling stop() manually (which was cutting
//     off sound mid-play = "sound full hoynai" bug).
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

  // Single shared AudioPlayer. Reusing one player is simplest and most
  // reliable. play() auto-stops any currently playing sound.
  AudioPlayer? _player;

  // Pre-resolved asset paths.
  static const Map<FeedbackType, String> _assetFor = {
    FeedbackType.tap: 'sounds/tap.mp3',
    FeedbackType.click: 'sounds/click.mp3',
    FeedbackType.success: 'sounds/success.mp3',
    FeedbackType.error: 'sounds/error.mp3',
  };

  // Volume per feedback type (0.0 – 1.0).
  static const Map<FeedbackType, double> _volumeFor = {
    FeedbackType.tap: 0.60,
    FeedbackType.click: 0.85,
    FeedbackType.success: 0.85,
    FeedbackType.error: 0.90, // louder so delete is clearly heard
  };

  bool _initialized = false;
  bool _soundInitFailed = false; // if true, skip sound forever (no audio device)

  /// Inject SharedPreferences and create the AudioPlayer.
  /// Safe to call multiple times.
  Future<void> init(SharedPreferences prefs) async {
    _prefs = prefs;
    if (_initialized) return;

    try {
      _player = AudioPlayer(playerId: 'ncp_feedback_sfx');
      try {
        await _player!.setReleaseMode(ReleaseMode.stop);
      } catch (_) {}
      try {
        await _player!.setVolume(1.0);
      } catch (_) {}
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

    // SIMPLEST APPROACH: just call play(AssetSource) directly.
    //   • No stop() — that was cutting off sound mid-play
    //   • No pre-loading — adds complexity without clear benefit
    //   • No seek/resume — race conditions on rapid taps
    //
    // play() automatically stops any currently playing sound on this
    // player and starts the new one. So rapid taps naturally retrigger.
    // The first tap of each session has ~100ms latency (asset decode);
    // audioplayers caches the decoded asset so subsequent taps are fast.
    //
    // Fire-and-forget — we don't await so the UI thread never blocks.
    p.play(
      AssetSource(_assetFor[type]!),
      volume: _volumeFor[type]!,
    ).catchError((e) {
      debugPrint('FeedbackService sound failed (${type.name}): $e');
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
