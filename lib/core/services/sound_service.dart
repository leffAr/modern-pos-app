import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class SoundService {
  static AudioPlayer? _player;
  static bool _isInitialized = false;

  /// Inisialisasi awal audio player agar siap dipanggil tanpa delay
  static Future<void> init() async {
    if (_isInitialized) return;
    try {
      _player = AudioPlayer();
      await _player!.setPlayerMode(PlayerMode.lowLatency);
      await _player!.setReleaseMode(ReleaseMode.stop);
      await _player!.setVolume(1.0);
      _isInitialized = true;
    } catch (e) {
      debugPrint('SoundService init error: $e');
    }
  }

  /// Memutar suara beep scan QR/Barcode + haptic tactile feedback
  static Future<void> playBeep() async {
    // 1. Berikan haptic feedback & system click untuk respon instan di device fisik
    try {
      HapticFeedback.mediumImpact();
    } catch (_) {}

    try {
      SystemSound.play(SystemSoundType.click);
    } catch (_) {}

    // 2. Putar audio beep.wav
    try {
      if (_player == null || !_isInitialized) {
        await init();
      }

      if (_player != null) {
        try {
          await _player!.stop();
        } catch (_) {}
        await _player!.play(
          AssetSource('audio/beep.wav'),
          mode: PlayerMode.lowLatency,
        );
      } else {
        final fallback = AudioPlayer();
        await fallback.play(AssetSource('audio/beep.wav'));
      }
    } catch (e) {
      debugPrint('SoundService playBeep failed: $e, trying fallback...');
      try {
        final fallback = AudioPlayer();
        await fallback.play(AssetSource('audio/beep.wav'));
      } catch (err) {
        debugPrint('SoundService playBeep fallback error: $err');
      }
    }
  }

  /// Bersihkan resource audio player jika diperlukan
  static void dispose() {
    try {
      _player?.dispose();
      _player = null;
      _isInitialized = false;
    } catch (_) {}
  }
}
