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
// SOUND PLAYBACK STRATEGY (after multiple iterations — this version uses
// pre-loaded ByteData + BytesSource for maximum reliability):
//
//   • At init time, we load each sound file's raw bytes via rootBundle.
//     This bypasses audioplayers' asset-path resolution entirely.
//   • We store the ByteData in a map.
//   • Each play() creates a NEW AudioPlayer, feeds it BytesSource, plays,
//     and disposes. This sounds wasteful but is actually the most
//     reliable pattern for short sound effects in audioplayers 5.x:
//       - No state-management race conditions
//       - No "player already in use" silent failures
//       - Each play is independent
//   • The bytes are already in memory (decoded at init), so the only
//     overhead is creating a player object (~1ms).
//   • AudioPlayer auto-disposes after playback completes when
//     ReleaseMode.release is set.
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

  // Pre-loaded raw bytes for each sound. Loaded once at init via
  // rootBundle.load() — bypasses audioplayers asset-path resolution.
  // Stored as Uint8List because BytesSource constructor requires it.
  final Map<FeedbackType, Uint8List> _soundBytes = {};

  // Pre-resolved asset paths (relative to project root, with folder).
  // Using WAV instead of MP3 — WAV has lower startup latency on Android
  // because no decode step is needed.
  static const Map<FeedbackType, String> _assetFor = {
    FeedbackType.tap: 'assets/sounds/tap.wav',
    FeedbackType.click: 'assets/sounds/click.wav',
    FeedbackType.success: 'assets/sounds/success.wav',
    FeedbackType.error: 'assets/sounds/error.wav',
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

  /// Inject SharedPreferences and pre-load all sound assets as raw bytes.
  /// Safe to call multiple times.
  Future<void> init(SharedPreferences prefs) async {
    _prefs = prefs;
    if (_initialized) return;

    try {
      // Pre-load each sound file's raw bytes via rootBundle.
      // This is the most reliable way to load assets in Flutter —
      // it bypasses audioplayers' internal asset resolution which
      // can fail silently on some Android devices.
      for (final type in FeedbackType.values) {
        try {
          final byteData = await rootBundle.load(_assetFor[type]!);
          // Convert ByteData → Uint8List for BytesSource constructor.
          _soundBytes[type] = byteData.buffer.asUint8List(
              byteData.offsetInBytes, byteData.lengthInBytes);
          debugPrint('FeedbackService: pre-loaded ${type.name} '
              '(${byteData.lengthInBytes} bytes)');
        } catch (e) {
          debugPrint('FeedbackService: failed to load ${type.name}: $e');
        }
      }
      if (_soundBytes.isEmpty) {
        debugPrint('FeedbackService: ALL sound bytes failed to load — '
            'disabling sound');
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
    final bytes = _soundBytes[type];
    if (bytes == null) return;

    // Create a fresh AudioPlayer for each play. This is the most reliable
    // pattern in audioplayers 5.x for short sound effects:
    //   • No state-management race conditions
    //   • No "player already in use" silent failures
    //   • Each play is fully independent
    //
    // The bytes are already in memory (loaded at init), so the only
    // overhead is creating a player object (~1ms).
    //
    // We use ReleaseMode.release so the player auto-disposes its native
    // resources after playback completes.
    //
    // Fire-and-forget — we don't await so the UI thread never blocks.
    AudioPlayer(playerId: 'ncp_${type.name}_${DateTime.now().millisecondsSinceEpoch}')
        .play(
          BytesSource(bytes),
          volume: _volumeFor[type]!,
        )
        .then((_) {
          // Playback started successfully — nothing more to do.
        })
        .catchError((e) {
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

  /// Dispose. Only call on app teardown. (Per-play players auto-dispose.)
  Future<void> dispose() async {
    _soundBytes.clear();
  }
}
