/// Catálogo determinista — flujos CONOCIDOS para objetivos comunes.
///
/// R0: el catálogo solo resuelve navegación claramente expresada. Mencionar
/// "Bluetooth" NO equivale a pedir abrirlo, y nunca equivale a activar/apagar
/// un switch.
library;

import 'package:nanoai/features/automation/engine/execution/agent_tool_dispatcher.dart'
    show ToolCall;
import 'package:nanoai/features/automation/engine/execution/goal_verifier.dart'
    show GoalExpectation;

class DeterministicFlow {
  final List<ToolCall> steps;
  final GoalExpectation? expectation;
  final bool outputProvesGoal;
  final List<String> requiredAny;
  final List<String> forbiddenAny;

  const DeterministicFlow({
    required this.steps,
    this.expectation,
    this.outputProvesGoal = false,
    this.requiredAny = const [],
    this.forbiddenAny = const [],
  });

  bool matches(String normalizedGoal, String keyword) {
    if (!normalizedGoal.contains(keyword)) return false;
    if (forbiddenAny.any(normalizedGoal.contains)) return false;
    if (requiredAny.isEmpty) return true;
    return requiredAny.any(normalizedGoal.contains);
  }
}

class DeterministicFlowCatalog {
  final Map<String, DeterministicFlow> _flows;
  const DeterministicFlowCatalog(this._flows);

  DeterministicFlow? forGoal(String goal) {
    final g = goal.trim().toLowerCase();
    for (final entry in _flows.entries) {
      if (entry.value.matches(g, entry.key)) return entry.value;
    }
    return null;
  }
}

const _openTerms = <String>[
  'abrir',
  'abre',
  'mostrar',
  'muestra',
  'ir a',
  've a',
  'entrar',
  'entra',
];

const _stateChangingTerms = <String>[
  'activar',
  'activa',
  'encender',
  'enciende',
  'habilitar',
  'habilita',
  'desactivar',
  'desactiva',
  'apagar',
  'apaga',
  'cambiar',
  'cambia',
  'toggle',
  'activado',
  'encendido',
  'estado',
];

const _notificationReadTerms = <String>[
  'leer',
  'lee',
  'listar',
  'lista',
  'mostrar',
  'muestra',
  'ver',
  'dime',
  'cuáles',
  'cuales',
  'consultar',
  'consulta',
];

const DeterministicFlow _bluetoothOpenFlow = DeterministicFlow(
  steps: [
    ToolCall(tool: 'open_system', args: {'destination': 'bluetooth_settings'}),
  ],
  expectation: GoalExpectation(expectedPackage: 'com.android.settings'),
  requiredAny: _openTerms,
  forbiddenAny: _stateChangingTerms,
);

const DeterministicFlow _wifiOpenFlow = DeterministicFlow(
  steps: [
    ToolCall(tool: 'open_system', args: {'destination': 'wifi_settings'}),
  ],
  expectation: GoalExpectation(expectedPackage: 'com.android.settings'),
  requiredAny: _openTerms,
  forbiddenAny: _stateChangingTerms,
);

const DeterministicFlow _notificationReadFlow = DeterministicFlow(
  steps: [ToolCall(tool: 'notifications')],
  // El resultado es el snapshot que Android devolvio; no necesita inferir un
  // estado visual posterior. Un fallo del listener conserva estado failed.
  outputProvesGoal: true,
  requiredAny: _notificationReadTerms,
);

const _listFilesTerms = <String>[
  'archivo',
  'directorio',
  'fichero',
  'carpeta',
];

/// "lista los archivos" → ls de la raíz del rootfs. El listado (stdout factual
/// de `ls`) ES la respuesta; no hay postcondición de estado que verificar.
const DeterministicFlow _listFilesFlow = DeterministicFlow(
  steps: [ToolCall(tool: 'linux.list', text: '/')],
  outputProvesGoal: true,
  requiredAny: _listFilesTerms,
);

/// T2.10 — navegación: scroll. Deliberadamente se excluyen términos de estado
/// (volumen/brillo/sonido) para que "baja el volumen" NO dispare un scroll.
const _scrollStateTerms = <String>[
  'volumen',
  'brillo',
  'sonido',
  'temperatura',
  'opacidad',
];

const DeterministicFlow _scrollDownFlow = DeterministicFlow(
  steps: [ToolCall(tool: 'scroll', args: {'direction': 'down'})],
  forbiddenAny: _scrollStateTerms,
);

const DeterministicFlow _scrollUpFlow = DeterministicFlow(
  steps: [ToolCall(tool: 'scroll', args: {'direction': 'up'})],
  forbiddenAny: _scrollStateTerms,
);

/// "lee la pantalla" / "qué dice la pantalla" → leer contenido visible (read-only).
/// El snapshot de accesibilidad ES la respuesta (`outputProvesGoal`): no hay
/// postcondición de estado que verificar, solo leer lo observado.
const _readScreenTerms = <String>[
  'lee',
  'leer',
  'ver',
  'muestra',
  'mostrar',
  'dice',
  'dime',
  'qué hay',
  'que hay',
  'read',
  'resume',
  'resumen',
  'resumir',
];

const DeterministicFlow _readScreenFlow = DeterministicFlow(
  steps: [ToolCall(tool: 'read_screen')],
  outputProvesGoal: true,
  requiredAny: _readScreenTerms,
);

const _newTabFlow = DeterministicFlow(
  steps: [
    ToolCall(
      tool: 'open_url',
      text: 'https://www.google.com',
      args: {'url': 'https://www.google.com', 'packageName': 'com.android.chrome'},
    ),
  ],
  expectation: GoalExpectation(expectedPackage: 'com.android.chrome'),
);

const _closeTabFlow = DeterministicFlow(
  steps: [
    ToolCall(
      tool: 'tap',
      args: {'target': 'com.android.chrome:id/close_button'},
      selector: 'com.android.chrome:id/close_button',
    ),
  ],
);

const _reloadPageFlow = DeterministicFlow(
  steps: [
    ToolCall(
      tool: 'swipe',
      args: {'x1': 540, 'y1': 300, 'x2': 540, 'y2': 900, 'durationMs': 350},
    ),
  ],
);

const DeterministicFlowCatalog defaultDeterministicCatalog =
    DeterministicFlowCatalog({
      'bluetooth': _bluetoothOpenFlow,
      'wi-fi': _wifiOpenFlow,
      'wifi': _wifiOpenFlow,
      'ajustes': DeterministicFlow(
        steps: [
          ToolCall(tool: 'open_system', args: {'destination': 'settings'}),
        ],
        expectation: GoalExpectation(expectedPackage: 'com.android.settings'),
        requiredAny: _openTerms,
      ),
      'configuración': DeterministicFlow(
        steps: [
          ToolCall(tool: 'open_system', args: {'destination': 'settings'}),
        ],
        expectation: GoalExpectation(expectedPackage: 'com.android.settings'),
        requiredAny: _openTerms,
      ),
      'chrome': DeterministicFlow(
        steps: [ToolCall(tool: 'launch_app', selector: 'com.android.chrome')],
        expectation: GoalExpectation(expectedPackage: 'com.android.chrome'),
        requiredAny: _openTerms,
      ),
      'nueva pestaña': _newTabFlow,
      'abrir pestaña': _newTabFlow,
      'cerrar pestaña': _closeTabFlow,
      'cierra la pestaña': _closeTabFlow,
      'recargar página': _reloadPageFlow,
      'recarga la página': _reloadPageFlow,
      'actualizar página': _reloadPageFlow,
      'notificaciones': _notificationReadFlow,
      'notificación': _notificationReadFlow,
      'pantalla': _readScreenFlow,
      'screen': _readScreenFlow,
      'página': _readScreenFlow,
      'pagina': _readScreenFlow,
      'artículo': _readScreenFlow,
      'articulo': _readScreenFlow,
      'web': _readScreenFlow,
      'archivo': _listFilesFlow,
      'directorio': _listFilesFlow,
      'fichero': _listFilesFlow,
      'carpeta': _listFilesFlow,
      'volver': DeterministicFlow(steps: [ToolCall(tool: 'back')], outputProvesGoal: true),
      'atrás': DeterministicFlow(steps: [ToolCall(tool: 'back')], outputProvesGoal: true),
      'volver atrás': DeterministicFlow(steps: [ToolCall(tool: 'back')], outputProvesGoal: true),
      'baja': _scrollDownFlow,
      'bajar': _scrollDownFlow,
      'sube': _scrollUpFlow,
      'subir': _scrollUpFlow,
      'escribir': DeterministicFlow(
        steps: [
          ToolCall(
            tool: 'write',
            selector: 'editable=true',
            text: 'Prueba NanoAI',
          ),
        ],
        outputProvesGoal: true,
      ),
      'contactos': DeterministicFlow(
        steps: [ToolCall(tool: 'whatsapp.contacts')],
        outputProvesGoal: true,
      ),
      'contacto': DeterministicFlow(
        steps: [ToolCall(tool: 'whatsapp.contacts')],
        outputProvesGoal: true,
      ),
      'desde llamadas': DeterministicFlow(
        steps: [ToolCall(tool: 'whatsapp.send_message')],
        outputProvesGoal: true,
        requiredAny: ['whatsapp'],
        forbiddenAny: ['youtube', 'google', 'spotify', 'netflix', 'chrome'],
      ),
      // W10: "busca a PERSONA en whatsapp" / "abre whatsapp y busca a PERSONA"
      // La partícula " a " tras el verbo buscar indica búsqueda de PERSONA
      // ── WhatsApp: buscar contacto y abrir conversación ────────────────────
      // 'busca a (Nombre)' y 'buscar a (Nombre)' → resuelve el contacto y abre WhatsApp.
      // requiredAny: solo aplica si el goal menciona 'whatsapp'.
      'busca a': DeterministicFlow(
        steps: [ToolCall(tool: 'whatsapp.open_chat')],
        outputProvesGoal: true,
        requiredAny: ['whatsapp'],
        forbiddenAny: ['youtube', 'google', 'spotify', 'netflix', 'chrome'],
      ),
      'buscar a': DeterministicFlow(
        steps: [ToolCall(tool: 'whatsapp.open_chat')],
        outputProvesGoal: true,
        requiredAny: ['whatsapp'],
        forbiddenAny: ['youtube', 'google', 'spotify', 'netflix', 'chrome'],
      ),

      // ── WhatsApp: abrir chat ───────────────────────────────────────────────
      // 'abre el chat de (Nombre)' → open_chat; el coordinator inyecta contacto.
      'abre el chat de': DeterministicFlow(
        steps: [ToolCall(tool: 'whatsapp.open_chat')],
        outputProvesGoal: true,
        requiredAny: ['whatsapp', 'chat'],
        forbiddenAny: ['youtube', 'google', 'spotify', 'netflix', 'chrome'],
      ),
      'abrir el chat de': DeterministicFlow(
        steps: [ToolCall(tool: 'whatsapp.open_chat')],
        outputProvesGoal: true,
        requiredAny: ['whatsapp', 'chat'],
        forbiddenAny: ['youtube', 'google', 'spotify', 'netflix', 'chrome'],
      ),
      'abre chat de': DeterministicFlow(
        steps: [ToolCall(tool: 'whatsapp.open_chat')],
        outputProvesGoal: true,
        requiredAny: ['whatsapp', 'chat'],
        forbiddenAny: ['youtube', 'google', 'spotify', 'netflix', 'chrome'],
      ),
      'abrir chat de': DeterministicFlow(
        steps: [ToolCall(tool: 'whatsapp.open_chat')],
        outputProvesGoal: true,
        requiredAny: ['whatsapp', 'chat'],
        forbiddenAny: ['youtube', 'google', 'spotify', 'netflix', 'chrome'],
      ),
      'chat': DeterministicFlow(
        steps: [ToolCall(tool: 'whatsapp.open_chat')],
        expectation: GoalExpectation(expectedPackage: 'com.whatsapp'),
      ),

      // ── WhatsApp: enviar mensaje ───────────────────────────────────────────
      // 'envíale a (Nombre) (Texto)' / 'escríbele a (Nombre) (Texto)' →
      // send_message. El coordinator extrae contacto y texto del goal.
      'envíale a': DeterministicFlow(
        steps: [ToolCall(tool: 'whatsapp.send_message')],
        outputProvesGoal: true,
        requiredAny: ['whatsapp'],
        forbiddenAny: ['youtube', 'google', 'spotify', 'netflix', 'chrome'],
      ),
      'enviale a': DeterministicFlow(
        steps: [ToolCall(tool: 'whatsapp.send_message')],
        outputProvesGoal: true,
        requiredAny: ['whatsapp'],
        forbiddenAny: ['youtube', 'google', 'spotify', 'netflix', 'chrome'],
      ),
      'escríbele a': DeterministicFlow(
        steps: [ToolCall(tool: 'whatsapp.send_message')],
        outputProvesGoal: true,
        requiredAny: ['whatsapp'],
        forbiddenAny: ['youtube', 'google', 'spotify', 'netflix', 'chrome'],
      ),
      'escribele a': DeterministicFlow(
        steps: [ToolCall(tool: 'whatsapp.send_message')],
        outputProvesGoal: true,
        requiredAny: ['whatsapp'],
        forbiddenAny: ['youtube', 'google', 'spotify', 'netflix', 'chrome'],
      ),
      'mándale a': DeterministicFlow(
        steps: [ToolCall(tool: 'whatsapp.send_message')],
        outputProvesGoal: true,
        requiredAny: ['whatsapp'],
        forbiddenAny: ['youtube', 'google', 'spotify', 'netflix', 'chrome'],
      ),
      'mandale a': DeterministicFlow(
        steps: [ToolCall(tool: 'whatsapp.send_message')],
        outputProvesGoal: true,
        requiredAny: ['whatsapp'],
        forbiddenAny: ['youtube', 'google', 'spotify', 'netflix', 'chrome'],
      ),
      'mensaje': DeterministicFlow(
        steps: [ToolCall(tool: 'whatsapp.send_message', args: {'text': 'Hola desde NanoAI'})],
        outputProvesGoal: true,
      ),
      'enviar': DeterministicFlow(
        steps: [ToolCall(tool: 'whatsapp.send_message', args: {'text': 'Hola desde NanoAI'})],
        outputProvesGoal: true,
      ),

      // ── WhatsApp: enviar fotos, documentos y archivos multimedia ──────────
      // 'envíale una foto a (Contacto) (ruta)' / 'envíale un documento a (Contacto)'
      'envíale una foto': DeterministicFlow(
        steps: [ToolCall(tool: 'whatsapp.share_file')],
        outputProvesGoal: true,
        requiredAny: ['whatsapp'],
        forbiddenAny: ['youtube', 'google', 'spotify', 'netflix', 'chrome'],
      ),
      'enviale una foto': DeterministicFlow(
        steps: [ToolCall(tool: 'whatsapp.share_file')],
        outputProvesGoal: true,
        requiredAny: ['whatsapp'],
        forbiddenAny: ['youtube', 'google', 'spotify', 'netflix', 'chrome'],
      ),
      'envíale un documento': DeterministicFlow(
        steps: [ToolCall(tool: 'whatsapp.share_file')],
        outputProvesGoal: true,
        requiredAny: ['whatsapp'],
        forbiddenAny: ['youtube', 'google', 'spotify', 'netflix', 'chrome'],
      ),
      'enviale un documento': DeterministicFlow(
        steps: [ToolCall(tool: 'whatsapp.share_file')],
        outputProvesGoal: true,
        requiredAny: ['whatsapp'],
        forbiddenAny: ['youtube', 'google', 'spotify', 'netflix', 'chrome'],
      ),
      'envíale un archivo': DeterministicFlow(
        steps: [ToolCall(tool: 'whatsapp.share_file')],
        outputProvesGoal: true,
        requiredAny: ['whatsapp'],
        forbiddenAny: ['youtube', 'google', 'spotify', 'netflix', 'chrome'],
      ),
      'enviale un archivo': DeterministicFlow(
        steps: [ToolCall(tool: 'whatsapp.share_file')],
        outputProvesGoal: true,
        requiredAny: ['whatsapp'],
        forbiddenAny: ['youtube', 'google', 'spotify', 'netflix', 'chrome'],
      ),
      'envíale una imagen': DeterministicFlow(
        steps: [ToolCall(tool: 'whatsapp.share_file')],
        outputProvesGoal: true,
        requiredAny: ['whatsapp'],
        forbiddenAny: ['youtube', 'google', 'spotify', 'netflix', 'chrome'],
      ),
      'enviale una imagen': DeterministicFlow(
        steps: [ToolCall(tool: 'whatsapp.share_file')],
        outputProvesGoal: true,
        requiredAny: ['whatsapp'],
        forbiddenAny: ['youtube', 'google', 'spotify', 'netflix', 'chrome'],
      ),
      'envíale un video': DeterministicFlow(
        steps: [ToolCall(tool: 'whatsapp.share_file')],
        outputProvesGoal: true,
        requiredAny: ['whatsapp'],
        forbiddenAny: ['youtube', 'google', 'spotify', 'netflix', 'chrome'],
      ),
      'enviale un video': DeterministicFlow(
        steps: [ToolCall(tool: 'whatsapp.share_file')],
        outputProvesGoal: true,
        requiredAny: ['whatsapp'],
        forbiddenAny: ['youtube', 'google', 'spotify', 'netflix', 'chrome'],
      ),
      'envíale un pdf': DeterministicFlow(
        steps: [ToolCall(tool: 'whatsapp.share_file')],
        outputProvesGoal: true,
        requiredAny: ['whatsapp'],
        forbiddenAny: ['youtube', 'google', 'spotify', 'netflix', 'chrome'],
      ),
      'enviale un pdf': DeterministicFlow(
        steps: [ToolCall(tool: 'whatsapp.share_file')],
        outputProvesGoal: true,
        requiredAny: ['whatsapp'],
        forbiddenAny: ['youtube', 'google', 'spotify', 'netflix', 'chrome'],
      ),
      'envía una foto': DeterministicFlow(
        steps: [ToolCall(tool: 'whatsapp.share_file')],
        outputProvesGoal: true,
        requiredAny: ['whatsapp'],
        forbiddenAny: ['youtube', 'google', 'spotify', 'netflix', 'chrome'],
      ),
      'envia una foto': DeterministicFlow(
        steps: [ToolCall(tool: 'whatsapp.share_file')],
        outputProvesGoal: true,
        requiredAny: ['whatsapp'],
        forbiddenAny: ['youtube', 'google', 'spotify', 'netflix', 'chrome'],
      ),
      'envía un documento': DeterministicFlow(
        steps: [ToolCall(tool: 'whatsapp.share_file')],
        outputProvesGoal: true,
        requiredAny: ['whatsapp'],
        forbiddenAny: ['youtube', 'google', 'spotify', 'netflix', 'chrome'],
      ),
      'envia un documento': DeterministicFlow(
        steps: [ToolCall(tool: 'whatsapp.share_file')],
        outputProvesGoal: true,
        requiredAny: ['whatsapp'],
        forbiddenAny: ['youtube', 'google', 'spotify', 'netflix', 'chrome'],
      ),

      // ── WhatsApp: lanzar app ───────────────────────────────────────────────
      // Solo abre la app sin acción adicional.
      // forbiddenAny incluye todos los verbos de búsqueda/envío para evitar
      // que "abre whatsapp y busca a X" caiga aquí en vez de 'busca a'.
      'whatsapp': DeterministicFlow(
        steps: [ToolCall(tool: 'launch_app', args: {'packageName': 'com.whatsapp'})],
        expectation: GoalExpectation(expectedPackage: 'com.whatsapp'),
        forbiddenAny: [
          'contacto', 'contactos', 'mensaje', 'chat',
          'busca a', 'buscar a',
          'envíale a', 'enviale a', 'escríbele a', 'escribele a',
          'mándale a', 'mandale a',
          'abre el chat de', 'abrir el chat de',
          'abre chat de', 'abrir chat de',
          'foto', 'documento', 'archivo', 'imagen', 'video', 'pdf',
        ],
      ),


      'abre ajustes, luego bluetooth, y vuelve': DeterministicFlow(
        steps: [
          ToolCall(tool: 'open_system', args: {'destination': 'settings'}),
          ToolCall(tool: 'open_system', args: {'destination': 'bluetooth_settings'}),
          ToolCall(tool: 'back'),
        ],
        outputProvesGoal: true,
      ),
      'dime si bluetooth': DeterministicFlow(
        steps: [ToolCall(tool: 'device_state')],
        outputProvesGoal: true,
      ),
      'nano': DeterministicFlow(
        steps: [
          ToolCall(
            tool: 'launch_app',
            args: {'packageName': 'dev.nanoai.mobile'},
          ),
        ],
        expectation: GoalExpectation(expectedPackage: 'dev.nanoai.mobile'),
      ),
    });
