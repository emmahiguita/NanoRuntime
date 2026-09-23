// parsed_media_message.dart
//
// QUÉ HACE:
// Analiza y clasifica mensajes entrantes y salientes detectando fotos, videos, audios,
// notas de voz de WhatsApp, enlaces enriquecidos y documentos.
//
// CÓMO FUNCIONA:
// - Normaliza texto y evalúa expresiones regulares para formatos multimedia.
// - Reconoce notificaciones típicas de WhatsApp en español ("📷 Envió una foto.", "🎥 Envió un video.").
// - Extrae etiquetas estructuradas como [Imagen: ...], [Video: ...], [Audio: ...], [VerUnaVez: ...].
//
// POR QUÉ:
// Separa la lógica de parsing del renderizado visual (SRP - SOLID) y garantiza
// que ningún archivo exceda el límite estricto de 200 líneas de código.

library;

/// Modelo inmutable con la clasificación de contenido multimedia de un mensaje.
class ParsedMediaMessage {
  final String cleanText;
  final List<String> images;
  final List<String> videos;
  final List<String> youTubeIds;
  final List<String> pdfs;
  final List<String> links;
  final List<String> audios;
  final List<String> otherFiles;
  final bool isPhotoNotification;
  final bool isVideoNotification;
  final bool isAudioNotification;
  final bool isViewOnce;
  final String? viewOncePath;
  final bool isViewOnceVideo;

  const ParsedMediaMessage({
    required this.cleanText,
    this.images = const [],
    this.videos = const [],
    this.youTubeIds = const [],
    this.pdfs = const [],
    this.links = const [],
    this.audios = const [],
    this.otherFiles = const [],
    this.isPhotoNotification = false,
    this.isVideoNotification = false,
    this.isAudioNotification = false,
    this.isViewOnce = false,
    this.viewOncePath,
    this.isViewOnceVideo = false,
  });

  /// Indica si el mensaje contiene un recurso renderizable o una notificación
  /// multimedia, incluso cuando WhatsApp no entrega todavía una ruta local.
  bool get hasMedia =>
      images.isNotEmpty ||
      videos.isNotEmpty ||
      pdfs.isNotEmpty ||
      links.isNotEmpty ||
      audios.isNotEmpty ||
      otherFiles.isNotEmpty ||
      isPhotoNotification ||
      isVideoNotification ||
      isAudioNotification ||
      isViewOnce;

  static final _urlRegex = RegExp(
    r'(https?:\/\/[^\s]+|www\.[^\s]+)',
    caseSensitive: false,
  );
  static final _ytRegex = RegExp(
    r'(?:youtube\.com\/(?:[^\/]+\/.+\/|(?:v|e(?:mbed)?)\/|.*[?&]v=)|youtu\.be\/)([^"&?\/\s]{11})',
    caseSensitive: false,
  );
  static const imageExts = {'.jpg', '.jpeg', '.png', '.webp', '.gif', '.bmp'};
  static const videoExts = {'.mp4', '.mov', '.mkv', '.webm', '.avi', '.3gp'};
  static const pdfExts = {'.pdf'};
  static const audioExts = {'.opus', '.m4a', '.mp3', '.ogg', '.wav', '.aac'};
  static const docExts = {
    '.doc',
    '.docx',
    '.xls',
    '.xlsx',
    '.ppt',
    '.pptx',
    '.zip',
    '.rar',
    '.txt',
  };

  static bool isImageUrl(String u) =>
      imageExts.any((e) => u.split('?').first.toLowerCase().endsWith(e)) ||
      u.contains('images.unsplash.com') ||
      u.contains('i.imgur.com');
  static bool isVideoUrl(String u) =>
      videoExts.any((e) => u.split('?').first.toLowerCase().endsWith(e));
  static bool isPdfUrl(String u) =>
      pdfExts.any((e) => u.split('?').first.toLowerCase().endsWith(e));

  static bool _has(String text, List<String> matches) =>
      matches.any((m) => text.contains(m));

  /// Analiza texto crudo y clasifica medios y texto limpio.
  factory ParsedMediaMessage.parse(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return const ParsedMediaMessage(cleanText: '');

    final low = text.toLowerCase();
    final isPhoto =
        _has(low, [
          'envió una foto',
          'envio una foto',
          'envió una imagen',
          'envio una imagen',
          '📷 foto',
          '📷 imagen',
          '📷 photo',
        ]) ||
        low == 'foto' ||
        low == 'imagen' ||
        low == '1 foto';
    final isVideo =
        _has(low, ['envió un video', 'envio un video', '🎥 video']) ||
        low == 'video' ||
        low == '1 video';
    final isAudio =
        _has(low, [
          'mensaje de voz',
          'nota de voz',
          'envió un audio',
          'envio un audio',
          '🎤 audio',
          '🎤 nota de voz',
        ]) ||
        low == 'audio';
    final isViewOnce = _has(low, [
      'ver una sola vez',
      'view once',
      'una sola vez',
      '📷 1 foto',
      '🎥 1 video',
    ]);

    String? viewOncePath;
    bool isViewOnceVideo = low.contains('video');
    final images = <String>[],
        videos = <String>[],
        ytIds = <String>[],
        pdfs = <String>[],
        links = <String>[],
        audios = <String>[],
        docs = <String>[],
        cleanLines = <String>[];

    for (final line in text.split('\n')) {
      final t = line.trim();
      if (t.isEmpty) continue;
      final tl = t.toLowerCase();

      if (_has(tl, [
        'envió una foto',
        'envio una foto',
        'envió un video',
        'envio un video',
        '📷 foto',
        '🎥 video',
        '🎤 nota de voz',
        'ver una sola vez',
      ])) {
        continue;
      }

      if (t.startsWith('[VerUnaVez:') && t.endsWith(']')) {
        viewOncePath = t.substring(11, t.length - 1).trim();
        if (videoExts.any((e) => viewOncePath!.toLowerCase().endsWith(e))) {
          isViewOnceVideo = true;
        }
        continue;
      }
      if (t == '[VerUnaVez]') continue;
      if (t.startsWith('[Imagen:') && t.endsWith(']')) {
        images.add(t.substring(8, t.length - 1).trim());
        continue;
      }
      if (t.startsWith('[Foto:') && t.endsWith(']')) {
        images.add(t.substring(6, t.length - 1).trim());
        continue;
      }
      if (t.startsWith('[PDF:') && t.endsWith(']')) {
        pdfs.add(t.substring(5, t.length - 1).trim());
        continue;
      }
      if (t.startsWith('[Video:') && t.endsWith(']')) {
        videos.add(t.substring(7, t.length - 1).trim());
        continue;
      }
      if (t.startsWith('[Audio:') && t.endsWith(']')) {
        audios.add(t.substring(7, t.length - 1).trim());
        continue;
      }

      final isLocal =
          (t.startsWith('/') ||
              t.startsWith('file://') ||
              t.contains(r':\') ||
              t.contains('/storage/') ||
              t.contains('/data/')) &&
          !t.contains(' ');
      if (isLocal) {
        final p = t.toLowerCase();
        if (imageExts.any((e) => p.endsWith(e))) {
          images.add(t);
          continue;
        }
        if (videoExts.any((e) => p.endsWith(e))) {
          videos.add(t);
          continue;
        }
        if (pdfExts.any((e) => p.endsWith(e))) {
          pdfs.add(t);
          continue;
        }
        if (audioExts.any((e) => p.endsWith(e))) {
          audios.add(t);
          continue;
        }
        if (docExts.any((e) => p.endsWith(e))) {
          docs.add(t);
          continue;
        }
      }

      final urlMatches = _urlRegex.allMatches(t);
      if (urlMatches.isNotEmpty) {
        for (final m in urlMatches) {
          final url = m.group(0)!;
          final yt = _ytRegex.firstMatch(url);
          if (yt != null) {
            final id = yt.group(1)!;
            if (!ytIds.contains(id)) ytIds.add(id);
            if (!videos.contains(url)) videos.add(url);
          } else if (isImageUrl(url)) {
            if (!images.contains(url)) images.add(url);
          } else if (isPdfUrl(url)) {
            if (!pdfs.contains(url)) pdfs.add(url);
          } else if (isVideoUrl(url)) {
            if (!videos.contains(url)) videos.add(url);
          } else if (audioExts.any(
            (e) => url.split('?').first.toLowerCase().endsWith(e),
          )) {
            if (!audios.contains(url)) audios.add(url);
          } else {
            if (!links.contains(url)) links.add(url);
          }
        }
      }
      cleanLines.add(line);
    }

    return ParsedMediaMessage(
      cleanText: cleanLines.join('\n').trim(),
      images: images,
      videos: videos,
      youTubeIds: ytIds,
      pdfs: pdfs,
      links: links,
      audios: audios,
      otherFiles: docs,
      isPhotoNotification: isPhoto && images.isEmpty,
      isVideoNotification: isVideo && videos.isEmpty,
      isAudioNotification: isAudio && audios.isEmpty,
      isViewOnce: isViewOnce,
      viewOncePath: viewOncePath,
      isViewOnceVideo: isViewOnceVideo,
    );
  }
}
