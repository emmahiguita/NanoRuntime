import 'package:audioplayers/audioplayers.dart';

/// Sonido armónico del búho (TER-22).
///
/// Dos golpes sintetizados: glissando ascendente consonante al soltar
/// ([playGlide]) y nota descendente suave al posarse ([playLand]).
///
/// Fallback silencioso OBLIGATORIO: si el plugin no registra o el asset
/// falla, se marca `_failed` y la app sigue muda pero jamás rompe la UI.
/// Inicialización lazy — no se toca el plugin hasta el primer uso.
class OwlSound {
  OwlSound._();

  static AudioPlayer? _player;
  static bool _failed = false;

  static AudioPlayer? get _instance {
    if (_player != null) return _player;
    if (_failed) return null;
    try {
      final player = AudioPlayer();
      player.setPlayerMode(PlayerMode.lowLatency);
      player.setReleaseMode(ReleaseMode.stop);
      player.setVolume(0.22);
      _player = player;
    } catch (_) {
      // Registro del plugin fallido: sin sonido, UI intacta.
      _failed = true;
    }
    return _player;
  }

  /// Glissando ascendente al soltar el búho (inicio del vuelo).
  static Future<void> playGlide() => _play('sounds/owl_glide.wav');

  /// Nota descendente breve al posarse en la esquina.
  static Future<void> playLand() => _play('sounds/owl_land.wav');

  static Future<void> _play(String asset) async {
    final player = _instance;
    if (player == null) return;
    try {
      await player.play(AssetSource(asset));
    } catch (_) {
      _failed = true;
    }
  }

  /// Libera el player (tests / cierre de app).
  static Future<void> dispose() async {
    await _player?.dispose();
    _player = null;
  }
}
