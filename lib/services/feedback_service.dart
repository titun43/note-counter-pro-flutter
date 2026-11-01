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
// SOUND PLAYBACK STRATEGY (after multiple iterations — this is the one
// that actually works reliably on Android):
//
//   • We keep ONE AudioPlayer PER sound type (4 players total).
//   • Each player's source is set ONCE at init time via setSourceAsset().
//     This pre-decodes the MP3 into PCM in memory — so play() is just
//     "start playback" with no decode delay.
//   • To replay a sound: stop() + resume(). This is the canonical pattern
//     audioplayers recommends for re-triggering the same sound rapidly.
//   • Using a dedicated player per sound means rapid taps on different
//     buttons (e.g. calculator) never interrupt each other.
//   • We use the DEFAULT PlayerMode (MediaPlayer), not lowLatency.
//     SoundPool (lowLatency) had asset-path issues on some Android
//     versions and only supports very short clips; MediaPlayer is
//     universally supported and our clips are <5KB so latency is fine.
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

  // ONE AudioPlayer per sound type. Each player's source is set once
  // at init time so play() has no decode latency.
  final Map<FeedbackType, AudioPlayer> _players = {};

  // Pre-resolved asset paths (relative to assets/, no leading slash).
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

  /// Inject SharedPreferences and pre-load all sound assets.
  /// Safe to call multiple times.
  Future<void> init(SharedPreferences prefs) async {
    _prefs = prefs;
    if (_initialized) return;

    try {
      // Pre-load each sound into its own dedicated player.
      // setSourceAsset() decodes the MP3 into PCM in memory at init time,
      // so subsequent resume() calls have ZERO decode latency.
      for (final type in FeedbackType.values) {
        try {
          final player = AudioPlayer(playerId: 'ncp_${type.name}');
          await player.setReleaseMode(ReleaseMode.stop);
          await player.setVolume(_volumeFor[type]!);
          // Pre-load the source. setSourceAsset is the recommended way
          // to load an asset into a player for repeated playback.
          await player.setSourceAsset(_assetFor[type]!);
          _players[type] = player;
          debugPrint('FeedbackService: pre-loaded ${type.name}');
        } catch (e) {
          debugPrint('FeedbackService: failed to pre-load ${type.name}: $e');
        }
      }
      if (_players.isEmpty) {
        debugPrint('FeedbackService: ALL sound pre-loading failed — disabling sound');
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

    // For an already-loaded player, the canonical replay pattern is:
    //   1. stop()  — rewind to start (ReleaseMode.stop = release, but
    //               since source is set, resume() will reload from cache)
    //   2. resume() — start playback from the beginning
    //
    // We use Future.then() chain (not await) so the UI thread never blocks.
    // Errors are silently swallowed — sound is best-effort.
    //
    // Why stop() + resume() instead of just play()?
    //   • play(AssetSource(...)) re-resolves the asset path every call
    //   • play() with no argument doesn't exist in audioplayers 5.x
    //   • stop() + resume() is the documented way to replay a loaded source
    p.stop().then((_) {
      return p.resume();
    }).catchError((e) {
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
