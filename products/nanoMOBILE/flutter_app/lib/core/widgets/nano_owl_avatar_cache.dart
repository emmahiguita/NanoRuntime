part of 'nano_owl_avatar.dart';

/// Miniaturas compartidas por las poses: mantiene la memoria del avatar
/// proporcional a su tamaño visible, sin decodificar el lienzo original.
extension _NanoOwlAvatarCache on _NanoOwlAvatarState {
  void _precacheSprites() {
    if (!_precached) {
      _precached = true;
      final width = (widget.size * MediaQuery.devicePixelRatioOf(context))
          .ceil();
      for (final a in NanoOwlFrames.allPrecacheAssets) {
        // Precarga miniaturas, no todos los sprites a su resolución original.
        precacheImage(ResizeImage(AssetImage(a), width: width), context);
      }
    }
  }
}
