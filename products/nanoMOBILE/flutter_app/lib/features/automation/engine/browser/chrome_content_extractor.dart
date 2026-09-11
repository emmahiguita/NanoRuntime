/// ChromeContentExtractor — Extractor limpio de contenido web para Google Chrome (SRP).
///
/// Discrimina entre los controles propios del navegador (omnibox, botones de pestañas,
/// menú, barra de herramientas) y el texto real del artículo o página web renderizada
/// dentro de la vista web accesible.
library;

import '../perception/nano_snapshot.dart';

class ChromeWebContent {
  final String title;
  final String? url;
  final List<String> paragraphs;
  final String rawText;

  const ChromeWebContent({
    required this.title,
    this.url,
    required this.paragraphs,
    required this.rawText,
  });

  bool get isEmpty => paragraphs.isEmpty && rawText.isEmpty;
  bool get isNotEmpty => !isEmpty;
}

class ChromeContentExtractor {
  const ChromeContentExtractor();

  static const String chromePackage = 'com.android.chrome';

  /// Identificadores de controles UI del navegador que NO forman parte del contenido web.
  static const Set<String> _ignoredChromeUiIds = {
    'url_bar',
    'search_box_text',
    'location_bar',
    'tab_switcher_button',
    'menu_button',
    'home_button',
    'toolbar',
    'control_container',
    'action_bar',
    'compositor_view_holder',
    'delete_button',
    'open_in_new_tab',
  };

  /// Extrae el contenido web limpio desde el [snapshot] activo de accesibilidad.
  ChromeWebContent extract(NanoSnapshot snapshot) {
    if (snapshot.isEmpty) {
      return const ChromeWebContent(title: '', paragraphs: [], rawText: '');
    }

    String? detectedUrl;
    String detectedTitle = '';
    final contentTexts = <String>[];

    for (final node in snapshot.nodes) {
      // 1. Extraer URL de la barra de direcciones si está visible
      if (node.id.contains('url_bar') && node.text.isNotEmpty) {
        detectedUrl = node.text;
        continue;
      }

      // 2. Ignorar controles del navegador Chrome
      if (_isChromeSystemOrToolbar(node)) {
        continue;
      }

      // 3. Obtener texto del nodo
      final text = _getNodeText(node);
      if (text.isEmpty) continue;

      // Descartar textos extremadamente cortos o símbolos aislados de navegación
      if (_isIrrelevantWebUi(text)) continue;

      // Primer encabezado significativo como título si no hay título aún
      if (detectedTitle.isEmpty && _isLikelyTitle(node, text)) {
        detectedTitle = text;
      }

      if (!contentTexts.contains(text)) {
        contentTexts.add(text);
      }
    }

    final rawText = contentTexts.join('\n\n');

    return ChromeWebContent(
      title: detectedTitle,
      url: detectedUrl,
      paragraphs: contentTexts,
      rawText: rawText,
    );
  }

  bool _isChromeSystemOrToolbar(NanoNode node) {
    final idLower = node.id.toLowerCase();
    for (final ignored in _ignoredChromeUiIds) {
      if (idLower.contains(ignored)) return true;
    }

    // Botones con descripciones de Chrome
    final descLower = node.description.toLowerCase();
    if (descLower == 'más opciones' ||
        descLower == 'more options' ||
        descLower == 'cambiar o cerrar pestañas' ||
        descLower == 'switch or close tabs' ||
        descLower == 'página principal' ||
        descLower == 'home') {
      return true;
    }

    return false;
  }

  String _getNodeText(NanoNode node) {
    final t = node.text.trim();
    if (t.isNotEmpty) return t;
    final l = node.label.trim();
    if (l.isNotEmpty) return l;
    return node.description.trim();
  }

  bool _isIrrelevantWebUi(String text) {
    if (text.length <= 1) return true;
    final lower = text.toLowerCase();
    return lower == 'buscar' ||
        lower == 'search' ||
        lower == 'menu' ||
        lower == 'menú' ||
        lower == 'share' ||
        lower == 'compartir';
  }

  bool _isLikelyTitle(NanoNode node, String text) {
    // Títulos suelen tener entre 10 y 120 caracteres y estar ubicados en la parte superior
    return text.length >= 10 && text.length <= 120 && node.bounds.top < 600;
  }
}
