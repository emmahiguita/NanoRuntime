/// AppAliasCatalog — mapa estático packageName → aliases coloquiales/fonéticos.
///
/// SRP: SOLO conoce aliases. No resuelve, no lanza, no toca inventario.
///
/// Reglas de inclusión:
///   - El alias debe ser un término REAL que un usuario hispanohablante use.
///   - El alias se normaliza (lowercase, sin acento) en [AppAliasCatalog.aliasesFor].
///   - NO se incluyen aliases trivialmente idénticos al label de la app (ya
///     los cubre exactLabel en [matchApps]).
///   - Un package puede tener múltiples aliases; un alias NO puede apuntar a
///     dos packages distintos (ambigüedad estática → compile-time warning aquí).
///
/// Para agregar una app nueva: busca su packageName en el dispositivo con
///   adb shell cmd package list packages | grep <nombre>
/// y añade los aliases que los usuarios realmente usarían.
library;

/// Catálogo estático de aliases. Inmutable en runtime.
class AppAliasCatalog {
  const AppAliasCatalog._();

  // ---------------------------------------------------------------------------
  // Tabla maestra: packageName → lista de aliases (sin normalizar aquí;
  // la normalización la hace [aliasesFor] al devolver).
  // ---------------------------------------------------------------------------
  static const Map<String, List<String>> _table = {
    // ── Mensajería ────────────────────────────────────────────────────────────
    'com.whatsapp': [
      'wasa', 'wha', 'wapp', 'wasap', 'guasap', 'guasap', 'wats app',
      'what sapp', 'watss', 'whats',
    ],
    'com.whatsapp.w4b': [
      'wasa business', 'wasap business', 'whatsapp negocios',
      'wasa negocios', 'wa business',
    ],
    'org.telegram.messenger': [
      'tele', 'telegrama', 'telegrm', 'tlegram', 'telgram',
    ],
    'org.telegram.plus': [
      'plus messenger', 'telegram plus', 'tgplus',
    ],
    'com.instagram.android': [
      'insta', 'ig', 'instagran', 'instragram', 'instagram app',
    ],
    'com.facebook.orca': [
      'mesen', 'messanger', 'messeger', 'mensajero', 'fb messenger',
      'facebook chat', 'messenger de facebook',
    ],
    'com.facebook.katana': [
      'fb', 'face', 'feis', 'feisbuk', 'feisbu', 'facebook app',
    ],
    'com.twitter.android': [
      'x app', 'twitter app', 'twiter', 'twiteer', 'pajaro azul',
    ],
    'com.twitterlite.android': [
      'twitter lite', 'x lite',
    ],
    'com.snapchat.android': [
      'snap', 'snapch', 'snpchat', 'snapchat app',
    ],
    'com.discord': [
      'discor', 'discort', 'gaming chat', 'discord app',
    ],
    'com.viber.voip': [
      'viver', 'viber app',
    ],
    'com.skype.raider': [
      'skype app', 'videollamada skype',
    ],
    'com.microsoft.teams': [
      'teams', 'microsoft teams', 'team', 'equipos microsoft',
    ],
    'com.microsoft.teams.free': [
      'teams gratis', 'teams free',
    ],
    'com.slack': [
      'slack app',
    ],
    'com.signaladvanced': [
      'signal app', 'sygnal',
    ],
    'org.thoughtcrime.securesms': [
      'signal', 'mensajes privados signal', 'sygnal',
    ],
    'com.beeper.android': [
      'biper', 'beeper app',
    ],

    // ── IA / Chatbots ─────────────────────────────────────────────────────────
    'com.openai.chatgpt': [
      'chat gpt', 'chatgpt', 'gpt', 'open ai', 'openai', 'chat de openai',
      'ia de openai', 'gpt app', 'chapt gpt', 'chatgp', 'chatgpts',
    ],
    'com.anthropic.claude': [
      'clod', 'claud', 'claude app', 'ia claude', 'anthropic',
    ],
    'com.google.android.apps.bard': [
      'bard', 'google bard',
    ],
    'com.google.android.apps.gemini': [
      'gemini', 'gemini app', 'ia de google', 'google ia', 'geminy',
    ],
    'com.deepseek.chat': [
      'deep seek', 'deepseek', 'deepsek', 'deep sek', 'seekdeep', 'dseek',
      'ia china', 'chat chino',
    ],
    'com.microsoft.copilot': [
      'copilot', 'co pilot', 'microsoft ia', 'copiloto', 'ia microsoft',
      'bing ia', 'bing chat',
    ],
    'io.perplexity.app': [
      'perplexi', 'perplexiti', 'perplexity app', 'buscador ia',
    ],
    'com.mistral.leChat': [
      'mistral', 'le chat', 'chat mistral',
    ],
    'com.llama.android': [
      'llama', 'meta ia', 'meta ai',
    ],

    // ── Música ────────────────────────────────────────────────────────────────
    'com.spotify.music': [
      'espotify', 'spotfy', 'spotifi', 'spotify app', 'musica spotify',
    ],
    'com.google.android.music': [
      'google play music', 'play music',
    ],
    'com.google.android.apps.youtube.music': [
      'yt music', 'youtube music', 'you tube music', 'musica de youtube',
    ],
    'com.amazon.mp3': [
      'amazon music', 'amazon musica',
    ],
    'com.deezer.android': [
      'deezer app',
    ],
    'com.soundcloud.android': [
      'sound cloud', 'soundclud',
    ],
    'com.tidal.android': [
      'tidal app',
    ],

    // ── Video / Streaming ─────────────────────────────────────────────────────
    'com.google.android.youtube': [
      'you tube', 'yt', 'yutub', 'youtu', 'youtube app', 'ver videos',
    ],
    'com.netflix.mediaclient': [
      'netflis', 'nettflix', 'netflix app', 'nf', 'ver peliculas netflix',
    ],
    'com.amazon.avod.thirdpartyclient': [
      'amazon prime', 'prime video', 'amazon video', 'prime',
    ],
    'com.disney.disneyplus': [
      'disney plus', 'disney+', 'disneyplus app',
    ],
    'com.hbo.hbonow': [
      'hbo max', 'max app', 'hbo app',
    ],
    'com.hbomax.android': [
      'hbo max', 'max app', 'hbo',
    ],
    'com.max.android': [
      'max streaming', 'max app', 'hbo max',
    ],
    'com.apple.android.music': [
      'apple music', 'itunes',
    ],
    'tv.twitch.android.app': [
      'twich', 'twtch', 'twitch app', 'streaming juegos',
    ],
    'com.tiktok.android': [
      'tik tok', 'tiктоk', 'tiktk', 'tik tok app',
    ],

    // ── Navegadores ───────────────────────────────────────────────────────────
    'com.android.chrome': [
      'crome', 'chorme', 'google chrome', 'chrome app', 'navegador chrome',
    ],
    'org.mozilla.firefox': [
      'firefox', 'fire fox', 'mozilla', 'navegador firefox',
    ],
    'com.brave.browser': [
      'brave browser', 'navegador brave',
    ],
    'com.microsoft.emmx': [
      'edge', 'microsoft edge', 'navegador edge', 'navegador microsoft',
    ],
    'com.opera.browser': [
      'opera browser', 'navegador opera',
    ],
    'com.opera.mini.native': [
      'opera mini', 'mini browser',
    ],
    'com.sec.android.app.sbrowser': [
      'samsung browser', 'navegador samsung', 'samsung internet',
    ],
    'com.vivaldi.browser': [
      'vivaldi browser',
    ],

    // ── Google Apps ───────────────────────────────────────────────────────────
    'com.google.android.gm': [
      'gmail app', 'correo google', 'mail google', 'correo gmail',
    ],
    'com.google.android.apps.maps': [
      'maps', 'google map', 'mapas google', 'gmaps', 'google maps app',
    ],
    'com.google.android.apps.docs': [
      'docs', 'google docs', 'google documentos', 'documentos',
    ],
    'com.google.android.apps.sheets': [
      'sheets', 'google sheets', 'hojas de calculo google', 'google excel',
    ],
    'com.google.android.apps.slides': [
      'slides', 'google slides', 'google presentaciones', 'presentaciones google',
    ],
    'com.google.android.apps.photos': [
      'fotos google', 'google photos', 'google fotos',
    ],
    'com.google.android.apps.translate': [
      'traductor', 'google translate', 'translator', 'translate',
    ],
    'com.google.android.keep': [
      'keep', 'google keep', 'notas google', 'keep notes',
    ],
    'com.google.android.calendar': [
      'calendario google', 'google cal', 'google calendar app',
    ],
    'com.google.android.apps.classroom': [
      'google class', 'classroom', 'google classroom app',
    ],
    'com.google.android.apps.meet': [
      'google meet', 'meet app', 'videollamada google',
    ],
    'com.google.android.gms': [
      'servicios google', 'google services',
    ],
    'com.google.android.apps.drive': [
      'drive', 'google drive', 'google disk', 'gdrive',
    ],

    // ── Microsoft Office ──────────────────────────────────────────────────────
    'com.microsoft.office.word': [
      'word app', 'microsoft word', 'ms word', 'word android',
    ],
    'com.microsoft.office.excel': [
      'excel app', 'microsoft excel', 'ms excel', 'excel android',
    ],
    'com.microsoft.office.powerpoint': [
      'powerpoint app', 'power point', 'ms ppt', 'ppt app', 'presentaciones microsoft',
    ],
    'com.microsoft.office.outlook': [
      'outlook app', 'correo microsoft', 'microsoft mail', 'ms outlook',
    ],
    'com.microsoft.skydrive': [
      'one drive', 'onedrive app', 'microsoft drive',
    ],
    'com.microsoft.launcher': [
      'microsoft launcher', 'launcher microsoft',
    ],

    // ── Correo ────────────────────────────────────────────────────────────────
    'com.yahoo.mobile.client.android.mail': [
      'yahoo mail', 'correo yahoo', 'yahoo correo',
    ],
    'com.apple.android.icloud': [
      'icloud', 'apple icloud',
    ],
    'me.proton.android.mail': [
      'proton mail', 'protonmail', 'correo proton',
    ],

    // ── Finanzas / Pagos ──────────────────────────────────────────────────────
    'com.paypal.android.p2pmobile': [
      'paypal app', 'pagar paypal', 'pay pal',
    ],
    'com.venmo': [
      'venmo app',
    ],
    'com.cashapp': [
      'cash app', 'cashapp',
    ],
    'com.nequi.app': [
      'nequi app',
    ],
    'co.bancolombia.mobile': [
      'bancolombia', 'banco colombia', 'app bancolombia',
    ],
    'com.daviplata.dmc': [
      'davi plata', 'daviplata app',
    ],
    'co.rappipay': [
      'rappi pay', 'rappipay', 'pagar rappi',
    ],

    // ── Transporte / Mapas ────────────────────────────────────────────────────
    'com.ubercab': [
      'uber app', 'pedir uber', 'uber taxi',
    ],
    'com.lyft.android': [
      'lyft app',
    ],
    'com.indriver.android': [
      'in driver', 'indriver app', 'indrive',
    ],
    'com.cabify.android': [
      'cabify app',
    ],
    'co.rappi': [
      'rappi app', 'domicilios rappi',
    ],
    'com.ifood.android': [
      'i food', 'ifood app',
    ],
    'com.rappi': [
      'rappi domicilios',
    ],
    'com.waze': [
      'waze app', 'navegacion waze',
    ],
    'com.google.android.apps.maps.automobile': [
      'maps auto', 'google maps auto',
    ],

    // ── Redes sociales ────────────────────────────────────────────────────────
    'com.pinterest': [
      'pinerest', 'pinteres', 'pinterest app',
    ],
    'com.reddit.frontpage': [
      'reddit app', 'redit',
    ],
    'com.tumblr': [
      'tumblr app',
    ],
    'com.linkedin.android': [
      'linked in', 'linkedin app', 'red profesional',
    ],
    'com.vk.android': [
      'vk app', 'vkontakte',
    ],
    'com.zhiliaoapp.musically': [
      'tik tok', 'musical ly', 'tiktok app',
    ],

    // ── Productividad ─────────────────────────────────────────────────────────
    'com.todoist.android': [
      'todoist app', 'todo list todoist',
    ],
    'com.notion.android': [
      'notion app', 'notion ia',
    ],
    'com.evernote': [
      'evernote app', 'ever note',
    ],
    'md.obsidian': [
      'obsidian app', 'obsidian notas',
    ],
    'com.any.do.prod': [
      'any do', 'any.do', 'tareas any do',
    ],
    'com.microsoft.todos': [
      'ms todo', 'microsoft to do', 'to do microsoft', 'tareas microsoft',
    ],
    'com.trello': [
      'trello app',
    ],
    'com.asana.app': [
      'asana app',
    ],

    // ── Terminal / Dev ────────────────────────────────────────────────────────
    'com.termux': [
      'termux app', 'terminal linux', 'terminal android',
    ],
    'com.github.android': [
      'github app', 'git hub',
    ],
    'com.gitify.android': [
      'gitify', 'notificaciones github',
    ],
    'com.acode.editor': [
      'acode editor', 'editor codigo android',
    ],
    'com.rhmsoft.edit': [
      'quill editor',
    ],

    // ── Cámara / Fotos ────────────────────────────────────────────────────────
    'com.instagram.barcelona': [
      'threads app', 'threads instagram',
    ],
    'com.vsco.cam': [
      'vsco cam', 'vsco app',
    ],
    'com.lightricks.facetune2': [
      'face tune', 'facetune app',
    ],
    'com.adobe.psmobile': [
      'photoshop mobile', 'ps mobile', 'adobe ps',
    ],
    'com.adobe.lrmobile': [
      'lightroom mobile', 'lightroom app', 'lr mobile',
    ],
    'com.picsart.studio': [
      'pics art', 'picsart app',
    ],
    'com.canva.editor': [
      'canva app', 'diseño canva',
    ],

    // ── Salud / Fitness ───────────────────────────────────────────────────────
    'com.fitbit.FitbitMobile': [
      'fitbit app',
    ],
    'com.google.android.apps.fitness': [
      'google fit', 'fit app',
    ],
    'com.samsung.android.health': [
      'samsung health', 'salud samsung',
    ],
    'com.nike.plusgps': [
      'nike run', 'nike running',
    ],
    'com.strava': [
      'strava app',
    ],

    // ── Juegos / Entretenimiento ──────────────────────────────────────────────
    'com.roblox.client': [
      'roblox app', 'roblox juego',
    ],
    'com.mojang.minecraftpe': [
      'minecraft app', 'mine craft', 'minecraf',
    ],
    'com.supercell.clashofclans': [
      'clash of clans', 'coc', 'clash clans',
    ],
    'com.supercell.clashroyale': [
      'clash royale', 'cr app',
    ],
    'com.miHoYo.GenshinImpact': [
      'genshin', 'genshin impact app',
    ],
    'com.ea.gp.jw3': [
      'jurassic world', 'jw3',
    ],
    'com.king.candycrushsaga': [
      'candy crush', 'candycrush app',
    ],
    'com.epicgames.fortnite': [
      'fortnite app', 'fortnite movil',
    ],
  };

  // ---------------------------------------------------------------------------
  // API pública
  // ---------------------------------------------------------------------------

  /// Aliases normalizados (lowercase, trim, sin tilde) para [packageName].
  /// Devuelve lista vacía si el package no está en el catálogo.
  static List<String> aliasesFor(String packageName) {
    final raw = _table[packageName.toLowerCase()] ?? const [];
    return raw.map(_normalize).toList(growable: false);
  }

  /// Todos los packages registrados en el catálogo.
  static Iterable<String> get knownPackages => _table.keys;

  /// Dado un alias normalizado, devuelve el packageName si hay UNA coincidencia
  /// estática única. null = no encontrado o ambiguo (no debe usarse para
  /// resolver — la resolución la hace [matchApps]).
  static String? packageForAlias(String alias) {
    final q = _normalize(alias);
    String? found;
    for (final entry in _table.entries) {
      final aliases = entry.value.map(_normalize);
      if (aliases.contains(q)) {
        if (found != null) return null; // ambiguo
        found = entry.key;
      }
    }
    return found;
  }

  static String _normalize(String s) =>
      s.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
}
