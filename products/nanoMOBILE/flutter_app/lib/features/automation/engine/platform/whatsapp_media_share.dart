/// WA-MEDIA-01 — fachada Dart del canal `com.nanoai/share` para envío de
/// archivos por WhatsApp (Camino A: ACTION_SEND dirigido, 1 tap del usuario).
///
/// Dos operaciones:
/// - [copyToCatalog]: el archivo elegido con file_picker se copia a la
///   carpeta FIJA del catálogo (files/nano/catalog/, nombre fijo = basename).
///   La regla persiste la ruta DEVUELTA (estable), nunca el path temporal
///   del picker.
/// - [shareFile]: abre WhatsApp con el archivo + contacto + caption. Éxito =
///   la actividad se LANZÓ; el envío final lo confirma el usuario en
///   WhatsApp (honesto, jamás se marca "enviado").
library;

import 'package:flutter/services.dart';

class WhatsAppMediaShare {
  const WhatsAppMediaShare();

  static const _channel = MethodChannel('com.nanoai/share');

  /// Copia [sourcePath] a una carpeta organizada del catálogo y devuelve la ruta estable.
  /// null = el canal no respondió o la copia falló.
  Future<String?> copyToCatalog(
    String sourcePath, {
    String category = NanoMediaCategory.documents,
  }) async {
    try {
      return await _channel.invokeMethod<String>('copyToCatalog', {
        'sourcePath': sourcePath,
        'category': category,
      });
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  /// Archivos guardados dentro del catálogo privado de Nano.
  Future<List<NanoCatalogFile>> listCatalog() async {
    try {
      final raw = await _channel.invokeListMethod<Map<Object?, Object?>>(
        'listCatalog',
      );
      return (raw ?? const <Map<Object?, Object?>>[])
          .map(NanoCatalogFile.fromMap)
          .toList(growable: false);
    } on PlatformException {
      return const [];
    } on MissingPluginException {
      return const [];
    }
  }

  /// Abre WhatsApp con el archivo [path], contacto [contact], caption y opcionalmente [packageName].
  /// false = no se lanzó (sin archivo, sin contacto, WhatsApp ausente).
  Future<bool> shareFile({
    required String path,
    required String contact,
    String caption = '',
    String? packageName,
    bool autoSend = false,
  }) async {
    try {
      final ok = await _channel.invokeMethod<bool>('shareFile', {
        'path': path,
        'contact': contact,
        'caption': caption,
        // Abrir el flujo nunca implica autorización para pulsar Enviar.
        'autoSend': autoSend,
        if (packageName != null) 'packageName': packageName,
      });
      return ok == true;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  /// Abre directamente el chat de WhatsApp con [contact], con el texto opcional [text].
  /// Si [autoSend] es `true`, Android solo arma el intento de accesibilidad.
  /// El retorno del canal confirma apertura, no clic, entrega ni lectura.
  /// Utiliza com.whatsapp o com.whatsapp.w4b.
  Future<bool> openChat({
    required String contact,
    String text = '',
    String? packageName,
    bool autoSend = false,
  }) async {
    try {
      final ok = await _channel.invokeMethod<bool>('openChat', {
        'contact': contact,
        'text': text,
        'autoSend': autoSend,
        if (packageName != null) 'packageName': packageName,
      });
      return ok == true;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  /// Verifica si el servicio de accesibilidad de Nano está habilitado en Android.
  Future<bool> isAccessibilityEnabled() async {
    try {
      final ok = await _channel.invokeMethod<bool>('isAccessibilityEnabled');
      return ok == true;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  /// Abre la pantalla de ajustes de accesibilidad de Android para que el usuario
  /// pueda activar Nano con 1 toque.
  Future<bool> openAccessibilitySettings() async {
    try {
      final ok = await _channel.invokeMethod<bool>('openAccessibilitySettings');
      return ok == true;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }
}

class NanoMediaCategory {
  static const products = 'productos_servicios';
  static const reports = 'informes';
  static const photos = 'fotos';
  static const videos = 'videos';
  static const documents = 'documentos';

  static const all = <NanoMediaCategoryInfo>[
    NanoMediaCategoryInfo(
      products,
      'Productos y servicios',
      'PDF de precios, catálogo y ofertas',
      '▤',
    ),
    NanoMediaCategoryInfo(
      reports,
      'Informes',
      'Reportes y documentos generados',
      '▥',
    ),
    NanoMediaCategoryInfo(
      photos,
      'Fotos',
      'Imágenes listas para compartir',
      '▧',
    ),
    NanoMediaCategoryInfo(videos, 'Videos', 'Clips y videos', '▶'),
    NanoMediaCategoryInfo(documents, 'Documentos', 'PDF y otros archivos', '▤'),
  ];

  static String forFileName(String name) {
    final extension = name.split('.').last.toLowerCase();
    if (const {
      'jpg',
      'jpeg',
      'png',
      'webp',
      'gif',
      'heic',
    }.contains(extension)) {
      return photos;
    }
    if (const {'mp4', 'mov', 'm4v', '3gp', 'mkv'}.contains(extension)) {
      return videos;
    }
    return documents;
  }
}

class NanoMediaCategoryInfo {
  final String id;
  final String title;
  final String subtitle;
  final String icon;

  const NanoMediaCategoryInfo(this.id, this.title, this.subtitle, this.icon);
}

class NanoCatalogFile {
  final String name;
  final String path;
  final String category;
  final int sizeBytes;
  final int modifiedAtMs;

  const NanoCatalogFile({
    required this.name,
    required this.path,
    required this.category,
    required this.sizeBytes,
    required this.modifiedAtMs,
  });

  factory NanoCatalogFile.fromMap(Map<Object?, Object?> map) => NanoCatalogFile(
    name: map['name']?.toString() ?? '',
    path: map['path']?.toString() ?? '',
    category: map['category']?.toString() ?? NanoMediaCategory.documents,
    sizeBytes: (map['sizeBytes'] as num?)?.toInt() ?? 0,
    modifiedAtMs: (map['modifiedAtMs'] as num?)?.toInt() ?? 0,
  );
}
