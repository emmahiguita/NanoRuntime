/// CONVERSATION-GROUP-RESOLVER — Resolución fidedigna de grupos de WhatsApp.
///
/// **QUÉ HACE:**
/// Identifica con precisión si una conversación proviene de un grupo (ej: "THE BOYS"),
/// extrae el nombre real del grupo de los metadatos de WhatsApp (evitando marcadores
/// genéricos o nombres de remitentes individuales/menciones), y mantiene una caché reactiva.
///
/// **CÓMO FUNCIONA:**
/// 1. Analiza flags nativos (isGroup, @g.us, patrones "Sender @ Group").
/// 2. Normaliza nombres limpiando prefijos técnicos y sufijos de conteo como "(2 mensajes)".
/// 3. Asocia la identidad/JID del chat al nombre real resuelto.
///
/// **POR QUÉ:**
/// Satisface Single Responsibility (SOLID), previene duplicidad y mantiene
/// un estricto límite modular de código menor a 200 líneas.
library;

abstract final class ConversationGroupResolver {
  /// Caché en memoria de JID / convId -> Nombre real del grupo
  static final Map<String, String> _groupTitleCache = {};

  /// Registra en caché el nombre real de un grupo para persistencia en sesión
  static void cacheGroupTitle(String key, String title) {
    final clean = cleanTitle(title);
    if (clean.isEmpty || isGenericTitle(clean)) return;

    final k = _normalizeKey(key);
    if (k.isNotEmpty) {
      _groupTitleCache[k] = clean;
    }

    final digits = RegExp(r'\d{8,25}').firstMatch(key)?.group(0);
    if (digits != null) {
      _groupTitleCache[digits] = clean;
    }
  }

  /// Recupera el nombre real del grupo desde la caché
  static String? getCachedGroupTitle(String key) {
    final k = _normalizeKey(key);
    if (_groupTitleCache.containsKey(k)) return _groupTitleCache[k];

    final digits = RegExp(r'\d{8,25}').firstMatch(key)?.group(0);
    if (digits != null && _groupTitleCache.containsKey(digits)) {
      return _groupTitleCache[digits];
    }
    return null;
  }

  /// Normaliza una clave de conversación para indexación en caché
  static String _normalizeKey(String raw) {
    return raw
        .replaceAll('live:', '')
        .replaceAll('shortcut:', '')
        .replaceAll('conv:', '')
        .replaceAll('group:', '')
        .replaceAll('title:', '')
        .trim();
  }

  /// Determina si una conversación corresponde a un grupo
  static bool isGroup({
    required String convId,
    String? packageName,
    bool isGroupFlag = false,
    String? rawTitle,
    String? conversationTitle,
    String? shortcutId,
  }) {
    if (isGroupFlag) return true;
    final id = convId.toLowerCase();
    if (id.contains('@g.us') || id.contains('group:')) return true;
    if (shortcutId != null && shortcutId.toLowerCase().contains('@g.us')) return true;
    if (rawTitle != null && rawTitle.contains(' @ ')) return true;
    if (conversationTitle != null && conversationTitle.trim().isNotEmpty) return true;
    if (getCachedGroupTitle(convId) != null) return true;
    return false;
  }

  /// Limpia sufijos de cantidad de mensajes y marcadores técnicos
  static String cleanTitle(String raw) {
    var s = raw.trim();
    for (final p in const ['title:', 'group:', 'conv:', 'live:', 'shortcut:', 'person:', 'jid:']) {
      if (s.toLowerCase().startsWith(p)) {
        s = s.substring(p.length).trim();
      }
    }
    // Si viene en formato compuesto "Title|Sender", el título real del grupo SIEMPRE es el primero
    if (s.contains('|')) {
      final parts = s.split('|').map((p) => p.trim()).where((p) => p.isNotEmpty).toList();
      if (parts.isNotEmpty) {
        s = parts.first;
      }
    }
    // Quita "(2 mensajes)", "(3 nuevos)", etc.
    s = s.replaceAll(RegExp(r'\s*\(\d+[^)]*\)'), '');
    s = s.replaceAll(RegExp(r'@g\.us.*'), '');
    s = s.replaceAll(RegExp(r'@s\.whatsapp\.net.*'), '');
    return s.trim();
  }

  /// Verifica si el título es un marcador genérico de fallback o una mención de chat
  static bool isGenericTitle(String? title) {
    if (title == null) return true;
    final lower = title.trim().toLowerCase();
    if (lower.isEmpty ||
        lower.startsWith('@') || // Menciones en mensajes (ej: @Infinity)
        lower == 'grupo de whatsapp' ||
        lower.startsWith('grupo de whatsapp') ||
        lower == 'grupo' ||
        lower == 'chat de whatsapp' ||
        lower.startsWith('contacto whatsapp') ||
        lower == 'whatsapp' ||
        lower == 'chat' ||
        RegExp(r'^\d+$').hasMatch(lower) ||
        lower.contains('@g.us')) {
      return true;
    }
    return false;
  }

  /// Resuelve la tupla (groupTitle, lastSender) a partir de los metadatos disponibles
  static ({String groupTitle, String lastSender}) resolveGroupInfo({
    required String convId,
    String? conversationTitle,
    String? title,
    String? sender,
  }) {
    var resolvedGroup = '';
    var resolvedSender = sender?.trim() ?? '';

    // 1. Prioridad: conversationTitle explícito de Android (ej: "THE BOYS")
    if (conversationTitle != null && conversationTitle.trim().isNotEmpty) {
      final clean = cleanTitle(conversationTitle);
      if (!isGenericTitle(clean)) {
        resolvedGroup = clean;
      }
    }

    // 2. Formato común de WhatsApp: "Sender @ GroupName"
    if (resolvedGroup.isEmpty && title != null && title.contains(' @ ')) {
      final parts = title.split(' @ ');
      if (parts.length >= 2) {
        if (resolvedSender.isEmpty) resolvedSender = parts[0].trim();
        final candidate = cleanTitle(parts.sublist(1).join(' @ '));
        if (!isGenericTitle(candidate)) resolvedGroup = candidate;
      }
    }

    // 3. Si title no coincide con el remitente ni es genérico (ej: "THE BOYS")
    if (resolvedGroup.isEmpty && title != null && title.trim().isNotEmpty) {
      final cleanedTitle = cleanTitle(title);
      if (cleanedTitle != resolvedSender && !isGenericTitle(cleanedTitle)) {
        resolvedGroup = cleanedTitle;
      }
    }

    // 4. Si convId contiene un nombre de grupo (ej: group:THE BOYS)
    if (resolvedGroup.isEmpty && (convId.contains('title:') || convId.contains('group:'))) {
      final cleanFromKey = cleanTitle(convId);
      if (cleanFromKey != resolvedSender && !isGenericTitle(cleanFromKey)) {
        resolvedGroup = cleanFromKey;
      }
    }

    // 5. Si aún no se resolvió, buscar en la caché histórica
    if (resolvedGroup.isEmpty || isGenericTitle(resolvedGroup)) {
      final cached = getCachedGroupTitle(convId);
      if (cached != null && !isGenericTitle(cached)) {
        resolvedGroup = cached;
      }
    }

    // 6. Fallback honesto si no hay ninguna evidencia de nombre
    if (resolvedGroup.isEmpty || isGenericTitle(resolvedGroup)) {
      resolvedGroup = 'Grupo de WhatsApp';
    } else {
      cacheGroupTitle(convId, resolvedGroup);
    }

    return (groupTitle: resolvedGroup, lastSender: resolvedSender);
  }
}
